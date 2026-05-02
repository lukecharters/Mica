// ResizableDimCalPlayground.swift
//
// Variant of DimensionCalibrationPlayground that uses
// .resizable().scaledToFit().frame() instead of .font(.system(size:)).
//
// By stripping SF Symbol's built-in font metric padding, the glyph
// bounding box is controlled directly — making it easier to see whether
// dimension groups truly share the same visual sizing behavior.
//
// Saves to ~/Library/Application Support/Icon Generator/resizable-dim-calibration.json
// (separate file so it doesn't interfere with the font-based calibration data).

import SwiftUI

// MARK: - Resizable Dim Calibration Store

/// Separate calibration store for the resizable approach.
/// Same format as DimCalibrationStore but writes to a different file.
@Observable
class ResizableDimCalibrationStore {
    var entries: [String: DimCalibrationEntry] = [:]
    var excludedSymbols: Set<String> = []
    var overrides: [String: DimCalibrationEntry] = [:]
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Mica", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("resizable-dim-calibration.json")
        load()
    }

    func entry(for key: String) -> DimCalibrationEntry? { entries[key] }

    func setEntry(_ entry: DimCalibrationEntry, for key: String) {
        entries[key] = entry
        save()
    }

    func isExcluded(_ symbol: String) -> Bool { excludedSymbols.contains(symbol) }

    func exclude(symbol: String) {
        excludedSymbols.insert(symbol)
        save()
    }

    func unexclude(symbol: String) {
        excludedSymbols.remove(symbol)
        overrides.removeValue(forKey: symbol)
        save()
    }

    func override(for symbol: String) -> DimCalibrationEntry? { overrides[symbol] }

    func setOverride(_ entry: DimCalibrationEntry, for symbol: String) {
        overrides[symbol] = entry
        save()
    }

    func save() {
        let file = DimCalibrationFile(
            version: 1,
            calibrations: entries,
            excludedSymbols: excludedSymbols.sorted(),
            overrides: overrides
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(file)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ResizableDimCalibrationStore: failed to save — \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let file = try JSONDecoder().decode(DimCalibrationFile.self, from: data)
            entries = file.calibrations
            excludedSymbols = Set(file.excludedSymbols)
            overrides = file.overrides
        } catch {
            print("ResizableDimCalibrationStore: failed to load — \(error)")
        }
    }

    var calibratedCount: Int { entries.values.filter { $0.status == "calibrated" }.count }
    var skippedCount: Int { entries.values.filter { $0.status == "skipped" }.count }
    var needsReviewCount: Int {
        entries.values.filter { $0.status == "needs-review" }.count +
        overrides.values.filter { $0.status == "needs-review" }.count
    }
    var overrideCount: Int { overrides.count }
}

// MARK: - Resizable Dim Icon View

/// Renders an icon using .resizable().scaledToFit().frame() with a single
/// bounding box. All symbols fit within the same frame regardless of aspect
/// ratio — no per-symbol intrinsic dimension scaling needed.
private struct ResizableDimIconView: View {
    let symbolName: String
    let displaySize: CGFloat
    /// Multiplier: fraction of enclosure size used as the bounding frame
    let multiplier: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
    let weight: Font.Weight
    let symbolOnly: Bool

    private let baseSize: CGFloat = 256
    private let baseCornerRadiusLG: CGFloat = 53
    private let baseBackgroundInset: CGFloat = 25

    private var scale: CGFloat { displaySize / baseSize }
    private var backgroundInset: CGFloat { baseBackgroundInset * scale }
    private var cornerRadius: CGFloat { baseCornerRadiusLG * scale }
    var enclosureSize: CGFloat { displaySize - (2 * backgroundInset) }

