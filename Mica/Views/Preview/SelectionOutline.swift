// Views/Preview/SelectionOutline.swift
import SwiftUI

/// Accent outline tracing the layer the inspector is editing, the way Icon
/// Composer marks the selected element — but it fades out after a moment so it
/// doesn't sit over the artwork while you judge colours.
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
    /// Which layer this outline is for. Changing it restarts the fade.
    var selection: PreviewSelection
    /// Bumped by the owner on every canvas click, so clicking the layer that's
    /// already selected re-shows the outline instead of doing nothing visible.
    var pulse: Int = 0
    /// Set false to hold the outline indefinitely (used by previews).
    var autoFade: Bool = true

    /// How long the outline stays at full strength before fading.
    private static let holdDuration: Duration = .milliseconds(500)
    private static let fadeDuration: TimeInterval = 0.2

    @State private var isVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Restart key: either a different layer, or another click on the same one.
    private struct FadeKey: Equatable {
        let selection: PreviewSelection
        let pulse: Int
    }

    private var lineWidth: CGFloat {
        // 2pt at the 256pt reference, clamped so extreme zooms stay usable.
        min(max(2 * (displaySize / 256), 1), 6)
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

            context.stroke(path, with: .color(.accentColor), lineWidth: lineWidth)
        }
        .frame(width: canvasSize, height: canvasSize)
        .allowsHitTesting(false)
        .opacity(isVisible ? 1 : 0)
        // Reduce Motion keeps the behaviour but drops the cross-fade.
        .animation(reduceMotion ? nil : .easeOut(duration: Self.fadeDuration), value: isVisible)
        .task(id: FadeKey(selection: selection, pulse: pulse)) {
            guard autoFade else {
                isVisible = true
                return
            }
            isVisible = true
            try? await Task.sleep(for: Self.holdDuration)
            guard !Task.isCancelled else { return }
            isVisible = false
        }
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
                            displaySize: displaySize,
                            selection: selection,
                            // Hold them so the preview is inspectable.
                            autoFade: false
                        )
                    }
                }
            }
        }
    }
    .padding()
    .onAppear { settings.showBadge = true }
}
