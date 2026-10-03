// SymbolCalibrationTool.swift
//
// Reviews the pixel fit's per-symbol calibration against Apple's rendering, and
// runs the fit. Edits go to Application Support/Mica/symbol-calibration-fitted.json;
// symbol-calibration.json, which the app renders from while the developer tools are
// on, changes only through Adopt Fitted Set and Restore Bundled Calibration.

import SwiftUI

// MARK: - Calibration Store

@Observable
class SymbolCalibrationStore {
    static let storedFileName = "symbol-calibration.json"
    static let fittedFileName = "symbol-calibration-fitted.json"

    /// The fitted set, which this tool shows and edits.
    var symbolEntries: [String: SymbolCalibrationEntry] = [:]
    /// Whether an Application Support `symbol-calibration.json` exists, i.e. whether
    /// `SymbolSizingService` renders from it rather than from the bundled one.
    private(set) var hasOverride = false
    private let directory: URL

    var storedURL: URL { directory.appendingPathComponent(Self.storedFileName) }
    var fittedURL: URL { directory.appendingPathComponent(Self.fittedFileName) }

    /// `directory` defaults to Application Support/Mica; tests pass a temporary one.
    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Mica", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.directory = dir
        hasOverride = FileManager.default.fileExists(atPath: storedURL.path)
        load()
    }

    /// The stored set as it is on disk, or as Mica ships it.
    func storedCalibration() -> SymbolCalibration? {
        let url = FileManager.default.fileExists(atPath: storedURL.path)
            ? storedURL
            : Bundle.main.url(forResource: "symbol-calibration", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url),
              var file = try? JSONDecoder().decode(SymbolCalibration.self, from: data) else { return nil }
        file.symbols = SymbolCatalog.bundled.rekeyedToCurrentNames(file.symbols)
        return file
    }

    func setEntry(_ entry: SymbolCalibrationEntry, forSymbol symbol: String) {
        symbolEntries[symbol] = entry
        save()
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try Self.encoded(SymbolCalibration(version: 1, symbols: symbolEntries))
            let backupURL = fittedURL.deletingPathExtension().appendingPathExtension("backup.json")
            if FileManager.default.fileExists(atPath: fittedURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.copyItem(at: fittedURL, to: backupURL)
            }
            try data.write(to: fittedURL, options: .atomic)
        } catch {
            print("SymbolCalibrationStore: failed to save — \(error)")
        }
    }

    private static func encoded(_ file: SymbolCalibration) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    /// The fitted file, or the stored calibration's symbols when there is none yet.
    /// Nothing is written until the first edit.
    private func load() {
        guard FileManager.default.fileExists(atPath: fittedURL.path) else {
            symbolEntries = storedCalibration()?.symbols ?? [:]
            return
        }
        do {
            let file = try JSONDecoder().decode(SymbolCalibration.self, from: Data(contentsOf: fittedURL))
            symbolEntries = SymbolCatalog.bundled.rekeyedToCurrentNames(file.symbols)
        } catch {
            print("SymbolCalibrationStore: failed to load — \(error)")
        }
    }

    /// Merges the fitted file into the stored one: each fitted entry replaces the stored
    /// entry for its symbol, and everything else in the stored file stays. The stored file
    /// is first copied to a timestamped name that no later save overwrites; returns that
    /// copy's URL. Throws when there is no fitted file.
    @discardableResult
    func adoptFittedSet(at date: Date = .now) throws -> URL? {
        let fitted = try JSONDecoder().decode(SymbolCalibration.self, from: Data(contentsOf: fittedURL))
        var adopted = storedCalibration() ?? fitted
        adopted.symbols.merge(SymbolCatalog.bundled.rekeyedToCurrentNames(fitted.symbols)) { _, fitted in fitted }
        let data = try Self.encoded(adopted)

        var copy: URL?
        if FileManager.default.fileExists(atPath: storedURL.path) {
            let stamp = date.formatted(.iso8601.year().month().day().dateSeparator(.omitted)
                .time(includingFractionalSeconds: false).timeSeparator(.omitted))
            let url = directory.appendingPathComponent("symbol-calibration.before-adopt-\(stamp).json")
            try FileManager.default.copyItem(at: storedURL, to: url)
            copy = url
        }
        try data.write(to: storedURL, options: .atomic)
        hasOverride = true
        return copy
    }

    /// Backs up and deletes the Application Support `symbol-calibration.json`, so the
    /// app renders with the bundled calibration again from its next launch. The fitted
    /// set is left alone.
    func restoreBundledCalibration() {
        let backupURL = storedURL.deletingPathExtension().appendingPathExtension("backup.json")
        if FileManager.default.fileExists(atPath: storedURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: storedURL, to: backupURL)
            try? FileManager.default.removeItem(at: storedURL)
        }
        hasOverride = FileManager.default.fileExists(atPath: storedURL.path)
    }
}

