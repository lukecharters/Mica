// Views/Sidebar/LayerThumbnail.swift
//
// One layer, drawn small, for its sidebar row.
//
// **This is the real render, not a copy of it.** The settings arrive with every
// other layer hidden (`IconSettings.isolatingLayer(_:_:)`) and go straight into
// `IconContentView` or `BadgeView`, the same views the preview and the export
// draw. The thumbnails that were here until 2026-07-25 re-implemented a slice of
// the render each and drifted from it; do not add a hand-drawn branch back.
//
// Live and synchronous, like the preset thumbnails, because the sidebar shows no
// layer rows in System mode — so no appex raster is ever needed here.

import SwiftUI

struct LayerThumbnail: View {
    let group: IconLayerGroup
    let layer: LayerTab
    /// Already isolated to the one layer this thumbnail shows.
    let settings: IconSettings
    let size: CGFloat

    /// A badge background is drawn centred at this fraction of the tile, not in
    /// its corner of a full icon canvas, where it would be a few points across.
    /// The badge's own scale and position are deliberately not shown: they are
    /// the Layout row's business, and a thumbnail is not where anyone reads them.
    static let badgeRatio: CGFloat = 0.8

    /// A foreground is zoomed until its box spans this fraction of the tile. The
    /// box is the symbol's point size, and most glyphs' ink sits inside it.
    static let foregroundRatio: CGFloat = 0.8

    /// A foreground scaled right down would otherwise be rendered at a canvas
    /// many times the tile for no visible gain.
    static let maxZoom: CGFloat = 12

    static let cornerRadius: CGFloat = 6

    var body: some View {
        render
            .frame(width: size, height: size)
            .background { CheckerboardBackground() }
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 1)
            }
    }

    @ViewBuilder
    private var render: some View {
        if let zoom = Self.foregroundZoom(group: group, layer: layer, settings: settings, size: size) {
            // The whole icon, drawn larger and shifted so the glyph's box lands
            // centred in the tile; the tile's clip crops the rest. Rendering at a
            // bigger canvas rather than scaling the view keeps the glyph sharp.
            IconContentView(settings: settings, displaySize: size * zoom.scale)
                .offset(zoom.offset)
        } else {
            switch group {
            case .icon:
                IconContentView(settings: settings, displaySize: size)
            case .badge:
                BadgeView(settings: settings, badgeSize: size * Self.badgeRatio)
            }
        }
    }

    /// How far to zoom a foreground, and where to move it, so its glyph fills the
    /// tile. Nil for a background, and for a foreground with nothing drawn.
    ///
    /// The box is `PreviewHitTester.selectionShape`'s, the one the canvas outlines
    /// when this layer is selected, so the thumbnail frames exactly what the
    /// selection does and follows the calibration offset and the user's nudge.
    static func foregroundZoom(
        group: IconLayerGroup, layer: LayerTab, settings: IconSettings, size: CGFloat
    ) -> (scale: CGFloat, offset: CGSize)? {
        guard layer == .foreground else { return nil }
        let selection: PreviewSelection = group == .icon ? .iconForeground : .badgeForeground
        guard case let .roundedRect(box, _) = PreviewHitTester.selectionShape(
            for: selection, settings: settings, displaySize: size) else { return nil }
        let side = max(box.width, box.height)
        guard side > 0 else { return nil }
        let scale = min(size * foregroundRatio / side, maxZoom)
        return (scale, CGSize(width: (size / 2 - box.midX) * scale,
                              height: (size / 2 - box.midY) * scale))
    }
}

/// The transparency ground behind a layer.
///
/// **A grey pair per appearance, kept away from white and black, not `.primary`
/// at an opacity.** The default foreground is a white symbol, and a ground built
/// from `.primary` is near-white in light mode, so the glyph vanished into it.
/// Mid-light greys in light mode and mid-dark greys in dark mode follow the
/// appearance while keeping a white glyph, a black one and a coloured background
/// legible in both.
private struct CheckerboardBackground: View {
    var squareSize: CGFloat = 7

    @Environment(\.colorScheme) private var colorScheme

    private var greys: (base: Double, square: Double) {
        colorScheme == .dark ? (0.30, 0.40) : (0.72, 0.82)
    }

    var body: some View {
        let greys = greys
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(white: greys.base)))
            let columns = Int((size.width / squareSize).rounded(.up))
            let rows = Int((size.height / squareSize).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let square = CGRect(x: CGFloat(column) * squareSize,
                                        y: CGFloat(row) * squareSize,
                                        width: squareSize,
                                        height: squareSize)
                    context.fill(Path(square), with: .color(Color(white: greys.square)))
                }
            }
        }
    }
}

private struct ThumbnailStrip: View {
    let settings = IconSettings()

    var body: some View {
        HStack {
            ForEach([IconLayerGroup.icon, .badge], id: \.self) { group in
                ForEach([LayerTab.foreground, .background], id: \.self) { tab in
                    if let isolated = settings.isolatingLayer(group, tab) {
                        LayerThumbnail(group: group, layer: tab, settings: isolated, size: 32)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview("Light") {
    ThumbnailStrip()
        .environment(\.colorScheme, .light)
}

#Preview("Dark") {
    ThumbnailStrip()
        .environment(\.colorScheme, .dark)
        .background(Color(white: 0.15))
}
