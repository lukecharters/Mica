// Views/Controls/FillingSegmentedPicker.swift
import SwiftUI
import AppKit

/// Segmented control that fills the width it's given, with equally-sized segments.
///
/// SwiftUI's `Picker(.segmented)` keeps its intrinsic width — neither
/// `maxWidth: .infinity` nor a definite `.frame(width:)` stretches it, they only
/// centre it — so the inspector's pickers wrap `NSSegmentedControl` directly to get
/// `segmentDistribution = .fillEqually`. Everything else is the stock control, so
/// it still picks up the app accent and the platform's current segmented look
/// (and needs no availability check to run on macOS 15).
///
/// Trade-off worth knowing: AppKit draws a slightly squarer bezel than SwiftUI's
/// capsule at the same control size. `segmentStyle` and `controlSize` don't change
/// that, and neither does forcing a taller frame — the control keeps its own bezel
/// metrics. Full width was the priority here.
struct FillingSegmentedPicker<Value: Hashable>: NSViewRepresentable {
    /// Segments in display order, paired with the value each one selects.
    let segments: [(label: String, value: Value)]
    @Binding var selection: Value
    /// Spoken/described name for the control as a whole.
    var accessibilityLabel: String

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: segments.map(\.label),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.segmentChanged(_:))
        )
        control.segmentDistribution = .fillEqually
        control.controlSize = .large
        control.setAccessibilityLabel(accessibilityLabel)
        // Let SwiftUI stretch us instead of pinning to the intrinsic width.
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self

        // The segment set changes with the selected group — the badge has three
        // tabs, the icon two — so rebuild labels whenever they don't match.
        if control.segmentCount != segments.count {
            control.segmentCount = segments.count
        }
        for (index, segment) in segments.enumerated() where control.label(forSegment: index) != segment.label {
            control.setLabel(segment.label, forSegment: index)
        }

        if let index = segments.firstIndex(where: { $0.value == selection }),
           control.selectedSegment != index {
            control.selectedSegment = index
        }
        control.setAccessibilityLabel(accessibilityLabel)
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
            segments: [("Alpha", "a"), ("Beta", "b")],
            selection: $selection,
            accessibilityLabel: "Two segments"
        )
        FillingSegmentedPicker(
            segments: [("Alpha", "a"), ("Beta", "b"), ("Gamma", "c")],
            selection: $selection,
            accessibilityLabel: "Three segments"
        )
        Text("Selected: \(selection)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .frame(width: 340)
    .padding()
}
