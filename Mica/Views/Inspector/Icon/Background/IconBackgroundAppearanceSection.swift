// Views/Inspector/Icon/Background/IconBackgroundAppearanceSection.swift
import SwiftUI

struct IconBackgroundAppearanceSection: View {
    @Binding var iconSettings: IconSettings

    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false


    var body: some View {
        switch iconSettings.icon.background.source {
        case .image:
            importedControls
        case .color:
            standardControls
        }
    }

    @ViewBuilder
    private var importedControls: some View {
        shadowControl
    }

    private var shadowControl: some View {
        ShadowStyleControl(
            style: $iconSettings.icon.background.shadowStyle,
            defaultStyle: IconBackgroundSpec().shadowStyle
        )
    }

    @ViewBuilder
    private var standardControls: some View {

        if advancedControlsEnabled {
            Picker("Corners", systemImage: "viewfinder", selection: $iconSettings.icon.background.cornerRadiusStyle) {
                ForEach(IconCornerRadiusStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Custom Gradient", isOn: Binding(
                get: { iconSettings.icon.background.usesCustomGradient },
                set: { newValue in
                    iconSettings.icon.background.usesCustomGradient = newValue
                    if newValue {
                        iconSettings.icon.background.usesGradient = true
                    }
                }
            ))
        }

        if iconSettings.icon.background.usesCustomGradient {
            // The same preset/custom control as the flat colour below, so a
            // gradient stop can be a token rather than only components.
            ColorPickerWithDropdown(
                label: "Primary",
                value: $iconSettings.icon.background.gradientStartColor
            )
            ColorPickerWithDropdown(
                label: "Secondary",
                value: $iconSettings.icon.background.gradientEndColor
            )
        } else {
            // Shared preset/custom flow — self-heals the reset `useCustom` flag
            // and shows the actual color as the fallback swatch.
            ColorPickerWithDropdown(
                label: "Color",
                value: $iconSettings.icon.background.color
            )
        }

        if advancedControlsEnabled && !iconSettings.icon.background.usesCustomGradient {
            Toggle("Gradient", systemImage: "app.translucent", isOn: $iconSettings.icon.background.usesGradient)
        }

        shadowControl
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Appearance") {
            IconBackgroundAppearanceSection(
                iconSettings: $settings
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
