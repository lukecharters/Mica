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
            .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .systemFill), lineWidth: 1)
                )
    }
}

// MARK: - Badge

/// A badge preset, centred, over the corner of a ghost icon.
///
/// **Built by cropping the real renderer, not by drawing a circle next to a rect.**
/// The ghost icon is composited at twice thumbnail size through `IconContentView` and
/// then clipped, so scale and both offsets come out truthful for free —
/// `BadgeGeometry` computed them, and there is no second geometry implementation to
/// keep in step. This codebase already goes out of its way to avoid that:
/// `PreviewHitTester` and the selection outline both read `BadgeGeometry` for exactly
/// this reason.
///
/// **The crop is centred on the badge, not anchored to the icon's corner.** Anchoring
/// was the first shape and it put the badge low and right of the tile's middle, with
/// the canvas's own empty inset filling the two edges the badge does not reach — a
/// composition that reads as a mistake even though every pixel of it is truthful.
///
/// The corner survives the change, which is what makes it safe: the badge is centred
/// and the **ghost chiclet is not**, so the grey mass sits up and to the left for a
/// `bottomRight` preset, down and to the left for a `topRight` one, and so on. The
/// thumbnail still says which corner; it says it with the icon rather than with the
/// frame. That is why `badge-position` stays in a badge preset's scope.
///
/// `settings` arrives already staged as the ghost.
struct BadgePresetThumbnail: View {
    let settings: IconSettings
    var size: CGFloat = PresetPaneMetrics.thumbnailSize

    /// The whole ghost icon, of which a badge-sized window is shown.
    ///
    /// **Exactly 2×.** The badge's diameter is `BadgeGeometry.diameterRatio` (≈0.385)
    /// of the *enclosure*, which is 206/256 of the canvas, so at 2× it comes to
    /// roughly 62% of the crop — big enough to read, with room for the chiclet edge
    /// behind it. Larger and the grey fills the tile; smaller and the badge floats.
    private var ghostSize: CGFloat { size * 2 }

    /// The enclosure the ghost renders at, which is what `BadgeGeometry` works in.
    ///
    /// `IconContentView` insets the chiclet by 25/256 of the canvas on each side, so
    /// the enclosure is 206/256 of it. `enclosureToCanvasRatio` is that same number
    /// the other way up — read from `BadgeGeometry` rather than restated, since a
    /// second copy of the inset is exactly the drift the crop exists to avoid.
    private var ghostEnclosure: CGFloat {
        ghostSize / BadgeGeometry.enclosureToCanvasRatio
    }

    /// How far to slide the ghost so the badge lands in the middle of the crop.
    ///
    /// The negative of where `BadgeGeometry` puts the badge — which is the whole
    /// point of asking it rather than reproducing the anchor arithmetic here. It is
    /// the *clamped* offset, so a badge pushed inward by an oversized scale is
    /// centred where it actually draws rather than where its anchor would have been.
    ///
    /// **A nudged badge therefore looks un-nudged**, since the crop follows it. That
    /// is the one thing this framing gives up: `badge-offset-x` and `badge-offset-y`
    /// still move the *chiclet* behind the badge, which is a much fainter tell than
    /// the badge moving. Accepted — the offsets are a fine adjustment, and a thumbnail
    /// is not where anyone reads one.
    private var cropShift: CGSize {
        let centre = BadgeGeometry.offset(for: settings, enclosureSize: ghostEnclosure)
        return CGSize(width: -centre.width, height: -centre.height)
    }

    var body: some View {
        IconContentView(settings: settings, displaySize: ghostSize)
            .frame(width: ghostSize, height: ghostSize)
            // `.offset` is layout-neutral — it reports the child's original size — so
            // the frame below still centres the full ghost and only the *drawing*
            // slides. That is what lets the crop be aimed without the frame chasing it.
            .offset(cropShift)
            // Frame first, then clip: the frame picks the window by centring the
            // oversized content, and the clip is what actually removes the rest.
            // Reversing them clips nothing, because the content is still its full size
            // when the clip applies.
            .frame(width: size, height: size, alignment: .center)
            .clipped()
            .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .systemFill), lineWidth: 1)
                )
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

// MARK: - Preview

/// Every built-in, through the same resolve step the pane uses — so both scopes'
/// staging and the badge crop are on show, at the pane's own two-column width.
#Preview {
    let resolved = ResolvedPreset.resolve(PresetCatalog.builtIn)
    ScrollView {
        LazyVGrid(columns: [
            GridItem(.fixed(PresetPaneMetrics.thumbnailSize)),
            GridItem(.fixed(PresetPaneMetrics.thumbnailSize)),
        ]) {
            ForEach(resolved) { PresetThumbnail(resolved: $0) }
        }
        .padding()
    }
}
