// Views/Tabs/IconTabContent.swift
import SwiftUI

struct IconTabContent: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    @State private var showSymbolNameHelp = false
    @State private var showRenderingModeHelp = false
    @State private var showSymbolColorHelp = false
    @State private var showColorRenderingModeHelp = false
    @State private var useCustomBackgroundColor = false
    @State private var useCustomSymbolColor = false
    @State private var useCustomHierarchicalColor = false
    @State private var useCustomPalettePrimaryColor = false
    @State private var useCustomPaletteSecondaryColor = false
    @State private var useCustomPaletteTertiaryColor = false

    var body: some View {
        Form {
            // MARK: - Icon Content Section
            Section(header: Text("Icon Content")) {
                Picker("Source", selection: $iconSettings.iconSource) {
                    Label("SF Symbol", systemImage: "character.textbox").tag(IconSource.sfSymbol)
                    Label("Imported", systemImage: "photo").tag(IconSource.customImage)
                }
                .pickerStyle(.segmented)

                switch iconSettings.iconSource {
                case .sfSymbol:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            TextField("Symbol name", text: $iconSettings.symbolName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button(action: { showSymbolNameHelp.toggle() }) {
                                Image(systemName: "info.circle")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .popover(isPresented: $showSymbolNameHelp) {
                                Text("Enter the name of any SF Symbol. \nDownload Apple's SF Symbols app to see a list of all available symbols.")
                                    .padding()
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Picker("Rendering Mode", systemImage: "paintpalette", selection: $iconSettings.symbolRenderingMode) {
                            ForEach(SymbolRenderingMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    symbolColorControls

                    HStack {
                        Text("Symbol Scale")
                        Spacer()
                        Text("\(Int(iconSettings.manualSymbolScale * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $iconSettings.manualSymbolScale,
                           in: IconSettings.manualSymbolScaleRange,
                           step: 0.05)

                    if #available(macOS 26.0, *) {
                        Toggle("Gradient", systemImage: "app.translucent", isOn: Binding(
                            get: { iconSettings.symbolColorRenderingMode == .gradient },
                            set: { iconSettings.symbolColorRenderingMode = $0 ? .gradient : .flat }
                        ))
                    }
                    Toggle("Drop Shadow", systemImage: "app.shadow", isOn: $iconSettings.enableSymbolShadow)
                        .help("Toggle the drop shadow behind the SF Symbol")

                case .customImage:
                    ImageImportControls(
                        importedImage: $iconSettings.importedImage,
                        paddingCompensation: .constant(false),
                        imageScale: $iconSettings.importedImageScale,
                        showPaddingCompensation: false,
                        onImport: {}
                    )

                    Toggle("Drop Shadow", systemImage: "app.shadow", isOn: $iconSettings.enableSymbolShadow)
                        .help("Toggle the drop shadow behind the imported image")
                }
            }

            // MARK: - Background Section
            Section(header: Text("Background")) {
                Picker("Background Type", systemImage: "app.grid", selection: $iconSettings.backgroundMode) {
                    Text("Standard").tag(BackgroundMode.custom)
                    Text("Liquid Glass").tag(BackgroundMode.preRendered)
                    Text("Imported").tag(BackgroundMode.importedImage)
                }
                .pickerStyle(.segmented)

                switch iconSettings.backgroundMode {
                case .importedImage:
                    ImageImportControls(
                        importedImage: $iconSettings.importedBackground,
                        paddingCompensation: $iconSettings.importedBackgroundPaddingCompensation,
                        imageScale: $iconSettings.importedBackgroundScale,
                        onImport: {}
                    )

                    Picker("Drop Shadow", systemImage: "app.shadow", selection: $iconSettings.backgroundShadowStyle) {
                        ForEach(BackgroundShadowStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                case .preRendered:
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
                    Picker("Drop Shadow", systemImage: "app.shadow", selection: $iconSettings.backgroundShadowStyle) {
                        ForEach(BackgroundShadowStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                case .custom:
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
                        ColorPicker("Primary Color", selection: $iconSettings.customPrimaryColor)
                        ColorPicker("Secondary Color", selection: $iconSettings.customSecondaryColor)
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
                            )
                            {
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

                    if !iconSettings.useCustomColors {
                        Toggle("Gradient", systemImage: "app.translucent", isOn: $iconSettings.enableBackgroundGradient)
                    }

                    Picker("Corner Radius", systemImage: "viewfinder", selection: $iconSettings.cornerRadiusStyle) {
                        ForEach(IconCornerRadiusStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Drop Shadow", systemImage: "app.shadow", selection: $iconSettings.backgroundShadowStyle) {
                        ForEach(BackgroundShadowStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .formStyle(GroupedFormStyle())
    }

    // MARK: - Symbol Color Controls

    @ViewBuilder
    private var symbolColorControls: some View {
        switch iconSettings.symbolRenderingMode {
        case .monochrome, .multicolor:
            colorPickerWithDropdown(
                label: iconSettings.symbolRenderingMode == .monochrome ? "Symbol Color" : "Base Color",
                color: $iconSettings.symbolColor,
                useCustom: $useCustomSymbolColor
            )
        case .hierarchical:
            colorPickerWithDropdown(
                label: "Base Color",
                color: $iconSettings.hierarchicalSymbolColor,
                useCustom: $useCustomHierarchicalColor
            )
        case .palette:
            colorPickerWithDropdown(
                label: "Primary Color",
                color: $iconSettings.paletteSymbolPrimaryColor,
                useCustom: $useCustomPalettePrimaryColor
            )
            colorPickerWithDropdown(
                label: "Secondary Color",
                color: $iconSettings.paletteSymbolSecondaryColor,
                useCustom: $useCustomPaletteSecondaryColor
            )
            colorPickerWithDropdown(
                label: "Tertiary Color",
                color: $iconSettings.paletteSymbolTertiaryColor,
                useCustom: $useCustomPaletteTertiaryColor
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

