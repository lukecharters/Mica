// Views/Controls/SymbolNameField.swift
import SwiftUI

/// SF Symbol name field with a button that opens the full symbol browser. Shared
/// by the icon and badge Source sections and by the simple pane, so all three
/// spell the row the same way.
struct SymbolNameField: View {
    @Binding var symbolName: String
    /// Help text for the text field. The browse button keeps its own.
    var help: String? = nil
    /// Which layer the name belongs to, for its System-mode render result.
    var group: IconLayerGroup = .icon
    /// Whether the layer renders through the appex, where the render decides a name.
    var isSystem: Bool = false

    @Environment(\.unresolvedSystemRenders) private var unresolvedRenders

    @State private var showSymbolPicker = false

    var body: some View {
        HStack(spacing: 8) {
            TextField(text: $symbolName, prompt: Text("Symbol")) {
                Label("Symbol", systemImage: labelSymbol)
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .help(SymbolAvailability.problem(with: symbolName, status: status) ?? help ?? "")

            Button(action: { showSymbolPicker = true }) {
                Image(systemName: "square.grid.2x2.fill")
            }
            .help("Browse SF Symbols")
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: $symbolName)
        }
    }

    private var status: SymbolCatalog.Status {
        let unresolvedName = group == .badge ? unresolvedRenders.badge : unresolvedRenders.icon
        return SymbolAvailability.status(
            of: symbolName,
            isSystem: isSystem,
            renderIsUnresolved: unresolvedName == symbolName
        )
    }

    /// The symbol's own glyph when it can be drawn here, so the label does not blank
    /// out on a partially-typed name; otherwise a glyph for what is wrong.
    private var labelSymbol: String {
        switch status {
        case .available(let renderName)
            where NSImage(systemSymbolName: renderName, accessibilityDescription: nil) != nil:
            renderName
        case .available:
            "app"
        case .needsNewerMacOS:
            "exclamationmark.triangle"
        case .unknown:
            "questionmark.square.dashed"
        }
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
