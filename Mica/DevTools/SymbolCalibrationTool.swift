// SymbolCalibrationTool.swift
//
// Calibration tool that groups SF Symbols by family (base symbol name).
// Each non-container symbol gets individual calibration. Container variants
// (.circle 117x114, .square 115x104, .rectangle 141x104) share a single
// calibration per container type.
//
// Saves to the sandbox container's Application Support/Mica/symbol-calibration.json.
// Migrates from dim-calibration.json on first load.

import SwiftUI

// MARK: - Calibration Store

@Observable
class SymbolCalibrationStore {
    var symbolEntries: [String: SymbolCalibrationEntry] = [:]
    var containerEntries: [String: SymbolCalibrationEntry] = [:]
    var familyOverrides: [String: String] = [:]
    private let fileURL: URL

    /// The three container shapes, their key under `containers` in
    /// symbol-calibration.json, and the representative dimensions shown in the
    /// tool's family list. Key and label coincide — see `ContainerType.containerKey`.
    static let containerDims: [(key: String, label: String, width: Double, height: Double)] = [
        (ContainerType.circle.containerKey, "circle", 117, 114),
        (ContainerType.square.containerKey, "square", 115, 104),
        (ContainerType.rectangle.containerKey, "rectangle", 141, 104),
    ]
    static let containerKeys: Set<String> = Set(containerDims.map(\.key))

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Mica", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("symbol-calibration.json")
        load()
    }

    static func isContainer(containerKey: String) -> Bool {
        containerKeys.contains(containerKey)
    }

    func entry(forSymbol symbol: String, containerKey: String?) -> SymbolCalibrationEntry? {
        if let dk = containerKey, Self.containerKeys.contains(dk) {
            return containerEntries[dk]
        }
        return symbolEntries[symbol]
    }

    func setEntry(_ entry: SymbolCalibrationEntry, forSymbol symbol: String, containerKey: String?) {
        if let dk = containerKey, Self.containerKeys.contains(dk) {
            containerEntries[dk] = entry
        } else {
            symbolEntries[symbol] = entry
        }
        save()
    }

    func status(forSymbol symbol: String, containerKey: String?) -> String {
        entry(forSymbol: symbol, containerKey: containerKey)?.status ?? "uncalibrated"
    }

    func familyHasMember(withStatus target: String, members: [String]) -> Bool {
        if target == "uncalibrated" {
            return members.contains { symbolEntries[$0] == nil }
        }
        return members.contains { symbolEntries[$0]?.status == target }
    }

    func familyAllMembers(withStatus target: String, members: [String]) -> Bool {
        if target == "uncalibrated" {
            return members.allSatisfy { symbolEntries[$0] == nil }
        }
        return members.allSatisfy { symbolEntries[$0]?.status == target }
    }

    var calibratedSymbolCount: Int {
        symbolEntries.values.filter { $0.status == "calibrated" }.count
    }
    var needsReviewSymbolCount: Int {
        symbolEntries.values.filter { $0.status == "needs-review" }.count
    }
    var skippedSymbolCount: Int {
        symbolEntries.values.filter { $0.status == "skipped" }.count
    }
    var totalSymbolEntries: Int { symbolEntries.count }

    // MARK: - Family Overrides

    func setFamilyOverride(symbol: String, newFamily: String) {
        familyOverrides[symbol] = newFamily
        save()
    }

    func removeFamilyOverride(symbol: String) {
        familyOverrides.removeValue(forKey: symbol)
        save()
    }

    func setFamilyOverrides(_ overrides: [String: String]) {
        for (symbol, family) in overrides {
            familyOverrides[symbol] = family
        }
        save()
    }

    func removeFamilyOverrides(for symbols: [String]) {
        for symbol in symbols {
            familyOverrides.removeValue(forKey: symbol)
        }
        save()
    }

    // MARK: - Persistence

    func save() {
        let file = SymbolCalibration(version: 1, symbols: symbolEntries, containers: containerEntries, familyOverrides: familyOverrides)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(file)

            let backupURL = fileURL.deletingPathExtension().appendingPathExtension("backup.json")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            }

            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("SymbolCalibrationStore: failed to save — \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            if !seedFromBundledCalibration() {
                migrateFromDimCalibration()
            }
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let file = try JSONDecoder().decode(SymbolCalibration.self, from: data)
            symbolEntries = file.symbols
            containerEntries = file.containers
            familyOverrides = file.familyOverrides
            print("SymbolCalibrationStore: loaded \(symbolEntries.count) symbols, \(containerEntries.count) containers, \(familyOverrides.count) overrides")
        } catch {
            print("SymbolCalibrationStore: failed to load — \(error)")
        }
    }

    /// Throws the override away: back it up, delete it, and load the bundled
    /// calibration into memory **without saving**, so production is genuinely
    /// back on what Mica ships until the next edit here writes a new one.
    ///
    /// The one way out of a calibration the user did not mean to change. Without
    /// it the only cure is deleting a file inside the sandbox container, which is
    /// not a thing to ask of anyone — and `SymbolSizingService` reads that file
    /// whenever the developer tools are on. It keeps the `.backup.json` copy, so
    /// a Restore is recoverable too.
    func restoreBundledCalibration() {
        let backupURL = fileURL.deletingPathExtension().appendingPathExtension("backup.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            try? FileManager.default.removeItem(at: fileURL)
        }
        guard let url = Bundle.main.url(forResource: "symbol-calibration", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SymbolCalibration.self, from: data)
        else { return }
        symbolEntries = file.symbols
        containerEntries = file.containers
        familyOverrides = file.familyOverrides
    }

    /// True while an Application Support copy exists — i.e. while
    /// `SymbolSizingService` would prefer it over the bundled one.
    var hasOverride: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Seeds the working copy from the bundled symbol-calibration.json
    /// (the same fallback SymbolSizingService uses in production) when no
    /// Application Support copy exists yet.
    private func seedFromBundledCalibration() -> Bool {
        guard let url = Bundle.main.url(forResource: "symbol-calibration", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SymbolCalibration.self, from: data)
        else { return false }
        symbolEntries = file.symbols
        containerEntries = file.containers
        familyOverrides = file.familyOverrides
        print("SymbolCalibrationStore: seeded \(symbolEntries.count) symbols from bundled calibration")
        save()
        return true
    }

    // MARK: - Migration from dim-calibration.json

    private func migrateFromDimCalibration() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Mica", isDirectory: true)
        let dimCalURL = dir.appendingPathComponent("dim-calibration.json")
        let metricsURL = dir.appendingPathComponent("symbol_metrics.json")

        guard FileManager.default.fileExists(atPath: dimCalURL.path),
              FileManager.default.fileExists(atPath: metricsURL.path) else {
            print("SymbolCalibrationStore: no migration sources found")
            return
        }

        struct MigEntry: Decodable {
            let multiplier: Double; let xOffset: Double; let yOffset: Double
            let weight: String; let status: String
        }
        struct MigFile: Decodable {
            let calibrations: [String: MigEntry]
            let excludedSymbols: [String]?
            let overrides: [String: MigEntry]?
            let subgroups: [String: [String]]?
        }

        guard let dimData = try? Data(contentsOf: dimCalURL),
              let dimFile = try? JSONDecoder().decode(MigFile.self, from: dimData),
              let metricsData = try? Data(contentsOf: metricsURL),
              let metricsFile = try? JSONDecoder().decode(SymbolMetricsFile.self, from: metricsData) else {
            print("SymbolCalibrationStore: failed to decode migration files")
            return
        }

        var subgroupLookup: [String: String] = [:]
        for (subKey, symbols) in dimFile.subgroups ?? [:] {
            for symbol in symbols { subgroupLookup[symbol] = subKey }
        }
        let overrides = dimFile.overrides ?? [:]

        for (symbol, metrics) in metricsFile.symbols {
            // dim-calibration.json is keyed by dimension signature throughout —
            // it predates container-name keys — so every lookup below uses the
            // signature, and only the destination uses the new container key.
            let signature = String(format: "%.4f_%.4f", metrics.width, metrics.height)

            if let container = ContainerType.matching(dimensionSignature: signature) {
                if containerEntries[container.containerKey] == nil,
                   let e = dimFile.calibrations[signature] {
                    containerEntries[container.containerKey] = SymbolCalibrationEntry(
                        multiplier: e.multiplier, xOffset: e.xOffset, yOffset: e.yOffset,
                        weight: e.weight, status: e.status)
                }
            } else {
                let source: MigEntry?
                if let ovr = overrides[symbol] {
                    source = ovr
                } else if let subKey = subgroupLookup[symbol], let sub = dimFile.calibrations[subKey] {
                    source = sub
                } else {
                    source = dimFile.calibrations[signature]
                }
                if let s = source {
                    symbolEntries[symbol] = SymbolCalibrationEntry(
                        multiplier: s.multiplier, xOffset: s.xOffset, yOffset: s.yOffset,
                        weight: s.weight, status: s.status)
                }
            }
        }

        print("SymbolCalibrationStore: migrated \(symbolEntries.count) symbols, \(containerEntries.count) containers")
        save()
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

