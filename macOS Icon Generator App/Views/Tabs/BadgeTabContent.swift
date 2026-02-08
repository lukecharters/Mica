// Views/Tabs/BadgeTabContent.swift
import SwiftUI

struct BadgeTabContent: View {
    @Binding var iconSettings: IconSettings
    let colorOptions: [(name: String, color: Color)]

    @State private var showRenderingModeHelp = false
    @State private var showColorRenderingModeHelp = false

    var body: some View {
        Form {
            Section(header: Text("Badge Settings")) {
                Toggle("Show Badge", systemImage: "app.badge", isOn: $iconSettings.showBadge.animation())
                    .help("Add a circular badge to the icon")
            }

            if iconSettings.showBadge {
                // MARK: - Badge Symbol Section
                Section(header: Text("Badge Symbol")) {
                    Picker("Position", systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", selection: $iconSettings.badgePosition) {
                        ForEach(BadgePosition.allCases) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }

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
                        Toggle(isOn: Binding(
                            get: { iconSettings.badgeSymbolColorRenderingMode == .gradient },
                            set: { iconSettings.badgeSymbolColorRenderingMode = $0 ? .gradient : .flat }
                        ))
                        {
                            HStack(spacing: 12) {
                            Circle()
                                    .fill(.blue.gradient)
                                .frame(width: 12, height: 12)
                            Text("Gradient")
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

                }

                // MARK: - Badge Shadow Section
                Section(header: Text("Badge Shadows")) {
                    Toggle("Badge Symbol Shadow", isOn: $iconSettings.badgeEnableSymbolShadow)
                        .help("Toggle the drop shadow behind the badge symbol")
                    Toggle("Badge Background Shadow", isOn: $iconSettings.badgeEnableBackgroundShadow)
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

}

