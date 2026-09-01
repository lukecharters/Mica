// Views/Presets/PresetThumbnail.swift
//
// What a preset looks like, drawn in isolation on neutral ground.
//
// **The ground, the clip and the border are not here** — they are
// `presetTileChrome()` in `PresetList.swift`, one shape applied once. They were split
// across two files with two radii and two corner styles until 2026-08-31, which is how
// the border came to be drawn with its corners clipped off.
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
    var size: CGFloat = PresetGridMetrics.thumbnailSize

    var body: some View {
        // No ground, clip or border here: `presetTileChrome()` owns all three, over
        // one shape. This view used to stroke a 6pt radius inside a 10pt continuous
        // clip, which is how the border lost its corners.
        IconContentView(settings: settings, displaySize: size)
            .frame(width: size, height: size)
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
    var size: CGFloat = PresetGridMetrics.thumbnailSize

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
        ZStack {
            ghostLayer
            badgeLayer
        }
        // Frame first, then clip: the frame picks the window by centring the
        // oversized content, and the clip is what actually removes the rest.
        // Reversing them clips nothing, because the content is still its full size
        // when the clip applies.
        .frame(width: size, height: size, alignment: .center)
        .clipped()
    }

    /// The placeholder chiclet, at a quarter weight.
    ///
    /// **`.opacity` on the render, not a colour of its own — and a mask was tried and
    /// reverted.** The ghost has to be adaptive, and the only adaptive colours
    /// `IconSettings` can carry are `ColorTokenTable`'s two semantic tokens: `primary`
    /// (~85% of label) and `secondary` (~50%). `secondary` was the original choice and
    /// is too heavy against the badge — the thing in this thumbnail the user is
    /// actually being asked to look at. Adding a lighter token would put a colour into
    /// the app's user-facing vocabulary and the CLI's colour grammar for the sake of a
    /// thumbnail, and extracting components from a dynamic `NSColor` is not possible at
    /// all: `NSColor.colorSpace` raises on one.
    ///
    /// So the colour is `primary` and the *weight* is here: 0.85 × 0.30 ≈ **0.25**,
    /// which is `tertiaryLabelColor`'s alpha and a little under half what `secondary`
    /// was. Measured luminance delta against the `controlBackgroundColor` ground, and
    /// it barely moves between appearances — 0.26 light, 0.22 dark.
    ///
    /// **A rejected version filled a rectangle and masked it with this render**, to
    /// reach `tertiarySystemFill` directly. What killed it is why the `*SystemFill`
    /// family cannot be used here at all: **those fills are 2–5% contrast against this
    /// ground.** Measured alphas — `quaternarySystemFill` 0.027, `tertiarySystemFill`
    /// 0.047, `secondarySystemFill` 0.078. They are built to tint a control sitting on
    /// a window, not to be the only thing separating two greys. Shipped for one build,
    /// `tertiarySystemFill` rendered the tile as flat quadrants with no readable chiclet
    /// at all. `.opacity` on the render reaches a usable weight without a mask, and
    /// keeps `IconContentView` authoritative for every pixel of the shape.
    ///
    /// **The ghost's rounded corner is not visible, and that is correct.** The crop is
    /// centred on the badge, and the badge sits *at* a corner of the chiclet, so the
    /// arc is directly behind it; what shows either side of the badge is the chiclet's
    /// two straight edges leaving the frame. This reads as a squared-off ghost in a
    /// screenshot and cost an investigation — the shape is fine, the badge is simply in
    /// front of it. Which corner is still legible from *where the grey mass sits*, and
    /// that is what `badge-position` being in scope buys.
    private var ghostLayer: some View {
        IconContentView(settings: Self.ghostOnly(settings), displaySize: ghostSize)
            .frame(width: ghostSize, height: ghostSize)
            .opacity(Self.ghostOpacity)
            // `.offset` is layout-neutral — it reports the child's original size — so
            // the frame above still centres the full ghost and only the *drawing*
            // slides. That is what lets the crop be aimed without the frame chasing it.
            .offset(cropShift)
    }

    /// Multiplied into the `primary` token's ~0.85 to land at ≈0.25. See `ghostLayer`.
    private static let ghostOpacity: Double = 0.10

    /// The badge, drawn over the ghost at the same geometry.
    ///
    /// **A second `IconContentView` pass rather than one shared with the ghost**, which
    /// is what lets the ghost be recoloured without touching the badge: a mask over a
    /// single render would have taken the badge's colours with it. Both passes are the
    /// same cheap SwiftUI view at the same `displaySize`, so the badge lands in exactly
    /// the same place in both — `BadgeGeometry.offset` reads the enclosure, which the
    /// icon's layer visibility does not change.
    private var badgeLayer: some View {
        IconContentView(settings: Self.badgeOnly(settings), displaySize: ghostSize)
            .frame(width: ghostSize, height: ghostSize)
            .offset(cropShift)
    }

    /// The staged settings with the badge switched off — the mask's source.
    private static func ghostOnly(_ settings: IconSettings) -> IconSettings {
        var copy = settings
        copy.badge.isHidden = true
        return copy
    }

    /// The staged settings with both icon layers switched off.
    ///
    /// The foreground is already hidden by the staging; the background goes too, so
    /// the chiclet is drawn once — by `ghostLayer` — rather than twice, with this pass
    /// laying an opaque black one over the tinted one.
    private static func badgeOnly(_ settings: IconSettings) -> IconSettings {
        var copy = settings
        copy.icon.foreground.isHidden = true
        copy.icon.background.isHidden = true
        return copy
    }
}

// MARK: - Either

/// The right thumbnail for a preset's scope, so call sites do not branch.
struct PresetThumbnail: View {
    let resolved: ResolvedPreset
    var size: CGFloat = PresetGridMetrics.thumbnailSize

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
            GridItem(.fixed(PresetGridMetrics.thumbnailSize)),
            GridItem(.fixed(PresetGridMetrics.thumbnailSize)),
        ]) {
            ForEach(resolved) { PresetThumbnail(resolved: $0).presetTileChrome() }
        }
        .padding()
    }
}
