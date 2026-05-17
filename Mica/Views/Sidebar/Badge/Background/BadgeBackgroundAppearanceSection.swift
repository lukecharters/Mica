// Views/Sidebar/BadgeBackgroundAppearanceSection.swift
import SwiftUI

struct BadgeBackgroundAppearanceSection: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    @State private var useCustomBadgeBackgroundColor = false

    var body: some View {
        if !iconSettings.badgeUseImportedBackground {
            Toggle("Custom Gradient", isOn: Binding(
                get: { iconSettings.badgeUseCustomColors },
                set: { newValue in
                    iconSettings.badgeUseCustomColors = newValue
                    if newValue {
                        iconSettings.badgeEnableBackgroundGradient = true
                    }
                }
            ))

            if iconSettings.badgeUseCustomColors {
                ColorPicker("Primary", selection: $iconSettings.badgeCustomPrimaryColor)
                ColorPicker("Secondary", selection: $iconSettings.badgeCustomSecondaryColor)
            } else {
                if useCustomBadgeBackgroundColor {
                    ColorPicker(selection: $iconSettings.badgeBaseColor) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(iconSettings.badgeBaseColor)
                                .frame(width: 12, height: 12)
                            Text("Color")
                        }
                    }
                    Button("Use Preset", systemImage: "arrow.clockwise") {
                        useCustomBadgeBackgroundColor = false
                    }
                    .buttonStyle(.link)
                } else {
                    let selectedColorOption = colorOptions.first { $0.color == iconSettings.badgeBaseColor }
                    Picker(
                        selection: Binding<Int?>(
                            get: { colorOptions.firstIndex { $0.color == iconSettings.badgeBaseColor } },
                            set: { newValue in
                                if let index = newValue, index >= 0 {
                                    iconSettings.badgeBaseColor = colorOptions[index].color
                                } else if newValue == -1 {
                                    useCustomBadgeBackgroundColor = true
                                }
                            }
                        ),
                        label: HStack(spacing: 12) {
                            Circle()
                                .fill(selectedColorOption?.color ?? Color.blue)
                                .frame(width: 12, height: 12)
                            Text("Color")
                        }
                    ) {
                        ForEach(Array(colorOptions.enumerated()), id: \.offset) { index, option in
                            Text(option.name).tag(Optional(index))
                        }
                        Divider()
                        Text("Custom…").tag(Optional(-1))
                    }
                    .pickerStyle(.menu)
                }
            }

            if !iconSettings.badgeUseCustomColors {
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