// MARK: - Enums

private enum FamilyComparisonMode: String, CaseIterable {
    case overlay = "Overlay"
    case tintedOverlay = "Tinted Overlay"
    case sideBySide = "Side by Side"
    case difference = "Difference"
    case gallery = "Gallery"
    case allIcons = "All Icons"
}

private enum FamilyFilterMode: String, CaseIterable {
    case all = "All"
    case uncalibrated = "Uncalibrated"
    case needsReview = "Needs Review"
    case outliers = "Outliers"
    case calibrated = "Calibrated"
    case skipped = "Skipped"
    case containers = "Containers"
}

private enum FamilySortMode: String, CaseIterable {
    case familyName = "Name"
    case familySize = "Size"
    case width = "Width"
    case height = "Height"
    /// Worst box-fit disagreement first — the order outlier review wants, and
    /// the reason the Auto Sizing Review tool had a sort of its own.
    case boxFitDelta = "Δ"
}

/// The three destructive confirmations, as one value.
///
/// **One `.alert` per view, so one enum.** Stacking a second `.alert` on the
/// same view silently wins over the first — the rule `CLAUDE.md` records for
/// `ContentView` — and this view already carries three `.sheet`s, so the batch
/// operations that arrived with the box-fit review cannot bring their own.
private enum CalibrationConfirmation: Identifiable {
    case applyToFamily(name: String, count: Int)
    case acceptShownPredictions(count: Int)
    case markShownNeedsReview(count: Int)
    case restoreBundledCalibration

    var id: String {
        switch self {
        case .applyToFamily: "apply"
        case .acceptShownPredictions: "accept"
        case .markShownNeedsReview: "review"
        case .restoreBundledCalibration: "restore"
        }
    }

    var title: String {
        switch self {
        case .applyToFamily: "Apply Calibration to Family"
        case .acceptShownPredictions(let count): "Accept \(count) Predictions"
        case .markShownNeedsReview(let count): "Mark \(count) as Needs Review"
        case .restoreBundledCalibration: "Restore Bundled Calibration"
        }
    }

    var confirmLabel: String {
        switch self {
        case .applyToFamily: "Apply"
        case .acceptShownPredictions: "Accept All"
        case .markShownNeedsReview: "Mark All"
        case .restoreBundledCalibration: "Restore"
        }
    }

    var message: String {
        switch self {
        case .applyToFamily(let name, let count):
            "Copy the current symbol's calibration values to all \(count) members of \"\(name)\"?"
        case .acceptShownPredictions(let count):
            "Write the predicted multiplier to all \(count) symbols shown as calibrated entries "
                + "(source: auto-boxfit). Apple hand-tuned symbols and containers are skipped."
        case .markShownNeedsReview(let count):
            "Set status to needs-review on all \(count) symbols shown, keeping their existing values."
        case .restoreBundledCalibration:
            "Delete the Application Support calibration and go back to the one Mica ships, "
                + "so the app renders with the shipped symbol sizing again. A .backup.json "
                + "copy is kept, and the app must be relaunched to pick this up."
        }
    }
}

// MARK: - Symbol Baseline Data

struct SymbolBaselineData {
    let capline: Double
    let referencePointSize: Double
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

    func yOffsetCorrection(for symbol: String, multiplier: Double) -> Double? {
        guard let baseline = baselines[symbol] else { return nil }
        let glyphCenter = (baseline + capline) / 2
        let emCenter = referencePointSize / 2
        let offsetInEmUnits = emCenter - glyphCenter
        return offsetInEmUnits * multiplier / referencePointSize
    }
}

// MARK: - Main Tool

struct SymbolCalibrationTool: View {
    @State private var store = SymbolCalibrationStore()
    @State private var service = AppexReferenceService()

    @State private var families: [SymbolFamily] = []
    @State private var selectedIndex = 0
    @State private var memberIndex = 0

    @State private var multiplier = 0.65
    @State private var xOffset = 0.0
    @State private var yOffset = 0.0
    @State private var weight: Font.Weight = .regular
    @State private var comparisonMode: FamilyComparisonMode = .overlay
    @State private var overlayOpacity = 0.5
    @State private var searchText = ""
    @State private var filterMode: FamilyFilterMode = .all
    @State private var sortMode: FamilySortMode = .familyName
    @State private var referenceImage: NSImage?
    @State private var isLoadingReference = false
    @State private var errorMessage: String?
    @State private var baselineData: SymbolBaselineData?
    @State private var useBaselineYOffset = false
    @State private var galleryThumbSize: CGFloat = 96
    @State private var galleryTintOverlay = false
    @State private var galleryReferenceImages: [String: NSImage] = [:]
    @State private var galleryLoadingSymbols: Set<String> = []
    @State private var galleryLoadTask: Task<Void, Never>?
    @State private var showGridOverlay = false

    /// symbol name -> dim key (for container lookup)
    @State private var symbolContainerKeys: [String: String] = [:]
    @State private var symbolMetrics: [String: SymbolMetrics] = [:]

    /// The box-fit rule's predictions, measured here since 2026-08-21 — this was
    /// a second window whose cache this tool could read but not write, so
    /// reviewing an outlier and fixing it were two tools apart. Drives the
    /// Outliers filter. See `DevTools/BoxFitPredictions.swift`.
    @State private var boxFit = BoxFitReview()

    /// Whether accepting a prediction also writes its advisory content-centring
    /// Y offset. Off by default: the multiplier is the rule's output, the offset
    /// is a hint, and offsets are partly optical.
    @State private var appliesSuggestedYOffset = false

    /// The one confirmation slot. See `CalibrationConfirmation`.
    @State private var confirmation: CalibrationConfirmation?

    /// Outlier membership frozen when the Outliers filter is entered. The
    /// filter must not re-evaluate live: editing a symbol to within the
    /// threshold would drop its family out of filteredFamilies mid-drag and
    /// silently jump the view to the next family. Re-entering the filter
    /// refreshes the snapshot.
    @State private var outlierSnapshot: Set<String> = []

    /// Lives on `boxFit` so the slider can move it; kept as a property here
    /// because five call sites read it and none of them care where it comes from.
    private var outlierThreshold: Double { boxFit.threshold }

    // All Icons multi-selection
    @State private var allIconsSelection: Set<String> = []
    @State private var lastTappedSymbol: String?
    @State private var showSelectionMoveSheet = false
    @State private var showSelectionApplySheet = false
    @State private var selectionMoveTargetSearch = ""
    @State private var selectionMoveNewFamilyName = ""
    @State private var selectionApplySourceSearch = ""

    // Family management sheet state
    @State private var showMoveSheet = false
    @State private var showMergeSheet = false
    @State private var showSplitSheet = false
    @State private var moveTargetSearch = ""
    @State private var moveNewFamilyName = ""
    @State private var mergeTargetSearch = ""
    @State private var splitSelections: Set<String> = [] // members that STAY in current family
    @State private var splitNewFamilyName = ""
    @State private var selectedMembersForMove: Set<String> = []

    private let displaySize: CGFloat = 512

    init() {
        let (fams, containerKeyLookup, metrics) = Self.buildFamilies()
        _families = State(initialValue: fams)
        _symbolContainerKeys = State(initialValue: containerKeyLookup)
        _symbolMetrics = State(initialValue: metrics)
    }

    // MARK: - Rebuild Families

    private func rebuildFamilies() {
        let currentFamilyId = currentFamily?.id
        let currentSym = currentSymbol

        let (fams, containerKeyLookup, metrics) = Self.buildFamilies(overrides: store.familyOverrides)
        families = fams
        symbolContainerKeys = containerKeyLookup
        symbolMetrics = metrics

        // Restore selection if possible
        let list = filteredFamilies
        if let fid = currentFamilyId, let idx = list.firstIndex(where: { $0.id == fid }) {
            selectedIndex = idx
            if let sym = currentSym, let mIdx = list[idx].members.firstIndex(of: sym) {
                memberIndex = mIdx
            } else {
                memberIndex = 0
            }
        } else {
            selectedIndex = min(selectedIndex, max(list.count - 1, 0))
            memberIndex = 0
        }
        loadCurrentMember()
    }

    // MARK: - Family Key

    static func familyKey(for symbol: String) -> String {
        var parts = symbol.split(separator: ".").map(String.init)
        if let badgeIdx = parts.firstIndex(of: "badge"), badgeIdx > 0 {
            parts = Array(parts[..<badgeIdx])
        }
        while let last = parts.last, last == "fill" || last == "slash" {
            parts.removeLast()
        }
        return parts.joined(separator: ".")
    }

    // MARK: - Build Families

