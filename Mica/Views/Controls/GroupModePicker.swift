// Views/Controls/GroupModePicker.swift
import SwiftUI

/// Views-layer display metadata for `GenerationMode` (kept out of the shared
/// model so the CLI doesn't carry UI strings).
extension GenerationMode {
    var label: String {
        switch self {
        case .mica: "Mica"
        case .system: "System"
        }
    }
}

/// Two-state segmented control: Mica vs System for a single group. Shown at the
/// top of a group's inspector (Icon / Badge) so the user can switch that group
/// between Mica's SwiftUI rendering and Apple's system reference.
///
/// Uses `FillingSegmentedPicker` so it spans the inspector width. It is the only
/// user of that wrapper since `LayerTabPicker` — which sat directly beneath it —
/// was deleted on 2026-08-16, the layer selection having gone back to the sidebar.
///
/// It was two `GenerationModeMenu`s in the window toolbar between 2026-08-04 and
/// 2026-08-16. The toolbar showed both groups at once, which the inspector cannot;
/// the inspector puts the setting next to the controls it reshapes, which the
/// toolbar could not. The second reading won. `InspectorGroupHeader` now names the
/// group being edited, so a picker that shows one group at a time is no longer
/// ambiguous about *which* group — which was the toolbar's other argument.
struct GroupModePicker: View {
    @Binding var isSystem: Bool

    private var selection: Binding<GenerationMode> {
        Binding(
            get: { isSystem ? .system : .mica },
            set: { isSystem = ($0 == .system) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Generation Mode")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            FillingSegmentedPicker(
                segments: GenerationMode.allCases.map { ($0.label, $0) },
                selection: selection,
                accessibilityLabel: "Generation Mode"
            )
            Divider()
        }
        // No top padding: `InspectorGroupHeader` sits directly above and its bottom
        // padding is the gap. (It carried `.padding(.top, 8)` before the header
        // existed, when this was the first thing in the pane.)
        .padding(.bottom, 12)
    }
}

#Preview {
    @Previewable @State var isSystem = false
    GroupModePicker(isSystem: $isSystem)
        .frame(width: 340)
        .padding()
}
