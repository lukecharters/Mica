// AspectRatioCalibrationPlayground.swift
//
// Calibration tool that groups SF Symbols by aspect ratio (4 decimal places).
// Instead of calibrating ~4,431 individual symbols, calibrate ~1,612 aspect
// ratio groups — the same multiplier/offsets apply to all symbols sharing
// the same intrinsic proportions.
//
// Saves to ~/Library/Application Support/Icon Generator/ar-calibration.json
// with per-aspect-ratio entries that map to all member symbols.

import SwiftUI

// MARK: - Aspect Ratio Group

struct AspectRatioGroup: Identifiable {
    let id: String // aspect ratio as 4dp string key, e.g. "1.0263"
    let aspectRatio: Double
    let symbols: [String]

    var count: Int { symbols.count }
    /// First symbol used as the visual representative
    var representative: String { symbols[0] }
}

// MARK: - AR Calibration Entry

struct ARCalibrationEntry: Codable, Equatable {
    var multiplier: Double
    var xOffset: Double
    var yOffset: Double
    var weight: String   // "regular" or "medium"
    var status: String   // "calibrated", "skipped", "needs-review"
}

struct ARCalibrationFile: Codable {
    var version: Int = 1
    /// Keyed by aspect ratio string (4dp), e.g. "1.0263"
    var calibrations: [String: ARCalibrationEntry] = [:]
    /// Symbol names that have been pulled out of their AR groups for individual calibration
    var excludedSymbols: [String] = []
    /// Per-symbol calibration overrides for excluded symbols
    var overrides: [String: ARCalibrationEntry] = [:]
}

// MARK: - AR Calibration Store

@Observable
class ARCalibrationStore {
    var entries: [String: ARCalibrationEntry] = [:]
    var excludedSymbols: Set<String> = []
    var overrides: [String: ARCalibrationEntry] = [:]
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Icon Generator", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("ar-calibration.json")
        load()
    }

    func entry(for arKey: String) -> ARCalibrationEntry? {
        entries[arKey]
    }

    func setEntry(_ entry: ARCalibrationEntry, for arKey: String) {
        entries[arKey] = entry
        save()
    }

    // MARK: - Exclusion Methods

    func isExcluded(_ symbol: String) -> Bool {
        excludedSymbols.contains(symbol)
    }

    func exclude(symbol: String) {
        excludedSymbols.insert(symbol)
        save()
    }

    func unexclude(symbol: String) {
        excludedSymbols.remove(symbol)
        overrides.removeValue(forKey: symbol)
        save()
    }

    func override(for symbol: String) -> ARCalibrationEntry? {
        overrides[symbol]
    }

    func setOverride(_ entry: ARCalibrationEntry, for symbol: String) {
        overrides[symbol] = entry
        save()
    }

    func save() {
        let file = ARCalibrationFile(
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
            print("ARCalibrationStore: failed to save — \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let file = try JSONDecoder().decode(ARCalibrationFile.self, from: data)
            entries = file.calibrations
            excludedSymbols = Set(file.excludedSymbols)
            overrides = file.overrides
        } catch {
            print("ARCalibrationStore: failed to load — \(error)")
        }
    }

    var calibratedCount: Int {
        entries.values.filter { $0.status == "calibrated" }.count
    }

    var skippedCount: Int {
        entries.values.filter { $0.status == "skipped" }.count
    }

    var overrideCount: Int {
        overrides.count
    }
}

// MARK: - AR Icon View

