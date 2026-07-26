// Views/Controls/SymbolNameField.swift
import SwiftUI

/// SF Symbol name field with a button that opens the full symbol browser. Shared
/// by the icon and badge Source sections and by the simple pane, so all three
/// spell the row the same way.
struct SymbolNameField: View {
    @Binding var symbolName: String
    /// Help text for the text field. The browse button keeps its own.
    var help: String? = nil

    @State private var showSymbolPicker = false

    var body: some View {
        HStack(spacing: 8) {
            TextField(text: $symbolName, prompt: Text("Symbol")) {
                Label("Symbol", systemImage: symbolNameIsValid ? symbolName : "questionmark.square.dashed")
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .help(help ?? "")

            Button(action: { showSymbolPicker = true }) {
                Image(systemName: "square.grid.2x2.fill")
            }
            .help("Browse SF Symbols")
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: $symbolName)
        }
    }

    /// Whether the current name resolves to a real SF Symbol, so the label can
    /// show its glyph without blanking out on a partially-typed name.
    private var symbolNameIsValid: Bool {
        !symbolName.isEmpty
            && NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) != nil
    }
}

#Preview {
    @Previewable @State var symbol = "star.fill"
    Form {
        Section("Source") {
            SymbolNameField(symbolName: $symbol)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
