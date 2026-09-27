// Views/Preview/UnresolvedSymbolMarker.swift
import SwiftUI

/// A red outline and a placeholder glyph over each layer whose symbol will not draw.
///
/// Preview-only, like `PreviewOutlineOverlay`: it lives here rather than in
/// `IconContentView` so it can never reach an export. Which layers is
/// `SymbolAvailability.markedLayers`; where they are is `PreviewHitTester`.
struct UnresolvedSymbolMarker: View {
    let settings: IconSettings
    let displaySize: CGFloat
    let layers: [PreviewSelection]

    var body: some View {
        ZStack {
            ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                if let shape = PreviewHitTester.selectionShape(for: layer, settings: settings, displaySize: displaySize) {
                    marker(for: shape)
                }
            }
        }
        .frame(width: displaySize, height: displaySize)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func marker(for shape: PreviewSelectionShape) -> some View {
        let (path, bounds) = Self.geometry(of: shape)
        path
            .stroke(Color.red, style: StrokeStyle(lineWidth: max(1.5, displaySize / 170), dash: [displaySize / 64, displaySize / 128]))
        Image(systemName: "questionmark.square.dashed")
            .font(.system(size: min(bounds.width, bounds.height) * 0.4))
            .foregroundStyle(Color.red)
            .position(x: bounds.midX, y: bounds.midY)
    }

    private static func geometry(of shape: PreviewSelectionShape) -> (Path, CGRect) {
        switch shape {
        case .roundedRect(let rect, let cornerRadius):
            return (Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous), rect)
        case .circle(let center, let radius):
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            return (Path(ellipseIn: rect), rect)
        }
    }
}

#Preview {
    var settings = IconSettings()
    settings.icon.foreground.symbolName = "zz.not.a.symbol"
    settings.badge.isVisible = true
    return ZStack {
        IconContentView(settings: settings, displaySize: 256)
        UnresolvedSymbolMarker(settings: settings, displaySize: 256, layers: [.iconForeground, .badgeForeground])
    }
    .padding()
}
