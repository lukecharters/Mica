// Views/Controls/AppexIconControls.swift
import SwiftUI

struct AppexIconControls: View {
    @Binding var iconSettings: IconSettings
    @Binding var enclosureColor: AppexEnclosureColor

    var body: some View {
        Form {
            Section(header: Text("Symbol")) {
                HStack(spacing: 6) {
                    TextField("Symbol name", text: $iconSettings.symbolName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                HStack(spacing: 8) {
                    Image(systemName: validSymbolName)
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)

                    Text(iconSettings.symbolName.isEmpty ? "Enter a symbol name" : iconSettings.symbolName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
                .frame(height: 36)
            }

            Section(header: Text("Enclosure Color")) {
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
                .labelsHidden()
            }

            Section {
                Label("Rendered by Apple's system icon pipeline.", systemImage: "apple.logo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Fixed output: 512pt @2x (1024×1024px), Display P3.", systemImage: "info.circle")
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
