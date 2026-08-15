// Views/Inspector/Badge/Foreground/BadgeForegroundAppearanceSection.swift
import SwiftUI

struct BadgeForegroundAppearanceSection: View {
    @Binding var iconSettings: IconSettings

    // Apple Reference bindings (only used when badgeIconSource == .system)
    @Binding var badgeAppexSymbolColor: AppexColor
    @Binding var badgeAppexEnclosureColor: AppexColor

    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false


    var body: some View {
        switch iconSettings.badge.foreground.source {
        case .system:
            appleReferenceControls
        case .symbol:
            sfSymbolControls
        case .image:
            importedControls
        }
    }

    @ViewBuilder
    private var appleReferenceControls: some View {
        AppexColorPickerRow(label: "Symbol Color", selection: $badgeAppexSymbolColor)
        AppexColorPickerRow(label: "Background Color", selection: $badgeAppexEnclosureColor, role: .enclosure)
    }

    @ViewBuilder
    private var sfSymbolControls: some View {
        if advancedControlsEnabled {
            Picker("Rendering", systemImage: "paintpalette", selection: $iconSettings.badge.foreground.renderingStyle) {
                ForEach(SymbolRenderingStyle.allCases) { mode in
                    // See the icon's copy of this picker: "Multicolor" needs the
                    // catalog, and `Text(aString)` would skip it.
                    Text(verbatim: mode.rawValue.localizedFromCatalog).tag(mode)
                }
            }
            .pickerStyle(.menu)
        }

        badgeSymbolColorControls

        if advancedControlsEnabled {
            Picker("Weight", systemImage: "bold", selection: $iconSettings.badge.foreground.symbolWeight) {
                ForEach(SymbolWeight.allCases) { weight in
                    Text(weight.rawValue).tag(weight)
                }
            }
            .pickerStyle(.menu)

            if #available(macOS 26.0, *) {
                Toggle("Gradient", systemImage: "app.translucent", isOn: Binding(
                    get: { iconSettings.badge.foreground.fillStyle == .gradient },
                    set: { iconSettings.badge.foreground.fillStyle = $0 ? .gradient : .flat }
                ))
            }
        }

        Toggle("Shadow", systemImage: "app.shadow", isOn: $iconSettings.badge.foreground.drawsShadow)
    }

    /// Imported image: only shadow applies
    @ViewBuilder
    private var importedControls: some View {
        Toggle("Shadow", systemImage: "app.shadow", isOn: $iconSettings.badge.foreground.drawsShadow)
            .help("Toggle the drop shadow behind the badge image")
    }

    @ViewBuilder
    private var badgeSymbolColorControls: some View {
        switch iconSettings.badge.foreground.renderingStyle {
        case .monochrome, .multicolor:
            ColorPickerWithDropdown(
                label: "Color",
                value: $iconSettings.badge.foreground.color
            )
        case .hierarchical:
            ColorPickerWithDropdown(
                label: "Color",
                value: $iconSettings.badge.foreground.hierarchicalColor
            )
        case .palette:
            ColorPickerWithDropdown(
                label: "Primary",
                value: $iconSettings.badge.foreground.palettePrimaryColor
            )
            ColorPickerWithDropdown(
                label: "Secondary",
                value: $iconSettings.badge.foreground.paletteSecondaryColor
            )
            ColorPickerWithDropdown(
                label: "Tertiary",
                value: $iconSettings.badge.foreground.paletteTertiaryColor
            )
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    @Previewable @State var badgeSymbolColor: AppexColor = .white
    @Previewable @State var badgeEnclosureColor: AppexColor = .blue
    Form {
        Section("Appearance") {
            BadgeForegroundAppearanceSection(
                iconSettings: $settings,
                badgeAppexSymbolColor: $badgeSymbolColor,
                badgeAppexEnclosureColor: $badgeEnclosureColor
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
