// Views/Controls/SFSymbolSection.swift
import SwiftUI

struct SFSymbolSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        Section(header: Text("SF Symbol")) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Symbol name (e.g., gearshape.fill)", text: $iconSettings.symbolName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .help("Enter the name of any SF Symbol. Examples: gearshape.fill, wifi, airplane, bell.fill")
            }

            Picker("Rendering Mode", selection: $iconSettings.symbolRenderingMode) {
                ForEach(SymbolRenderingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            switch iconSettings.symbolRenderingMode {
            case .monochrome:
                ColorPicker("Symbol Color", selection: $iconSettings.symbolColor)
            case .hierarchical:
                ColorPicker("Base Color", selection: $iconSettings.hierarchicalSymbolColor)
            case .multicolor:
                ColorPicker("Base Color", selection: $iconSettings.symbolColor)
            case .palette:
                ColorPicker("Primary Color", selection: $iconSettings.paletteSymbolPrimaryColor)
                ColorPicker("Secondary Color", selection: $iconSettings.paletteSymbolSecondaryColor)
                ColorPicker("Tertiary Color", selection: $iconSettings.paletteSymbolTertiaryColor)
            }
        }
    }
}
