// Views/Tabs/BadgeTabContent.swift
import SwiftUI

struct BadgeTabContent: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    @State private var useCustomBadgeSymbolColor = false
    @State private var useCustomBadgeHierarchicalColor = false
    @State private var useCustomBadgePalettePrimaryColor = false
    @State private var useCustomBadgePaletteSecondaryColor = false
    @State private var useCustomBadgePaletteTertiaryColor = false
    @State private var useCustomBadgeBackgroundColor = false

    var body: some View {
        Form {
            Section(header: Text("Badge Settings")) {
                Toggle("Show Badge", systemImage: "app.badge", isOn: $iconSettings.showBadge.animation())
                    .help("Add a circular badge to the icon")

            }

            if iconSettings.showBadge {
                Picker("Position", systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", selection: $iconSettings.badgePosition) {
                    ForEach(BadgePosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .onChange(of: iconSettings.badgePosition) {
                    iconSettings.badgeManualOffsetX = 0
                    iconSettings.badgeManualOffsetY = 0
                }

                // Manual badge offset
                HStack {
                    Text("X Offset")
                    Spacer()
                    Text("\(Int(iconSettings.badgeManualOffsetX * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $iconSettings.badgeManualOffsetX,
                       in: IconSettings.badgeOffsetRange,
                       step: 0.01)

                HStack {
                    Text("Y Offset")
                    Spacer()
                    Text("\(Int(iconSettings.badgeManualOffsetY * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $iconSettings.badgeManualOffsetY,
                       in: IconSettings.badgeOffsetRange,
                       step: 0.01)

                if iconSettings.badgeManualOffsetX != 0 || iconSettings.badgeManualOffsetY != 0 {
                    Button("Reset Position") {
                        iconSettings.badgeManualOffsetX = 0
                        iconSettings.badgeManualOffsetY = 0
                    }
                }

                HStack {
                    Text("Badge Size")
                    Spacer()
                    Text("\(Int(iconSettings.badgeScale * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $iconSettings.badgeScale,
                       in: IconSettings.manualSymbolScaleRange,
                       step: 0.05)

                // MARK: - Badge Content Section
                Section(header: Text("Badge Content")) {
                    Picker("Source", selection: $iconSettings.badgeIconSource) {
                        Label("SF Symbol", systemImage: "character.textbox").tag(IconSource.sfSymbol)
                        Label("Custom Image", systemImage: "photo").tag(IconSource.customImage)
                    }
                    .pickerStyle(.segmented)

                    switch iconSettings.badgeIconSource {
                    case .sfSymbol:
                        TextField("Symbol Name", text: $iconSettings.badgeSymbolName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .help("Enter an SF Symbol name for the badge (e.g., 1.circle.fill, plus, checkmark)")

                        HStack(spacing: 6) {
                            Picker("Rendering Mode", systemImage: "paintpalette", selection: $iconSettings.badgeSymbolRenderingMode) {
                                ForEach(SymbolRenderingMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        badgeSymbolColorControls

                        HStack {
                            Text("Symbol Scale")
                            Spacer()
                            Text("\(Int(iconSettings.badgeSymbolScale * 100))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $iconSettings.badgeSymbolScale,
                               in: IconSettings.manualSymbolScaleRange,
                               step: 0.05)

                        if #available(macOS 26.0, *) {
                            Toggle("Gradient", systemImage: "app.translucent", isOn: Binding(
                                get: { iconSettings.badgeSymbolColorRenderingMode == .gradient },
                                set: { iconSettings.badgeSymbolColorRenderingMode = $0 ? .gradient : .flat }
                            ))
                        }

                        Toggle("Drop Shadow", systemImage: "app.shadow", isOn: $iconSettings.badgeEnableSymbolShadow)
                            .help("Toggle the drop shadow behind the badge symbol")

                    case .customImage:
                        ImageImportControls(
                            importedImage: $iconSettings.badgeImportedImage,
                            paddingCompensation: $iconSettings.badgeImportedImagePaddingCompensation,
                            imageScale: $iconSettings.badgeImportedImageScale,
                            onImport: {}
                        )

                        Toggle("Drop Shadow", systemImage: "app.shadow", isOn: $iconSettings.badgeEnableSymbolShadow)
                            .help("Toggle the drop shadow behind the badge image")
                    }
                }

                // MARK: - Badge Background Section
                Section(header: Text("Badge Background")) {
                    Toggle("Custom Gradient", isOn: Binding(
                        get: { iconSettings.badgeUseCustomColors },
                        set: { newValue in
                            iconSettings.badgeUseCustomColors = newValue
                            if newValue {
                                iconSettings.badgeEnableBackgroundGradient = true
                            }
                        }
                    ))

                    if iconSettings.badgeUseCustomColors {
                        ColorPicker("Primary Color", selection: $iconSettings.badgeCustomPrimaryColor)
                        ColorPicker("Secondary Color", selection: $iconSettings.badgeCustomSecondaryColor)
                    } else {
                        if useCustomBadgeBackgroundColor {
                            ColorPicker(selection: $iconSettings.badgeBaseColor) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(iconSettings.badgeBaseColor)
                                        .frame(width: 12, height: 12)
                                    Text("Color")
                                }
                            }
                            Button("Use Preset", systemImage: "arrow.clockwise") {
                                useCustomBadgeBackgroundColor = false
                            }
                            .buttonStyle(.link)
                        } else {
                            let selectedColorOption = colorOptions.first { $0.color == iconSettings.badgeBaseColor }
                            Picker(
                                selection: Binding<Int?>(
                                    get: { colorOptions.firstIndex { $0.color == iconSettings.badgeBaseColor } },
                                    set: { newValue in
                                        if let index = newValue, index >= 0 {
                                            iconSettings.badgeBaseColor = colorOptions[index].color
                                        } else if newValue == -1 {
                                            useCustomBadgeBackgroundColor = true
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
                                    HStack(spacing: 12) {
                                        Text(option.name)
                                    }
                                    .tag(Optional(index))
                                }
                                Divider()
                                Text("Custom…").tag(Optional(-1))
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    if !iconSettings.badgeUseCustomColors {
                        Toggle("Gradient", systemImage: "app.translucent", isOn: $iconSettings.badgeEnableBackgroundGradient)
                    }

                    Toggle("Drop Shadow", systemImage: "app.shadow", isOn: $iconSettings.badgeEnableBackgroundShadow)
                        .help("Toggle the drop shadow behind the badge background")
                }
            }
        }
        .formStyle(GroupedFormStyle())
    }

    // MARK: - Badge Symbol Color Controls

    @ViewBuilder
    private var badgeSymbolColorControls: some View {
        switch iconSettings.badgeSymbolRenderingMode {
        case .monochrome, .multicolor:
            colorPickerWithDropdown(
                label: iconSettings.badgeSymbolRenderingMode == .monochrome ? "Symbol Color" : "Base Color",
                color: $iconSettings.badgeSymbolColor,
                useCustom: $useCustomBadgeSymbolColor
            )
        case .hierarchical:
            colorPickerWithDropdown(
                label: "Base Color",
                color: $iconSettings.badgeHierarchicalSymbolColor,
                useCustom: $useCustomBadgeHierarchicalColor
            )
        case .palette:
            colorPickerWithDropdown(
                label: "Primary Color",
                color: $iconSettings.badgePaletteSymbolPrimaryColor,
                useCustom: $useCustomBadgePalettePrimaryColor
            )
            colorPickerWithDropdown(
                label: "Secondary Color",
                color: $iconSettings.badgePaletteSymbolSecondaryColor,
                useCustom: $useCustomBadgePaletteSecondaryColor
            )
            colorPickerWithDropdown(
                label: "Tertiary Color",
                color: $iconSettings.badgePaletteSymbolTertiaryColor,
                useCustom: $useCustomBadgePaletteTertiaryColor
            )
        }
    }

    @ViewBuilder
    private func colorPickerWithDropdown(label: String, color: Binding<Color>, useCustom: Binding<Bool>) -> some View {
        if useCustom.wrappedValue {
            ColorPicker(selection: color) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(color.wrappedValue)
                        .frame(width: 12, height: 12)
                    Text(label)
                }
            }
            Button("Use Preset", systemImage: "arrow.clockwise") {
                useCustom.wrappedValue = false
            }
            .buttonStyle(.link)
        } else {
            let selectedColorOption = colorOptions.first { $0.color == color.wrappedValue }
            Picker(
                selection: Binding<Int?>(
                    get: { colorOptions.firstIndex { $0.color == color.wrappedValue } },
                    set: { newValue in
                        if let index = newValue, index >= 0 {
                            color.wrappedValue = colorOptions[index].color
                        } else if newValue == -1 {
                            useCustom.wrappedValue = true
                        }
                    }
                ),
                label: HStack(spacing: 12) {
                    Circle()
                        .fill(selectedColorOption?.color ?? color.wrappedValue)
                        .frame(width: 12, height: 12)
                    Text(label)
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

}