    /// Single bounding frame size — symbol fits within this square
    var frameSize: CGFloat { enclosureSize * multiplier }

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
                .resizable()
                .scaledToFit()
                .fontWeight(weight)
                .frame(width: frameSize, height: frameSize)
                .border(Color.red, width: 1)
                .foregroundColor(symbolOnly ? .red : .white)
                .offset(x: xPx, y: yPx)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

// MARK: - Comparison & Filter Enums

private enum RDimComparisonMode: String, CaseIterable {
    case overlay = "Overlay"
    case tintedOverlay = "Tinted Overlay"
    case sideBySide = "Side by Side"
    case difference = "Difference"
    case gallery = "Gallery"
    case allIcons = "All Icons"
}

private enum RDimFilterMode: String, CaseIterable {
    case all = "All"
    case uncalibrated = "Uncalibrated"
    case needsReview = "Needs Review"
    case calibrated = "Calibrated"
    case skipped = "Skipped"
    case overrides = "Overrides"
}

private enum RDimSortMode: String, CaseIterable {
    case groupSize = "Group Size"
    case width = "Width"
    case height = "Height"
}

// MARK: - Main Playground

struct ResizableDimCalPlayground: View {
    @State private var store = ResizableDimCalibrationStore()
    @State private var service = AppexReferenceService()

    @State private var groups: [DimensionGroup] = []
    @State private var selectedIndex = 0
    @State private var memberIndex = 0

    @State private var multiplier = 0.55
    @State private var xOffset = 0.0
    @State private var yOffset = 0.0
    @State private var weight: Font.Weight = .regular
    @State private var comparisonMode: RDimComparisonMode = .overlay
    @State private var overlayOpacity = 0.5
    @State private var searchText = ""
    @State private var filterMode: RDimFilterMode = .all
    @State private var sortMode: RDimSortMode = .groupSize
    @State private var referenceImage: NSImage?
    @State private var isLoadingReference = false
    @State private var errorMessage: String?

    @State private var symbolToGroupKey: [String: String] = [:]
    @State private var symbolMetrics: [String: SymbolMetrics] = [:]

    private let displaySize: CGFloat = 512

    init() {
        let (groups, lookup, metrics) = Self.buildGroups()
        _groups = State(initialValue: groups)
        _symbolToGroupKey = State(initialValue: lookup)
        _symbolMetrics = State(initialValue: metrics)
    }

    private static func buildGroups() -> ([DimensionGroup], [String: String], [String: SymbolMetrics]) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = appSupport
            .appendingPathComponent("Mica", isDirectory: true)
            .appendingPathComponent("symbol_metrics.json")

        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SymbolMetricsFile.self, from: data)
        else { return ([], [:], [:]) }

        let orderedSymbols: [String]
        if let txtURL = Bundle.main.url(forResource: "sf_symbols", withExtension: "txt"),
           let contents = try? String(contentsOf: txtURL, encoding: .utf8) {
            orderedSymbols = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        } else {
            orderedSymbols = Array(file.symbols.keys).sorted()
        }

        var groupMap: [String: [String]] = [:]
        var widthValues: [String: Double] = [:]
        var heightValues: [String: Double] = [:]
        var symbolLookup: [String: String] = [:]

        for symbol in orderedSymbols {
            guard let metrics = file.symbols[symbol] else { continue }
            let dimKey = String(format: "%.4f_%.4f", metrics.width, metrics.height)
            groupMap[dimKey, default: []].append(symbol)
            widthValues[dimKey] = metrics.width
            heightValues[dimKey] = metrics.height
            symbolLookup[symbol] = dimKey
        }

        let groups = groupMap.map { key, symbols in
            DimensionGroup(
                id: key,
                width: widthValues[key] ?? 0,
                height: heightValues[key] ?? 0,
                symbols: symbols
            )
        }
        .sorted { $0.count > $1.count }

