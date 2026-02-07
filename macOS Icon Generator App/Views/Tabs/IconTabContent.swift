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
            // MARK: - Symbol Section
            Section(header: Text("SF Symbol")) {
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

                if #available(macOS 26.0, *) {
                    Toggle("Gradient", systemImage: "app.translucent", isOn: Binding(
                        get: { iconSettings.symbolColorRenderingMode == .gradient },
                        set: { iconSettings.symbolColorRenderingMode = $0 ? .gradient : .flat }
                    ))
                }
                Toggle("Drop Shadow", systemImage: "app.shadow", isOn: $iconSettings.enableSymbolShadow)
                    .help("Toggle the drop shadow behind the SF Symbol")
            }

            // MARK: - Background Section
            Section(header: Text("Background")) {
                Toggle("Custom Gradient", isOn: $iconSettings.useCustomColors)

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

                Toggle("Gradient", systemImage: "app.translucent", isOn: $iconSettings.enableBackgroundGradient)

                if #available(macOS 26.0, *) {
                    Picker("Liquid Glass", systemImage: "app.specular", selection: $iconSettings.glassEffect) {
                        ForEach(GlassEffect.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if iconSettings.glassEffect.supportsTintColorSelection {
                        glassTintColorPicker
                    }
                }
                Picker("Corner Radius", systemImage: "viewfinder", selection: $iconSettings.cornerRadiusStyle) {
                    ForEach(IconCornerRadiusStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Drop Shadow", systemImage: "app.shadow", isOn: $iconSettings.enableBackgroundShadow)
                    .help("Toggle the drop shadow behind the background shape")
                
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

    // MARK: - Glass Tint Color Picker

    @available(macOS 26.0, *)
    private var glassTintColorPicker: some View {
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

        return Picker(
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

