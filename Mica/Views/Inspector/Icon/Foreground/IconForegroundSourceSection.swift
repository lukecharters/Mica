// Views/Sidebar/IconSourceSection.swift
import SwiftUI

struct IconSourceSection: View {
    @Binding var iconSettings: IconSettings
    let isSystem: Bool

    @State private var showSymbolPicker = false

    /// Source selection within Custom mode (SF Symbol vs Imported image).
    private enum SourceType: String, CaseIterable, Identifiable {
        case sfSymbol = "SF Symbol"
        case imported = "Imported"
        var id: String { rawValue }
    }

    private var sourceType: Binding<SourceType> {
        Binding(
            get: {
                switch iconSettings.iconSource {
                case .sfSymbol: return .sfSymbol
                case .customImage: return .imported
                case .system: return .sfSymbol
                }
            },
            set: { newValue in
                switch newValue {
                case .sfSymbol:
                    iconSettings.iconSource = .sfSymbol
                case .imported:
                    iconSettings.iconSource = .customImage
                }
            }
        )
    }

    var body: some View {
        if isSystem {
            // System mode renders the icon as one appex image, so visibility is
            // all-or-nothing for the group rather than per layer.
            LayerVisibleToggle(isHidden: $iconSettings.iconHidden)
            symbolField
        } else {
            LayerVisibleToggle(isHidden: $iconSettings.iconForegroundHidden)

            Picker("Source", selection: sourceType) {
                ForEach(SourceType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch sourceType.wrappedValue {
            case .sfSymbol:
                symbolField

            case .imported:
                ImageImportControls(
                    importedImage: $iconSettings.importedImage,
                    onImport: { iconSettings.applyImportedIconForeground($0) }
                )
            }
        }
    }

    /// Whether the current name resolves to a real SF Symbol, so the label can
    /// show its glyph without blanking out on a partially-typed name.
    private var symbolNameIsValid: Bool {
        !iconSettings.symbolName.isEmpty
            && NSImage(systemSymbolName: iconSettings.symbolName, accessibilityDescription: nil) != nil
    }

    /// SF Symbol name field with a button that opens the full symbol browser.
    private var symbolField: some View {
        HStack(spacing: 8) {
            TextField(text: $iconSettings.symbolName, prompt: Text("Symbol")) {
                Label("Symbol", systemImage: symbolNameIsValid ? iconSettings.symbolName : "questionmark.square.dashed")
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: { showSymbolPicker = true }) {
                Image(systemName: "square.grid.2x2.fill")
            }
            .help("Browse SF Symbols")
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: $iconSettings.symbolName)
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Source") {
            IconSourceSection(iconSettings: $settings, isSystem: false)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