    private static func loadFamilyOverrides() -> [String: String] {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = appSupport
            .appendingPathComponent("Mica", isDirectory: true)
            .appendingPathComponent("symbol-calibration.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SymbolCalibration.self, from: data)
        else { return [:] }
        return file.familyOverrides
    }

    private static func buildFamilies(overrides: [String: String]? = nil) -> ([SymbolFamily], [String: String], [String: SymbolMetrics]) {
        // Try Application Support first, then bundled fallback
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appSupportURL = appSupport
            .appendingPathComponent("Mica", isDirectory: true)
            .appendingPathComponent("symbol_metrics.json")
        let url = FileManager.default.fileExists(atPath: appSupportURL.path)
            ? appSupportURL
            : Bundle.main.url(forResource: "symbol_metrics", withExtension: "json") ?? appSupportURL

        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SymbolMetricsFile.self, from: data)
        else { return ([], [:], [:]) }

        let familyOverrides = overrides ?? loadFamilyOverrides()

        let orderedSymbols: [String]
        if let txtURL = Bundle.main.url(forResource: "sf-symbols", withExtension: "txt"),
           let contents = try? String(contentsOf: txtURL, encoding: .utf8) {
            orderedSymbols = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        } else {
            orderedSymbols = Array(file.symbols.keys).sorted()
        }

        var containerMembers: [String: [String]] = [:]
        var familyMembers: [String: [String]] = [:]
        var containerKeyLookup: [String: String] = [:]

        for symbol in orderedSymbols {
            guard let metrics = file.symbols[symbol] else { continue }
            // Recognise a container by its measured size, then key it by name —
            // the calibration file stores containers under "circle"/"square"/
            // "rectangle", not under the dimension signature.
            let signature = String(format: "%.4f_%.4f", metrics.width, metrics.height)
            let containerKey = ContainerType.matching(dimensionSignature: signature)?.containerKey
                ?? signature
            containerKeyLookup[symbol] = containerKey

            if SymbolCalibrationStore.containerKeys.contains(containerKey) {
                containerMembers[containerKey, default: []].append(symbol)
            } else {
                let fk = familyOverrides[symbol] ?? familyKey(for: symbol)
                familyMembers[fk, default: []].append(symbol)
            }
        }

        var result: [SymbolFamily] = []

        for (fk, members) in familyMembers {
            let rep = members[0]
            let m = file.symbols[rep]!
            result.append(SymbolFamily(
                id: fk, members: members, isContainer: false, containerLabel: nil,
                width: m.width, height: m.height))
        }

        for info in SymbolCalibrationStore.containerDims {
            if let members = containerMembers[info.key] {
                result.append(SymbolFamily(
                    id: "container.\(info.label)", members: members, isContainer: true,
                    containerLabel: info.label, width: info.width, height: info.height))
            }
        }

        result.sort { $0.id < $1.id }
        return (result, containerKeyLookup, file.symbols)
    }

    // MARK: - Filtered & Sorted Families

    private var filteredFamilies: [SymbolFamily] {
        var list = families

        switch filterMode {
        case .containers:
            list = list.filter { $0.isContainer }
        case .all:
            break
        case .uncalibrated:
            list = list.filter { family in
                if family.isContainer {
                    let dk = SymbolCalibrationStore.containerDims.first { $0.label == family.containerLabel }?.key
                    return store.entry(forSymbol: "", containerKey: dk) == nil
                }
                return family.members.contains { store.symbolEntries[$0] == nil }
            }
        case .needsReview:
            list = list.filter { family in
                if family.isContainer {
                    let dk = SymbolCalibrationStore.containerDims.first { $0.label == family.containerLabel }?.key
                    return store.entry(forSymbol: "", containerKey: dk)?.status == "needs-review"
                }
                return store.familyHasMember(withStatus: "needs-review", members: family.members)
            }
        case .calibrated:
            list = list.filter { family in
                if family.isContainer {
                    let dk = SymbolCalibrationStore.containerDims.first { $0.label == family.containerLabel }?.key
                    return store.entry(forSymbol: "", containerKey: dk)?.status == "calibrated"
                }
                return store.familyAllMembers(withStatus: "calibrated", members: family.members)
            }
        case .skipped:
            list = list.filter { family in
                if family.isContainer {
                    let dk = SymbolCalibrationStore.containerDims.first { $0.label == family.containerLabel }?.key
                    return store.entry(forSymbol: "", containerKey: dk)?.status == "skipped"
                }
                return store.familyAllMembers(withStatus: "skipped", members: family.members)
            }
        case .outliers:
            list = list.filter { family in
                !family.isContainer && family.members.contains { outlierSnapshot.contains($0) }
            }
        }

        if !searchText.isEmpty {
            list = list.filter { family in
                family.id.localizedCaseInsensitiveContains(searchText) ||
                family.members.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        switch sortMode {
        case .familyName:
            list.sort { $0.id < $1.id }
        case .familySize:
            list.sort { $0.count > $1.count }
        case .width:
            list.sort { $0.width < $1.width }
        case .height:
            list.sort { $0.height < $1.height }
        case .boxFitDelta:
            // A family's disagreement is its *worst* member's, so a family with
            // one badly-sized variant does not sink under nine agreeing ones.
            list.sort { worstBoxFitDelta(in: $0) > worstBoxFitDelta(in: $1) }
        }

        return list
    }

    // MARK: - Box-Fit Outliers

    /// Calibrated symbol whose stored multiplier disagrees with the box-fit
    /// prediction by more than the threshold. Live check — used to build the
    /// snapshot and for row deltas, never for filtering directly.
    private func isBoxFitOutlier(_ symbol: String) -> Bool {
        guard let delta = boxFitDelta(for: symbol) else { return false }
        return abs(delta) > outlierThreshold
    }

    private func rebuildOutlierSnapshot() {
        outlierSnapshot = Set(boxFit.predictions.keys.filter(isBoxFitOutlier))
    }

    /// prediction − calibrated multiplier, or nil when either side is missing.
    private func boxFitDelta(for symbol: String) -> Double? {
        guard let entry = store.symbolEntries[symbol], entry.status == "calibrated",
              let prediction = boxFit.multiplier(for: symbol) else { return nil }
        return prediction - entry.multiplier
    }

    private func worstBoxFitDelta(in family: SymbolFamily) -> Double {
        family.members.compactMap { boxFitDelta(for: $0).map(abs) }.max() ?? 0
    }

    /// Every calibrated symbol's disagreement, for the agreement summary.
    private var allBoxFitDeltas: [Double] {
        store.symbolEntries.keys.compactMap(boxFitDelta(for:))
    }

    /// The non-container symbols the batch operations would touch: everything in
    /// the current filter that the rule has a prediction for.
    private func shownPredictedSymbols(excludingAppleTuned: Bool) -> [String] {
        filteredFamilies
            .filter { !$0.isContainer }
            .flatMap(\.members)
            .filter { boxFit.predictions[$0] != nil }
            .filter { !excludingAppleTuned || !boxFit.isAppleTuned($0) }
    }

    /// In the Outliers filter, land on the first outlier member instead of
    /// member 0 so the flagged symbol is immediately editable.
    private func firstRelevantMemberIndex() -> Int {
        guard filterMode == .outliers, let family = currentFamily,
              let idx = family.members.firstIndex(where: outlierSnapshot.contains) else { return 0 }
        return idx
    }

    private var currentFamily: SymbolFamily? {
        let list = filteredFamilies
        guard list.indices.contains(selectedIndex) else { return nil }
        return list[selectedIndex]
    }

    private var currentSymbol: String? {
        guard let family = currentFamily else { return nil }
        let idx = min(memberIndex, family.members.count - 1)
        return family.members[idx]
    }

    private var currentContainerKey: String? {
        guard let symbol = currentSymbol else { return nil }
        return symbolContainerKeys[symbol]
    }

    private var effectiveYOffset: CGFloat {
        var offset = yOffset
        if useBaselineYOffset, let symbol = currentSymbol, let data = baselineData {
            offset += data.yOffsetCorrection(for: symbol, multiplier: multiplier) ?? 0
        }
        return offset
    }

    private var baselineCorrection: Double? {
        guard let symbol = currentSymbol, let data = baselineData else { return nil }
        return data.yOffsetCorrection(for: symbol, multiplier: multiplier)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if families.isEmpty {
                ContentUnavailableView("Metrics Not Available", systemImage: "exclamationmark.triangle",
                    description: Text("symbol_metrics.json not found. Run Generate Symbol Metrics first."))
            } else {
                mainContent
            }
        }
        .onAppear {
            baselineData = SymbolBaselineData.load()
            boxFit.loadCatalogs()
            if boxFit.loadCachedMeasurements() {
                rebuildOutlierSnapshot()
            }
            loadCurrentMember()
        }
        // A measurement pass or a threshold change moves the outlier set under
        // the filter, and both are explicit user actions — unlike an edit, which
        // is why the snapshot is frozen against those. See `outlierSnapshot`.
        .onChange(of: boxFit.isMeasuring) { _, measuring in
            if !measuring { rebuildOutlierSnapshot() }
        }
        .onChange(of: boxFit.threshold) { _, _ in rebuildOutlierSnapshot() }
        .onChange(of: selectedIndex) { _, _ in
            memberIndex = firstRelevantMemberIndex()
            loadCurrentMember()
        }
        .onChange(of: memberIndex) { _, _ in loadCurrentMember() }
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
            previousMember(); return .handled
        case .rightArrow:
            nextMember(); return .handled
        case .upArrow:
            navigatePrevious(); return .handled
        case .downArrow:
            navigateNext(); return .handled
        default:
            return .ignored
        }
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            controlsSidebar
                .frame(width: 650)

            Divider()

            comparisonArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .sheet(isPresented: $showMoveSheet) { moveSheet }
        .sheet(isPresented: $showMergeSheet) { mergeSheet }
        .sheet(isPresented: $showSplitSheet) { splitSheet }
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
    }