/// Renders an icon using calibration parameters (same formula as CalibratingIconView).
private struct ARIconView: View {
    let symbolName: String
    let displaySize: CGFloat
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

// MARK: - Comparison Mode

private enum ARComparisonMode: String, CaseIterable {
    case overlay = "Overlay"
    case tintedOverlay = "Tinted Overlay"
    case sideBySide = "Side by Side"
    case difference = "Difference"
    case gallery = "Gallery"
}

private enum ARFilterMode: String, CaseIterable {
    case all = "All"
    case uncalibrated = "Uncalibrated"
    case calibrated = "Calibrated"
    case skipped = "Skipped"
    case overrides = "Overrides"
}

private enum ARSortMode: String, CaseIterable {
    case groupSize = "Group Size"
    case aspectRatio = "Aspect Ratio"
}

// MARK: - Symbol Baseline Data

/// Loads baseline metrics from symbol_baselines.json (extracted from CoreGlyphs asset catalog).
/// Baseline + capline define where the glyph sits vertically within the em square.
struct SymbolBaselineData {
    let capline: Double          // constant: 9.1598
    let referencePointSize: Double // constant: 13
    let baselines: [String: Double]

    static func load() -> SymbolBaselineData? {
        guard let url = Bundle.main.url(forResource: "symbol_baselines", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }

        struct File: Decodable {
            let capline: Double
            let referencePointSize: Double
            let baselines: [String: Double]
        }

        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return nil }
        return SymbolBaselineData(
            capline: file.capline,
            referencePointSize: file.referencePointSize,
            baselines: file.baselines
        )
    }

    /// Compute the Y offset correction for a symbol based on its baseline.
    /// The glyph sits between baseline and capline within the em square.
    /// This returns a fractional offset (relative to enclosure size) that
    /// vertically centers the glyph within the icon.
    ///
    /// Formula:
    ///   glyphCenter = (baseline + capline) / 2
    ///   emCenter = referencePointSize / 2
    ///   offset = (emCenter - glyphCenter) * multiplier / referencePointSize
    func yOffsetCorrection(for symbol: String, multiplier: Double) -> Double? {
        guard let baseline = baselines[symbol] else { return nil }
        let glyphCenter = (baseline + capline) / 2
        let emCenter = referencePointSize / 2
        let offsetInEmUnits = emCenter - glyphCenter
        return offsetInEmUnits * multiplier / referencePointSize
    }
}

// MARK: - Main Playground

struct AspectRatioCalibrationPlayground: View {
    @State private var store = ARCalibrationStore()
    @State private var service = AppexReferenceService()

    @State private var groups: [AspectRatioGroup] = []
    @State private var selectedIndex = 0
    @State private var memberIndex = 0 // which member of the group to show as reference

    @State private var multiplier = 0.55
    @State private var xOffset = 0.0
    @State private var yOffset = 0.0
    @State private var weight: Font.Weight = .regular
    @State private var comparisonMode: ARComparisonMode = .overlay
    @State private var overlayOpacity = 0.5
    @State private var searchText = ""
    @State private var filterMode: ARFilterMode = .all
    @State private var sortMode: ARSortMode = .groupSize
    @State private var referenceImage: NSImage?
    @State private var isLoadingReference = false
    @State private var errorMessage: String?
    @State private var baselineData: SymbolBaselineData?
    @State private var useBaselineYOffset = false

    private let displaySize: CGFloat = 512

    init() {
        let groups = Self.buildGroups()
        _groups = State(initialValue: groups)
    }

    /// Load metrics and build aspect ratio groups.
    private static func buildGroups() -> [AspectRatioGroup] {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = appSupport
            .appendingPathComponent("Icon Generator", isDirectory: true)
            .appendingPathComponent("symbol_metrics.json")

        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SymbolMetricsFile.self, from: data)
        else { return [] }

        // Preserve symbol ordering from sf_symbols.txt
        let orderedSymbols: [String]
        if let txtURL = Bundle.main.url(forResource: "sf_symbols", withExtension: "txt"),
           let contents = try? String(contentsOf: txtURL, encoding: .utf8) {
            orderedSymbols = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        } else {
            orderedSymbols = Array(file.symbols.keys).sorted()
        }

        // Group by 4dp aspect ratio
        var groupMap: [String: [String]] = [:]
        var arValues: [String: Double] = [:]

