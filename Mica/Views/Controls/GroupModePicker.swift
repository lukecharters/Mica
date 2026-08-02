// Views/Controls/GroupModePicker.swift
import SwiftUI

/// Views-layer display metadata for `GenerationMode` (kept out of the shared
/// model so the CLI doesn't carry UI strings).
extension GenerationMode {
    var systemImageName: String {
        switch self {
        case .mica: "slider.horizontal.3"
        case .system: "gearshape.2.fill"
        }
    }

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
/// Uses `FillingSegmentedPicker` so it spans the inspector width, matching
/// `LayerTabPicker` directly beneath it — keep the two visually aligned.
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
            Spacer()
            Divider()
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

#Preview {
    @Previewable @State var isSystem = false
    GroupModePicker(isSystem: $isSystem)
        .frame(width: 340)
        .padding()
}
