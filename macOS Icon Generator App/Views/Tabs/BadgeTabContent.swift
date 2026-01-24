// Views/Tabs/BadgeTabContent.swift
import SwiftUI

struct BadgeTabContent: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    @State private var showRenderingModeHelp = false
    @State private var showColorRenderingModeHelp = false
    @State private var showGlassEffectHelp = false

    var body: some View {
        Form {
            Section(header: Text("Badge Settings")) {
                Toggle("Show Badge", isOn: $iconSettings.showBadge.animation())
                    .help("Add a circular badge to the icon")
            }

            if iconSettings.showBadge {
                // MARK: - Badge Symbol Section
                Section(header: Text("Badge Symbol")) {
                    Picker("Badge Position", selection: $iconSettings.badgePosition) {
                        ForEach(BadgePosition.allCases) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }

                    TextField("Badge Symbol", text: $iconSettings.badgeSymbolName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .help("Enter an SF Symbol name for the badge (e.g., 1.circle.fill, plus, checkmark)")

                    HStack(spacing: 6) {
                        Picker("Rendering Mode", selection: $iconSettings.badgeSymbolRenderingMode) {
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
                            Text("Choose how the badge symbol should be rendered:\nMonochrome, Hierarchical, Multicolor, or Palette.")
                                .padding()
                                .multilineTextAlignment(.center)
                        }
                    }

                    badgeSymbolColorControls

                    if #available(macOS 26.0, *) {
                        HStack(spacing: 6) {
                            Picker("Color Rendering Mode", selection: $iconSettings.badgeSymbolColorRenderingMode) {
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
                                Text("Choose how badge symbol colors are rendered, affecting appearance and blending.")
                                    .padding()
                                    .frame(maxWidth: 240)
                            }
                        }
                    }
                }

                // MARK: - Badge Background Section
                Section(header: Text("Badge Background")) {
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

                    if #available(macOS 26.0, *) {
                        HStack(spacing: 6) {
                            Picker("Liquid Glass", selection: $iconSettings.badgeGlassEffect) {
                                ForEach(GlassEffect.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            Button(action: { showGlassEffectHelp.toggle() }) {
                                Image(systemName: "info.circle")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .popover(isPresented: $showGlassEffectHelp) {
                                Text("Apply a Liquid Glass effect to the badge background.")
                                    .padding()
                                    .frame(maxWidth: 240)
                            }
                        }

                        if iconSettings.badgeGlassEffect.supportsTintColorSelection {
                            badgeGlassTintColorPicker
                        }
                    }
                }

                // MARK: - Badge Shadow Section
                Section(header: Text("Badge Shadows")) {
                    Toggle("Badge Background Shadow", isOn: $iconSettings.badgeEnableBackgroundShadow)
                        .help("Toggle the drop shadow behind the badge background")
                    Toggle("Badge Symbol Shadow", isOn: $iconSettings.badgeEnableSymbolShadow)
                        .help("Toggle the drop shadow behind the badge symbol")
                }
            }
        }
        .formStyle(GroupedFormStyle())
    }

    // MARK: - Badge Symbol Color Controls

    @ViewBuilder
    private var badgeSymbolColorControls: some View {
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
    }

    // MARK: - Badge Glass Tint Color Picker

    @available(macOS 26.0, *)
    private var badgeGlassTintColorPicker: some View {
        let binding = Binding(
            get: {
                colorOptions.firstIndex { $0.color == iconSettings.badgeGlassTintColor } ?? 0
            },
            set: { newValue in
                guard colorOptions.indices.contains(newValue) else { return }
                iconSettings.badgeGlassTintColor = colorOptions[newValue].color
            }
        )

        let selectedOption = colorOptions.first { $0.color == iconSettings.badgeGlassTintColor }

        return Picker(
            selection: binding,
            label: HStack(spacing: 8) {
                Circle()
                    .fill(selectedOption?.color ?? Color.blue)
                    .frame(width: 12, height: 12)
                Text("Badge Glass Tint Color")
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
