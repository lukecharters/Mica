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
        repeating: GridItem(.flexible(), spacing: 16),
        count: SymbolGridNavigation.columnCount
    )

    var body: some View {
        NavigationStack {
            grid
                .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
                .safeAreaInset(edge: .bottom) { footer }
        }
        // Wide enough that six columns leave each label ~120pt, which is most of a
        // symbol name on one or two lines. The column count is fixed because the
        // arrow keys need it — see `SymbolGridNavigation`.
        .frame(width: 900, height: 640)
        .onAppear { cursor = selectedSymbol }
        .onChange(of: searchText) { _, _ in reseatCursor() }
        .background(WindowKeyMonitor(handler: handleKeyDown))
    }

    private var grid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
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
                .padding(20)
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
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 36))
                .frame(width: 76, height: 76)
                .background(
                    isSelected ? Color.accentColor.opacity(0.15)
                               : Color(nsColor: .controlBackgroundColor)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isCursor ? Color.accentColor : Color.clear, lineWidth: 2.5)
                )
            Text(verbatim: Self.wrappableName(symbol))
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                // Two lines is the common case; a third keeps the longest names whole
                // rather than truncating them, and the minimum keeps rows level.
                .frame(maxWidth: 122, minHeight: 30, alignment: .top)
        }
        .help(symbol)
        // Copy the name and nothing else. A symbol name is the one thing in this
        // sheet that is useful outside it — in a CLI invocation, a configuration
        // file, a commit message — and until now the only way to get one out was
        // to select the symbol and then re-select the text in the inspector's
        // field.
        //
        // *Not* here, deliberately: **Open in SF Symbols**, which review finding
        // 12 lists. There is no public URL scheme that opens that app at a given
        // symbol, so the row could only launch it at whatever it last showed —
        // which is a worse answer than no row, and one that does nothing at all
        // if the app is not installed.
        .contextMenu {
            Button("Copy Symbol Name") {
                IconPasteboard.write(symbolName: symbol)
            }
        }
    }

    /// A symbol name with a break opportunity after each dot.
    ///
    /// Symbol names are long, dot-separated and have no spaces, so the line breaker
    /// treats each one as a single word and hyphenates it mid-component —
    /// `rectangle.portrait.and.ar-` / `row.right`. A zero-width space is invisible and
    /// is a legal break, and a legal break is preferred over hyphenation, so the name
    /// wraps at its dots instead. Display only: `.help`, the search and the committed
    /// value all use the raw name.
    private static func wrappableName(_ symbol: String) -> String {
        symbol.replacingOccurrences(of: ".", with: ".\u{200B}")
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
