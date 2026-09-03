// Views/Controls/FillingSegmentedPicker.swift
import SwiftUI
import AppKit

/// What the segments *mean*, which on macOS 27 is a thing the control can be told.
///
/// `NSSegmentedControl.role` (macOS 27) separates "these are tabs onto different
/// views" from "these are values of one setting", and draws them differently: the
/// tabs role gets a neutral raised pill for the selection, the value role keeps the
/// accent fill. Below 27 the property does not exist and both cases render as the
/// stock accent-filled control, which is what every version of this wrapper did.
enum SegmentedRole {
    /// Two views of the same thing — Mica vs System. Neutral selection on macOS 27.
    case tabs
    /// Two values of one setting. Accent-filled selection.
    case valueSelection
}

/// Segmented control that fills the width it's given, with equally-sized segments.
///
/// SwiftUI's `Picker` keeps its intrinsic width — neither `maxWidth: .infinity` nor
/// a definite `.frame(width:)` stretches it, they only centre it — so the
/// inspector's pickers wrap `NSSegmentedControl` directly to get
/// `segmentDistribution = .fillEqually`. **That is still true of macOS 27's
/// `.pickerStyle(.tabs)`**, measured 2026-08-28: the tabs style does not fill
/// either. So the tabs *look* is reached here, through `role`, rather than by
/// moving the control to SwiftUI and losing the fill.
///
/// **The bezel is a capsule**, via `borderShape` (macOS 26). AppKit used to draw a
/// squarer bezel here than SwiftUI's capsule and nothing could change it —
/// `segmentStyle` and `controlSize` both failed — so the shape was a standing cost
/// of taking the AppKit route. `borderShape` is the knob that was missing.
///
/// **`controlSize` is set but does nothing, and that is not a bug to go fix.**
/// Measured 2026-08-28: an `NSSegmentedControl` on macOS 27 draws at **24pt tall
/// whatever you do** — `.mini` through `.extraLarge`, `cell.controlSize`,
/// `segmentStyle`, `borderShape` and a 16pt font all leave it at 24. Reporting a
/// taller height from `sizeThatFits` grows the *box* and leaves the control drawn
/// at 24pt inside it. The line stays because it is what the control asks for; do
/// not read it as load-bearing. Height is the price of the fill: SwiftUI's
/// `.pickerStyle(.tabs)` does scale (20/24/28/36pt at
/// `.small`/`.regular`/`.large`/`.extraLarge`) but never fills, topping out at
/// 176pt in a 330pt pane.
struct FillingSegmentedPicker<Value: Hashable>: NSViewRepresentable {

    /// One segment: what it selects, and how it draws.
    ///
    /// **A struct rather than the `(label:value:)` tuple this took until symbols were
    /// needed**, because a tuple cannot carry an optional third member with a default
    /// and every call site would have had to name it. The two initializers keep a
    /// text segment as short to write as it was.
    ///
    /// `label` is required even for an image segment: it is the segment's
    /// accessibility description and its tooltip, which are the only things that name
    /// a control drawn as a bare glyph.
    struct Segment {
        var label: String
        /// An SF Symbol name. When set, the segment draws the glyph and **no text**.
        var systemImage: String?
        var value: Value

        init(_ label: String, value: Value) {
            self.label = label
            self.systemImage = nil
            self.value = value
        }

        init(_ label: String, systemImage: String, value: Value) {
            self.label = label
            self.systemImage = systemImage
            self.value = value
        }
    }

