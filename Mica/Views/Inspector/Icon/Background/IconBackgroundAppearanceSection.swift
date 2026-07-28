// Views/Inspector/Icon/Background/IconBackgroundAppearanceSection.swift
import SwiftUI

struct IconBackgroundAppearanceSection: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    @State private var useCustomBackgroundColor = false

    var body: some View {
        switch iconSettings.backgroundMode {
        case .image:
            importedControls
        case .preRendered:
            liquidGlassControls
        case .color:
            standardControls
        }
    }

    @ViewBuilder
    private var importedControls: some View {
        shadowControl
    }

    /// Advanced mode exposes all shadow styles; simple mode is a plain on/off
    /// toggle that maps "on" to the modern macOS 26 style.
    @ViewBuilder
    private var shadowControl: some View {
        if advancedControlsEnabled {
            Picker("Shadow", systemImage: "app.shadow", selection: $iconSettings.backgroundShadowStyle) {
                ForEach(BackgroundShadowStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
        } else {
            Toggle("Shadow", systemImage: "app.shadow", isOn: Binding(
                get: { iconSettings.backgroundShadowStyle != .off },
                set: { iconSettings.backgroundShadowStyle = $0 ? .macOS26 : .off }
            ))
        }
    }

    @ViewBuilder
    private var liquidGlassControls: some View {
        Picker(
            selection: $iconSettings.preRenderedColorName,
            label: HStack(spacing: 12) {
                Circle()
                    .stroke(.secondary.opacity(0.5), lineWidth: 1.0)
                    .fill(OptionsCatalog.color(named: iconSettings.preRenderedColorName))
                    .frame(width: 12, height: 12)
                Text("Color")
            }
        ) {
            ForEach(colorOptions, id: \.name) { option in
                Text(option.name).tag(option.name)
            }
        }
        .pickerStyle(.menu)

        if advancedControlsEnabled {
            Toggle("Gradient", systemImage: "app.translucent", isOn: $iconSettings.enableBackgroundGradient)
        }

        shadowControl
    }

    @ViewBuilder
    private var standardControls: some View {

        if advancedControlsEnabled {
            Picker("Corners", systemImage: "viewfinder", selection: $iconSettings.cornerRadiusStyle) {
                ForEach(IconCornerRadiusStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Custom Gradient", isOn: Binding(
                get: { iconSettings.useCustomColors },
                set: { newValue in
                    iconSettings.useCustomColors = newValue
                    if newValue {
                        iconSettings.enableBackgroundGradient = true
                    }
                }
            ))
        }

        if iconSettings.useCustomColors {
            ColorPicker("Primary", selection: $iconSettings.customPrimaryColor)
            ColorPicker("Secondary", selection: $iconSettings.customSecondaryColor)
        } else {
            // Shared preset/custom flow — self-heals the reset `useCustom` flag
            // and shows the actual color as the fallback swatch.
            ColorPickerWithDropdown(
                label: "Color",
                color: $iconSettings.baseColor,
                useCustom: $useCustomBackgroundColor,
                colorOptions: colorOptions
            )
        }

        if advancedControlsEnabled && !iconSettings.useCustomColors {
            Toggle("Gradient", systemImage: "app.translucent", isOn: $iconSettings.enableBackgroundGradient)
        }

        shadowControl
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Appearance") {
            IconBackgroundAppearanceSection(
                iconSettings: $settings,
                colorOptions: OptionsCatalog.colorOptions
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
