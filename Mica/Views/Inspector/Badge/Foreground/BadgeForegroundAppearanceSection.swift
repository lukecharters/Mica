// Views/Inspector/Badge/Foreground/BadgeForegroundAppearanceSection.swift
import SwiftUI

struct BadgeForegroundAppearanceSection: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    // Apple Reference bindings (only used when badgeIconSource == .system)
    @Binding var badgeAppexSymbolColor: AppexColor
    @Binding var badgeAppexEnclosureColor: AppexColor

    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    @State private var useCustomBadgeSymbolColor = false
    @State private var useCustomBadgeHierarchicalColor = false
    @State private var useCustomBadgePalettePrimaryColor = false
    @State private var useCustomBadgePaletteSecondaryColor = false
    @State private var useCustomBadgePaletteTertiaryColor = false

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
        AppexColorPickerRow(label: "Background Color", selection: $badgeAppexEnclosureColor)
    }

    @ViewBuilder
    private var sfSymbolControls: some View {
        if advancedControlsEnabled {
            Picker("Rendering", systemImage: "paintpalette", selection: $iconSettings.badge.foreground.renderingStyle) {
                ForEach(SymbolRenderingStyle.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.inline)
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
                color: $iconSettings.badge.foreground.color,
                useCustom: $useCustomBadgeSymbolColor,
                colorOptions: colorOptions
            )
        case .hierarchical:
            ColorPickerWithDropdown(
                label: "Color",
                color: $iconSettings.badge.foreground.hierarchicalColor,
                useCustom: $useCustomBadgeHierarchicalColor,
                colorOptions: colorOptions
            )
        case .palette:
            ColorPickerWithDropdown(
                label: "Primary",
                color: $iconSettings.badge.foreground.palettePrimaryColor,
                useCustom: $useCustomBadgePalettePrimaryColor,
                colorOptions: colorOptions
            )
            ColorPickerWithDropdown(
                label: "Secondary",
                color: $iconSettings.badge.foreground.paletteSecondaryColor,
                useCustom: $useCustomBadgePaletteSecondaryColor,
                colorOptions: colorOptions
            )
            ColorPickerWithDropdown(
                label: "Tertiary",
                color: $iconSettings.badge.foreground.paletteTertiaryColor,
                useCustom: $useCustomBadgePaletteTertiaryColor,
                colorOptions: colorOptions
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
                colorOptions: OptionsCatalog.colorOptions,
                badgeAppexSymbolColor: $badgeSymbolColor,
                badgeAppexEnclosureColor: $badgeEnclosureColor
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
