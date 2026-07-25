// Views/Preview/SelectionOutline.swift
import SwiftUI

/// Accent outline tracing the layer the inspector is editing, the way Icon
/// Composer marks the selected element.
///
/// Preview-only chrome: it lives here rather than in `IconContentView` so it can
/// never reach an export. Its geometry comes from
/// `PreviewHitTester.selectionShape(for:...)`, so the outline is exactly the
/// region a click resolves to.
struct SelectionOutline: View {
    let shape: PreviewSelectionShape
    /// Canvas side length; the shape's coordinates are relative to this square.
    let canvasSize: CGFloat
    /// Scales the stroke with the preview so it stays hairline-thin when zoomed out
    /// and doesn't turn into a thick band when zoomed in.
    var displaySize: CGFloat

    private var lineWidth: CGFloat {
        // 1.5pt at the 256pt reference, clamped so extreme zooms stay usable.
        min(max(1.5 * (displaySize / 256), 1), 6)
    }

    var body: some View {
        Canvas { context, _ in
            let path: Path
            switch shape {
            case .roundedRect(let rect, let cornerRadius):
                path = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
            case .circle(let center, let radius):
                path = Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }

            // Dark halo first so the accent stays legible over a same-coloured
            // layer (a blue chiclet under a blue outline).
            context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: lineWidth * 2)
            context.stroke(path, with: .color(.accentColor), lineWidth: lineWidth)
        }
        .frame(width: canvasSize, height: canvasSize)
        .allowsHitTesting(false)
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    let displaySize: CGFloat = 256

    VStack(spacing: 24) {
        ForEach(
            [
                ("Icon background", PreviewSelection.iconBackground),
                ("Icon foreground", .iconForeground),
                ("Badge", .badge),
                ("Badge foreground", .badgeForeground)
            ],
            id: \.0
        ) { label, selection in
            VStack(spacing: 4) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                ZStack {
                    IconContentView(settings: settings, displaySize: displaySize)
                    if let shape = PreviewHitTester.selectionShape(
                        for: selection,
                        settings: settings,
                        displaySize: displaySize
                    ) {
                        SelectionOutline(
                            shape: shape,
                            canvasSize: IconContentView.totalCanvasSize(for: settings, displaySize: displaySize),
                            displaySize: displaySize
                        )
                    }
                }
            }
        }
    }
    .padding()
    .onAppear { settings.showBadge = true }
}