    /// Segments in display order.
    let segments: [Segment]
    @Binding var selection: Value
    /// Spoken/described name for the control as a whole.
    var accessibilityLabel: String
    /// Tabs or values. Only observable on macOS 27; ignored below it.
    var role: SegmentedRole = .valueSelection

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: segments.map(\.label),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.segmentChanged(_:))
        )
        control.segmentDistribution = .fillEqually
        control.controlSize = .large
        applyAppearance(to: control)
        applySegments(to: control)
        control.setAccessibilityLabel(accessibilityLabel)
        // Let SwiftUI stretch us instead of pinning to the intrinsic width.
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        applyAppearance(to: control)
        applySegments(to: control)

        if let index = segments.firstIndex(where: { $0.value == selection }),
           control.selectedSegment != index {
            control.selectedSegment = index
        }
        control.setAccessibilityLabel(accessibilityLabel)
    }

    /// Labels, images and tooltips, from both `makeNSView` and `updateNSView`.
    ///
    /// The segment *set* changes with the selected group — the badge has three tabs,
    /// the icon two — so the count is reconciled here rather than assumed.
    ///
    /// **An image segment sets its label to the empty string.** `NSSegmentedControl`
    /// draws both when both are present, so leaving the text in place gives a glyph
    /// with a word beside it in a segment sized for one of them.
    private func applySegments(to control: NSSegmentedControl) {
        if control.segmentCount != segments.count {
            control.segmentCount = segments.count
        }

        for (index, segment) in segments.enumerated() {
            // A tooltip on every segment, because an image segment has no other way
            // to say what it is on hover.
            control.setToolTip(segment.label, forSegment: index)

            guard let symbol = segment.systemImage else {
                control.setImage(nil, forSegment: index)
                if control.label(forSegment: index) != segment.label {
                    control.setLabel(segment.label, forSegment: index)
                }
                continue
            }

            // **A misspelled SF Symbol name returns nil and draws nothing at all**,
            // with no error — the trap `LayerTabTests` resolves each of its glyphs
            // through `NSImage` to catch. Falling back to the text keeps a typo
            // legible rather than shipping an invisible segment.
            guard let image = NSImage(
                systemSymbolName: symbol,
                accessibilityDescription: segment.label
            ) else {
                control.setImage(nil, forSegment: index)
                control.setLabel(segment.label, forSegment: index)
                continue
            }

            if control.label(forSegment: index) != "" {
                control.setLabel("", forSegment: index)
            }
            control.setImage(image, forSegment: index)
            control.setImageScaling(.scaleProportionallyDown, forSegment: index)
        }
    }

    /// The two version-gated appearance knobs, set from both `makeNSView` and
    /// `updateNSView` so a caller that varies the role is honoured rather than stuck
    /// with whatever it was made with.
    private func applyAppearance(to control: NSSegmentedControl) {
        if #available(macOS 26.0, *) {
            control.borderShape = .capsule
        }
        if #available(macOS 27.0, *) {
            switch role {
            case .tabs: control.role = .tabs
            case .valueSelection: control.role = .valueSelection
            }
        }
    }

    /// Fill the proposed width; keep the control's own height.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSegmentedControl, context: Context) -> CGSize? {
        let intrinsic = nsView.intrinsicContentSize
        return CGSize(
            width: proposal.width ?? intrinsic.width,
            height: intrinsic.height
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: FillingSegmentedPicker

        init(parent: FillingSegmentedPicker) {
            self.parent = parent
        }

        /// `@MainActor` because the body reaches `parent`, and `FillingSegmentedPicker`
        /// is a `NSViewRepresentable` and so main-actor isolated, while an `@objc`
        /// method is nonisolated by default. It is an AppKit target/action, which is
        /// only ever delivered on the main thread, so this annotates the isolation
        /// that already holds rather than adding a hop.
        ///
        /// Without it, Swift 6 mode reports three warnings here — the two `segments`
        /// reads and the `selection` write — that a later language mode makes errors.
        @MainActor
        @objc func segmentChanged(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard parent.segments.indices.contains(index) else { return }
            parent.selection = parent.segments[index].value
        }
    }
}

#Preview {
    @Previewable @State var selection = "b"
    VStack(spacing: 16) {
        FillingSegmentedPicker(
            segments: [.init("Alpha", value: "a"), .init("Beta", value: "b")],
            selection: $selection,
            accessibilityLabel: "Two segments"
        )
        FillingSegmentedPicker(
            segments: [
                .init("Layers", systemImage: "square.3.layers.3d", value: "a"),
                .init("Presets", systemImage: "square.on.circle", value: "b"),
                .init("Gamma", value: "c"),
            ],
            selection: $selection,
            accessibilityLabel: "Mixed text and glyph segments"
        )
        Text("Selected: \(selection)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .frame(width: 340)
    .padding()
}
