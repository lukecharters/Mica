// Views/Controls/AppexIconControls.swift
import SwiftUI

struct AppexIconControls: View {
    @Binding var iconSettings: IconSettings
    @Binding var enclosureColor: AppexEnclosureColor
    @Binding var symbolColor: AppexEnclosureColor
    @State private var showSymbolNameHelp = false

    var body: some View {
        Form {
            Section(header: Text("Symbol")) {
                HStack(spacing: 6) {
                    TextField("Symbol Name", text: $iconSettings.symbolName)
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
                Picker("Color", selection: $symbolColor) {
                    ForEach(AppexEnclosureColor.allCases) { color in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color.previewColor)
                                .frame(width: 12, height: 12)
                            Text(color.displayName)
                        }
                        .tag(color)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text("Background")) {
                Picker("Color", selection: $enclosureColor) {
                    ForEach(AppexEnclosureColor.allCases) { color in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color.previewColor)
                                .frame(width: 10, height: 10)
                            Text(color.displayName)
                        }
                        .tag(color)
                    }
                }
                .pickerStyle(.menu)
            }

//            Section(header: Text("Symbol Color")) {
//
//                .labelsHidden()
//            }

            Section {
                Label("Rendered by Apple's system icon pipeline.", systemImage: "apple.logo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Falls back to a placeholder if the symbol name is invalid so the preview doesn't crash.
    private var validSymbolName: String {
        guard !iconSettings.symbolName.isEmpty,
              NSImage(systemSymbolName: iconSettings.symbolName, accessibilityDescription: nil) != nil
        else { return "app.dashed" }
        return iconSettings.symbolName
    }
}
