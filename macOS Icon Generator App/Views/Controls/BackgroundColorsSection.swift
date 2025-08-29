// Views/Controls/BackgroundColorsSection.swift
import SwiftUI

struct BackgroundColorsSection: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    var body: some View {
        Section(header: Text("Background Colors")) {
            Toggle("Use Custom Colors", isOn: $iconSettings.useCustomColors)

            if iconSettings.useCustomColors {
                ColorPicker("Primary Color", selection: $iconSettings.customPrimaryColor)
                ColorPicker("Secondary Color", selection: $iconSettings.customSecondaryColor)
            } else {
                Picker("Color Preset", selection: Binding(
                    get: { colorOptions.firstIndex { $0.color == iconSettings.baseColor } ?? 0 },
                    set: { newValue in iconSettings.baseColor = colorOptions[newValue].color }
                )) {
                    ForEach(0..<colorOptions.count, id: \.self) { index in
                        Text(colorOptions[index].name)
                    }
                }
            }
        }
    }
}
