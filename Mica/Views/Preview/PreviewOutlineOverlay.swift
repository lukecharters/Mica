// Views/Preview/PreviewOutlineOverlay.swift
import SwiftUI

/// The accent outlines over the preview: the layer the inspector is editing, and
/// the layer under the pointer, in two weights — Icon Composer's pattern, measured
/// on 2026-08-22 (`docs/plans/hover-and-selection-outlines-2026-08-22.md` §1).
///
/// Preview-only chrome: it lives here rather than in `IconContentView` so it can
/// never reach an export. Its geometry comes from
/// `PreviewHitTester.selectionShape(for:...)`, so an outline is exactly the region
/// a click resolves to.
///
/// **This view owns the fade, and that is the reason it exists.** The hold used to
/// sit inside the view that drew the stroke, which was fine while there was one
/// outline and wrong the moment there were two: the measurement says both fade
/// *together* on a single idle timer, and two independently-keyed strokes would
/// drift apart the first time only one of them changed. So the stroke below is
/// stateless and the timer is here, above both.
struct PreviewOutlineOverlay: View {
    let settings: IconSettings
    /// Canvas side length — the shapes' coordinates are relative to this square,
    /// and the strokes scale with it so they stay hairline-thin zoomed out and don't
    /// become a band zoomed in. One value for both because the canvas is always the
    /// display size: a badge that would overhang it is moved inward by
    /// `BadgeGeometry` rather than growing the canvas.
    let displaySize: CGFloat
    /// The layer the inspector is editing, drawn at the selected weight.
    var selected: PreviewSelection?
    /// The layer under the pointer, drawn at the hover weight. Hovering the layer
    /// that is already selected draws the selected weight alone — see
    /// `PreviewOutlines.resolve`.
    var hovered: PreviewSelection?
    /// Bumped by the owner whenever the pointer moves over the canvas or the
    /// hovered sidebar row changes. Restarting the hold on it is what makes rule 3
    /// work — moving anywhere over the canvas brings the selected outline back —
    /// and it is why re-clicking the already-selected layer still flashes it.
    var wake: Int = 0
    /// Set false to hold the outlines indefinitely (used by previews).
    var autoFade: Bool = true

    /// How long the outlines stay up after the last wake.
    ///
    /// Icon Composer holds for roughly 1–1.5s: measured present at +1.0s and gone
    /// by +1.5s, with a 0.79s capture latency on either figure. 1.5s is the user's
    /// call between that bracket and the 3s the brief asked for — and it is
    /// deliberately *longer* than the 500ms Mica held while the selection was the
    /// only thing outlined, because a hover that vanishes before you have looked at
    /// it is worse than one that lingers.
    private static let holdDuration: Duration = .milliseconds(1500)
    /// **Only the fade *out* is animated.** An outline appears the instant the
    /// pointer asks for it — anything else reads as lag on a control the user is
    /// steering — and then fades rather than blinking away, which is what
    /// distinguishes "it timed out" from "it moved". Same asymmetry as a scrollbar.
    private static let fadeDuration: TimeInterval = 0.2

    @State private var isVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Restart key: a different selection, a different hover, or any pointer motion.
    private struct FadeKey: Equatable {
        let selected: PreviewSelection?
        let hovered: PreviewSelection?
        let wake: Int
    }

    /// Resolved outlines paired with their shapes, in draw order — hovered first,
    /// so the selected stroke paints over it wherever the two overlap.
    ///
    /// A `PreviewSelection` with no shape is dropped rather than skipped later: a
    /// badge selection with the badge switched off, or a foreground with nothing
    /// drawn, has nothing to trace.
    private var strokes: [(offset: Int, shape: PreviewSelectionShape, emphasis: PreviewOutlineEmphasis)] {
        PreviewOutlines.resolve(selected: selected, hovered: hovered)
            .enumerated()
            .compactMap { offset, outline in
                guard let shape = PreviewHitTester.selectionShape(
                    for: outline.selection,
                    settings: settings,
                    displaySize: displaySize
                ) else { return nil }
                return (offset, shape, outline.emphasis)
            }
    }

    var body: some View {
        ZStack {
            ForEach(strokes, id: \.offset) { stroke in
                PreviewOutlineStroke(
                    shape: stroke.shape,
                    displaySize: displaySize,
                    emphasis: stroke.emphasis
                )
            }
        }
        .frame(width: displaySize, height: displaySize)
        .allowsHitTesting(false)
        .opacity(isVisible ? 1 : 0)
        // No `.animation(_:value:)` here: it would animate the change in *both*
        // directions, and appearing must be instant. The one animated transition is
        // driven explicitly below.
        .task(id: FadeKey(selected: selected, hovered: hovered, wake: wake)) {
            guard autoFade else {
                show()
                return
            }
            show()
            try? await Task.sleep(for: Self.holdDuration)
            guard !Task.isCancelled else { return }
            // Reduce Motion keeps the behaviour and drops the cross-fade.
            withAnimation(reduceMotion ? nil : .easeOut(duration: Self.fadeDuration)) {
                isVisible = false
            }
        }
    }

    /// Instantly, and explicitly so: `withAnimation(nil)` also protects the appear
    /// from an ambient transaction further up the hierarchy, which is the way an
    /// asymmetric fade quietly becomes symmetric again.
    private func show() {
        withAnimation(nil) { isVisible = true }
    }
}

/// One outline, at one weight. Stateless on purpose: the hold above is shared, so
/// nothing here may own a timer.
private struct PreviewOutlineStroke: View {
    let shape: PreviewSelectionShape
    let displaySize: CGFloat
    let emphasis: PreviewOutlineEmphasis

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

            context.stroke(
                path,
                with: .color(emphasis.strokeColor),
                lineWidth: emphasis.lineWidth(displaySize: displaySize)
            )
        }
        .frame(width: displaySize, height: displaySize)
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    let displaySize: CGFloat = 256

    // The four single-outline cases down the left, and the pair on the right — the
    // shape that only exists once there are two weights.
    HStack(spacing: 24) {
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
                        PreviewOutlineOverlay(
                            settings: settings,
                            displaySize: displaySize,
                            selected: selection,
                            // Hold them so the preview is inspectable.
                            autoFade: false
                        )
                    }
                }
            }
        }

        VStack(spacing: 4) {
            Text("Background selected, badge hovered").font(.caption2).foregroundStyle(.secondary)
            ZStack {
                IconContentView(settings: settings, displaySize: displaySize)
                PreviewOutlineOverlay(
                    settings: settings,
                    displaySize: displaySize,
                    selected: .iconBackground,
                    hovered: .badge,
                    autoFade: false
                )
            }
        }
    }
    .padding()
    .onAppear { settings.badge.isVisible = true }
}
