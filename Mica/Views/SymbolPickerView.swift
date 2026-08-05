// SymbolPickerView.swift - For selecting SF Symbols
import SwiftUI

struct SymbolPickerView: View {
    @Binding var selectedSymbol: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    /// The keyboard cursor, deliberately *not* `selectedSymbol`: arrow keys move a
    /// pending highlight and Return commits it, so moving the cursor must not write
    /// through to the icon behind the sheet.
    @State private var cursor: String?

    /// Every SF Symbol shipped in `sf-symbols.txt`, loaded once and cached.
    private static let allSymbols: [String] = {
        guard let url = Bundle.main.url(forResource: "sf-symbols", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }()

    private var filteredSymbols: [String] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return Self.allSymbols }
        return Self.allSymbols.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: SymbolGridNavigation.columnCount
    )

    var body: some View {
        NavigationStack {
            grid
                .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
                .safeAreaInset(edge: .bottom) { footer }
        }
        .frame(width: 640, height: 460)
        .onAppear { cursor = selectedSymbol }
        .onChange(of: searchText) { _, _ in reseatCursor() }
        .background(WindowKeyMonitor(handler: handleKeyDown))
    }

    private var grid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredSymbols, id: \.self) { symbol in
                        Button {
                            commit(symbol)
                        } label: {
                            symbolCell(symbol)
                        }
                        .buttonStyle(.plain)
                        .id(symbol)
                    }
                }
                .padding()
            }
            .overlay {
                if filteredSymbols.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .onChange(of: cursor) { _, symbol in
                guard let symbol else { return }
                proxy.scrollTo(symbol, anchor: .center)
            }
            // Clearing the query restores the whole list under a cursor that did not
            // move, so nothing above scrolls it back into view.
            .onChange(of: searchText) { _, _ in
                guard let cursor else { return }
                proxy.scrollTo(cursor, anchor: .center)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Select") { commitCursor() }
                .keyboardShortcut(.defaultAction)
                .disabled(cursor == nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }

    @ViewBuilder
    private func symbolCell(_ symbol: String) -> some View {
        // Two states, because there are two: the symbol the icon is using, and the one
        // the keyboard is on. They coincide when the sheet opens.
        let isSelected = symbol == selectedSymbol
        let isCursor = symbol == cursor
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 26))
                .frame(width: 56, height: 56)
                .background(
                    isSelected ? Color.accentColor.opacity(0.15)
                               : Color(nsColor: .controlBackgroundColor)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isCursor ? Color.accentColor : Color.clear, lineWidth: 2)
                )
            Text(symbol)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 80)
        }
        .help(symbol)
    }

    // MARK: - Keyboard

    /// The search field owns the keyboard while it has focus, so the keys the grid
    /// needs are taken back before AppKit dispatches them — see `WindowKeyMonitor`.
    /// Which key means what lives in `SymbolPickerKey`, where it can be tested.
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let intent = SymbolPickerKey.intent(
            for: event,
            isEditingText: isEditingText(in: event.window),
            queryIsEmpty: searchText.isEmpty
        )

        switch intent {
        case .move(let direction):
            return move(direction)
        case .commit:
            guard cursor != nil else { return false }
            commitCursor()
            return true
        case .dismiss:
            dismiss()
            return true
        case nil:
            return false
        }
    }

    /// Whether a text field, rather than a button, is what the keyboard is aimed at.
    /// SwiftUI's fields are backed by AppKit's shared field editor, an `NSTextView`.
    private func isEditingText(in window: NSWindow?) -> Bool {
        window?.firstResponder is NSTextView
    }

    /// Moves the cursor. Plain arrow keys navigate the grid in both axes rather than
    /// only vertically: at six columns, up and down alone would reach one cell in six.
    private func move(_ direction: SymbolGridNavigation.Direction) -> Bool {
        let symbols = filteredSymbols
        let current = cursor.flatMap { symbols.firstIndex(of: $0) }
        guard let destination = SymbolGridNavigation.destination(
            from: current,
            moving: direction,
            itemCount: symbols.count
        ) else { return false }
        cursor = symbols[destination]
        return true
    }

    private func commitCursor() {
        guard let cursor else { return }
        commit(cursor)
    }

    /// Keeps the cursor on something the user can see: after a search it sits on the
    /// first match, so typing a name and pressing Return selects it without a detour
    /// through the grid.
    private func reseatCursor() {
        let symbols = filteredSymbols
        if let cursor, symbols.contains(cursor) { return }
        cursor = symbols.first
    }

    private func commit(_ symbol: String) {
        selectedSymbol = symbol
        dismiss()
    }
}

#Preview {
    @Previewable @State var selectedSymbol = "star.fill"
    SymbolPickerView(selectedSymbol: $selectedSymbol)
}