        for symbol in orderedSymbols {
            guard let metrics = file.symbols[symbol] else { continue }
            let arKey = String(format: "%.4f", metrics.aspectRatio)
            groupMap[arKey, default: []].append(symbol)
            arValues[arKey] = metrics.aspectRatio
        }

        return groupMap.map { key, symbols in
            AspectRatioGroup(id: key, aspectRatio: arValues[key] ?? 0, symbols: symbols)
        }
        .sorted { $0.count > $1.count } // default sort: largest groups first
    }

    // MARK: - Filtered & Sorted Groups

    /// Whether a group ID represents an excluded singleton (prefixed with "!")
    private func isExcludedGroup(_ group: AspectRatioGroup) -> Bool {
        group.id.hasPrefix("!")
    }

    private var filteredGroups: [AspectRatioGroup] {
        // When showing overrides, only show excluded singletons
        if filterMode == .overrides {
            var singletons = store.excludedSymbols.map { symbol in
                AspectRatioGroup(id: "!\(symbol)", aspectRatio: 0, symbols: [symbol])
            }
            if !searchText.isEmpty {
                singletons = singletons.filter { group in
                    group.symbols.contains { $0.localizedCaseInsensitiveContains(searchText) }
                }
            }
            singletons.sort { $0.symbols[0] < $1.symbols[0] }
            return singletons
        }

        // Filter excluded symbols out of their parent groups
        var list = groups.compactMap { group -> AspectRatioGroup? in
            let remaining = group.symbols.filter { !store.isExcluded($0) }
            guard !remaining.isEmpty else { return nil }
            return AspectRatioGroup(id: group.id, aspectRatio: group.aspectRatio, symbols: remaining)
        }

        // Append excluded symbols as singleton groups
        let singletons = store.excludedSymbols.map { symbol in
            AspectRatioGroup(id: "!\(symbol)", aspectRatio: 0, symbols: [symbol])
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
                if isExcludedGroup(group) {
                    return store.override(for: group.symbols[0]) == nil
                }
                let s = store.entry(for: group.id)?.status
                return s != "calibrated" && s != "skipped"
            }
        case .calibrated:
            list = list.filter { group in
                if isExcludedGroup(group) {
                    return store.override(for: group.symbols[0])?.status == "calibrated"
                }
                return store.entry(for: group.id)?.status == "calibrated"
            }
        case .skipped:
            list = list.filter { group in
                if isExcludedGroup(group) {
                    return store.override(for: group.symbols[0])?.status == "skipped"
                }
                return store.entry(for: group.id)?.status == "skipped"
            }
        case .overrides:
            break // handled above
        }

        switch sortMode {
        case .groupSize:
            list.sort { $0.count > $1.count }
        case .aspectRatio:
            list.sort { $0.aspectRatio < $1.aspectRatio }
        }

        return list
    }

    private var currentGroup: AspectRatioGroup? {
        let list = filteredGroups
        guard list.indices.contains(selectedIndex) else { return nil }
        return list[selectedIndex]
    }

    private var currentSymbol: String? {
        guard let group = currentGroup else { return nil }
        let idx = min(memberIndex, group.symbols.count - 1)
        return group.symbols[idx]
    }

    /// Effective Y offset: manual offset + optional baseline correction.
    private var effectiveYOffset: CGFloat {
        var offset = yOffset
        if useBaselineYOffset, let symbol = currentSymbol, let data = baselineData {
            offset += data.yOffsetCorrection(for: symbol, multiplier: multiplier) ?? 0
        }
        return offset
    }

    /// The baseline correction alone (for display purposes).
    private var baselineCorrection: Double? {
        guard let symbol = currentSymbol, let data = baselineData else { return nil }
        return data.yOffsetCorrection(for: symbol, multiplier: multiplier)
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
        .onAppear {
            baselineData = SymbolBaselineData.load()
            loadCurrentGroup()
        }
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
                .frame(width: 500)

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
                Divider()
                parameterSliders
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
            Text("Search")
                .font(.headline)

            TextField("Filter by symbol name or AR...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in
                    selectedIndex = 0
                    memberIndex = 0
                    loadCurrentGroup()
                }

            HStack(spacing: 12) {
                Picker("Filter", selection: $filterMode) {
                    ForEach(ARFilterMode.allCases, id: \.self) { mode in
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
                    ForEach(ARSortMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            Text("\(filteredGroups.count) aspect ratio groups")
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
                    Text("AR \(group.id)")
                        .font(.title3.bold().monospacedDigit())
                    Spacer()
                    Text("\(group.count) symbols")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15), in: Capsule())
                }

                // Member browser
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

                    // Show a few member names
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

            // Baseline Y correction toggle
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $useBaselineYOffset) {
                    Text("Baseline Y Correction")
                }

                if let correction = baselineCorrection {
                    HStack(spacing: 4) {
                        Text("Correction:")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%+.4f", correction))
                            .monospacedDigit()
                            .foregroundStyle(.purple)
                        if useBaselineYOffset {
                            Text("Effective:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%+.4f", effectiveYOffset))
                                .monospacedDigit()
                                .foregroundStyle(.blue)
                        }
                    }
                    .font(.caption)
                } else if baselineData == nil {
                    Text("symbol_baselines.json not found in bundle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if let symbol = currentSymbol {
                    Text("No baseline data for \(symbol)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
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

            if let symbol = currentSymbol {
                let view = ARIconView(
                    symbolName: symbol, displaySize: displaySize,
                    multiplier: multiplier, xOffset: xOffset, yOffset: effectiveYOffset,
                    weight: weight, symbolOnly: false
                )
                Text("Font size: \(String(format: "%.1f", view.enclosureSize * multiplier)) pt (enclosure: \(String(format: "%.1f", view.enclosureSize)) pt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var progressInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)

            let total = groups.count
            let calibrated = store.calibratedCount
            let skipped = store.skippedCount
            let remaining = total - calibrated - skipped

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Total groups:")
                        .foregroundStyle(.secondary)
                    Text("\(total)")
                        .monospacedDigit()
                }
                GridRow {
                    Text("Calibrated:")
                        .foregroundStyle(.secondary)
                    Text("\(calibrated)")
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
                GridRow {
                    Text("Skipped:")
                        .foregroundStyle(.secondary)
                    Text("\(skipped)")
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
                GridRow {
                    Text("Remaining:")
                        .foregroundStyle(.secondary)
                    Text("\(remaining)")
                        .monospacedDigit()
                }
                GridRow {
                    Text("Overrides:")
                        .foregroundStyle(.secondary)
                    Text("\(store.overrideCount)")
                        .monospacedDigit()
                        .foregroundStyle(.purple)
                }
            }
            .font(.caption)

            if total > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: Double(calibrated + skipped), total: Double(total))
                    Text("\(calibrated + skipped) / \(total) groups")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Symbol coverage
                let coveredSymbols = groups.filter {
                    let s = store.entry(for: $0.id)?.status
                    return s == "calibrated" || s == "skipped"
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
            if let group = currentGroup, let symbol = currentSymbol {
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
                            Text("AR \(group.id)")
                                .font(.title3.bold().monospacedDigit())
                            Text("—")
                                .foregroundStyle(.secondary)
                            Text(symbol)
                                .font(.title3.monospaced())
                        }
                    }

                    comparisonContent(for: symbol)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Picker("Mode", selection: $comparisonMode) {
                        ForEach(ARComparisonMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400)

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

                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            } else {
                ContentUnavailableView("No Groups", systemImage: "magnifyingglass",
                    description: Text("No aspect ratio groups match the current filter"))
            }

            Divider()

            // Navigation bar
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

    private func galleryView(for group: AspectRatioGroup) -> some View {
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

    private func galleryIcon(for symbol: String, size: CGFloat) -> some View {
        let yOff: CGFloat = {
            var offset = yOffset
            if useBaselineYOffset, let data = baselineData {
                offset += data.yOffsetCorrection(for: symbol, multiplier: multiplier) ?? 0
            }
            return offset
        }()

        return ARIconView(
            symbolName: symbol,
            displaySize: size,
            multiplier: multiplier,
            xOffset: xOffset,
            yOffset: yOff,
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
        ARIconView(
            symbolName: symbol,
            displaySize: displaySize,
            multiplier: multiplier,
            xOffset: xOffset,
            yOffset: effectiveYOffset,
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
        guard let group = currentGroup, memberIndex > 0 else { return }
        memberIndex -= 1
        _ = group // suppress unused warning
    }

    private func nextMember() {
        guard let group = currentGroup, memberIndex < group.count - 1 else { return }
        memberIndex += 1
    }

    private func markCalibratedAndAdvance() {
        guard let group = currentGroup else { return }
        let entry = ARCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "calibrated"
        )
        if isExcludedGroup(group) {
            store.setOverride(entry, for: group.symbols[0])
        } else {
            store.setEntry(entry, for: group.id)
        }

        if selectedIndex < filteredGroups.count - 1 {
            selectedIndex += 1
        }
    }

    private func markSkippedAndAdvance() {
        guard let group = currentGroup else { return }
        let entry = ARCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "skipped"
        )
        if isExcludedGroup(group) {
            store.setOverride(entry, for: group.symbols[0])
        } else {
            store.setEntry(entry, for: group.id)
        }

        if selectedIndex < filteredGroups.count - 1 {
            selectedIndex += 1
        }
    }

    private func copyPreviousAndAdvance() {
        guard selectedIndex > 0, let group = currentGroup else { return }
        let previousGroup = filteredGroups[selectedIndex - 1]
        let previous: ARCalibrationEntry? = {
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
        let entry = ARCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "calibrated"
        )
        if isExcludedGroup(group) {
            store.setOverride(entry, for: group.symbols[0])
        } else {
            store.setEntry(entry, for: group.id)
        }

        if selectedIndex < filteredGroups.count - 1 {
            selectedIndex += 1
        }
    }

    // MARK: - Load / Save

    private func loadCurrentGroup() {
        guard let group = currentGroup else {
            referenceImage = nil
            return
        }

        // Load saved values or defaults — check overrides for excluded singletons
        let existing: ARCalibrationEntry? = {
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

        // Load reference image for current member
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

            // Prefetch next few groups' representatives
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
            let existingStatus = store.override(for: group.symbols[0])?.status ?? "needs-review"
            let entry = ARCalibrationEntry(
                multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
                weight: weight == .medium ? "medium" : "regular",
                status: existingStatus
            )
            store.setOverride(entry, for: group.symbols[0])
        } else {
            let existingStatus = store.entry(for: group.id)?.status ?? "needs-review"
            let entry = ARCalibrationEntry(
                multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
                weight: weight == .medium ? "medium" : "regular",
                status: existingStatus
            )
            store.setEntry(entry, for: group.id)
        }
    }

    private func autoSave() {
        saveCurrentValues()
    }

    // MARK: - Exclude / Restore

    private func excludeSymbol(_ symbol: String) {
        store.exclude(symbol: symbol)
        // Reset member index since the group just lost a member
        memberIndex = 0
        loadCurrentGroup()
    }

    private func restoreSymbol(_ symbol: String) {
        store.unexclude(symbol: symbol)
        // The singleton group we were on is now gone — stay at current index
        let list = filteredGroups
        if selectedIndex >= list.count {
            selectedIndex = max(0, list.count - 1)
        }
        memberIndex = 0
        loadCurrentGroup()
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

// MARK: - Preview

#Preview {
    AspectRatioCalibrationPlayground()
        .frame(width: 1200, height: 800)
}
