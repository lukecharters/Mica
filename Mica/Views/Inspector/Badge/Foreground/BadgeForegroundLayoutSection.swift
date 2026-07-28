// Views/Inspector/Badge/Foreground/BadgeForegroundLayoutSection.swift
import SwiftUI

/// Layout controls specific to the **badge foreground layer** (symbol scale or
/// imported-image scale). Badge-wide layout (position, offset, overall size) lives
/// in `BadgeGroupLayoutSection`, shown when the Badge group header is selected.
struct BadgeForegroundLayoutSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        switch iconSettings.badgeIconSource {
        case .symbol:
            Slider(value: $iconSettings.badgeSymbolScale,
                   in: IconSettings.manualSymbolScaleRange,
                   step: 0.05) {
                Text("Symbol Scale")
                Text("\(Int(iconSettings.badgeSymbolScale * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

        case .image:
            ImageImportLayoutControls(
                paddingCompensation: .constant(false),
                imageScale: $iconSettings.badgeImportedImageScale,
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
