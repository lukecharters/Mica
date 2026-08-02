// Views/Inspector/Badge/Background/BadgeBackgroundAppearanceSection.swift
import SwiftUI

struct BadgeBackgroundAppearanceSection: View {
    @Binding var iconSettings: IconSettings

    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false


    var body: some View {
        if iconSettings.badge.background.source != .image {
            if advancedControlsEnabled {
                Toggle("Custom Gradient", isOn: Binding(
                    get: { iconSettings.badge.background.usesCustomGradient },
                    set: { newValue in
                        iconSettings.badge.background.usesCustomGradient = newValue
                        if newValue {
                            iconSettings.badge.background.usesGradient = true
                        }
                    }
                ))
            }

            if iconSettings.badge.background.usesCustomGradient {
                ColorPicker("Primary", selection: $iconSettings.badge.background.gradientStartColor.asColor)
                ColorPicker("Secondary", selection: $iconSettings.badge.background.gradientEndColor.asColor)
            } else {
                // Shared preset/custom flow — self-heals the reset `useCustom`
                // flag and shows the actual color as the fallback swatch.
                ColorPickerWithDropdown(
                    label: "Color",
                    value: $iconSettings.badge.background.color
                )
            }

            if advancedControlsEnabled && !iconSettings.badge.background.usesCustomGradient {
                Toggle("Gradient", systemImage: "app.translucent", isOn: $iconSettings.badge.background.usesGradient)
            }
        }

        Toggle("Shadow", systemImage: "app.shadow", isOn: $iconSettings.badge.background.drawsShadow)
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Appearance") {
            BadgeBackgroundAppearanceSection(
                iconSettings: $settings
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

