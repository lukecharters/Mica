// Views/Presets/PresetThumbnail.swift
//
// What a preset looks like, drawn in isolation on neutral ground.
//
// **The ground, the clip and the border are not here** — they are
// `presetTileChrome()` in `PresetGrid.swift`, one shape applied once. They were split
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

    /// The render's size as a fraction of the tile. `IconContentView` insets the
    /// chiclet by 25/256 of the render on each side, so this is the dial on how much
    /// ground shows around it.
    static let renderRatio: CGFloat = 0.9

    var body: some View {
        // No ground, clip or border here: `presetTileChrome()` owns all three, over
        // one shape.
        IconContentView(settings: settings, displaySize: size * Self.renderRatio)
            .frame(width: size, height: size)
    }
}

// MARK: - Badge

/// A badge preset: the badge alone, centred, with an arrow in the corner it goes to.
///
/// **The badge is drawn by `BadgeView` itself**, at the diameter `BadgeGeometry` gives a
/// badge of this preset's scale, so the scale is truthful and there is no second sizing
/// rule to keep in step. The corner is said by the arrow, and the ground under it is
/// the tile's own flat `controlBackgroundColor`, so the arrow needs no background.
///
/// `settings` arrives with both icon layers hidden — see
/// `ResolvedPreset.thumbnailSettings(for:)`.
struct BadgePresetThumbnail: View {
    let settings: IconSettings
    var size: CGFloat = PresetGridMetrics.thumbnailSize

    /// The enclosure a badge of this preset's scale is sized against, as a multiple of
    /// the tile. At 1.43 a scale-1 badge is about 55% of the tile, which leaves the
    /// corners clear for the arrow.
    static let enclosureRatio: CGFloat = 1.8

    private var badgeSize: CGFloat {
        BadgeGeometry.diameter(enclosureSize: size * Self.enclosureRatio,
                               badgeScale: settings.badge.scale)
    }

    var body: some View {
        BadgeView(settings: settings, badgeSize: badgeSize)
            .frame(width: size, height: size)
            .overlay(alignment: settings.badge.position.cornerAlignment) {
                Image(systemName: settings.badge.position.cornerArrowSymbolName)
                    .font(.system(size: PresetGridMetrics.cornerArrowSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(PresetGridMetrics.cornerArrowInset)
                    .accessibilityHidden(true)
            }
    }
}

extension BadgePosition {
    /// The arrow a badge thumbnail draws in this corner, pointing into it.
    var cornerArrowSymbolName: String {
        switch self {
        case .topLeft:     "arrow.up.left"
        case .topRight:    "arrow.up.right"
        case .bottomLeft:  "arrow.down.left"
        case .bottomRight: "arrow.down.right"
        }
    }

    var cornerAlignment: Alignment {
        switch self {
        case .topLeft:     .topLeading
        case .topRight:    .topTrailing
        case .bottomLeft:  .bottomLeading
        case .bottomRight: .bottomTrailing
        }
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

/// Every built-in, through the same resolve step the list uses, so both scopes'
/// staging and the corner arrows are on show.
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
