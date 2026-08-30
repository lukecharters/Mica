// Views/Presets/PresetThumbnail.swift
//
// What a preset looks like, drawn in isolation on neutral ground.
//
// **A catalogue, not a preview of the current document.** Every thumbnail renders the
// preset over `IconSettings()` and nothing else, so the pane is stable while the icon
// is being edited — a preset row does not change because the user picked a different
// background colour.
//
// Both kinds are plain SwiftUI views over `IconContentView`, which is what makes them
// live and cheap: **no `ImageRenderer`, no cache, no bundled PNGs, and no loading
// state.** That is a property of the built-in set having no System-mode entry — an
// appex icon needs an async raster per thumbnail — and it stops being true the moment
// one is added. Don't build a cache speculatively; build it then.
//
// **These views take settings, not a preset**, and that is not incidental: decoding a
// preset costs a `JSONSerialization` round trip plus the whole configuration decoder,
// so reading it from a computed property here meant paying for it on every body
// evaluation. `ResolvedPreset` does it once. Do not add a `MicaPreset` parameter back.

import SwiftUI

// MARK: - Icon

/// An icon preset at thumbnail size. `settings` arrives with the badge already
/// suppressed — see `ResolvedPreset.thumbnailSettings(for:)`.
struct IconPresetThumbnail: View {
    let settings: IconSettings
    var size: CGFloat = PresetPaneMetrics.thumbnailSize

    var body: some View {
        IconContentView(settings: settings, displaySize: size)
            .frame(width: size, height: size)
    }
}

// MARK: - Badge

/// A badge preset over the corner of a ghost icon.
///
/// **Built by cropping the real renderer, not by drawing a circle next to a rect.**
/// The ghost icon is composited at twice thumbnail size through `IconContentView` and
/// then clipped to the quadrant the badge sits in, so position, scale and both offsets
/// come out truthful for free — `BadgeGeometry` computed them, and there is no second
/// geometry implementation to keep in step. This codebase already goes out of its way
/// to avoid that: `PreviewHitTester` and the selection outline both read
/// `BadgeGeometry` for exactly this reason.
///
/// The crop is what makes the thumbnail *say which corner*, which is in turn why
/// `badge-position` is in a badge preset's scope at all. A thumbnail showing a corner
/// the preset does not set would be decoration.
///
/// `settings` arrives already staged as the ghost.
struct BadgePresetThumbnail: View {
    let settings: IconSettings
    var size: CGFloat = PresetPaneMetrics.thumbnailSize

    /// The whole ghost icon, of which one quadrant is shown.
    ///
    /// **Exactly 2×**, so the crop is a quadrant and the badge lands where the
    /// arithmetic says. The badge anchor is `BadgeGeometry.anchorXRatio` (≈0.365) of
    /// the *enclosure*, which is 206/256 of the canvas, so its centre sits ≈0.79 of
    /// the way across — comfortably inside the far half — and its diameter comes to
    /// roughly 62% of the crop. Any other factor either clips the badge or floats it
    /// in an acre of grey.
    ///
    /// **The empty band along the two edges the badge does not touch is the canvas,
    /// and it cannot be cropped away.** `IconContentView` insets the chiclet by 25/256
    /// on each side, so a quadrant shows ~20% of nothing at the far right and bottom.
    /// Sliding the crop inward to cut it was written, measured and removed on
    /// 2026-08-30: at the default badge scale the shadow's own extent already reaches
    /// to within 1.5pt of the canvas corner (reach 82.5 against a half-canvas of 84 at
    /// this size), so the shift computes to **zero** and the code did nothing at all.
    /// The band is real geometry — a badge does hang off the chiclet's corner — and
    /// showing it is the thumbnail being truthful rather than a defect to fix. Don't
    /// re-derive this; the arithmetic is in `BadgeGeometry.extents`.
    private var ghostSize: CGFloat { size * 2 }

    /// Which quadrant to keep. The badge's own corner, in SwiftUI's alignment
    /// vocabulary — derived from the preset rather than fixed, which is the whole
    /// point of the crop.
    private var cropAlignment: Alignment {
        switch settings.badge.position {
        case .topLeft:     return .topLeading
        case .topRight:    return .topTrailing
        case .bottomLeft:  return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }

    var body: some View {
        IconContentView(settings: settings, displaySize: ghostSize)
            .frame(width: ghostSize, height: ghostSize)
            // Frame first, then clip: the frame chooses the quadrant by pushing the
            // oversized content to the opposite corner, and the clip is what actually
            // removes the other three. Reversing them clips nothing, because the
            // content is still its full size when the clip applies.
            .frame(width: size, height: size, alignment: cropAlignment)
            .clipped()
    }
}

// MARK: - Either

/// The right thumbnail for a preset's scope, so call sites do not branch.
struct PresetThumbnail: View {
    let resolved: ResolvedPreset
    var size: CGFloat = PresetPaneMetrics.thumbnailSize

    var body: some View {
        switch resolved.scope {
        case .icon:
            IconPresetThumbnail(settings: resolved.thumbnailSettings, size: size)
        case .badge:
            BadgePresetThumbnail(settings: resolved.thumbnailSettings, size: size)
        }
    }
}