    private var confirmationPresented: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } })
    }

    private func perform(_ item: CalibrationConfirmation) {
        switch item {
        case .applyToFamily:
            if let symbol = currentSymbol, let entry = store.symbolEntries[symbol], let family = currentFamily {
                applyCalibration(entry: entry, toFamily: family)
            }
        case .acceptShownPredictions:
            acceptShownPredictions()
        case .markShownNeedsReview:
            markShownNeedsReview()
        case .restoreBundledCalibration:
            store.restoreBundledCalibration()
            rebuildFamilies()
        }
    }

    // MARK: - Controls Sidebar

    private var controlsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                searchAndFilter
                Divider()
                familyInfo
                if let family = currentFamily, !family.isContainer {
                    familyActions(for: family)
                }
                if comparisonMode != .allIcons {
                    Divider()
                    parameterSliders
                }
                Divider()
                progressInfo
                Divider()
                boxFitSection
                Divider()
                overrideSection
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

            TextField("Filter by symbol name or family...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in
                    selectedIndex = 0
                    memberIndex = 0
                    loadCurrentMember()
                }

            HStack(spacing: 12) {
                Picker("Filter", selection: $filterMode) {
                    ForEach(FamilyFilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: filterMode) { _, newMode in
                    if newMode == .outliers { rebuildOutlierSnapshot() }
                    selectedIndex = 0
                    memberIndex = firstRelevantMemberIndex()
                    loadCurrentMember()
                }
            }

            if filterMode == .outliers && !boxFit.hasMeasurements {
                Label("Nothing measured yet — use Measure All Symbols below.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // **One label, the Picker's own.** A `.segmented` Picker on macOS
            // draws its label to the left of the segments, so the `Text("Sort:")`
            // that used to sit beside it was a second one — and the pair, plus
            // the Δ segment that made five, is what compressed it into "Sor t"
            // across two lines. The Filter row above has always relied on the
            // Picker's label alone; this now matches it. Widen the frame rather
            // than adding a label back: a definite width covers label *and*
            // segments, so too small squeezes the label to nothing.
            Picker("Sort", selection: $sortMode) {
                ForEach(FamilySortMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 400)

            Text("\(filteredFamilies.count) families")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Family Info

    private var familyInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Family")
                .font(.headline)

            if let family = currentFamily {
                HStack {
                    Text(family.displayLabel)
                        .font(.title3.bold())
                    Spacer()

                    if family.isContainer {
                        Text("\(family.count) symbols (shared)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.cyan.opacity(0.15), in: Capsule())
                    } else {
                        let calCount = family.members.filter {
                            store.symbolEntries[$0]?.status == "calibrated"
                        }.count
                        Text("\(calCount)/\(family.count) calibrated")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                calCount == family.count ? .green.opacity(0.15) : .blue.opacity(0.15),
                                in: Capsule()
                            )
                    }
                }

                // Member browser
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Symbol")
                            .font(.subheadline.bold())
                        Spacer()
                        if family.count > 1 {
                            Button(action: previousMember) {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(memberIndex <= 0)

                            Text("\(memberIndex + 1)/\(family.count)")
                                .font(.caption.monospacedDigit())

                            Button(action: nextMember) {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(memberIndex >= family.count - 1)
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

                        if let metrics = symbolMetrics[symbol] {
                            Text(String(format: "%.1f x %.1f", metrics.width, metrics.height))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Member list with status markers
                    if !family.isContainer {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(family.members.prefix(10).enumerated()), id: \.offset) { idx, sym in
                                let s = store.symbolEntries[sym]?.status
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(statusColor(for: s ?? "uncalibrated"))
                                        .frame(width: 6, height: 6)
                                    if store.familyOverrides[sym] != nil {
                                        Image(systemName: "arrow.turn.down.right")
                                            .font(.system(size: 7))
                                            .foregroundStyle(.purple)
                                    }
                                    Text(sym)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(idx == memberIndex ? .primary : .tertiary)
                                        .fontWeight(idx == memberIndex ? .bold : .regular)
                                    if let delta = boxFitDelta(for: sym), abs(delta) > outlierThreshold {
                                        Text(String(format: "%+.3f", delta))
                                            .font(.system(size: 8).monospacedDigit())
                                            .foregroundStyle(.red)
                                            .help("Box-fit prediction disagrees with calibration by this much")
                                    }
                                }
                                .onTapGesture { memberIndex = idx }
                                .contextMenu {
                                    Button("Move to Another Family...") {
                                        selectedMembersForMove = [sym]
                                        moveTargetSearch = ""
                                        moveNewFamilyName = ""
                                        showMoveSheet = true
                                    }
                                    if store.familyOverrides[sym] != nil {
                                        Button("Reset to Algorithmic Family") {
                                            store.removeFamilyOverride(symbol: sym)
                                            rebuildFamilies()
                                        }
                                    }
                                    Divider()
                                    Button("Apply This Calibration to Family") {
                                        if let entry = store.symbolEntries[sym] {
                                            applyCalibration(entry: entry, toFamily: family)
                                        }
                                    }
                                    .disabled(store.symbolEntries[sym] == nil)
                                }
                            }
                            if family.count > 10 {
                                Text("... +\(family.count - 10) more")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                let symbolStatus = store.status(forSymbol: currentSymbol ?? "", containerKey: currentContainerKey)
                HStack {
                    Label(symbolStatus.capitalized, systemImage: statusIcon(for: symbolStatus))
                        .font(.caption)
                        .foregroundStyle(statusColor(for: symbolStatus))
                    if family.isContainer {
                        Text("Shared calibration")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                    }
                }
            } else {
                Text("No families match filter")
                    .foregroundStyle(.secondary)
            }
        }
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
                Slider(value: $multiplier, in: 0.3...1.0, step: 0.005)
                    .onChange(of: multiplier) { _, _ in autoSave() }
                if let symbol = currentSymbol, let prediction = boxFit.predictions[symbol] {
                    BoxFitPredictionRow(
                        prediction: prediction,
                        calibratedMultiplier: store.symbolEntries[symbol]?.multiplier,
                        threshold: outlierThreshold,
                        isAppleTuned: boxFit.isAppleTuned(symbol),
                        currentMultiplier: multiplier,
                        currentYOffset: yOffset,
                        acceptMultiplier: { acceptPrediction(for: symbol) },
                        acceptYOffset: { acceptSuggestedYOffset(for: symbol) })
                }
                HStack(spacing: 4) {
                    ForEach([0.43, 0.44, 0.46, 0.48, 0.5, 0.52, 0.53, 0.54, 0.56, 0.58, 0.59, 0.6, 0.61, 0.62, 0.63, 0.64, 0.65, 0.66], id: \.self) { val in
                        Button(String(format: "%.2f", val)) {
                            multiplier = val
                            autoSave()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(multiplier == val ? .accentColor : nil)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("X Offset")
                    Spacer()
                    Text(String(format: "%+.4f", xOffset))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $xOffset, in: -0.1...0.1, step: 0.005)
                    .onChange(of: xOffset) { _, _ in autoSave() }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Y Offset")
                    Spacer()
                    Text(String(format: "%+.4f", yOffset))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $yOffset, in: -0.1...0.1, step: 0.005)
                    .onChange(of: yOffset) { _, _ in autoSave() }
            }

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

            // Same rule as the Sort row above: the Picker's label is the only
            // one, and the frame has to fit it as well as the four segments —
            // 200pt left it reading "Wei".
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
                let view = DimIconView(
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

    // MARK: - Progress Info

    private var progressInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)

            let nonContainerFamilies = families.filter { !$0.isContainer }
            let totalSymbols = nonContainerFamilies.reduce(0) { $0 + $1.count }
            let calibrated = store.calibratedSymbolCount
            let needsReview = store.needsReviewSymbolCount
            let skipped = store.skippedSymbolCount
            let remaining = totalSymbols - calibrated - needsReview - skipped

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Total symbols:")
                        .foregroundStyle(.secondary)
                    Text("\(totalSymbols)")
                        .monospacedDigit()
                }
                GridRow {
                    Text("Families:")
                        .foregroundStyle(.secondary)
                    Text("\(nonContainerFamilies.count)")
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
                    Text("Needs review:")
                        .foregroundStyle(.secondary)
                    Text("\(needsReview)")
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                }
                GridRow {
                    Text("Skipped:")
                        .foregroundStyle(.secondary)
                    Text("\(skipped)")
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
                GridRow {
                    Text("Uncalibrated:")
                        .foregroundStyle(.secondary)
                    Text("\(remaining)")
                        .monospacedDigit()
                }
                GridRow {
                    Text("Containers:")
                        .foregroundStyle(.secondary)
                    Text("\(store.containerEntries.count) groups")
                        .monospacedDigit()
                        .foregroundStyle(.cyan)
                }
            }
            .font(.caption)

            if totalSymbols > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: Double(calibrated + needsReview + skipped), total: Double(totalSymbols))
                    Text("\(calibrated + needsReview + skipped) / \(totalSymbols) symbols")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                let calFamilies = nonContainerFamilies.filter {
                    store.familyAllMembers(withStatus: "calibrated", members: $0.members)
                }.count
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: Double(calFamilies), total: Double(nonContainerFamilies.count))
                        .tint(.cyan)
                    Text("\(calFamilies) / \(nonContainerFamilies.count) families fully calibrated")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Box-Fit Review

    /// The former Auto Sizing Review tool, as a section rather than a window:
    /// measure, set the disagreement threshold, see how the rule is doing
    /// overall, and accept or flag the whole filter at once.
    private var boxFitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Box-Fit Review")
                    .font(.headline)
                Spacer()
                Button(boxFit.hasMeasurements ? "Remeasure" : "Measure All Symbols") {
                    boxFit.measureAll()
                }
                .controlSize(.small)
                .disabled(boxFit.isMeasuring)
            }

            if boxFit.isMeasuring {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: boxFit.progress)
                    Text("Measuring tight bounds… \(boxFit.measuredCount) symbols")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if let error = boxFit.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !boxFit.hasMeasurements {
                Text("Predicts each symbol's multiplier from its tight bounds, "
                     + "so a stale calibration shows up as a disagreement.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if boxFit.hasMeasurements {
                HStack(spacing: 10) {
                    Text("Outlier threshold")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $boxFit.threshold, in: 0.01...0.1, step: 0.005)
                        .frame(width: 130)
                    Text(String(format: "±%.3f", boxFit.threshold))
                        .font(.caption.monospacedDigit())
                }

                BoxFitAgreementSummary(deltas: allBoxFitDeltas, threshold: boxFit.threshold)

                if boxFit.recipeSymbols.isEmpty {
                    Label("container_recipes.plist unavailable — Apple's hand-tuned symbols "
                          + "cannot be excluded from a batch accept.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if let symbol = currentSymbol, let prediction = boxFit.predictions[symbol] {
                    BoxFitBoundsGrid(bounds: prediction.bounds)
                    if let base = boxFit.appleFamilyOf[symbol], base != symbol {
                        Text("Apple family: \(base)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Also apply the suggested Y offset", isOn: $appliesSuggestedYOffset)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .help("Write the content-centring Y hint as well when accepting a prediction")

                let batchCount = shownPredictedSymbols(excludingAppleTuned: true).count
                let reviewCount = shownPredictedSymbols(excludingAppleTuned: false).count
                HStack(spacing: 8) {
                    Button("Accept Shown Predictions") {
                        confirmation = .acceptShownPredictions(count: batchCount)
                    }
                    .controlSize(.small)
                    .disabled(batchCount == 0)

                    Button("Mark Shown as Needs Review") {
                        confirmation = .markShownNeedsReview(count: reviewCount)
                    }
                    .controlSize(.small)
                    .disabled(reviewCount == 0)
                }

                Text("\(batchCount) of \(reviewCount) shown symbols are batch-acceptable")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Box-Fit Actions

    /// Adopts the predicted multiplier for one symbol.
    ///
    /// **Writes the entry itself rather than going through `saveCurrentValues()`**,
    /// for two reasons: that function returns early when no entry exists yet, so
    /// on an uncalibrated symbol a slider write saves nothing; and it omits
    /// `source`, which is right for a hand edit and wrong here. Accepting a
    /// prediction is what `auto-boxfit` means.
    private func acceptPrediction(for symbol: String) {
        guard let prediction = boxFit.predictions[symbol] else { return }
        writeAccepted(prediction, for: symbol)
        store.save()
        loadCurrentMember()
    }

    /// Adopts only the advisory Y offset, leaving the multiplier and the status
    /// alone — so this is a hand edit, and clears `source` like any other.
    private func acceptSuggestedYOffset(for symbol: String) {
        guard let prediction = boxFit.predictions[symbol] else { return }
        yOffset = round3(prediction.suggestedYOffset)
        autoSave()
    }

    private func writeAccepted(_ prediction: AutoSizingPrediction, for symbol: String) {
        let existing = store.symbolEntries[symbol]
        store.symbolEntries[symbol] = SymbolCalibrationEntry(
            multiplier: round3(prediction.multiplier),
            xOffset: existing?.xOffset ?? 0,
            yOffset: appliesSuggestedYOffset
                ? round3(prediction.suggestedYOffset)
                : existing?.yOffset ?? 0,
            weight: existing?.weight ?? "regular",
            status: "calibrated",
            source: "auto-boxfit")
    }

    /// Apple's hand-tuned symbols are skipped: the rule is not expected to match
    /// them, so accepting a prediction there replaces a measured value with an
    /// estimate. Containers are skipped too — their entries live under
    /// `containers`, keyed by shape, and a per-symbol write would not reach them.
    private func acceptShownPredictions() {
        for symbol in shownPredictedSymbols(excludingAppleTuned: true) {
            guard let prediction = boxFit.predictions[symbol] else { continue }
            writeAccepted(prediction, for: symbol)
        }
        store.save()
        loadCurrentMember()
    }

    private func markShownNeedsReview() {
        for symbol in shownPredictedSymbols(excludingAppleTuned: false) {
            if var entry = store.symbolEntries[symbol] {
                entry.status = "needs-review"
                store.symbolEntries[symbol] = entry
            } else if let prediction = boxFit.predictions[symbol] {
                store.symbolEntries[symbol] = SymbolCalibrationEntry(
                    multiplier: round3(prediction.multiplier),
                    xOffset: 0, yOffset: 0, weight: "regular",
                    status: "needs-review", source: "auto-boxfit")
            }
        }
        store.save()
        loadCurrentMember()
    }

    private func round3(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }

    // MARK: - The Override

    /// What this tool's edits actually do to the running app, and the way back.
    ///
    /// Not decoration: `SymbolSizingService` prefers the file this tool writes
    /// over the bundled one whenever the developer tools are enabled, so every
    /// slider in this window is changing how the app beside it sizes symbols.
    /// That was invisible while the tools were Debug-only.
    private var overrideSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Production Override")
                .font(.headline)

            if store.hasOverride {
                Label("Mica is rendering with this file, not the bundled calibration.",
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
                GridRow { Text("Up/Down"); Text("Previous / Next family") }
                GridRow { Text("Left/Right"); Text("Previous / Next member") }
                GridRow { Text("Space"); Text("Mark calibrated + advance member") }
                GridRow { Text("Tab"); Text("Same as previous + advance member") }
                GridRow { Text("Escape"); Text("Mark skipped + advance member") }
                GridRow { Text("Cmd+Up/Down"); Text("Nudge multiplier +/-0.001") }
                GridRow { Text("Shift+Left/Right"); Text("Nudge X offset +/-0.001") }
                GridRow { Text("Shift+Up/Down"); Text("Nudge Y offset +/-0.001") }
                GridRow { Text("Right-click member"); Text("Move / Reset / Apply calibration") }
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
            } else if let family = currentFamily, let symbol = currentSymbol {
                VStack(spacing: 12) {
                    HStack {
                        Text(family.displayLabel)
                            .font(.title3.bold())
                        if family.isContainer {
                            Text("Container")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.cyan.opacity(0.15), in: Capsule())
                                .foregroundStyle(.cyan)
                        }
                        Text("—")
                            .foregroundStyle(.secondary)
                        Text(symbol)
                            .font(.title3.monospaced())
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
                ContentUnavailableView("No Families", systemImage: "magnifyingglass",
                    description: Text("No families match the current filter"))
            }

            Divider()

            VStack(spacing: 8) {
                Picker("Mode", selection: $comparisonMode) {
                    ForEach(FamilyComparisonMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 500)

                HStack(spacing: 16) {
                    if comparisonMode == .overlay || comparisonMode == .tintedOverlay {
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

                if comparisonMode != .allIcons {
                    HStack {
                        Button(action: navigatePrevious) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(selectedIndex <= 0)

                        Spacer()

                        Text("\(selectedIndex + 1) / \(filteredFamilies.count)")
                            .font(.caption.monospacedDigit())

                        Spacer()

                        Button(action: navigateNext) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(selectedIndex >= filteredFamilies.count - 1)
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
            if let family = currentFamily {
                galleryView(for: family)
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

    // MARK: - Gallery View

    private func galleryView(for family: SymbolFamily) -> some View {
        let columns = [GridItem(.adaptive(minimum: galleryThumbSize + 8), spacing: 8)]

        return VStack(spacing: 0) {
            ScrollView {
                if galleryTintOverlay && !galleryLoadingSymbols.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading references: \(family.members.count - galleryLoadingSymbols.count)/\(family.members.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(family.members.enumerated()), id: \.element) { idx, symbol in
                        VStack(spacing: 2) {
                            galleryThumbView(for: symbol, inFamily: family, size: galleryThumbSize)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay {
                                    if idx == memberIndex {
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(.blue, lineWidth: 2)
                                    }
                                }

                            HStack(spacing: 2) {
                                let s = family.isContainer
                                    ? store.containerEntries[SymbolCalibrationStore.containerDims.first { $0.label == family.containerLabel }?.key ?? ""]?.status
                                    : store.symbolEntries[symbol]?.status
                                Circle()
                                    .fill(statusColor(for: s ?? "uncalibrated"))
                                    .frame(width: 5, height: 5)
                                Text(symbol)
                                    .font(.system(size: max(8, galleryThumbSize * 0.08)).monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(width: galleryThumbSize - 8)
                            }
                        }
                        .draggable(symbol) {
                            HStack(spacing: 4) {
                                Image(systemName: symbol)
                                    .font(.title3)
                            }
                            .padding(6)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .dropDestination(for: String.self) { droppedSymbols, _ in
                            guard !family.isContainer,
                                  let sourceSymbol = droppedSymbols.first,
                                  let entry = store.symbolEntries[sourceSymbol],
                                  entry.status == "calibrated"
                            else { return false }
                            store.symbolEntries[symbol] = entry
                            store.save()
                            loadCurrentMember()
                            return true
                        }
                        .onTapGesture {
                            memberIndex = idx
                            comparisonMode = .overlay
                        }
                    }
                }
                .padding(8)
            }

            Divider()

            HStack(spacing: 16) {
                Toggle("Grid", isOn: $showGridOverlay)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Toggle("Tint Overlay", isOn: $galleryTintOverlay)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: galleryTintOverlay) { _, newValue in
                        if newValue, let family = currentFamily {
                            loadGalleryReferences(for: family.members)
                        } else if !newValue {
                            galleryLoadTask?.cancel()
                            galleryReferenceImages = [:]
                            galleryLoadingSymbols = []
                        }
                    }

                if galleryTintOverlay {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $overlayOpacity, in: 0...1)
                        .frame(width: 100)
                    Text(String(format: "%.0f%%", overlayOpacity * 100))
                        .font(.caption.monospacedDigit())
                        .frame(width: 36, alignment: .trailing)
                }

                Spacer()

                Text("Size")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $galleryThumbSize, in: 48...256, step: 8)
                    .frame(width: 140)
                Text("\(Int(galleryThumbSize))")
                    .font(.caption.monospacedDigit())
                    .frame(width: 28, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - All Icons View

    /// Flat ordered list of all non-container symbols across filtered families, used for shift-click range selection.
    private var allIconsFlatSymbols: [String] {
        filteredFamilies.filter { !$0.isContainer }.flatMap(\.members)
    }

    private var allIconsView: some View {
        let thumbSize: CGFloat = 56
        let columns = [GridItem(.adaptive(minimum: thumbSize + 4), spacing: 4)]
        let familyList = filteredFamilies
        let totalSymbols = familyList.reduce(0) { $0 + $1.count }

        return VStack(spacing: 4) {
            HStack {
                Text("All Icons")
                    .font(.headline)
                Spacer()
                legendView
                Spacer()
                Toggle("Grid", isOn: $showGridOverlay)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Text("\(totalSymbols) symbols")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(familyList) { family in
                        Section {
                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(family.members, id: \.self) { symbol in
                                    allIconsThumb(symbol: symbol, family: family, size: thumbSize)
                                        .id(symbol)
                                        .onTapGesture {
                                            handleAllIconsTap(symbol: symbol, family: family)
                                        }
                                        .simultaneousGesture(TapGesture().modifiers(.command).onEnded {
                                            handleAllIconsCmdTap(symbol: symbol)
                                        })
                                        .simultaneousGesture(TapGesture().modifiers(.shift).onEnded {
                                            handleAllIconsShiftTap(symbol: symbol)
                                        })
                                        .draggable(symbol) {
                                            // Drag preview: show count if multi-selected, otherwise single symbol
                                            let dragSymbols = allIconsSelection.contains(symbol) ? allIconsSelection : [symbol]
                                            HStack(spacing: 4) {
                                                Image(systemName: symbol)
                                                    .font(.title3)
                                                if dragSymbols.count > 1 {
                                                    Text("\(dragSymbols.count) symbols")
                                                        .font(.caption.bold())
                                                }
                                            }
                                            .padding(6)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                                        }
                                }
                            }
                        } header: {
                            allIconsFamilyHeader(family: family)
                        }
                    }
                }
                .padding(8)
            }
            .onAppear {
                if let symbol = currentSymbol {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation {
                            scrollProxy.scrollTo(symbol, anchor: .center)
                        }
                    }
                }
            }
            } // ScrollViewReader

            if !allIconsSelection.isEmpty {
                allIconsSelectionBar
            }
        }
        .sheet(isPresented: $showSelectionMoveSheet) { selectionMoveSheet }
        .sheet(isPresented: $showSelectionApplySheet) { selectionApplySheet }
    }

    private func allIconsFamilyHeader(family: SymbolFamily) -> some View {
        HStack(spacing: 6) {
            Text(family.displayLabel)
                .font(.caption.bold())
            Text("\(family.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if family.isContainer {
                Text("Container")
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.cyan.opacity(0.15), in: Capsule())
                    .foregroundStyle(.cyan)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .dropDestination(for: String.self) { droppedSymbols, _ in
            guard !family.isContainer else { return false }
            let symbolsToMove = allIconsSelection.isEmpty ? Set(droppedSymbols) : allIconsSelection.union(droppedSymbols)
            let nonContainer = symbolsToMove.filter { sym in
                guard let dk = symbolContainerKeys[sym] else { return true }
                return !SymbolCalibrationStore.containerKeys.contains(dk)
            }
            guard !nonContainer.isEmpty else { return false }
            moveSymbols(Array(nonContainer), toFamily: family.id)
            allIconsSelection = []
            return true
        } isTargeted: { isTargeted in
            // Could add highlight state here if desired
        }
    }

    private func allIconsThumb(symbol: String, family: SymbolFamily, size: CGFloat) -> some View {
        let dk = symbolContainerKeys[symbol]
        let cal = store.entry(forSymbol: symbol, containerKey: dk)
        let mul = cal?.multiplier ?? 0.65
        let xOff = cal?.xOffset ?? 0.0
        let yOff: CGFloat = {
            var off = cal?.yOffset ?? 0.0
            if useBaselineYOffset, let data = baselineData {
                off += data.yOffsetCorrection(for: symbol, multiplier: mul) ?? 0
            }
            return off
        }()
        let w: Font.Weight = cal?.weight == "medium" ? .medium : .regular
        let status = cal?.status ?? "uncalibrated"
        let isSelected = allIconsSelection.contains(symbol)

        return ZStack {
            DimIconView(
                symbolName: symbol,
                displaySize: size,
                multiplier: mul,
                xOffset: xOff,
                yOffset: yOff,
                weight: w,
                symbolOnly: false
            )
            gridOverlay(size: size)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    isSelected ? .purple : borderColor(for: status),
                    lineWidth: isSelected ? 2.5 : (status == "uncalibrated" || status == "needs-review" ? 0 : 1.5)
                )
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white, .purple)
                    .offset(x: 2, y: -2)
            }
        }
        .help(symbol)
        .dropDestination(for: String.self) { droppedSymbols, _ in
            guard !family.isContainer,
                  let sourceSymbol = droppedSymbols.first,
                  let entry = store.symbolEntries[sourceSymbol],
                  entry.status == "calibrated"
            else { return false }
            // Apply to drop target + its selection if selected, otherwise just the drop target
            let targets = isSelected ? allIconsSelection : [symbol]
            for target in targets {
                store.symbolEntries[target] = entry
            }
            store.save()
            allIconsSelection = []
            loadCurrentMember()
            return true
        }
        .contextMenu {
            if !family.isContainer {
                let targetSymbols = isSelected ? Array(allIconsSelection) : [symbol]
                let label = targetSymbols.count == 1 ? symbol : "\(targetSymbols.count) symbols"

                Button("Move \(label) to Family...") {
                    allIconsSelection = Set(targetSymbols)
                    selectionMoveTargetSearch = ""
                    selectionMoveNewFamilyName = ""
                    showSelectionMoveSheet = true
                }

                Button("Apply Calibration to \(label)...") {
                    allIconsSelection = Set(targetSymbols)
                    selectionApplySourceSearch = ""
                    showSelectionApplySheet = true
                }

                if targetSymbols.contains(where: { store.familyOverrides[$0] != nil }) {
                    Divider()
                    Button("Reset to Algorithmic Families") {
                        let overridden = targetSymbols.filter { store.familyOverrides[$0] != nil }
                        store.removeFamilyOverrides(for: overridden)
                        allIconsSelection = []
                        rebuildFamilies()
                    }
                }

                Divider()
                Button("Clear Selection") {
                    allIconsSelection = []
                }
            }
        }
    }

    // MARK: - All Icons Selection Handling

    private func handleAllIconsTap(symbol: String, family: SymbolFamily) {
        // Plain tap without modifiers: navigate to symbol and clear selection
        if allIconsSelection.isEmpty {
            navigateToSymbol(symbol, inFamily: family)
        } else {
            allIconsSelection = []
        }
    }

    private func handleAllIconsCmdTap(symbol: String) {
        if allIconsSelection.contains(symbol) {
            allIconsSelection.remove(symbol)
        } else {
            allIconsSelection.insert(symbol)
        }
        lastTappedSymbol = symbol
    }

    private func handleAllIconsShiftTap(symbol: String) {
        let flat = allIconsFlatSymbols
        guard let tappedIdx = flat.firstIndex(of: symbol) else { return }

        if let lastSym = lastTappedSymbol, let lastIdx = flat.firstIndex(of: lastSym) {
            let range = min(lastIdx, tappedIdx)...max(lastIdx, tappedIdx)
            for i in range {
                allIconsSelection.insert(flat[i])
            }
        } else {
            allIconsSelection.insert(symbol)
        }
        lastTappedSymbol = symbol
    }

    // MARK: - All Icons Selection Bar

    private var allIconsSelectionBar: some View {
        HStack(spacing: 12) {
            Text("\(allIconsSelection.count) selected")
                .font(.caption.bold())
                .foregroundStyle(.purple)

            Divider()
                .frame(height: 16)

            Button("Move to Family...") {
                selectionMoveTargetSearch = ""
                selectionMoveNewFamilyName = ""
                showSelectionMoveSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Apply Calibration...") {
                selectionApplySourceSearch = ""
                showSelectionApplySheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Button("Deselect All") {
                allIconsSelection = []
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Selection Move Sheet

    private var selectionMoveSheet: some View {
        VStack(spacing: 16) {
            Text("Move \(allIconsSelection.count) Symbol(s) to Family")
                .font(.headline)

            let preview = allIconsSelection.sorted().prefix(5)
            Text(preview.joined(separator: ", ") + (allIconsSelection.count > 5 ? "..." : ""))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            TextField("Search families...", text: $selectionMoveTargetSearch)
                .textFieldStyle(.roundedBorder)

            let matchingFamilies = families.filter { family in
                !family.isContainer &&
                (selectionMoveTargetSearch.isEmpty || family.id.localizedCaseInsensitiveContains(selectionMoveTargetSearch))
            }.prefix(20)

            List(Array(matchingFamilies), id: \.id) { family in
                Button {
                    moveSymbols(Array(allIconsSelection), toFamily: family.id)
                    allIconsSelection = []
                    showSelectionMoveSheet = false
                } label: {
                    HStack {
                        Text(family.id)
                            .font(.body.monospaced())
                        Spacer()
                        Text("\(family.count) members")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 300)

            Divider()

            HStack {
                Text("Or create new family:")
                    .font(.caption)
                TextField("New family name", text: $selectionMoveNewFamilyName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("Create & Move") {
                    let name = selectionMoveNewFamilyName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    moveSymbols(Array(allIconsSelection), toFamily: name)
                    allIconsSelection = []
                    showSelectionMoveSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectionMoveNewFamilyName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Button("Cancel") { showSelectionMoveSheet = false }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 500, height: 520)
    }

    // MARK: - Selection Apply Calibration Sheet

    private var selectionApplySheet: some View {
        VStack(spacing: 16) {
            Text("Apply Calibration to \(allIconsSelection.count) Symbol(s)")
                .font(.headline)

            Text("Choose a calibrated symbol to copy its values from:")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search calibrated symbols...", text: $selectionApplySourceSearch)
                .textFieldStyle(.roundedBorder)

            let calibratedSymbols = store.symbolEntries
                .filter { $0.value.status == "calibrated" }
                .keys
                .filter { selectionApplySourceSearch.isEmpty || $0.localizedCaseInsensitiveContains(selectionApplySourceSearch) }
                .sorted()
                .prefix(30)

            List(Array(calibratedSymbols), id: \.self) { symbol in
                let entry = store.symbolEntries[symbol]!
                Button {
                    for targetSymbol in allIconsSelection {
                        store.symbolEntries[targetSymbol] = entry
                    }
                    store.save()
                    allIconsSelection = []
                    showSelectionApplySheet = false
                    loadCurrentMember()
                } label: {
                    HStack {
                        Image(systemName: symbol)
                            .font(.body)
                            .frame(width: 24)
                        Text(symbol)
                            .font(.body.monospaced())
                        Spacer()
                        Text(String(format: "mul=%.3f", entry.multiplier))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 350)

            Button("Cancel") { showSelectionApplySheet = false }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 500, height: 520)
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
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
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

    /// Navigate from All Icons view to a symbol's family.
    private func navigateToSymbol(_ symbol: String, inFamily family: SymbolFamily) {
        comparisonMode = .overlay

        let list = filteredFamilies
        if let idx = list.firstIndex(where: { $0.id == family.id }) {
            selectedIndex = idx
            if let memberIdx = list[idx].members.firstIndex(of: symbol) {
                memberIndex = memberIdx
            }
        }
    }

    @ViewBuilder
    private func galleryThumbView(for symbol: String, inFamily family: SymbolFamily, size: CGFloat) -> some View {
        if galleryTintOverlay {
            ZStack {
                if let refImage = galleryReferenceImages[symbol] {
                    Image(nsImage: refImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: size, height: size)
                } else if galleryLoadingSymbols.contains(symbol) {
                    ProgressView()
                        .frame(width: size, height: size)
                        .background(Color.gray.opacity(0.1))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: size, height: size)
                }
                galleryIcon(for: symbol, inFamily: family, size: size, tinted: true)
                    .opacity(overlayOpacity)
            }
        } else {
            galleryIcon(for: symbol, inFamily: family, size: size, tinted: false)
        }
    }

    private func galleryIcon(for symbol: String, inFamily family: SymbolFamily, size: CGFloat, tinted: Bool) -> some View {
        // Use saved calibration for each member; current slider values only for selected member
        let dk = symbolContainerKeys[symbol]
        let isSelected = symbol == currentSymbol

        let mul: CGFloat
        let xOff: CGFloat
        let yOff: CGFloat
        let w: Font.Weight

        if isSelected {
            mul = multiplier
            xOff = xOffset
            w = weight
            var off = yOffset
            if useBaselineYOffset, let data = baselineData {
                off += data.yOffsetCorrection(for: symbol, multiplier: multiplier) ?? 0
            }
            yOff = off
        } else {
            let cal = store.entry(forSymbol: symbol, containerKey: dk)
            mul = cal?.multiplier ?? 0.65
            xOff = cal?.xOffset ?? 0.0
            w = cal?.weight == "medium" ? .medium : .regular
            var off = cal?.yOffset ?? 0.0
            if useBaselineYOffset, let data = baselineData {
                off += data.yOffsetCorrection(for: symbol, multiplier: mul) ?? 0
            }
            yOff = off
        }

        return ZStack {
            DimIconView(
                symbolName: symbol,
                displaySize: size,
                multiplier: mul,
                xOffset: xOff,
                yOffset: yOff,
                weight: w,
                symbolOnly: tinted
            )
            gridOverlay(size: size)
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
                yOffset: effectiveYOffset,
                weight: weight,
                symbolOnly: symbolOnly
            )
            gridOverlay(size: displaySize)
        }
    }

    // MARK: - Family Actions UI

    private func familyActions(for family: SymbolFamily) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Family Actions")
                .font(.subheadline.bold())

            HStack(spacing: 8) {
                Button("Merge...") {
                    mergeTargetSearch = ""
                    showMergeSheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Split...") {
                    splitSelections = Set(family.members)
                    splitNewFamilyName = ""
                    showSplitSheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(family.count < 2)

                Button("Apply to Family") {
                    confirmation = .applyToFamily(name: family.id, count: family.count)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentSymbol == nil || store.symbolEntries[currentSymbol ?? ""] == nil)
            }

            let overriddenMembers = family.members.filter { store.familyOverrides[$0] != nil }
            if !overriddenMembers.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text("\(overriddenMembers.count) custom override(s)")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Spacer()
                    Button("Reset All") {
                        store.removeFamilyOverrides(for: overriddenMembers)
                        rebuildFamilies()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Move Sheet

    private var moveSheet: some View {
        VStack(spacing: 16) {
            Text("Move Symbol(s) to Family")
                .font(.headline)

            let symbolsToMove = Array(selectedMembersForMove)
            if symbolsToMove.count == 1 {
                Text("Moving: \(symbolsToMove[0])")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Moving \(symbolsToMove.count) symbols")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Search families...", text: $moveTargetSearch)
                .textFieldStyle(.roundedBorder)

            let matchingFamilies = families.filter { family in
                !family.isContainer &&
                family.id != currentFamily?.id &&
                (moveTargetSearch.isEmpty || family.id.localizedCaseInsensitiveContains(moveTargetSearch))
            }.prefix(20)

            List(Array(matchingFamilies), id: \.id) { family in
                Button {
                    moveSymbols(symbolsToMove, toFamily: family.id)
                    showMoveSheet = false
                } label: {
                    HStack {
                        Text(family.id)
                            .font(.body.monospaced())
                        Spacer()
                        Text("\(family.count) members")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 300)

            Divider()

            HStack {
                Text("Or create new family:")
                    .font(.caption)
                TextField("New family name", text: $moveNewFamilyName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("Create & Move") {
                    let name = moveNewFamilyName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    moveSymbols(symbolsToMove, toFamily: name)
                    showMoveSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(moveNewFamilyName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Button("Cancel") { showMoveSheet = false }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 500, height: 520)
    }

    // MARK: - Merge Sheet

    private var mergeSheet: some View {
        VStack(spacing: 16) {
            Text("Merge Family Into...")
                .font(.headline)

            if let family = currentFamily {
                Text("Merge all \(family.count) members of \"\(family.id)\" into another family")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Search families...", text: $mergeTargetSearch)
                .textFieldStyle(.roundedBorder)

            let matchingFamilies = families.filter { family in
                !family.isContainer &&
                family.id != currentFamily?.id &&
                (mergeTargetSearch.isEmpty || family.id.localizedCaseInsensitiveContains(mergeTargetSearch))
            }.prefix(20)

            List(Array(matchingFamilies), id: \.id) { family in
                Button {
                    mergeCurrentFamily(into: family.id)
                    showMergeSheet = false
                } label: {
                    HStack {
                        Text(family.id)
                            .font(.body.monospaced())
                        Spacer()
                        Text("\(family.count) members")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 350)

            Button("Cancel") { showMergeSheet = false }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 500, height: 500)
    }

    // MARK: - Split Sheet

    private var splitSheet: some View {
        VStack(spacing: 16) {
            Text("Split Family")
                .font(.headline)

            if let family = currentFamily {
                Text("Check symbols to keep in \"\(family.id)\". Unchecked symbols move to the new family.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List(family.members, id: \.self) { symbol in
                    Toggle(isOn: Binding(
                        get: { splitSelections.contains(symbol) },
                        set: { isOn in
                            if isOn { splitSelections.insert(symbol) } else { splitSelections.remove(symbol) }
                        }
                    )) {
                        HStack(spacing: 4) {
                            Image(systemName: symbol)
                                .font(.body)
                                .frame(width: 24)
                            Text(symbol)
                                .font(.body.monospaced())
                        }
                    }
                }
                .frame(height: 300)

                let stayCount = splitSelections.count
                let moveCount = family.count - stayCount

                HStack {
                    Text("Stay: \(stayCount)")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Move: \(moveCount)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Text("New family name:")
                        .font(.caption)
                    TextField("e.g. star.special", text: $splitNewFamilyName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }

                let canSplit = stayCount >= 1 && moveCount >= 1 &&
                    !splitNewFamilyName.trimmingCharacters(in: .whitespaces).isEmpty

                HStack {
                    Button("Cancel") { showSplitSheet = false }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Split") {
                        performSplit(family: family)
                        showSplitSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSplit)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 520)
    }

    // MARK: - Family Management Actions

    private func moveSymbols(_ symbols: [String], toFamily target: String) {
        var overrides: [String: String] = [:]
        for symbol in symbols {
            overrides[symbol] = target
        }
        store.setFamilyOverrides(overrides)
        rebuildFamilies()
    }

    private func mergeCurrentFamily(into target: String) {
        guard let family = currentFamily else { return }
        var overrides: [String: String] = [:]
        for symbol in family.members {
            overrides[symbol] = target
        }
        store.setFamilyOverrides(overrides)
        rebuildFamilies()
    }

    private func performSplit(family: SymbolFamily) {
        let newName = splitNewFamilyName.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else { return }
        let symbolsToMove = family.members.filter { !splitSelections.contains($0) }
        guard !symbolsToMove.isEmpty else { return }
        var overrides: [String: String] = [:]
        for symbol in symbolsToMove {
            overrides[symbol] = newName
        }
        store.setFamilyOverrides(overrides)
        rebuildFamilies()
    }

    private func applyCalibration(entry: SymbolCalibrationEntry, toFamily family: SymbolFamily) {
        for member in family.members {
            store.symbolEntries[member] = entry
        }
        store.save()
        loadCurrentMember()
    }

    // MARK: - Navigation

    private func navigatePrevious() {
        guard selectedIndex > 0 else { return }
        saveCurrentValues()
        selectedIndex -= 1
    }

    private func navigateNext() {
        guard selectedIndex < filteredFamilies.count - 1 else { return }
        saveCurrentValues()
        selectedIndex += 1
    }

    private func previousMember() {
        guard memberIndex > 0 else { return }
        saveCurrentValues()
        memberIndex -= 1
    }

    private func nextMember() {
        guard let family = currentFamily, memberIndex < family.count - 1 else { return }
        saveCurrentValues()
        memberIndex += 1
    }

    /// Advance to next member within family, or next family if at end.
    private func advanceToNextMember() {
        guard let family = currentFamily else { return }
        if family.isContainer || memberIndex >= family.count - 1 {
            // Move to next family
            if selectedIndex < filteredFamilies.count - 1 {
                selectedIndex += 1
            }
        } else {
            memberIndex += 1
            loadCurrentMember()
        }
    }

    private func markCalibratedAndAdvance() {
        guard let symbol = currentSymbol else { return }
        let entry = SymbolCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "calibrated"
        )
        store.setEntry(entry, forSymbol: symbol, containerKey: currentContainerKey)
        advanceToNextMember()
    }

    private func markSkippedAndAdvance() {
        guard let symbol = currentSymbol else { return }
        let entry = SymbolCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "skipped"
        )
        store.setEntry(entry, forSymbol: symbol, containerKey: currentContainerKey)
        advanceToNextMember()
    }

    /// Copy current slider values to current symbol as calibrated, then advance.
    /// Since sliders retain values from the previous member, this effectively copies them.
    private func copyPreviousAndAdvance() {
        markCalibratedAndAdvance()
    }

    // MARK: - Load / Save

    private func loadCurrentMember() {
        guard let symbol = currentSymbol else {
            referenceImage = nil
            return
        }

        let existing = store.entry(forSymbol: symbol, containerKey: currentContainerKey)
        if let existing {
            multiplier = existing.multiplier
            xOffset = existing.xOffset
            yOffset = existing.yOffset
            weight = existing.weight == "medium" ? .medium : .regular
        } else {
            multiplier = 0.65
            xOffset = 0.0
            yOffset = 0.0
            weight = .regular
        }

        loadReferenceImage()

        if galleryTintOverlay && comparisonMode == .gallery, let family = currentFamily {
            loadGalleryReferences(for: family.members)
        }
    }

    private func loadReferenceImage() {
        guard let symbol = currentSymbol else {
            referenceImage = nil
            return
        }
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

            let list = filteredFamilies
            let nextStart = selectedIndex + 1
            let nextEnd = min(nextStart + 3, list.count)
            if nextStart < nextEnd {
                let names = (nextStart..<nextEnd).map { list[$0].representative }
                service.prefetch(names)
            }
        }
    }

    private func loadGalleryReferences(for symbols: [String]) {
        galleryLoadTask?.cancel()
        galleryReferenceImages = [:]
        galleryLoadingSymbols = Set(symbols)

        galleryLoadTask = Task {
            await withTaskGroup(of: (String, NSImage?).self) { taskGroup in
                for symbol in symbols {
                    taskGroup.addTask {
                        guard !Task.isCancelled else { return (symbol, nil) }
                        let image = try? await service.referenceIcon(for: symbol)
                        return (symbol, image)
                    }
                }
                for await (symbol, image) in taskGroup {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if let image {
                            galleryReferenceImages[symbol] = image
                        }
                        galleryLoadingSymbols.remove(symbol)
                    }
                }
            }
        }
    }

    private func saveCurrentValues() {
        guard let symbol = currentSymbol else { return }
        guard let existingStatus = store.entry(forSymbol: symbol, containerKey: currentContainerKey)?.status else { return }
        let entry = SymbolCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: existingStatus
        )
        store.setEntry(entry, forSymbol: symbol, containerKey: currentContainerKey)
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

// MARK: - Preview

#Preview {
    SymbolCalibrationTool()
        .frame(width: 1100, height: 800)
}
