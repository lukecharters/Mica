// Views/Inspector/Icon/Foreground/IconForegroundAppearanceSection.swift
import SwiftUI

struct IconForegroundAppearanceSection: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]
    var isAppleReference: Bool = false

    // Apple Reference bindings (only used when isAppleReference == true)
    @Binding var appexSymbolColor: AppexColor
    @Binding var appexEnclosureColor: AppexColor

    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    @State private var useCustomSymbolColor = false
    @State private var useCustomHierarchicalColor = false
    @State private var useCustomPalettePrimaryColor = false
    @State private var useCustomPaletteSecondaryColor = false
    @State private var useCustomPaletteTertiaryColor = false

    var body: some View {
        if isAppleReference {
            appleReferenceControls
        } else if iconSettings.icon.foreground.source == .symbol {
            sfSymbolControls
        } else {
            importedControls
        }
    }

    @ViewBuilder
    private var appleReferenceControls: some View {
        AppexColorPickerRow(label: "Symbol Color", selection: $appexSymbolColor)
        AppexColorPickerRow(label: "Background Color", selection: $appexEnclosureColor)
    }

    @ViewBuilder
    private var sfSymbolControls: some View {
        if advancedControlsEnabled {
            Picker("Rendering", systemImage: "paintpalette", selection: $iconSettings.icon.foreground.renderingStyle) {
                ForEach(SymbolRenderingStyle.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.inline)
        }

        symbolColorControls

        if advancedControlsEnabled {
            Picker("Weight", systemImage: "bold", selection: $iconSettings.icon.foreground.symbolWeight) {
                ForEach(SymbolWeight.allCases) { weight in
                    Text(weight.rawValue).tag(weight)
                }
            }
            .pickerStyle(.menu)

            if #available(macOS 26.0, *) {
                Toggle("Gradient", systemImage: "app.translucent", isOn: Binding(
                    get: { iconSettings.icon.foreground.fillStyle == .gradient },
                    set: { iconSettings.icon.foreground.fillStyle = $0 ? .gradient : .flat }
                ))
            }
        }

        Toggle("Shadow", systemImage: "app.shadow", isOn: $iconSettings.icon.foreground.drawsShadow)
    }

    /// Imported image: only shadow applies
    @ViewBuilder
    private var importedControls: some View {
        Toggle("Shadow", systemImage: "app.shadow", isOn: $iconSettings.icon.foreground.drawsShadow)
            .help("Toggle the drop shadow behind the imported image")
    }

    @ViewBuilder
    private var symbolColorControls: some View {
        switch iconSettings.icon.foreground.renderingStyle {
        case .monochrome, .multicolor:
            ColorPickerWithDropdown(
                label: "Color",
                color: $iconSettings.icon.foreground.color,
                useCustom: $useCustomSymbolColor,
                colorOptions: colorOptions
            )
        case .hierarchical:
            ColorPickerWithDropdown(
                label: "Color",
                color: $iconSettings.icon.foreground.hierarchicalColor,
                useCustom: $useCustomHierarchicalColor,
                colorOptions: colorOptions
            )
        case .palette:
            ColorPickerWithDropdown(
                label: "Primary",
                color: $iconSettings.icon.foreground.palettePrimaryColor,
                useCustom: $useCustomPalettePrimaryColor,
                colorOptions: colorOptions
            )
            ColorPickerWithDropdown(
                label: "Secondary",
                color: $iconSettings.icon.foreground.paletteSecondaryColor,
                useCustom: $useCustomPaletteSecondaryColor,
                colorOptions: colorOptions
            )
            ColorPickerWithDropdown(
                label: "Tertiary",
                color: $iconSettings.icon.foreground.paletteTertiaryColor,
                useCustom: $useCustomPaletteTertiaryColor,
                colorOptions: colorOptions
            )
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    @Previewable @State var symbolColor: AppexColor = .white
    @Previewable @State var enclosureColor: AppexColor = .blue
    Form {
        Section("Appearance") {
            IconForegroundAppearanceSection(
                iconSettings: $settings,
                colorOptions: OptionsCatalog.colorOptions,
                appexSymbolColor: $symbolColor,
                appexEnclosureColor: $enclosureColor
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
