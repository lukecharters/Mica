// Views/Tabs/IconTabContent.swift
import SwiftUI

struct IconTabContent: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    @State private var showSymbolNameHelp = false
    @State private var showRenderingModeHelp = false
    @State private var showSymbolColorHelp = false
    @State private var showColorRenderingModeHelp = false

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
                    Picker("Rendering Mode", selection: $iconSettings.symbolRenderingMode) {
                        ForEach(SymbolRenderingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Button(action: { showRenderingModeHelp.toggle() }) {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .popover(isPresented: $showRenderingModeHelp) {
                        Text("Choose how the symbol should be rendered:\n Monochrome, Hierarchical, Multicolor, or Palette.")
                            .padding()
                            .multilineTextAlignment(.center)
                    }
                }

                symbolColorControls

                if #available(macOS 26.0, *) {
                    HStack(spacing: 6) {
                        Picker("Color Rendering Mode", selection: $iconSettings.symbolColorRenderingMode) {
                            ForEach(SymbolColorRenderingMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        Button(action: { showColorRenderingModeHelp.toggle() }) {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .popover(isPresented: $showColorRenderingModeHelp) {
                            Text("Choose how symbol colors are rendered, affecting appearance and blending.")
                                .padding()
                                .frame(maxWidth: 240)
                        }
                    }
                }
            }

            // MARK: - Background Section
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
                        glassTintColorPicker
                    }
                }
            }

            // MARK: - Shadow Section
            Section(header: Text("Shadow Settings")) {
                Toggle("Background Drop Shadow", isOn: $iconSettings.enableBackgroundShadow)
                    .help("Toggle the drop shadow behind the background shape")
                Toggle("Symbol Drop Shadow", isOn: $iconSettings.enableSymbolShadow)
                    .help("Toggle the drop shadow behind the SF Symbol")
            }
        }
        .formStyle(GroupedFormStyle())
    }

    // MARK: - Symbol Color Controls

    @ViewBuilder
    private var symbolColorControls: some View {
        switch iconSettings.symbolRenderingMode {
        case .monochrome:
            HStack(spacing: 6) {
                ColorPicker("Symbol Color", selection: $iconSettings.symbolColor)
                Button(action: { showSymbolColorHelp.toggle() }) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(BorderlessButtonStyle())
                .popover(isPresented: $showSymbolColorHelp) {
                    Text("Pick a single color for the symbol.")
                        .padding()
                        .frame(maxWidth: 240)
                }
            }
        case .hierarchical:
            HStack(spacing: 6) {
                ColorPicker("Base Color", selection: $iconSettings.hierarchicalSymbolColor)
                Button(action: { showSymbolColorHelp.toggle() }) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(BorderlessButtonStyle())
                .popover(isPresented: $showSymbolColorHelp) {
                    Text("Pick a base color for the hierarchical symbol.")
                        .padding()
                        .frame(maxWidth: 240)
                }
            }
        case .multicolor:
            HStack(spacing: 6) {
                ColorPicker("Base Color", selection: $iconSettings.symbolColor)
                Button(action: { showSymbolColorHelp.toggle() }) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(BorderlessButtonStyle())
                .popover(isPresented: $showSymbolColorHelp) {
                    Text("Pick a base color for the multicolor symbol.")
                        .padding()
                        .frame(maxWidth: 240)
                }
            }
        case .palette:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ColorPicker("Primary Color", selection: $iconSettings.paletteSymbolPrimaryColor)
                    Button(action: { showSymbolColorHelp.toggle() }) {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .popover(isPresented: $showSymbolColorHelp) {
                        Text("Pick up to three colors for palette symbols.")
                            .padding()
                            .frame(maxWidth: 240)
                    }
                }
                ColorPicker("Secondary Color", selection: $iconSettings.paletteSymbolSecondaryColor)
                ColorPicker("Tertiary Color", selection: $iconSettings.paletteSymbolTertiaryColor)
            }
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
