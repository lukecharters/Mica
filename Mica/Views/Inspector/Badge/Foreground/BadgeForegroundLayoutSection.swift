// Views/Inspector/Badge/Foreground/BadgeForegroundLayoutSection.swift
import SwiftUI

/// Layout controls specific to the **badge foreground layer** (symbol scale or
/// imported-image scale). Badge-wide layout (position, offset, overall size) lives
/// in `BadgeGroupLayoutSection`, shown when the Badge group header is selected.
struct BadgeForegroundLayoutSection: View {
    @Binding var iconSettings: IconSettings
    /// So a drag is one undo step rather than one per frame.
    @Environment(\.continuousEdit) private var continuousEdit

    var body: some View {
        switch iconSettings.badge.foreground.source {
        case .symbol:
            Slider(value: $iconSettings.badge.foreground.symbolScale,
                   in: ForegroundSpec.symbolScaleRange,
                   step: 0.05) {
                Text("Symbol Scale")
                Text("\(Int(iconSettings.badge.foreground.symbolScale * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } onEditingChanged: { continuousEdit.sliderEditing($0) }

        case .image:
            ImageImportLayoutControls(
                paddingCompensation: .constant(false),
                imageScale: $iconSettings.badge.foreground.imageScale,
                showPaddingCompensation: false
            )

        case .system:
            EmptyView()
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Layout") {
            BadgeForegroundLayoutSection(iconSettings: $settings)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
