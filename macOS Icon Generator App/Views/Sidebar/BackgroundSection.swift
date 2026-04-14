// Views/Sidebar/BackgroundSection.swift
import SwiftUI

struct BackgroundSection: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    @State private var useCustomBackgroundColor = false

    var body: some View {
        Picker("Type", systemImage: "app.grid", selection: $iconSettings.backgroundMode) {
            Text("Standard").tag(BackgroundMode.custom)
            Text("Liquid Glass").tag(BackgroundMode.preRendered)
            Text("Imported").tag(BackgroundMode.importedImage)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        switch iconSettings.backgroundMode {
        case .importedImage:
            importedBackgroundControls
        case .preRendered:
            liquidGlassControls
        case .custom:
            standardBackgroundControls
        }
    }

    @ViewBuilder
    private var importedBackgroundControls: some View {
        ImageImportControls(
            importedImage: $iconSettings.importedBackground,
            paddingCompensation: $iconSettings.importedBackgroundPaddingCompensation,
            imageScale: $iconSettings.importedBackgroundScale,
            onImport: {}
        )

        Picker("Shadow", systemImage: "app.shadow", selection: $iconSettings.backgroundShadowStyle) {
            ForEach(BackgroundShadowStyle.allCases) { style in
                Text(style.rawValue).tag(style)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var liquidGlassControls: some View {
        Picker(
            selection: $iconSettings.preRenderedColorName,
            label: HStack(spacing: 12) {
                Circle()
                    .fill(OptionsCatalog.color(named: iconSettings.preRenderedColorName))
                    .frame(width: 12, height: 12)
                Text("Color")
            }
        ) {
            ForEach(colorOptions, id: \.name) { option in
                Text(option.name).tag(option.name)
            }
        }
        .pickerStyle(.menu)

        Toggle("Gradient", systemImage: "app.translucent", isOn: $iconSettings.enableBackgroundGradient)

        Picker("Shadow", systemImage: "app.shadow", selection: $iconSettings.backgroundShadowStyle) {
            ForEach(BackgroundShadowStyle.allCases) { style in
                Text(style.rawValue).tag(style)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var standardBackgroundControls: some View {
        Toggle("Custom Gradient", isOn: Binding(
            get: { iconSettings.useCustomColors },
            set: { newValue in
                iconSettings.useCustomColors = newValue
                if newValue {
                    iconSettings.enableBackgroundGradient = true
                }
            }
        ))

        if iconSettings.useCustomColors {
            ColorPicker("Primary", selection: $iconSettings.customPrimaryColor)
            ColorPicker("Secondary", selection: $iconSettings.customSecondaryColor)
        } else {
            if useCustomBackgroundColor {
                ColorPicker(selection: $iconSettings.baseColor) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(iconSettings.baseColor)
                            .frame(width: 12, height: 12)
                        Text("Color")
                    }
                }
                Button("Use Preset", systemImage: "arrow.clockwise") {
                    useCustomBackgroundColor = false
                }
                .buttonStyle(.link)
            } else {
                let selectedColorOption = colorOptions.first { $0.color == iconSettings.baseColor }
                Picker(
                    selection: Binding<Int?>(
                        get: { colorOptions.firstIndex { $0.color == iconSettings.baseColor } },
                        set: { newValue in
                            if let index = newValue, index >= 0 {
                                iconSettings.baseColor = colorOptions[index].color
                            } else if newValue == -1 {
                                useCustomBackgroundColor = true
                            }
                        }
                    ),
                    label: HStack(spacing: 12) {
                        Circle()
                            .fill(selectedColorOption?.color ?? Color.blue)
                            .frame(width: 12, height: 12)
                        Text("Color")
                    }
                ) {
                    ForEach(Array(colorOptions.enumerated()), id: \.offset) { index, option in
                        Text(option.name).tag(Optional(index))
                    }
                    Divider()
                    Text("Custom…").tag(Optional(-1))
                }
                .pickerStyle(.menu)
            }
        }

        if !iconSettings.useCustomColors {
            Toggle("Gradient", systemImage: "app.translucent", isOn: $iconSettings.enableBackgroundGradient)
        }

        Picker("Corners", systemImage: "viewfinder", selection: $iconSettings.cornerRadiusStyle) {
            ForEach(IconCornerRadiusStyle.allCases) { style in
                Text(style.rawValue).tag(style)
            }
        }
        .pickerStyle(.segmented)

        Picker("Shadow", systemImage: "app.shadow", selection: $iconSettings.backgroundShadowStyle) {
            ForEach(BackgroundShadowStyle.allCases) { style in
                Text(style.rawValue).tag(style)
            }
        }
        .pickerStyle(.segmented)
    }
}
