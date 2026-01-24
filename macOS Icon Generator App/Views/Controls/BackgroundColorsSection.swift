// Views/Controls/BackgroundColorsSection.swift
import SwiftUI

struct BackgroundColorsSection: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    var body: some View {
        Section(header: Text("Background Colors")) {
            Picker("Corner Radius", selection: $iconSettings.cornerRadiusStyle) {
                ForEach(IconCornerRadiusStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

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
            if #available(macOS 26.0, *) {
                Picker("Liquid Glass", selection: $iconSettings.glassEffect) {
                    ForEach(GlassEffect.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if iconSettings.glassEffect.supportsTintColorSelection {
                    let binding = Binding(
                        get: {
                            colorOptions.firstIndex { $0.color == iconSettings.glassTintColor } ?? 0
                        },
                        set: { newValue in
                            guard colorOptions.indices.contains(newValue) else { return }
                            iconSettings.glassTintColor = colorOptions[newValue].color
                        }
                    )

                    let selectedOption = colorOptions.first { $0.color == iconSettings.glassTintColor }

                    Picker(
                        selection: binding,
                        label: HStack(spacing: 8) {
                            Circle()
                                .fill(selectedOption?.color ?? Color.blue)
                                .frame(width: 12, height: 12)
                            Text("Glass Tint Color")
                        }
                    ) {
                        ForEach(Array(colorOptions.enumerated()), id: \.offset) { index, option in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 12, height: 12)
                                Text(option.name)
                            }
                            .tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
    }
    }
}
