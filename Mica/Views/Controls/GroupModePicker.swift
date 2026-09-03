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

/// Two-state control: Mica vs System for a single group. Shown at the top of a
/// group's inspector (Icon / Badge) so the user can switch that group between
/// Mica's SwiftUI rendering and Apple's system reference.
///
/// **It is a tab control, and says so.** Mica and System are two views of one group
/// rather than two values of a setting, so it passes `role: .tabs` to
/// `FillingSegmentedPicker`. On macOS 27 that draws the neutral tab selection —
/// the same appearance as SwiftUI's `.pickerStyle(.tabs)`, and the same thing
/// Xcode's navigator and inspector selector bars use. Below 27 the role is ignored
/// and the control renders exactly as it always has.
///
/// **This deliberately does not use `.pickerStyle(.tabs)`.** That style was tried
/// here on 2026-08-28 and reverted the same day: a SwiftUI picker cannot be
/// stretched — not by `maxWidth: .infinity`, not by a definite `.frame(width:)`,
/// both only centre it — so it rendered 156pt wide in a 330pt pane. Going through
/// `NSSegmentedControl.role` gets the identical look *and* keeps the full-width
/// fill, which is the whole reason `FillingSegmentedPicker` exists. Don't swap it
/// back.
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
                segments: GenerationMode.allCases.map { .init($0.label, value: $0) },
                selection: selection,
                accessibilityLabel: "Generation Mode",
                role: .tabs
            )
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
