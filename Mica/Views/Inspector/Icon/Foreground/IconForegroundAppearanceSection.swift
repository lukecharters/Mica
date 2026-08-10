// Views/Inspector/Icon/Foreground/IconForegroundAppearanceSection.swift
import SwiftUI

struct IconForegroundAppearanceSection: View {
    @Binding var iconSettings: IconSettings
    var isAppleReference: Bool = false

    // Apple Reference bindings (only used when isAppleReference == true)
    @Binding var appexSymbolColor: AppexColor
    @Binding var appexEnclosureColor: AppexColor

    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false


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
        AppexColorPickerRow(label: "Background Color", selection: $appexEnclosureColor, role: .enclosure)
    }

    @ViewBuilder
    private var sfSymbolControls: some View {
        if advancedControlsEnabled {
            Picker("Rendering", systemImage: "paintpalette", selection: $iconSettings.icon.foreground.renderingStyle) {
                ForEach(SymbolRenderingStyle.allCases) { mode in
                    // The raw value is a display string here, and "Multicolor"
                    // is one of the two words that differ between English
                    // variants. `Text(aString)` is the verbatim overload, so the
                    // catalog has to be consulted explicitly.
                    Text(verbatim: mode.rawValue.localizedFromCatalog).tag(mode)
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
                value: $iconSettings.icon.foreground.color
            )
        case .hierarchical:
            ColorPickerWithDropdown(
                label: "Color",
                value: $iconSettings.icon.foreground.hierarchicalColor
            )
        case .palette:
            ColorPickerWithDropdown(
                label: "Primary",
                value: $iconSettings.icon.foreground.palettePrimaryColor
            )
            ColorPickerWithDropdown(
                label: "Secondary",
                value: $iconSettings.icon.foreground.paletteSecondaryColor
            )
            ColorPickerWithDropdown(
                label: "Tertiary",
                value: $iconSettings.icon.foreground.paletteTertiaryColor
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
                appexSymbolColor: $symbolColor,
                appexEnclosureColor: $enclosureColor
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
