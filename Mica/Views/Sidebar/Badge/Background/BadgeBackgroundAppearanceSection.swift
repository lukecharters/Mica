// Views/Sidebar/BadgeBackgroundAppearanceSection.swift
import SwiftUI

struct BadgeBackgroundAppearanceSection: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    @AppStorage(SidebarSettings.advancedControlsKey) private var advancedControlsEnabled = false

    @State private var useCustomBadgeBackgroundColor = false

    var body: some View {
        if !iconSettings.badgeUseImportedBackground {
            if advancedControlsEnabled {
                Toggle("Custom Gradient", isOn: Binding(
                    get: { iconSettings.badgeUseCustomColors },
                    set: { newValue in
                        iconSettings.badgeUseCustomColors = newValue
                        if newValue {
                            iconSettings.badgeEnableBackgroundGradient = true
                        }
                    }
                ))
            }

            if iconSettings.badgeUseCustomColors {
                ColorPicker("Primary", selection: $iconSettings.badgeCustomPrimaryColor)
                ColorPicker("Secondary", selection: $iconSettings.badgeCustomSecondaryColor)
            } else {
                // Shared preset/custom flow — self-heals the reset `useCustom`
                // flag and shows the actual color as the fallback swatch.
                ColorPickerWithDropdown(
                    label: "Color",
                    color: $iconSettings.badgeBaseColor,
                    useCustom: $useCustomBadgeBackgroundColor,
                    colorOptions: colorOptions
                )
            }

            if advancedControlsEnabled && !iconSettings.badgeUseCustomColors {
                Toggle("Gradient", systemImage: "app.translucent", isOn: $iconSettings.badgeEnableBackgroundGradient)
            }
        }

        Toggle("Shadow", systemImage: "app.shadow", isOn: $iconSettings.badgeEnableBackgroundShadow)
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Appearance") {
            BadgeBackgroundAppearanceSection(
                iconSettings: $settings,
                colorOptions: OptionsCatalog.colorOptions
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

