// AutoSizingReviewTool.swift
//
// Auto-calibration review tool built on the tight-bounds box-fit rule
// (SymbolAutoSizingService). Measures every SF Symbol, predicts its sizing
// multiplier, and compares against symbol-calibration.json:
//
//   - Uncalibrated symbols can be batch-filled from predictions.
//   - Calibrated symbols that disagree with the rule are surfaced as outliers
//     (likely stale macOS 15-era captures) for review against Apple's
//     ground-truth appex render.
//   - Symbols in Apple's container_recipes.plist carry an apple.logo badge
//     and are excluded from batch accept (the rule is NOT expected to match
//     them), but otherwise bucket like any other symbol: only actual
//     threshold misses show as outliers.
//
// Research: research/automated-sizing-and-system-resources-2026-07.md

import SwiftUI

// MARK: - Row Model

private struct AutoCalItem: Identifiable {
    let symbol: String
    let prediction: AutoSizingPrediction
    var id: String { symbol }
}

private enum AutoCalFilter: String, CaseIterable {
    case outliers = "Outliers"
    case uncalibrated = "Uncalibrated"
    case agrees = "Agrees"
    case all = "All"
}

private enum AutoCalSort: String, CaseIterable {
    case delta = "Δ"
    case name = "Name"
    case multiplier = "Predicted"
}

// MARK: - Measurement Cache

private struct TightBoundsCacheFile: Codable {
    var version: Int = 1
    var generatedAt: String
    var bounds: [String: SymbolTightBounds]
}

