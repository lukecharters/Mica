// Views/Controls/SFSymbolSection.swift
import SwiftUI

struct SFSymbolSection: View {
    @Binding var iconSettings: IconSettings

    @State private var showSymbolNameHelp = false
    @State private var showRenderingModeHelp = false
    @State private var showSymbolColorHelp = false
    @State private var showColorRenderingModeHelp = false
    @State private var showAutoScaleHelp = false
    @State private var showManualScaleHelp = false

    var body: some View {
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
                            //.presentationCompactAdaptation(.none)
                            //.frame(maxWidth: 500)
                            //.fixedSize(horizontal: true, vertical: false)
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
//Preference Key Resize
//            HStack(spacing: 6) {
//                Toggle("Auto scale symbol to fit", isOn: $iconSettings.useAutomaticSymbolSizing)
//                    .toggleStyle(.switch)
//                Button(action: { showAutoScaleHelp.toggle() }) {
//                    Image(systemName: "info.circle")
//                }
//                .buttonStyle(BorderlessButtonStyle())
//                .popover(isPresented: $showAutoScaleHelp) {
//                    Text("Toggle whether the symbol automatically scales to fit its container or use a manual scale.")
//                        .padding()
//                        .frame(maxWidth: 240)
//                }
//            }
//
//            if !iconSettings.useAutomaticSymbolSizing {
//                VStack(alignment: .leading, spacing: 6) {
//                    HStack(spacing: 6) {
//                        Slider(value: $iconSettings.manualSymbolScale,
//                               in: IconSettings.manualSymbolScaleRange,
//                               step: 0.01)
//                        Button(action: { showManualScaleHelp.toggle() }) {
//                            Image(systemName: "info.circle")
//                        }
//                        .buttonStyle(BorderlessButtonStyle())
//                        .popover(isPresented: $showManualScaleHelp) {
//                            Text("Manually adjust the symbol's scale percentage when automatic scaling is off.")
//                                .padding()
//                                .frame(maxWidth: 240)
//                        }
//                    }
//                    HStack {
//                        Text("Smaller")
//                        Spacer()
//                        Text("\(Int(iconSettings.manualSymbolScale * 100))%")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                        Spacer()
//                        Text("Larger")
//                    }
//                    .font(.caption)
//                }
//                .padding(.top, 4)
//            }
        }
    }
}
