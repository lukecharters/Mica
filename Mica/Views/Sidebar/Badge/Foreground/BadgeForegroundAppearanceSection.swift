// Views/Sidebar/BadgeAppearanceSection.swift
import SwiftUI

struct BadgeAppearanceSection: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    // Apple Reference bindings (only used when badgeIconSource == .appleReference)
    @Binding var badgeAppexSymbolColor: AppexColor
    @Binding var badgeAppexEnclosureColor: AppexColor

    @State private var useCustomBadgeSymbolColor = false
    @State private var useCustomBadgeHierarchicalColor = false
    @State private var useCustomBadgePalettePrimaryColor = false
    @State private var useCustomBadgePaletteSecondaryColor = false
    @State private var useCustomBadgePaletteTertiaryColor = false

    var body: some View {
        switch iconSettings.badgeIconSource {
        case .appleReference:
            appleReferenceControls
        case .sfSymbol:
            sfSymbolControls
        case .customImage:
            importedControls
        }
    }

    @ViewBuilder
    private var appleReferenceControls: some View {
        AppexColorPickerRow(label: "Symbol Color", selection: $badgeAppexSymbolColor)
        AppexColorPickerRow(label: "Background", selection: $badgeAppexEnclosureColor)
    }

    @ViewBuilder
    private var sfSymbolControls: some View {
        Picker("Rendering", systemImage: "paintpalette", selection: $iconSettings.badgeSymbolRenderingMode) {
            ForEach(SymbolRenderingMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.inline)

        badgeSymbolColorControls

        Picker("Weight", systemImage: "bold", selection: $iconSettings.badgeSymbolWeight) {
            ForEach(SymbolWeight.allCases) { weight in
                Text(weight.rawValue).tag(weight)
            }
        }
        .pickerStyle(.menu)

        if #available(macOS 26.0, *) {
            Toggle("Gradient", systemImage: "app.translucent", isOn: Binding(
                get: { iconSettings.badgeSymbolColorRenderingMode == .gradient },
                set: { iconSettings.badgeSymbolColorRenderingMode = $0 ? .gradient : .flat }
            ))
        }

        Toggle("Shadow", systemImage: "app.shadow", isOn: $iconSettings.badgeEnableSymbolShadow)
    }

    /// Imported image: only shadow applies
    @ViewBuilder
    private var importedControls: some View {
        Toggle("Shadow", systemImage: "app.shadow", isOn: $iconSettings.badgeEnableSymbolShadow)
            .help("Toggle the drop shadow behind the badge image")
    }

    @ViewBuilder
    private var badgeSymbolColorControls: some View {
        switch iconSettings.badgeSymbolRenderingMode {
        case .monochrome, .multicolor:
            ColorPickerWithDropdown(
                label: "Color",
                color: $iconSettings.badgeSymbolColor,
                useCustom: $useCustomBadgeSymbolColor,
                colorOptions: colorOptions
            )
        case .hierarchical:
            ColorPickerWithDropdown(
                label: "Color",
                color: $iconSettings.badgeHierarchicalSymbolColor,
                useCustom: $useCustomBadgeHierarchicalColor,
                colorOptions: colorOptions
            )
        case .palette:
            ColorPickerWithDropdown(
                label: "Primary",
                color: $iconSettings.badgePaletteSymbolPrimaryColor,
                useCustom: $useCustomBadgePalettePrimaryColor,
                colorOptions: colorOptions
            )
            ColorPickerWithDropdown(
                label: "Secondary",
                color: $iconSettings.badgePaletteSymbolSecondaryColor,
                useCustom: $useCustomBadgePaletteSecondaryColor,
                colorOptions: colorOptions
            )
            ColorPickerWithDropdown(
                label: "Tertiary",
                color: $iconSettings.badgePaletteSymbolTertiaryColor,
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
            BadgeAppearanceSection(
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