// MARK: - Icon View

private struct DimIconView: View {
    let symbolName: String
    let displaySize: CGFloat
    let multiplier: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
    let weight: Font.Weight
    let symbolOnly: Bool

    private var scale: CGFloat { displaySize / CalibrationIconGeometry.baseSize }
    private var backgroundInset: CGFloat { CalibrationIconGeometry.baseInset * scale }
    private var cornerRadius: CGFloat { CalibrationIconGeometry.baseCornerRadius * scale }
    var enclosureSize: CGFloat { CalibrationIconGeometry.enclosure(forDisplaySize: displaySize) }

    private var fontSize: CGFloat { enclosureSize * multiplier }
    private var xPx: CGFloat { enclosureSize * xOffset }
    private var yPx: CGFloat { enclosureSize * yOffset }

    var body: some View {
        ZStack {
            if !symbolOnly {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.blue.gradient)
                    .padding(backgroundInset)
            }

            Image(systemName: symbolName)
                .font(.system(size: fontSize, weight: weight))
                .foregroundColor(symbolOnly ? .red : .white)
                .offset(x: xPx, y: yPx)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

// MARK: - Review List

enum CalibrationReviewFilter: String, CaseIterable {
    case all = "All"
    case needsReview = "Needs Review"
    case lowScore = "Low Score"
    case reviewed = "Reviewed"
    case handEdited = "Hand-edited"
    case skipped = "Skipped"
    case unfitted = "Unfitted"

    /// Whether `entry` belongs under this filter; `threshold` is the pixel fit's.
    func includes(_ entry: SymbolCalibrationEntry?, threshold: Double) -> Bool {
        switch self {
        case .all: true
        case .needsReview: entry?.status == "needs-review"
        case .lowScore: entry?.fitScore.map { $0 < threshold } ?? false
        case .reviewed: entry?.reviewed == true
        case .handEdited: entry != nil && entry?.source == nil
        case .skipped: entry?.status == "skipped"
        case .unfitted: entry == nil
        }
    }
}

enum CalibrationReviewSort: String, CaseIterable {
    case name = "Name"
    case score = "Score"
}

enum CalibrationReviewList {
    /// The symbols to show, in order: every catalog name and every name with an entry,
    /// narrowed by `filter` and `search`. Score order puts the worst first, then the
    /// entries without a score.
    static func symbols(
        catalog: [String], entries: [String: SymbolCalibrationEntry],
        filter: CalibrationReviewFilter, threshold: Double, search: String, sort: CalibrationReviewSort
    ) -> [String] {
        let names = Set(catalog).union(entries.keys)
        var list = names.filter { filter.includes(entries[$0], threshold: threshold) }
        if !search.isEmpty {
            list = list.filter { $0.localizedCaseInsensitiveContains(search) }
        }
        switch sort {
        case .name:
            return list.sorted()
        case .score:
            return list.sorted { a, b in
                switch (entries[a]?.fitScore, entries[b]?.fitScore) {
                case let (x?, y?): x == y ? a < b : x < y
                case (.some, nil): true
                case (nil, .some): false
                case (nil, nil): a < b
                }
            }
        }
    }
}

// MARK: - Advance

/// Where Space and Escape land once the current symbol is written.
///
/// The write can drop the current symbol out of a live filter, shifting every later
/// symbol up one. So the next symbol is chosen from the list as it stood before the
/// write, and located in the list after it.
enum CalibrationAdvance: Equatable {
    case stay
    case index(Int)

    static func next(symbol: String, before: [String], after: [String]) -> CalibrationAdvance {
        if let position = before.firstIndex(of: symbol),
           before.indices.contains(position + 1),
           let next = after.firstIndex(of: before[position + 1]) {
            return .index(next)
        }
        if after.contains(symbol) || after.isEmpty { return .stay }
        return .index(after.count - 1)
    }
}

// MARK: - Confirmations

/// The destructive confirmations, as one value: one `.alert` per view.
private enum CalibrationConfirmation: Identifiable {
    case restoreBundledCalibration
    case adoptFittedSet(count: Int, flagged: Int)

    var id: String {
        switch self {
        case .restoreBundledCalibration: "restore"
        case .adoptFittedSet: "adopt"
        }
    }

    var title: String {
        switch self {
        case .restoreBundledCalibration: "Restore Bundled Calibration"
        case .adoptFittedSet: "Adopt Fitted Set"
        }
    }

    var confirmLabel: String {
        switch self {
        case .restoreBundledCalibration: "Restore"
        case .adoptFittedSet: "Adopt"
        }
    }

    var message: String {
        switch self {
        case .restoreBundledCalibration:
            "Delete the Application Support calibration and go back to the one Mica ships, "
                + "so the app renders with the shipped symbol sizing again. A .backup.json "
                + "copy is kept, and the app must be relaunched to pick this up."
        case .adoptFittedSet(let count, let flagged):
            "Replace the stored calibration with the fitted set's \(count) symbols, keeping any stored "
                + "symbol the fitted set lacks. The stored file is copied to a symbol-calibration.before-adopt "
                + "file first, and the app must be relaunched to render with it."
                + (flagged > 0 ? " \(flagged) fitted symbols are flagged for review and will not be used." : "")
        }
    }
}

private enum ComparisonMode: String, CaseIterable {
    case overlay = "Overlay"
    case tintedOverlay = "Tinted Overlay"
    case sideBySide = "Side by Side"
    case difference = "Difference"
    case grid = "Grid"
}

// MARK: - Main Tool

struct SymbolCalibrationTool: View {
    @State private var store = SymbolCalibrationStore()
    @State private var service = AppexReferenceService()
    @State private var pixelFit = PixelFitRun()
    @AppStorage("pixelFitThreshold") private var pixelFitThreshold = 0.85

    private let catalog = SymbolCatalog.bundled.currentNames(on: .running)

    /// The list as last computed. Recomputed on a filter, search or sort change and after
    /// each write that can move a symbol, never on a slider edit, so dragging a slider
    /// cannot drop the symbol out from under it.
    @State private var shown: [String] = []
    @State private var selectedSymbol: String?

    @State private var filter: CalibrationReviewFilter = .needsReview
    @State private var sort: CalibrationReviewSort = .score
    @State private var searchText = ""

    @State private var multiplier = 0.65
    @State private var xOffset = 0.0
    @State private var yOffset = 0.0
    @State private var weight: Font.Weight = SymbolCalibrationEntry.defaultWeight

    @State private var comparisonMode: ComparisonMode = .overlay
    @State private var overlayOpacity = 0.5
    @State private var showGridOverlay = false
    @State private var gridThumbSize: CGFloat = 96
    @State private var gridTintOverlay = false

    @State private var referenceImage: NSImage?
    @State private var isLoadingReference = false
    @State private var errorMessage: String?

    @State private var adoptResult: String?
    @State private var confirmation: CalibrationConfirmation?

    private let displaySize: CGFloat = 512

    private var currentSymbol: String? {
        guard let selectedSymbol, shown.contains(selectedSymbol) else { return nil }
        return selectedSymbol
    }

    private var currentIndex: Int? {
        currentSymbol.flatMap { shown.firstIndex(of: $0) }
    }

    private func computeList() -> [String] {
        CalibrationReviewList.symbols(
            catalog: catalog, entries: store.symbolEntries, filter: filter,
            threshold: pixelFitThreshold, search: searchText, sort: sort)
    }

    /// Recomputes the list, keeping the selection when it is still shown.
    private func refreshList() {
        shown = computeList()
        if selectedSymbol == nil || !shown.contains(selectedSymbol!) {
            selectedSymbol = shown.first
        }
        loadCurrentSymbol()
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            controlsSidebar
                .frame(width: 650)

            Divider()

            comparisonArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .alert(
            confirmation?.title ?? "",
            isPresented: confirmationPresented,
            presenting: confirmation
        ) { item in
            Button(item.confirmLabel) { perform(item) }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(item.message)
        }
        .onAppear { refreshList() }
        .onChange(of: pixelFit.isRunning) { _, running in
            if !running { refreshList() }
        }
        .onChange(of: selectedSymbol) { _, _ in loadCurrentSymbol() }
        .focusable()
        .onKeyPress(.space) { markCalibratedAndAdvance(); return .handled }
        .onKeyPress(.escape) { markSkippedAndAdvance(); return .handled }
        .onKeyPress(phases: .down) { press in handleKeyPress(press) }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let hasShift = press.modifiers.contains(.shift)
        let hasCommand = press.modifiers.contains(.command)

        switch press.key {
        case .leftArrow where hasShift:
            nudgeXOffset(by: -0.001); return .handled
        case .rightArrow where hasShift:
            nudgeXOffset(by: 0.001); return .handled
        case .upArrow where hasShift:
            nudgeYOffset(by: -0.001); return .handled
        case .downArrow where hasShift:
            nudgeYOffset(by: 0.001); return .handled
        case .upArrow where hasCommand:
            nudgeMultiplier(by: 0.001); return .handled
        case .downArrow where hasCommand:
            nudgeMultiplier(by: -0.001); return .handled
        case .upArrow:
            navigate(by: -1); return .handled
        case .downArrow:
            navigate(by: 1); return .handled
        default:
            return .ignored
        }
    }

    private var confirmationPresented: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } })
    }

    private func perform(_ item: CalibrationConfirmation) {
        switch item {
        case .restoreBundledCalibration:
            store.restoreBundledCalibration()
        case .adoptFittedSet:
            do {
                let copy = try store.adoptFittedSet()
                adoptResult = copy.map { "Adopted. The previous stored calibration is in \($0.lastPathComponent)." }
                    ?? "Adopted."
            } catch {
                adoptResult = "Could not adopt the fitted set: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Controls Sidebar

    private var controlsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                searchAndFilter
                Divider()
                symbolInfo
                if comparisonMode != .grid {
                    Divider()
                    parameterSliders
                }
                Divider()
                progressInfo
                Divider()
                pixelFitSection
                Divider()
                overrideSection
                Divider()
                keyboardShortcutsHelp
            }
            // Both bounds: a max alone adopts a wider child's width, and the
            // scroll view then centres the overflow off the pane's left edge.
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var searchAndFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search")
                .font(.headline)

            TextField("Filter by symbol name...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in refreshList() }

            FillingSegmentedPicker(
                segments: CalibrationReviewFilter.allCases.map { .init($0.rawValue, value: $0) },
                selection: $filter,
                accessibilityLabel: "Filter"
            )
            .onChange(of: filter) { _, _ in refreshList() }

            // A definite width covers the Picker's label *and* its segments, so
            // too small squeezes the label to nothing.
            Picker("Sort", selection: $sort) {
                ForEach(CalibrationReviewSort.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            .onChange(of: sort) { _, _ in refreshList() }

            Text("\(shown.count) symbols")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Symbol Info

    private var symbolInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Symbol")
                    .font(.headline)
                Spacer()
                if let index = currentIndex {
                    Button { navigate(by: -1) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.borderless)
                        .disabled(index <= 0)
                    Text("\(index + 1)/\(shown.count)")
                        .font(.caption.monospacedDigit())
                    Button { navigate(by: 1) } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.borderless)
                        .disabled(index >= shown.count - 1)
                }
            }

            if let symbol = currentSymbol {
                HStack {
                    Image(systemName: symbol)
                        .font(.title2)
                    Text(symbol)
                        .font(.body.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }

                let entry = store.symbolEntries[symbol]
                let status = entry?.status ?? "unfitted"
                HStack(spacing: 8) {
                    Label(status.capitalized, systemImage: statusIcon(for: status))
                        .foregroundStyle(statusColor(for: status))
                    Text(provenance(of: entry))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            } else {
                Text("No symbols match the filter")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func provenance(of entry: SymbolCalibrationEntry?) -> String {
        guard let entry else { return "No entry" }
        guard entry.source == PixelFitter.source, let score = entry.fitScore else { return "Hand-edited" }
        return String(format: "Pixel fit, score %.3f", score) + (entry.reviewed == true ? ", reviewed" : "")
    }

    // MARK: - Parameter Sliders

    private var parameterSliders: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Parameters")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    multiplier = 0.65
                    xOffset = 0.0
                    yOffset = 0.0
                    weight = SymbolCalibrationEntry.defaultWeight
                    autoSave()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            parameterSlider("Multiplier", value: $multiplier, in: 0.3...1.0, format: "%.4f")
            parameterSlider("X Offset", value: $xOffset, in: -0.1...0.1, format: "%+.4f")
            parameterSlider("Y Offset", value: $yOffset, in: -0.1...0.1, format: "%+.4f")

            // The frame has to fit the Picker's label as well as the four segments.
            Picker("Weight", selection: $weight) {
                Text("Regular").tag(Font.Weight.regular)
                Text("Medium").tag(Font.Weight.medium)
                Text("Semibold").tag(Font.Weight.semibold)
                Text("Bold").tag(Font.Weight.bold)
            }
            .pickerStyle(.segmented)
            .frame(width: 340)
            .onChange(of: weight) { _, _ in autoSave() }

            if let symbol = currentSymbol {
                let enclosure = DimIconView(
                    symbolName: symbol, displaySize: displaySize,
                    multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
                    weight: weight, symbolOnly: false
                ).enclosureSize
                Text("Font size: \(String(format: "%.1f", enclosure * multiplier)) pt (enclosure: \(String(format: "%.1f", enclosure)) pt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func parameterSlider(_ title: LocalizedStringKey, value: Binding<Double>,
                                 in range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: String(format: format, value.wrappedValue))
                    .font(.caption.monospacedDigit())
            }
            Slider(value: value, in: range, step: 0.005)
                .onChange(of: value.wrappedValue) { _, _ in autoSave() }
        }
    }

    // MARK: - Progress

    private var progressInfo: some View {
        let entries = Array(store.symbolEntries.values)
        let fitted = entries.filter { $0.source == PixelFitter.source }.count
        let needsReview = entries.filter { $0.status == "needs-review" }.count
        let reviewed = entries.filter { $0.reviewed == true }.count
        let handEdited = entries.filter { $0.source == nil }.count
        let unfitted = catalog.filter { store.symbolEntries[$0] == nil }.count

        return VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                progressRow("Catalog symbols:", catalog.count)
                progressRow("Fitted:", fitted, .green)
                progressRow("Needs review:", needsReview, .blue)
                progressRow("Reviewed:", reviewed)
                progressRow("Hand-edited:", handEdited)
                progressRow("Unfitted:", unfitted, .orange)
            }
            .font(.caption)
        }
    }

    private func progressRow(_ label: LocalizedStringKey, _ count: Int, _ colour: Color = .primary) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(verbatim: "\(count)")
                .monospacedDigit()
                .foregroundStyle(colour)
        }
    }

    // MARK: - Pixel Fit

    /// Fits symbols to Apple's macOS rendering, into the fitted set.
    private var pixelFitSection: some View {
        let remaining = catalog.filter { store.symbolEntries[$0] == nil }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Pixel Fit")
                .font(.headline)

            Text("Fits each symbol's size, offset and weight to Apple's rendering on this Mac. "
                 + "Nothing renders from the fitted set until it is adopted.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if pixelFit.isRunning {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: pixelFit.progress)
                    Text(pixelFitProgressText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                if pixelFit.isRunning {
                    Button("Stop") { pixelFit.cancel() }
                        .controlSize(.small)
                } else {
                    Button(remaining.count == catalog.count ? "Fit Catalog" : "Fit Remaining \(remaining.count)") {
                        runPixelFit(on: remaining)
                    }
                    .controlSize(.small)
                    .disabled(remaining.isEmpty)

                    Button("Refit This Symbol") {
                        if let symbol = currentSymbol { runPixelFit(on: [symbol]) }
                    }
                    .controlSize(.small)
                    .disabled(currentSymbol == nil)
                }
                Spacer()
                Button("Adopt Fitted Set…") {
                    confirmation = .adoptFittedSet(
                        count: store.symbolEntries.count,
                        flagged: store.symbolEntries.values.filter { $0.status == "needs-review" }.count)
                }
                .controlSize(.small)
                .disabled(pixelFit.isRunning || !FileManager.default.fileExists(atPath: store.fittedURL.path))
                .help("Make the fitted set the stored calibration, keeping a copy of the current one")
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([store.fittedURL])
                }
                .controlSize(.small)
            }

            HStack(spacing: 10) {
                Text("Review below")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $pixelFitThreshold, in: 0.5...0.99, step: 0.01)
                    .frame(width: 130)
                Text(verbatim: String(format: "%.2f", pixelFitThreshold))
                    .font(.caption.monospacedDigit())
                Button("Re-flag") { reflagFittedEntries() }
                    .controlSize(.small)
                    .disabled(pixelFit.isRunning)
                    .help("Mark fitted entries scoring below the threshold as needs-review, and the rest calibrated. Entries you have marked yourself keep their status.")
            }

            if let adoptResult {
                Text(adoptResult)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if PixelFitRun.systemIsDark {
                Label("The Mac is in dark mode, which changes Apple's rendering. Switch to light mode to fit.",
                      systemImage: "moon.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let message = pixelFit.message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var pixelFitProgressText: String {
        var text = "\(pixelFit.processed) / \(pixelFit.total)"
        if let symbol = pixelFit.currentSymbol { text += "  \(symbol)" }
        if let remaining = pixelFit.estimatedRemaining {
            text += "  ~" + Duration.seconds(remaining).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        }
        if pixelFit.flagged + pixelFit.unresolved + pixelFit.failed > 0 {
            text += "  flagged \(pixelFit.flagged), unresolved \(pixelFit.unresolved), failed \(pixelFit.failed)"
        }
        return text
    }

    /// Each fit starts from the symbol's own entry, so a refit reproduces its values.
    private func runPixelFit(on symbols: [String]) {
        let stored = store.storedCalibration()
        let entries = store.symbolEntries
        pixelFit.start(
            symbols: symbols,
            threshold: pixelFitThreshold,
            start: { symbol in
                let entry = entries[symbol] ?? stored?.symbols[symbol]
                return PixelFitter.Values(
                    multiplier: entry?.multiplier ?? 0.65, xOffset: entry?.xOffset ?? 0,
                    yOffset: entry?.yOffset ?? 0, weight: entry?.weight ?? "regular")
            },
            write: { symbol, entry in store.symbolEntries[symbol] = entry },
            checkpoint: { store.save() })
    }

    private func reflagFittedEntries() {
        store.symbolEntries = PixelFitter.reflagged(store.symbolEntries, threshold: pixelFitThreshold)
        store.save()
        refreshList()
    }

    // MARK: - The Override

    /// What adopting does to the running app, and the way back: `SymbolSizingService`
    /// prefers the stored file over the bundled one whenever the developer tools are on.
    private var overrideSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Production Override")
                .font(.headline)

            if store.hasOverride {
                Label("Mica is rendering with the adopted calibration, not the bundled one.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Label("Mica is rendering with the bundled calibration.",
                      systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            HStack {
                Button("Restore Bundled Calibration") {
                    confirmation = .restoreBundledCalibration
                }
                .controlSize(.small)
                .disabled(!store.hasOverride)
                Spacer()
            }

            Text("Restoring keeps a .backup.json copy. Symbol sizing is read once "
                 + "per launch, so either way the app needs restarting to catch up.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var keyboardShortcutsHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow { Text("Up/Down"); Text("Previous / Next symbol") }
                GridRow { Text("Space"); Text("Accept + advance") }
                GridRow { Text("Escape"); Text("Skip + advance") }
                GridRow { Text("Cmd+Up/Down"); Text("Nudge multiplier +/-0.001") }
                GridRow { Text("Shift+Left/Right"); Text("Nudge X offset +/-0.001") }
                GridRow { Text("Shift+Up/Down"); Text("Nudge Y offset +/-0.001") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Comparison Area

    private var comparisonArea: some View {
        VStack(spacing: 0) {
            if comparisonMode == .grid {
                gridView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let symbol = currentSymbol {
                VStack(spacing: 12) {
                    Text(symbol)
                        .font(.title3.monospaced())

                    comparisonContent(for: symbol)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            } else {
                ContentUnavailableView("No Symbols", systemImage: "magnifyingglass",
                    description: Text("No symbols match the current filter"))
            }

            Divider()

            VStack(spacing: 8) {
                Picker("Mode", selection: $comparisonMode) {
                    ForEach(ComparisonMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 500)

                HStack(spacing: 16) {
                    if comparisonMode == .overlay || comparisonMode == .tintedOverlay
                        || (comparisonMode == .grid && gridTintOverlay) {
                        Text("Opacity")
                        Slider(value: $overlayOpacity, in: 0...1)
                        Text(String(format: "%.0f%%", overlayOpacity * 100))
                            .font(.caption.monospacedDigit())
                            .frame(width: 36, alignment: .trailing)
                    }

                    Toggle("Grid", isOn: $showGridOverlay)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
                .frame(maxWidth: 400)
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func comparisonContent(for symbol: String) -> some View {
        switch comparisonMode {
        case .overlay:
            overlayView(for: symbol, tinted: false)
        case .tintedOverlay:
            overlayView(for: symbol, tinted: true)
        case .sideBySide:
            sideBySideView(for: symbol)
        case .difference:
            differenceView(for: symbol)
        case .grid:
            EmptyView()
        }
    }

    private func overlayView(for symbol: String, tinted: Bool) -> some View {
        ZStack {
            referenceImageView
            ourIconView(for: symbol, symbolOnly: tinted)
                .opacity(overlayOpacity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4, y: 2)
    }

    private func sideBySideView(for symbol: String) -> some View {
        HStack(spacing: 24) {
            VStack(spacing: 6) {
                referenceImageView
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4, y: 2)
                Text("Apple Reference")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ourIconView(for: symbol, symbolOnly: false)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4, y: 2)
                Text("Our Rendering")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func differenceView(for symbol: String) -> some View {
        ZStack {
            referenceImageView
            ourIconView(for: symbol, symbolOnly: false)
                .blendMode(.difference)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4, y: 2)
    }

    @ViewBuilder
    private var referenceImageView: some View {
        if isLoadingReference {
            ProgressView()
                .frame(width: displaySize, height: displaySize)
        } else if let image = referenceImage {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: displaySize, height: displaySize)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: displaySize, height: displaySize)
                .overlay {
                    Image(systemName: "questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func ourIconView(for symbol: String, symbolOnly: Bool) -> some View {
        ZStack {
            DimIconView(
                symbolName: symbol,
                displaySize: displaySize,
                multiplier: multiplier,
                xOffset: xOffset,
                yOffset: yOffset,
                weight: weight,
                symbolOnly: symbolOnly
            )
            gridOverlay(size: displaySize)
        }
    }

    @ViewBuilder
    private func gridOverlay(size: CGFloat) -> some View {
        if showGridOverlay {
            Image("App Icon Template SVG")
                .resizable()
                .scaledToFit()
                .opacity(0.6)
                .frame(width: size, height: size)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Grid

    /// Every symbol in the list at its saved values. A tap opens it in Overlay.
    private var gridView: some View {
        let columns = [GridItem(.adaptive(minimum: gridThumbSize + 8), spacing: 8)]

        return VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(shown, id: \.self) { symbol in
                            gridCell(for: symbol)
                                .id(symbol)
                                .onTapGesture {
                                    selectedSymbol = symbol
                                    comparisonMode = .overlay
                                }
                        }
                    }
                    .padding(8)
                }
                .onAppear {
                    if let symbol = currentSymbol { proxy.scrollTo(symbol, anchor: .center) }
                }
            }

            Divider()

            HStack(spacing: 16) {
                Toggle("Tint Overlay", isOn: $gridTintOverlay)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                Text("Size")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $gridThumbSize, in: 48...256, step: 8)
                    .frame(width: 140)
                Text(verbatim: "\(Int(gridThumbSize))")
                    .font(.caption.monospacedDigit())
                    .frame(width: 28, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func gridCell(for symbol: String) -> some View {
        let entry = store.symbolEntries[symbol]
        let status = entry?.status ?? "unfitted"
        return VStack(spacing: 2) {
            GridThumbnail(
                symbol: symbol, entry: entry, size: gridThumbSize, tinted: gridTintOverlay,
                overlayOpacity: overlayOpacity, service: service
            )
            .overlay { gridOverlay(size: gridThumbSize) }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(symbol == currentSymbol ? .blue : statusColor(for: status).opacity(0.6),
                                  lineWidth: symbol == currentSymbol ? 2 : 1)
            }

            HStack(spacing: 2) {
                Circle()
                    .fill(statusColor(for: status))
                    .frame(width: 5, height: 5)
                Text(symbol)
                    .font(.system(size: max(8, gridThumbSize * 0.08)).monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: gridThumbSize - 8)
            }
        }
        .help(symbol)
    }

    // MARK: - Navigation

    private func navigate(by step: Int) {
        guard let index = currentIndex else { return }
        let target = index + step
        guard shown.indices.contains(target) else { return }
        saveCurrentValues()
        selectedSymbol = shown[target]
    }

    /// Writes `entry` to the current symbol, then moves to the next one.
    private func commitAndAdvance(_ entry: SymbolCalibrationEntry) {
        guard let symbol = currentSymbol else { return }
        let before = shown
        store.setEntry(entry, forSymbol: symbol)
        let after = computeList()
        shown = after
        switch CalibrationAdvance.next(symbol: symbol, before: before, after: after) {
        case .stay:
            selectedSymbol = after.contains(symbol) ? symbol : nil
            loadCurrentSymbol()
        case .index(let index):
            selectedSymbol = after[index]
        }
    }

    private func currentEntry(status: String) -> SymbolCalibrationEntry {
        SymbolCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: SymbolCalibrationEntry.weightToken(for: weight),
            status: status
        )
    }

    private func markCalibratedAndAdvance() {
        commitAndAdvance(markedOverCurrent(currentEntry(status: "calibrated")))
    }

    private func markSkippedAndAdvance() {
        commitAndAdvance(markedOverCurrent(currentEntry(status: "skipped")))
    }

    private func markedOverCurrent(_ entry: SymbolCalibrationEntry) -> SymbolCalibrationEntry {
        guard let symbol = currentSymbol else { return entry }
        return PixelFitter.marked(entry, over: store.symbolEntries[symbol])
    }

    // MARK: - Load / Save

    private func loadCurrentSymbol() {
        guard let symbol = currentSymbol else {
            referenceImage = nil
            return
        }

        if let existing = store.symbolEntries[symbol] {
            multiplier = existing.multiplier
            xOffset = existing.xOffset
            yOffset = existing.yOffset
            weight = existing.fontWeight
        } else {
            multiplier = 0.65
            xOffset = 0.0
            yOffset = 0.0
            weight = SymbolCalibrationEntry.defaultWeight
        }

        loadReferenceImage(for: symbol)
    }

    private func loadReferenceImage(for symbol: String) {
        isLoadingReference = true
        errorMessage = nil
        referenceImage = nil

        Task {
            do {
                let image = try await service.referenceIcon(for: symbol)
                guard symbol == currentSymbol else { return }
                referenceImage = image
                isLoadingReference = false
            } catch {
                guard symbol == currentSymbol else { return }
                errorMessage = error.localizedDescription
                isLoadingReference = false
            }

            if let index = shown.firstIndex(of: symbol) {
                service.prefetch(Array(shown.dropFirst(index + 1).prefix(3)))
            }
        }
    }

    private func saveCurrentValues() {
        guard let symbol = currentSymbol, let existing = store.symbolEntries[symbol] else { return }
        let entry = SymbolCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: SymbolCalibrationEntry.weightToken(for: weight),
            status: existing.status
        )
        // Loading a symbol sets every slider, and each one's onChange lands here: only a
        // changed value is an edit, or viewing an entry would strip its source and score.
        guard !entry.hasSameValues(as: existing) else { return }
        store.setEntry(entry, forSymbol: symbol)
    }

    private func autoSave() {
        saveCurrentValues()
    }

    // MARK: - Nudge Helpers

    private func nudgeMultiplier(by delta: Double) {
        multiplier += delta
        autoSave()
    }

    private func nudgeXOffset(by delta: Double) {
        xOffset += delta
        autoSave()
    }

    private func nudgeYOffset(by delta: Double) {
        yOffset += delta
        autoSave()
    }

    // MARK: - Status Helpers

    private func statusIcon(for status: String) -> String {
        switch status {
        case "calibrated": "checkmark.circle.fill"
        case "skipped": "forward.fill"
        case "needs-review": "pencil.circle"
        default: "circle.dashed"
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "calibrated": .green
        case "skipped": .orange
        case "needs-review": .blue
        default: .secondary
        }
    }
}

// MARK: - Grid Thumbnail

/// One symbol at its saved values, over Apple's reference when `tinted`. The reference
/// loads only while the cell is on screen.
private struct GridThumbnail: View {
    let symbol: String
    let entry: SymbolCalibrationEntry?
    let size: CGFloat
    let tinted: Bool
    let overlayOpacity: Double
    let service: AppexReferenceService

    @State private var reference: NSImage?

    var body: some View {
        ZStack {
            if tinted {
                if let reference {
                    Image(nsImage: reference)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
            }
            DimIconView(
                symbolName: symbol,
                displaySize: size,
                multiplier: entry?.multiplier ?? 0.65,
                xOffset: entry?.xOffset ?? 0,
                yOffset: entry?.yOffset ?? 0,
                weight: entry?.fontWeight ?? SymbolCalibrationEntry.defaultWeight,
                symbolOnly: tinted
            )
            .opacity(tinted ? overlayOpacity : 1)
        }
        .frame(width: size, height: size)
        .task(id: tinted) {
            guard tinted, reference == nil else { return }
            reference = try? await service.referenceIcon(for: symbol)
        }
    }
}

// MARK: - Preview

#Preview {
    SymbolCalibrationTool()
        .frame(width: 1100, height: 800)
}