/// Shared with SymbolCalibrationTool, which reads the same cache to
/// flag box-fit outliers for editing.
enum TightBoundsCache {
    static var url: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("Mica", isDirectory: true)
            .appendingPathComponent("auto-tight-bounds.json")
    }

    static func load() -> [String: SymbolTightBounds]? {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(TightBoundsCacheFile.self, from: data),
              !file.bounds.isEmpty
        else { return nil }
        return file.bounds
    }

    static func save(_ bounds: [String: SymbolTightBounds]) {
        let file = TightBoundsCacheFile(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            bounds: bounds)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Apple Family Map (optional, informational)

private enum AppleFamilyMap {
    static let candidatePaths = [
        "/Applications/SF Symbols.app/Contents/Resources/Metadata/base_symbols_map.json",
        "/Applications/SF Symbols Beta.app/Contents/Resources/Metadata/base_symbols_map.json",
    ]

    /// variant -> base symbol, from Apple's own grouping. Empty if the
    /// SF Symbols app is not installed.
    static func load() -> [String: String] {
        for path in candidatePaths {
            guard let data = FileManager.default.contents(atPath: path),
                  let map = try? JSONDecoder().decode([String: [String]].self, from: data)
            else { continue }
            var reverse: [String: String] = [:]
            for (base, variants) in map {
                for variant in variants { reverse[variant] = base }
            }
            return reverse
        }
        return [:]
    }
}

// MARK: - Preview Icon (same layout math as SymbolCalibrationTool)

private struct AutoCalIconView: View {
    let symbolName: String
    let displaySize: CGFloat
    let multiplier: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
    let weight: Font.Weight
    var symbolOnly = false

    private let baseSize: CGFloat = 256
    private let baseCornerRadiusLG: CGFloat = 53
    private let baseBackgroundInset: CGFloat = 25

    private var scale: CGFloat { displaySize / baseSize }
    var enclosureSize: CGFloat { displaySize - (2 * baseBackgroundInset * scale) }

    var body: some View {
        ZStack {
            if !symbolOnly {
                RoundedRectangle(cornerRadius: baseCornerRadiusLG * scale, style: .continuous)
                    .fill(Color.blue.gradient)
                    .padding(baseBackgroundInset * scale)
            }
            Image(systemName: symbolName)
                .font(.system(size: enclosureSize * multiplier, weight: weight))
                .foregroundColor(symbolOnly ? .red : .white)
                .offset(x: enclosureSize * xOffset, y: enclosureSize * yOffset)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

// MARK: - Tool

struct AutoSizingReviewTool: View {
    @State private var store = SymbolCalibrationStore()
    @State private var service = AppexReferenceService()

    @State private var items: [AutoCalItem] = []
    @State private var recipeSymbols: Set<String> = []
    @State private var appleFamilyOf: [String: String] = [:]

    @State private var isMeasuring = false
    @State private var measureProgress = 0.0
    @State private var measuredCount = 0

    @State private var filter: AutoCalFilter = .outliers
    @State private var sort: AutoCalSort = .delta
    @State private var searchText = ""
    @State private var threshold = 0.02
    @State private var applySuggestedYOffset = false

    @State private var selectedSymbol: String?
    @State private var referenceImage: NSImage?
    @State private var isLoadingReference = false
    @State private var showReferenceOverlay = false
    @State private var overlayOpacity = 0.5
    @State private var errorMessage: String?

    @State private var showBatchAcceptConfirmation = false
    @State private var showBatchReviewConfirmation = false

    private let previewSize: CGFloat = 300

    var body: some View {
        Group {
            if isMeasuring {
                measuringView
            } else if items.isEmpty {
                ContentUnavailableView {
                    Label("No Measurements", systemImage: "ruler")
                } description: {
                    Text("Measure tight bounds for all symbols to compute predictions.")
                } actions: {
                    Button("Measure All Symbols") { startMeasurement(force: true) }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                mainContent
            }
        }
        .onAppear {
            recipeSymbols = ContainerRecipeCatalog.loadSymbolNames()
            appleFamilyOf = AppleFamilyMap.load()
            startMeasurement(force: false)
        }
    }

    // MARK: - Measurement

    private var measuringView: some View {
        VStack(spacing: 12) {
            ProgressView(value: measureProgress)
                .frame(width: 320)
            Text("Measuring tight bounds… \(measuredCount) symbols")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startMeasurement(force: Bool) {
        guard !isMeasuring else { return }

        if !force, let cached = TightBoundsCache.load() {
            buildItems(from: cached)
            return
        }

        let symbols = Self.loadSymbolList()
        guard !symbols.isEmpty else {
            errorMessage = "sf-symbols.txt not found in bundle"
            return
        }

        isMeasuring = true
        measureProgress = 0
        measuredCount = 0

        Task.detached(priority: .userInitiated) {
            var results: [String: SymbolTightBounds] = [:]
            results.reserveCapacity(symbols.count)
            for (index, symbol) in symbols.enumerated() {
                if let bounds = SymbolAutoSizingService.measureTightBounds(symbol: symbol) {
                    results[symbol] = bounds
                }
                if index % 100 == 0 {
                    let progress = Double(index) / Double(symbols.count)
                    let count = results.count
                    await MainActor.run {
                        measureProgress = progress
                        measuredCount = count
                    }
                }
            }
            TightBoundsCache.save(results)
            let final = results
            await MainActor.run {
                isMeasuring = false
                buildItems(from: final)
            }
        }
    }

    private func buildItems(from bounds: [String: SymbolTightBounds]) {
        let containerSymbols = Self.loadContainerSymbols()
        items = bounds
            .filter { !containerSymbols.contains($0.key) }
            .map { AutoCalItem(symbol: $0.key, prediction: SymbolAutoSizingService.prediction(
                for: $0.value, isBadge: SymbolAutoSizingService.isBadgeVariant($0.key))) }
            .sorted { $0.symbol < $1.symbol }
        if selectedSymbol == nil {
            selectedSymbol = filteredItems.first?.symbol
        }
    }

    private static func loadSymbolList() -> [String] {
        guard let url = Bundle.main.url(forResource: "sf-symbols", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    /// Symbols whose calibration is shared per container type — excluded here
    /// because their store entries live in `containers`, not `symbols`.
    private static func loadContainerSymbols() -> Set<String> {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appSupportURL = appSupport
            .appendingPathComponent("Mica", isDirectory: true)
            .appendingPathComponent("symbol_metrics.json")
        let url = FileManager.default.fileExists(atPath: appSupportURL.path)
            ? appSupportURL
            : Bundle.main.url(forResource: "symbol_metrics", withExtension: "json") ?? appSupportURL
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SymbolMetricsFile.self, from: data)
        else { return [] }
        var result: Set<String> = []
        for (symbol, metrics) in file.symbols {
            // Containers are recognised by measured size, not by storage key.
            let signature = String(format: "%.4f_%.4f", metrics.width, metrics.height)
            if ContainerType.matching(dimensionSignature: signature) != nil {
                result.insert(symbol)
            }
        }
        return result
    }

    // MARK: - Classification

    private func delta(for item: AutoCalItem) -> Double? {
        guard let entry = store.symbolEntries[item.symbol], entry.status == "calibrated" else { return nil }
        return item.prediction.multiplier - entry.multiplier
    }

    private func matchesFilter(_ item: AutoCalItem) -> Bool {
        matches(item, filter: filter)
    }

    private func matches(_ item: AutoCalItem, filter: AutoCalFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .uncalibrated:
            return store.symbolEntries[item.symbol] == nil
        case .outliers:
            guard let d = delta(for: item) else { return false }
            return abs(d) > threshold
        case .agrees:
            guard let d = delta(for: item) else { return false }
            return abs(d) <= threshold
        }
    }

    private var filteredItems: [AutoCalItem] {
        var list = items.filter(matchesFilter)
        if !searchText.isEmpty {
            list = list.filter { $0.symbol.localizedCaseInsensitiveContains(searchText) }
        }
        switch sort {
        case .delta:
            list.sort { abs(delta(for: $0) ?? 0) > abs(delta(for: $1) ?? 0) }
        case .name:
            list.sort { $0.symbol < $1.symbol }
        case .multiplier:
            list.sort { $0.prediction.multiplier > $1.prediction.multiplier }
        }
        return list
    }

    private var selectedItem: AutoCalItem? {
        guard let selectedSymbol else { return nil }
        return items.first { $0.symbol == selectedSymbol }
    }

    // MARK: - Main Layout

    private var mainContent: some View {
        HSplitView {
            VStack(spacing: 0) {
                header
                Divider()
                symbolList
                Divider()
                batchBar
            }
            .frame(minWidth: 460)

            detailPane
                .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .focusable()
        .onKeyPress(.space) { acceptSelectedPrediction(); return .handled }
        .onKeyPress(.escape) { markSelectedNeedsReview(); return .handled }
        .onKeyPress(.upArrow) { selectAdjacent(-1); return .handled }
        .onKeyPress(.downArrow) { selectAdjacent(1); return .handled }
        .alert("Accept \(filteredItems.count) Predictions", isPresented: $showBatchAcceptConfirmation) {
            Button("Accept All") { batchAcceptFiltered() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Write the predicted multiplier to all \(filteredItems.count) symbols in the current filter as calibrated entries (source: auto-boxfit). Apple-tuned symbols are skipped.")
        }
        .alert("Mark \(filteredItems.count) as Needs Review", isPresented: $showBatchReviewConfirmation) {
            Button("Mark All") { batchMarkNeedsReviewFiltered() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Set status to needs-review on all \(filteredItems.count) symbols in the current filter, keeping their existing values. Use the Apple Reference Calibration tool (⇧⌘K) to recapture them.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Search symbols…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $sort) {
                    ForEach(AutoCalSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            Picker("", selection: $filter) {
                ForEach(AutoCalFilter.allCases, id: \.self) { mode in
                    Text("\(mode.rawValue) (\(count(for: mode)))").tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Text("Outlier threshold")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $threshold, in: 0.01...0.1, step: 0.005)
                    .frame(width: 140)
                Text(String(format: "±%.3f", threshold))
                    .font(.caption.monospacedDigit())

                Spacer()

                if recipeSymbols.isEmpty {
                    Label("container_recipes.plist unavailable", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Button("Remeasure") { startMeasurement(force: true) }
                    .controlSize(.small)
            }

            agreementSummary
        }
        .padding(10)
    }

    private func count(for mode: AutoCalFilter) -> Int {
        items.count { matches($0, filter: mode) }
    }

    private var agreementSummary: some View {
        let deltas = items.compactMap { delta(for: $0) }
        let within = deltas.filter { abs($0) <= threshold }.count
        let mae = deltas.isEmpty ? 0 : deltas.map(abs).reduce(0, +) / Double(deltas.count)
        return HStack(spacing: 12) {
            Text("\(deltas.count) calibrated compared")
            Text(String(format: "MAE %.4f", mae))
                .monospacedDigit()
            if !deltas.isEmpty {
                Text(String(format: "%.0f%% within threshold", Double(within) / Double(deltas.count) * 100))
                    .monospacedDigit()
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    // MARK: - Symbol List

    private var symbolList: some View {
        let list = filteredItems
        return ScrollViewReader { proxy in
            List(list, selection: $selectedSymbol) { item in
                symbolRow(item)
                    .id(item.symbol)
                    .tag(item.symbol)
            }
            .onChange(of: selectedSymbol) { _, newValue in
                if let newValue {
                    proxy.scrollTo(newValue)
                    loadReference(for: newValue)
                }
            }
            .onChange(of: filter) { _, _ in
                if let first = filteredItems.first?.symbol { selectedSymbol = first }
            }
        }
    }

    private func symbolRow(_ item: AutoCalItem) -> some View {
        let entry = store.symbolEntries[item.symbol]
        let d = delta(for: item)
        return HStack(spacing: 8) {
            Image(systemName: item.symbol)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.symbol)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    if let entry {
                        Text(String(format: "cal %.3f", entry.multiplier))
                        if entry.source == "auto-boxfit" {
                            Text("auto")
                                .foregroundStyle(.purple)
                        }
                        if entry.status != "calibrated" {
                            Text(entry.status)
                                .foregroundStyle(statusColor(entry.status))
                        }
                    } else {
                        Text("uncalibrated")
                            .foregroundStyle(.secondary)
                    }
                    Text(String(format: "pred %.3f", item.prediction.multiplier))
                        .foregroundStyle(.blue)
                    if item.prediction.isClamped {
                        Text("clamped")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption2.monospacedDigit())
            }

            Spacer()

            if recipeSymbols.contains(item.symbol) {
                Image(systemName: "apple.logo")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .help("In Apple's container_recipes.plist — hand-tuned, rule not expected to match")
            }

            if let d {
                Text(String(format: "%+.3f", d))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(abs(d) > threshold ? .red : .green)
            }
        }
        .padding(.vertical, 1)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "calibrated": .green
        case "skipped": .orange
        case "needs-review": .blue
        default: .secondary
        }
    }

    // MARK: - Batch Bar

    private var batchBar: some View {
        HStack(spacing: 10) {
            Text("\(filteredItems.count) shown")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Toggle("Apply suggested Y offset", isOn: $applySuggestedYOffset)
                .toggleStyle(.checkbox)
                .font(.caption)
                .help("Also write the content-centering Y offset hint when accepting predictions")

            Button("Mark Shown as Needs Review") { showBatchReviewConfirmation = true }
                .controlSize(.small)
                .disabled(filteredItems.isEmpty)

            Button("Accept Shown Predictions") { showBatchAcceptConfirmation = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(filteredItems.isEmpty)
        }
        .padding(8)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let item = selectedItem {
            ScrollView {
                VStack(spacing: 14) {
                    detailHeader(item)
                    previewRow(item)
                    boundsInfo(item)
                    detailActions(item)
                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
        } else {
            ContentUnavailableView("No Symbol Selected", systemImage: "square.dashed")
        }
    }

    private func detailHeader(_ item: AutoCalItem) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: item.symbol)
                    .font(.title2)
                Text(item.symbol)
                    .font(.title3.monospaced())
            }
            HStack(spacing: 10) {
                if recipeSymbols.contains(item.symbol) {
                    Label("Apple hand-tuned (container_recipes)", systemImage: "apple.logo")
                        .foregroundStyle(.orange)
                }
                if let base = appleFamilyOf[item.symbol], base != item.symbol {
                    Text("Apple family: \(base)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }

    private func previewRow(_ item: AutoCalItem) -> some View {
        let entry = store.symbolEntries[item.symbol]
        return HStack(alignment: .top, spacing: 20) {
            if let entry {
                previewColumn(
                    title: String(format: "Current (%.3f)", entry.multiplier),
                    item: item,
                    multiplier: entry.multiplier,
                    xOffset: entry.xOffset,
                    yOffset: entry.yOffset,
                    weight: entry.weight == "medium" ? .medium : .regular)
            }
            previewColumn(
                title: String(format: "Predicted (%.3f)", item.prediction.multiplier),
                item: item,
                multiplier: item.prediction.multiplier,
                xOffset: 0,
                yOffset: applySuggestedYOffset ? item.prediction.suggestedYOffset : 0,
                weight: .regular)
        }
    }

    private func previewColumn(title: String, item: AutoCalItem,
                               multiplier: Double, xOffset: Double, yOffset: Double,
                               weight: Font.Weight) -> some View {
        VStack(spacing: 6) {
            ZStack {
                if showReferenceOverlay, let referenceImage {
                    Image(nsImage: referenceImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: previewSize, height: previewSize)
                    AutoCalIconView(
                        symbolName: item.symbol, displaySize: previewSize,
                        multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
                        weight: weight, symbolOnly: true)
                        .opacity(overlayOpacity)
                } else {
                    AutoCalIconView(
                        symbolName: item.symbol, displaySize: previewSize,
                        multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
                        weight: weight)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 3, y: 1)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func boundsInfo(_ item: AutoCalItem) -> some View {
        let b = item.prediction.bounds
        return VStack(spacing: 8) {
            HStack(spacing: 16) {
                Toggle("Apple reference overlay", isOn: $showReferenceOverlay)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: showReferenceOverlay) { _, on in
                        if on { loadReference(for: item.symbol) }
                    }
                if showReferenceOverlay {
                    if isLoadingReference { ProgressView().controlSize(.small) }
                    Text("Opacity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $overlayOpacity, in: 0...1)
                        .frame(width: 100)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 2) {
                GridRow {
                    Text("Tight bounds:").foregroundStyle(.secondary)
                    Text(String(format: "%.1f × %.1f pt @100pt", b.tightWidth, b.tightHeight))
                }
                GridRow {
                    Text("Frame:").foregroundStyle(.secondary)
                    Text(String(format: "%.1f × %.1f pt", b.frameWidth, b.frameHeight))
                }
                GridRow {
                    Text("Content center:").foregroundStyle(.secondary)
                    Text(String(format: "%+.1f, %+.1f pt", b.centerXOffset, b.centerYOffset))
                }
                GridRow {
                    Text("Suggested Y offset:").foregroundStyle(.secondary)
                    Text(String(format: "%+.4f", item.prediction.suggestedYOffset))
                }
            }
            .font(.caption.monospacedDigit())
        }
    }

    private func detailActions(_ item: AutoCalItem) -> some View {
        HStack(spacing: 10) {
            Button("Accept Prediction (Space)") { acceptSelectedPrediction() }
                .buttonStyle(.borderedProminent)
            Button("Needs Review (Esc)") { markSelectedNeedsReview() }
        }
    }

    // MARK: - Actions

    private func acceptSelectedPrediction() {
        guard let item = selectedItem else { return }
        accept(item)
        store.save()
        selectAdjacent(1)
    }

    /// Writes the prediction to the store without saving; callers save once.
    private func accept(_ item: AutoCalItem) {
        let existing = store.symbolEntries[item.symbol]
        let entry = SymbolCalibrationEntry(
            multiplier: (item.prediction.multiplier * 1000).rounded() / 1000,
            xOffset: existing?.xOffset ?? 0,
            yOffset: applySuggestedYOffset
                ? (item.prediction.suggestedYOffset * 1000).rounded() / 1000
                : existing?.yOffset ?? 0,
            weight: existing?.weight ?? "regular",
            status: "calibrated",
            source: "auto-boxfit")
        store.symbolEntries[item.symbol] = entry
    }

    private func markSelectedNeedsReview() {
        guard let item = selectedItem else { return }
        markNeedsReview(item)
        store.save()
        selectAdjacent(1)
    }

    private func markNeedsReview(_ item: AutoCalItem) {
        if var entry = store.symbolEntries[item.symbol] {
            entry.status = "needs-review"
            store.symbolEntries[item.symbol] = entry
        } else {
            store.symbolEntries[item.symbol] = SymbolCalibrationEntry(
                multiplier: (item.prediction.multiplier * 1000).rounded() / 1000,
                xOffset: 0, yOffset: 0, weight: "regular",
                status: "needs-review", source: "auto-boxfit")
        }
    }

    private func batchAcceptFiltered() {
        for item in filteredItems where !recipeSymbols.contains(item.symbol) {
            accept(item)
        }
        store.save()
    }

    private func batchMarkNeedsReviewFiltered() {
        for item in filteredItems {
            markNeedsReview(item)
        }
        store.save()
    }

    private func selectAdjacent(_ step: Int) {
        let list = filteredItems
        guard !list.isEmpty else { return }
        guard let current = selectedSymbol,
              let idx = list.firstIndex(where: { $0.symbol == current }) else {
            selectedSymbol = list.first?.symbol
            return
        }
        let next = min(max(idx + step, 0), list.count - 1)
        selectedSymbol = list[next].symbol
    }

    // MARK: - Apple Reference

    private func loadReference(for symbol: String) {
        guard showReferenceOverlay else { return }
        isLoadingReference = true
        errorMessage = nil
        referenceImage = nil
        Task {
            do {
                let image = try await service.referenceIcon(for: symbol)
                if selectedSymbol == symbol {
                    referenceImage = image
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingReference = false
        }
    }
}

// MARK: - Preview

#Preview {
    AutoSizingReviewTool()
        .frame(width: 1200, height: 800)
}
