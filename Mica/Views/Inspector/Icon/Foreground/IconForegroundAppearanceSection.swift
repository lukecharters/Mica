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
        } else if iconSettings.iconSource == .sfSymbol {
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
            Picker("Rendering", systemImage: "paintpalette", selection: $iconSettings.symbolRenderingMode) {
                ForEach(SymbolRenderingStyle.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.inline)
        }

        symbolColorControls

        if advancedControlsEnabled {
            Picker("Weight", systemImage: "bold", selection: $iconSettings.symbolWeight) {
                ForEach(SymbolWeight.allCases) { weight in
                    Text(weight.rawValue).tag(weight)
                }
            }
            .pickerStyle(.menu)

            if #available(macOS 26.0, *) {
                Toggle("Gradient", systemImage: "app.translucent", isOn: Binding(
                    get: { iconSettings.symbolColorRenderingMode == .gradient },
                    set: { iconSettings.symbolColorRenderingMode = $0 ? .gradient : .flat }
                ))
            }
        }

        Toggle("Shadow", systemImage: "app.shadow", isOn: $iconSettings.enableSymbolShadow)
    }

    /// Imported image: only shadow applies
    @ViewBuilder
    private var importedControls: some View {
        Toggle("Shadow", systemImage: "app.shadow", isOn: $iconSettings.enableSymbolShadow)
            .help("Toggle the drop shadow behind the imported image")
    }

    @ViewBuilder
    private var symbolColorControls: some View {
        switch iconSettings.symbolRenderingMode {
        case .monochrome, .multicolor:
            ColorPickerWithDropdown(
                label: "Color",
                color: $iconSettings.symbolColor,
                useCustom: $useCustomSymbolColor,
                colorOptions: colorOptions
            )
        case .hierarchical:
            ColorPickerWithDropdown(
                label: "Color",
                color: $iconSettings.hierarchicalSymbolColor,
                useCustom: $useCustomHierarchicalColor,
                colorOptions: colorOptions
            )
        case .palette:
            ColorPickerWithDropdown(
                label: "Primary",
                color: $iconSettings.paletteSymbolPrimaryColor,
                useCustom: $useCustomPalettePrimaryColor,
                colorOptions: colorOptions
            )
            ColorPickerWithDropdown(
                label: "Secondary",
                color: $iconSettings.paletteSymbolSecondaryColor,
                useCustom: $useCustomPaletteSecondaryColor,
                colorOptions: colorOptions
            )
            ColorPickerWithDropdown(
                label: "Tertiary",
                color: $iconSettings.paletteSymbolTertiaryColor,
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