        return (groups, symbolLookup, file.symbols)
    }

    // MARK: - Filtered & Sorted Groups

    private func isExcludedGroup(_ group: DimensionGroup) -> Bool {
        group.id.hasPrefix("!")
    }

    private var filteredGroups: [DimensionGroup] {
        if filterMode == .overrides {
            var singletons = store.excludedSymbols.map { symbol in
                DimensionGroup(id: "!\(symbol)", width: 0, height: 0, symbols: [symbol])
            }
            if !searchText.isEmpty {
                singletons = singletons.filter { group in
                    group.symbols.contains { $0.localizedCaseInsensitiveContains(searchText) }
                }
            }
            singletons.sort { $0.symbols[0] < $1.symbols[0] }
            return singletons
        }

        var list = groups.compactMap { group -> DimensionGroup? in
            let remaining = group.symbols.filter { !store.isExcluded($0) }
            guard !remaining.isEmpty else { return nil }
            return DimensionGroup(id: group.id, width: group.width, height: group.height, symbols: remaining)
        }

        let singletons = store.excludedSymbols.map { symbol in
            DimensionGroup(id: "!\(symbol)", width: 0, height: 0, symbols: [symbol])
        }
        list.append(contentsOf: singletons)

        if !searchText.isEmpty {
            list = list.filter { group in
                group.id.contains(searchText) ||
                group.symbols.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        switch filterMode {
        case .all: break
        case .uncalibrated:
            list = list.filter { group in
                if isExcludedGroup(group) { return store.override(for: group.symbols[0]) == nil }
                return store.entry(for: group.id)?.status == nil
            }
        case .needsReview:
            list = list.filter { group in
                if isExcludedGroup(group) { return store.override(for: group.symbols[0])?.status == "needs-review" }
                return store.entry(for: group.id)?.status == "needs-review"
            }
        case .calibrated:
            list = list.filter { group in
                if isExcludedGroup(group) { return store.override(for: group.symbols[0])?.status == "calibrated" }
                return store.entry(for: group.id)?.status == "calibrated"
            }
        case .skipped:
            list = list.filter { group in
                if isExcludedGroup(group) { return store.override(for: group.symbols[0])?.status == "skipped" }
                return store.entry(for: group.id)?.status == "skipped"
            }
        case .overrides:
            break
        }

        switch sortMode {
        case .groupSize: list.sort { $0.count > $1.count }
        case .width: list.sort { $0.width < $1.width }
        case .height: list.sort { $0.height < $1.height }
        }

        return list
    }

    private var currentGroup: DimensionGroup? {
        let list = filteredGroups
        guard list.indices.contains(selectedIndex) else { return nil }
        return list[selectedIndex]
    }

    private var currentSymbol: String? {
        guard let group = currentGroup else { return nil }
        let idx = min(memberIndex, group.symbols.count - 1)
        return group.symbols[idx]
    }

    // MARK: - Body

    var body: some View {
        Group {
            if groups.isEmpty {
                ContentUnavailableView("Metrics Not Available", systemImage: "exclamationmark.triangle",
                    description: Text("symbol_metrics.json not found. Run Generate Symbol Metrics first."))
            } else {
                mainContent
            }
        }
        .onAppear { loadCurrentGroup() }
        .onChange(of: selectedIndex) { _, _ in
            memberIndex = 0
            loadCurrentGroup()
        }
        .onChange(of: memberIndex) { _, _ in loadCurrentGroup() }
        .focusable()
        .onKeyPress(.space) { markCalibratedAndAdvance(); return .handled }
        .onKeyPress(.escape) { markSkippedAndAdvance(); return .handled }
        .onKeyPress(.tab) { copyPreviousAndAdvance(); return .handled }
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
        case .leftArrow:
            navigatePrevious(); return .handled
        case .rightArrow:
            navigateNext(); return .handled
        default:
            return .ignored
        }
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            controlsSidebar
                .frame(width: 550)
            Divider()
            comparisonArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
        }
    }

    // MARK: - Controls Sidebar

    private var controlsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                searchAndFilter
                Divider()
                groupInfo
                if comparisonMode != .allIcons {
                    Divider()
                    parameterSliders
                }
                Divider()
                progressInfo
                Divider()
                keyboardShortcutsHelp
            }
            .padding()
        }
    }

    private var searchAndFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Search")
                    .font(.headline)
                Spacer()
                Text("RESIZABLE MODE")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.2), in: Capsule())
                    .foregroundStyle(.orange)
            }

            TextField("Filter by symbol name or dimensions...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in
                    selectedIndex = 0
                    memberIndex = 0
                    loadCurrentGroup()
                }

            HStack(spacing: 12) {
                Picker("Filter", selection: $filterMode) {
                    ForEach(RDimFilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: filterMode) { _, _ in
                    selectedIndex = 0
                    memberIndex = 0
                    loadCurrentGroup()
                }
            }

            HStack {
                Text("Sort:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Sort", selection: $sortMode) {
                    ForEach(RDimSortMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }

            Text("\(filteredGroups.count) dimension groups")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var groupInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Group")
                .font(.headline)

            if let group = currentGroup {
                HStack {
                    Text(group.dimensionLabel)
                        .font(.title3.bold().monospacedDigit())
                    Spacer()
                    Text("\(group.count) symbols")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Representative")
                            .font(.subheadline.bold())
                        Spacer()
                        if group.count > 1 {
                            Button(action: previousMember) {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(memberIndex <= 0)

                            Text("\(memberIndex + 1)/\(group.count)")
                                .font(.caption.monospacedDigit())

                            Button(action: nextMember) {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(memberIndex >= group.count - 1)
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
                            if isExcludedGroup(group) {
                                Button("Restore to Group") {
                                    restoreSymbol(symbol)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.green)
                            } else {
                                Button("Exclude") {
                                    excludeSymbol(symbol)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.red)
                            }
                        }
                    }

                    if !isExcludedGroup(group) {
                        let preview = group.symbols.prefix(6).joined(separator: ", ")
                        let suffix = group.count > 6 ? "..." : ""
                        Text(preview + suffix)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }

                let isOverride = isExcludedGroup(group)
                let status: String = {
                    if isOverride {
                        return store.override(for: group.symbols[0])?.status ?? "uncalibrated"
                    }
                    return store.entry(for: group.id)?.status ?? "uncalibrated"
                }()
                HStack {
                    Label(status.capitalized, systemImage: statusIcon(for: status))
                        .font(.caption)
                        .foregroundStyle(statusColor(for: status))
                    if isOverride {
                        Text("(Override)")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
            } else {
                Text("No groups match filter")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var parameterSliders: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Parameters")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    multiplier = 0.55
                    xOffset = 0.0
                    yOffset = 0.0
                    weight = .regular
                    autoSave()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Multiplier")
                    Spacer()
                    Text(String(format: "%.4f", multiplier))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $multiplier, in: 0.2...1.0, step: 0.001)
                    .onChange(of: multiplier) { _, _ in autoSave() }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("X Offset")
                    Spacer()
                    Text(String(format: "%+.4f", xOffset))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $xOffset, in: -0.1...0.1, step: 0.001)
                    .onChange(of: xOffset) { _, _ in autoSave() }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Y Offset")
                    Spacer()
                    Text(String(format: "%+.4f", yOffset))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $yOffset, in: -0.1...0.1, step: 0.001)
                    .onChange(of: yOffset) { _, _ in autoSave() }
            }

            HStack {
                Text("Weight")
                Spacer()
                Picker("Weight", selection: $weight) {
                    Text("Regular").tag(Font.Weight.regular)
                    Text("Medium").tag(Font.Weight.medium)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: weight) { _, _ in autoSave() }
            }

            // Show computed frame size
            if let symbol = currentSymbol {
                let view = ResizableDimIconView(
                    symbolName: symbol, displaySize: displaySize,
                    multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
                    weight: weight, symbolOnly: false
                )
                Text("Frame: \(String(format: "%.1f", view.frameSize)) × \(String(format: "%.1f", view.frameSize)) pt (enclosure: \(String(format: "%.1f", view.enclosureSize)) pt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @State private var showBatchConfirm = false

    private var progressInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Button("Batch Auto-Calculate") {
                    showBatchConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.blue)
                .confirmationDialog(
                    "Auto-calculate multipliers for all uncalibrated groups?",
                    isPresented: $showBatchConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Auto-Calculate \(uncalibratedGroupCount) Groups") {
                        batchAutoCalculate()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Uses IDW interpolation (k=3) over calibrated entries. Results marked 'Needs Review'.")
                }
            }

            let total = groups.count
            let calibrated = store.calibratedCount
            let needsReview = store.needsReviewCount
            let skipped = store.skippedCount
            let remaining = total - calibrated - needsReview - skipped

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Total groups:").foregroundStyle(.secondary)
                    Text("\(total)").monospacedDigit()
                }
                GridRow {
                    Text("Calibrated:").foregroundStyle(.secondary)
                    Text("\(calibrated)").monospacedDigit().foregroundStyle(.green)
                }
                GridRow {
                    Text("Needs review:").foregroundStyle(.secondary)
                    Text("\(needsReview)").monospacedDigit().foregroundStyle(.blue)
                }
                GridRow {
                    Text("Skipped:").foregroundStyle(.secondary)
                    Text("\(skipped)").monospacedDigit().foregroundStyle(.orange)
                }
                GridRow {
                    Text("Uncalibrated:").foregroundStyle(.secondary)
                    Text("\(remaining)").monospacedDigit()
                }
                GridRow {
                    Text("Overrides:").foregroundStyle(.secondary)
                    Text("\(store.overrideCount)").monospacedDigit().foregroundStyle(.purple)
                }
            }
            .font(.caption)

            if total > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: Double(calibrated + needsReview + skipped), total: Double(total))
                    Text("\(calibrated + needsReview + skipped) / \(total) groups")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                let coveredSymbols = groups.filter {
                    let s = store.entry(for: $0.id)?.status
                    return s == "calibrated" || s == "needs-review" || s == "skipped"
                }.reduce(0) { $0 + $1.count }
                let totalSymbols = groups.reduce(0) { $0 + $1.count }

                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: Double(coveredSymbols), total: Double(totalSymbols))
                        .tint(.cyan)
                    Text("\(coveredSymbols) / \(totalSymbols) symbols covered")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var keyboardShortcutsHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow { Text("Left/Right"); Text("Previous / Next group") }
                GridRow { Text("Space"); Text("Mark calibrated + advance") }
                GridRow { Text("Tab"); Text("Same as previous + advance") }
                GridRow { Text("Escape"); Text("Mark skipped + advance") }
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
            if comparisonMode == .allIcons {
                allIconsView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let group = currentGroup, let symbol = currentSymbol {
                VStack(spacing: 12) {
                    HStack {
                        if isExcludedGroup(group) {
                            Image(systemName: "person.fill.xmark")
                                .foregroundStyle(.red)
                            Text(symbol)
                                .font(.title3.bold().monospaced())
                            Text("(Override)")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        } else {
                            Text(group.dimensionLabel)
                                .font(.title3.bold().monospacedDigit())
                            Text("—")
                                .foregroundStyle(.secondary)
                            Text(symbol)
                                .font(.title3.monospaced())
                        }
                    }

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
                ContentUnavailableView("No Groups", systemImage: "magnifyingglass",
                    description: Text("No dimension groups match the current filter"))
            }

            Divider()

            VStack(spacing: 8) {
                Picker("Mode", selection: $comparisonMode) {
                    ForEach(RDimComparisonMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 500)

                if comparisonMode == .overlay || comparisonMode == .tintedOverlay {
                    HStack {
                        Text("Opacity")
                        Slider(value: $overlayOpacity, in: 0...1)
                        Text(String(format: "%.0f%%", overlayOpacity * 100))
                            .font(.caption.monospacedDigit())
                            .frame(width: 36, alignment: .trailing)
                    }
                    .frame(maxWidth: 400)
                }

                if comparisonMode != .allIcons {
                    HStack {
                        Button(action: navigatePrevious) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(selectedIndex <= 0)

                        Spacer()

                        Text("\(selectedIndex + 1) / \(filteredGroups.count)")
                            .font(.caption.monospacedDigit())

                        Spacer()

                        Button(action: navigateNext) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(selectedIndex >= filteredGroups.count - 1)
                    }
                }
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
        case .gallery:
            if let group = currentGroup {
                galleryView(for: group)
            }
        case .allIcons:
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
                Text("Our Rendering (Resizable)")
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

    private func galleryView(for group: DimensionGroup) -> some View {
        let thumbSize: CGFloat = 96
        let columns = [GridItem(.adaptive(minimum: thumbSize + 8), spacing: 8)]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(group.symbols, id: \.self) { symbol in
                    VStack(spacing: 2) {
                        galleryIcon(for: symbol, size: thumbSize)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay {
                                if store.isExcluded(symbol) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(.red, lineWidth: 2)
                                }
                            }

                        Text(symbol)
                            .font(.system(size: 8).monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(width: thumbSize)
                            .strikethrough(store.isExcluded(symbol), color: .red)
                    }
                }
            }
            .padding(8)
        }
    }

    // MARK: - All Icons View

    private var allIconsView: some View {
        let thumbSize: CGFloat = 56
        let columns = [GridItem(.adaptive(minimum: thumbSize + 4), spacing: 4)]

        let allSymbols: [(symbol: String, groupKey: String, status: String)] = {
            var result: [(String, String, String)] = []
            for group in filteredGroups {
                let isOverride = isExcludedGroup(group)
                let status: String = {
                    if isOverride {
                        return store.override(for: group.symbols[0])?.status ?? "uncalibrated"
                    }
                    return store.entry(for: group.id)?.status ?? "uncalibrated"
                }()
                for symbol in group.symbols {
                    result.append((symbol, group.id, status))
                }
            }
            return result
        }()

        return VStack(spacing: 4) {
            HStack {
                Text("All Icons (Resizable)")
                    .font(.headline)
                Spacer()
                legendView
                Spacer()
                Text("\(allSymbols.count) symbols")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(allSymbols.enumerated()), id: \.offset) { _, item in
                        allIconsThumb(symbol: item.symbol, groupKey: item.groupKey, status: item.status, size: thumbSize)
                            .onTapGesture {
                                navigateToSymbol(item.symbol)
                            }
                    }
                }
                .padding(8)
            }
        }
    }

    private func allIconsThumb(symbol: String, groupKey: String, status: String, size: CGFloat) -> some View {
        let cal: DimCalibrationEntry? = {
            if groupKey.hasPrefix("!") { return store.override(for: symbol) }
            return store.entry(for: groupKey)
        }()
        let mul = cal?.multiplier ?? 0.55
        let xOff = cal?.xOffset ?? 0.0
        let yOff = cal?.yOffset ?? 0.0
        let w: Font.Weight = cal?.weight == "medium" ? .medium : .regular

        return ResizableDimIconView(
            symbolName: symbol,
            displaySize: size,
            multiplier: mul,
            xOffset: xOff,
            yOffset: yOff,
            weight: w,
            symbolOnly: false
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(borderColor(for: status), lineWidth: status == "uncalibrated" || status == "needs-review" ? 0 : 1.5)
        }
        .help(symbol)
    }

    private var legendView: some View {
        HStack(spacing: 12) {
            legendDot(color: .green, label: "Calibrated")
            legendDot(color: .orange, label: "Skipped")
            legendDot(color: .secondary.opacity(0.3), label: "Uncalibrated / Needs Review")
        }
        .font(.caption2)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
        }
    }

    private func borderColor(for status: String) -> Color {
        switch status {
        case "calibrated": .green
        case "skipped": .orange
        case "needs-review": .blue
        default: .clear
        }
    }

    private func navigateToSymbol(_ symbol: String) {
        guard let groupKey = symbolToGroupKey[symbol] else { return }
        comparisonMode = .overlay
        let list = filteredGroups
        if let idx = list.firstIndex(where: { $0.id == groupKey }) {
            selectedIndex = idx
            if let memberIdx = list[idx].symbols.firstIndex(of: symbol) {
                memberIndex = memberIdx
            }
        }
    }

    private func galleryIcon(for symbol: String, size: CGFloat) -> some View {
        ResizableDimIconView(
            symbolName: symbol,
            displaySize: size,
            multiplier: multiplier,
            xOffset: xOffset,
            yOffset: yOffset,
            weight: weight,
            symbolOnly: false
        )
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
        ResizableDimIconView(
            symbolName: symbol,
            displaySize: displaySize,
            multiplier: multiplier,
            xOffset: xOffset,
            yOffset: yOffset,
            weight: weight,
            symbolOnly: symbolOnly
        )
    }

    // MARK: - Navigation

    private func navigatePrevious() {
        guard selectedIndex > 0 else { return }
        saveCurrentValues()
        selectedIndex -= 1
    }

    private func navigateNext() {
        guard selectedIndex < filteredGroups.count - 1 else { return }
        saveCurrentValues()
        selectedIndex += 1
    }

    private func previousMember() {
        guard memberIndex > 0 else { return }
        memberIndex -= 1
    }

    private func nextMember() {
        guard let group = currentGroup, memberIndex < group.count - 1 else { return }
        memberIndex += 1
    }

    private func markCalibratedAndAdvance() {
        guard let group = currentGroup else { return }
        let entry = DimCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "calibrated"
        )
        if isExcludedGroup(group) {
            store.setOverride(entry, for: group.symbols[0])
        } else {
            store.setEntry(entry, for: group.id)
        }
        if selectedIndex < filteredGroups.count - 1 { selectedIndex += 1 }
    }

    private func markSkippedAndAdvance() {
        guard let group = currentGroup else { return }
        let entry = DimCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "skipped"
        )
        if isExcludedGroup(group) {
            store.setOverride(entry, for: group.symbols[0])
        } else {
            store.setEntry(entry, for: group.id)
        }
        if selectedIndex < filteredGroups.count - 1 { selectedIndex += 1 }
    }

    private func copyPreviousAndAdvance() {
        guard selectedIndex > 0, let group = currentGroup else { return }
        let previousGroup = filteredGroups[selectedIndex - 1]
        let previous: DimCalibrationEntry? = {
            if isExcludedGroup(previousGroup) {
                return store.override(for: previousGroup.symbols[0])
            }
            return store.entry(for: previousGroup.id)
        }()
        if let previous {
            multiplier = previous.multiplier
            xOffset = previous.xOffset
            yOffset = previous.yOffset
            weight = previous.weight == "medium" ? .medium : .regular
        }
        let entry = DimCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "calibrated"
        )
        if isExcludedGroup(group) {
            store.setOverride(entry, for: group.symbols[0])
        } else {
            store.setEntry(entry, for: group.id)
        }
        if selectedIndex < filteredGroups.count - 1 { selectedIndex += 1 }
    }

    // MARK: - Load / Save

    private func loadCurrentGroup() {
        guard let group = currentGroup else {
            referenceImage = nil
            return
        }

        let existing: DimCalibrationEntry? = {
            if isExcludedGroup(group) {
                return store.override(for: group.symbols[0])
            }
            return store.entry(for: group.id)
        }()

        if let existing {
            multiplier = existing.multiplier
            xOffset = existing.xOffset
            yOffset = existing.yOffset
            weight = existing.weight == "medium" ? .medium : .regular
        } else {
            multiplier = 0.55
            xOffset = 0.0
            yOffset = 0.0
            weight = .regular
        }

        guard let symbol = currentSymbol else { return }
        isLoadingReference = true
        errorMessage = nil
        referenceImage = nil

        Task {
            do {
                let image = try await service.referenceIcon(for: symbol)
                await MainActor.run {
                    referenceImage = image
                    isLoadingReference = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingReference = false
                }
            }

            let list = filteredGroups
            let nextStart = selectedIndex + 1
            let nextEnd = min(nextStart + 3, list.count)
            if nextStart < nextEnd {
                let names = (nextStart..<nextEnd).map { list[$0].representative }
                service.prefetch(names)
            }
        }
    }

    private func saveCurrentValues() {
        guard let group = currentGroup else { return }
        if isExcludedGroup(group) {
            guard let existingStatus = store.override(for: group.symbols[0])?.status else { return }
            let entry = DimCalibrationEntry(
                multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
                weight: weight == .medium ? "medium" : "regular",
                status: existingStatus
            )
            store.setOverride(entry, for: group.symbols[0])
        } else {
            guard let existingStatus = store.entry(for: group.id)?.status else { return }
            let entry = DimCalibrationEntry(
                multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
                weight: weight == .medium ? "medium" : "regular",
                status: existingStatus
            )
            store.setEntry(entry, for: group.id)
        }
    }

    private func autoSave() { saveCurrentValues() }

    // MARK: - Exclude / Restore

    private func excludeSymbol(_ symbol: String) {
        store.exclude(symbol: symbol)
        memberIndex = 0
        loadCurrentGroup()
    }

    private func restoreSymbol(_ symbol: String) {
        store.unexclude(symbol: symbol)
        let list = filteredGroups
        if selectedIndex >= list.count {
            selectedIndex = max(0, list.count - 1)
        }
        memberIndex = 0
        loadCurrentGroup()
    }

    // MARK: - Batch Auto-Calculate

    private var uncalibratedGroupCount: Int {
        groups.filter { store.entry(for: $0.id) == nil }.count
    }

    private func idwPredict(width: Double, height: Double, k: Int = 3) -> (multiplier: Double, xOffset: Double, yOffset: Double) {
        struct RefPoint { let w, h, mul, xo, yo: Double }
        var refs: [RefPoint] = []
        for (key, entry) in store.entries where entry.status == "calibrated" {
            let parts = key.split(separator: "_")
            guard parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]) else { continue }
            refs.append(RefPoint(w: w, h: h, mul: entry.multiplier, xo: entry.xOffset, yo: entry.yOffset))
        }

        guard !refs.isEmpty else {
            let limit = max(width, height)
            return (limit > 0 ? 0.55 * 100.0 / limit : 0.55, 0.0, 0.0)
        }

        let sorted = refs.map { r -> (dist: Double, ref: RefPoint) in
            let d = ((r.w - width) * (r.w - width) + (r.h - height) * (r.h - height)).squareRoot()
            return (d, r)
        }.sorted { $0.dist < $1.dist }

        let topK = Array(sorted.prefix(k))

        if topK[0].dist == 0 {
            return (topK[0].ref.mul, topK[0].ref.xo, topK[0].ref.yo)
        }

        let weights = topK.map { 1.0 / $0.dist }
        let totalW = weights.reduce(0, +)
        let mul = zip(weights, topK).reduce(0.0) { $0 + $1.0 * $1.1.ref.mul } / totalW
        let xo  = zip(weights, topK).reduce(0.0) { $0 + $1.0 * $1.1.ref.xo  } / totalW
        let yo  = zip(weights, topK).reduce(0.0) { $0 + $1.0 * $1.1.ref.yo  } / totalW
        return (mul, xo, yo)
    }

    private func batchAutoCalculate() {
        var processed = 0
        for group in groups {
            guard store.entry(for: group.id) == nil else { continue }
            guard let metrics = symbolMetrics[group.representative] else { continue }

            let (autoMul, autoXO, autoYO) = idwPredict(width: metrics.width, height: metrics.height)
            let entry = DimCalibrationEntry(
                multiplier: autoMul, xOffset: autoXO, yOffset: autoYO,
                weight: "regular", status: "needs-review"
            )
            store.setEntry(entry, for: group.id)
            processed += 1
        }

        print("batchAutoCalculate (resizable): processed \(processed) groups using IDW interpolation")
        loadCurrentGroup()
    }

    // MARK: - Nudge Helpers

    private func nudgeMultiplier(by delta: Double) { multiplier += delta; autoSave() }
    private func nudgeXOffset(by delta: Double) { xOffset += delta; autoSave() }
    private func nudgeYOffset(by delta: Double) { yOffset += delta; autoSave() }

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

// MARK: - Preview

#Preview {
    ResizableDimCalPlayground()
        .frame(width: 1100, height: 800)
}
