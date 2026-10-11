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
    /// Already isolated to the one layer this thumbnail shows.
    let settings: IconSettings
    let size: CGFloat

    /// A badge layer is drawn centred at this fraction of the tile, not in its
    /// corner of a full icon canvas, where it would be a few points across. The
    /// badge's own scale and position are deliberately not shown: they are the
    /// Layout row's business, and a thumbnail is not where anyone reads them.
    static let badgeRatio: CGFloat = 0.8

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
        switch group {
        case .icon:
            IconContentView(settings: settings, displaySize: size)
        case .badge:
            BadgeView(settings: settings, badgeSize: size * Self.badgeRatio)
        }
    }
}

/// The transparency ground behind a layer.
///
/// **Fixed mid-greys, not `.primary` at an opacity.** The default foreground is a
/// white symbol, and a ground that follows the appearance is near-white in light
/// mode — the glyph vanished into it. Two greys between black and white keep a
/// white glyph, a black one and a coloured background all legible in either
/// appearance.
private struct CheckerboardBackground: View {
    var squareSize: CGFloat = 3

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(white: 0.62)))
            let columns = Int((size.width / squareSize).rounded(.up))
            let rows = Int((size.height / squareSize).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let square = CGRect(x: CGFloat(column) * squareSize,
                                        y: CGFloat(row) * squareSize,
                                        width: squareSize,
                                        height: squareSize)
                    context.fill(Path(square), with: .color(Color(white: 0.72)))
                }
            }
        }
    }
}

#Preview {
    let settings = IconSettings()
    HStack {
        ForEach([LayerTab.foreground, .background], id: \.self) { tab in
            if let isolated = settings.isolatingLayer(.icon, tab) {
                LayerThumbnail(group: .icon, settings: isolated, size: 36)
            }
        }
        ForEach([LayerTab.foreground, .background], id: \.self) { tab in
            if let isolated = settings.isolatingLayer(.badge, tab) {
                LayerThumbnail(group: .badge, settings: isolated, size: 36)
            }
        }
    }
    .padding()
}
