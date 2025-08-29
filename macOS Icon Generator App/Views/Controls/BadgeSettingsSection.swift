// Views/Controls/BadgeSettingsSection.swift
import SwiftUI

struct BadgeSettingsSection: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    var body: some View {
        Section(header: Text("Badge Settings")) {
            Toggle("Show Badge", isOn: $iconSettings.showBadge)
                .help("Add a circular badge to the icon")

            if iconSettings.showBadge {
                Picker("Badge Position", selection: $iconSettings.badgePosition) {
                    ForEach(BadgePosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }

                TextField("Badge Symbol", text: $iconSettings.badgeSymbolName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .help("Enter an SF Symbol name for the badge (e.g., 1.circle.fill, plus, checkmark)")

                Picker("Badge Rendering Mode", selection: $iconSettings.badgeSymbolRenderingMode) {
                    ForEach(SymbolRenderingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                switch iconSettings.badgeSymbolRenderingMode {
                case .monochrome:
                    ColorPicker("Badge Symbol Color", selection: $iconSettings.badgeSymbolColor)
                case .hierarchical:
                    ColorPicker("Badge Base Color", selection: $iconSettings.badgeHierarchicalSymbolColor)
                case .multicolor:
                    ColorPicker("Badge Base Color", selection: $iconSettings.badgeSymbolColor)
                case .palette:
                    ColorPicker("Badge Primary Color", selection: $iconSettings.badgePaletteSymbolPrimaryColor)
                    ColorPicker("Badge Secondary Color", selection: $iconSettings.badgePaletteSymbolSecondaryColor)
                    ColorPicker("Badge Tertiary Color", selection: $iconSettings.badgePaletteSymbolTertiaryColor)
                }

                Group {
                    Toggle("Badge Custom Colors", isOn: $iconSettings.badgeUseCustomColors)

                    if iconSettings.badgeUseCustomColors {
                        ColorPicker("Badge Primary Color", selection: $iconSettings.badgeCustomPrimaryColor)
                        ColorPicker("Badge Secondary Color", selection: $iconSettings.badgeCustomSecondaryColor)
                    } else {
                        Picker("Badge Color Preset", selection: Binding(
                            get: { colorOptions.firstIndex { $0.color == iconSettings.badgeBaseColor } ?? 0 },
                            set: { newValue in iconSettings.badgeBaseColor = colorOptions[newValue].color }
                        )) {
                            ForEach(0..<colorOptions.count, id: \.self) { index in
                                Text(colorOptions[index].name)
                            }
                        }
                    }

                    Toggle("Badge Background Shadow", isOn: $iconSettings.badgeEnableBackgroundShadow)
                        .help("Toggle the drop shadow behind the badge background")
                    Toggle("Badge Symbol Shadow", isOn: $iconSettings.badgeEnableSymbolShadow)
                        .help("Toggle the drop shadow behind the badge symbol")
                }
            }
        }
    }
}
