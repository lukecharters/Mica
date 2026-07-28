// AppleReferenceCalibrationPlayground.swift
//
// Calibration tool for generating ground-truth reference icons via Apple's
// private rendering pipeline (.appex manipulation), then overlaying our
// rendered icon on top and fine-tuning multiplier + offsets until they match.
//
// Produces icon-calibration.json in the sandbox container's
// Application Support/Mica/ (via ReferenceCalibrationStore), mapping every SF Symbol
// to its calibrated {multiplier, xOffset, yOffset, weight}.

import SwiftUI

// MARK: - Symbol Deduplicator

/// Deduplicates SF Symbols to a canonical set (~3,684 from ~7,007).
/// Rules: strip .fill variants, collapse .circle/.square containers.
struct SymbolDeduplicator {
    let canonicalSymbols: [String]
    let canonicalToMembers: [String: [String]]
    private let memberToCanonical: [String: String]

    static func build(from allSymbols: [String]) -> SymbolDeduplicator {
        // Exceptions: these are unique shapes, not containers
        let squareExceptions: Set<String> = [
            "square.on.square", "square.filled.on.square",
            "square.on.square.dashed", "square.on.fill"
        ]

        var canonicalMap: [String: [String]] = [:]
        var reverseMap: [String: String] = [:]

        for symbol in allSymbols {
            let canonical = computeCanonical(for: symbol, squareExceptions: squareExceptions)

            if canonicalMap[canonical] == nil {
                canonicalMap[canonical] = []
            }
            canonicalMap[canonical]!.append(symbol)
            reverseMap[symbol] = canonical
        }

        // Preserve original ordering by first appearance
        var seen = Set<String>()
        var ordered: [String] = []
        for symbol in allSymbols {
            let c = reverseMap[symbol]!
            if seen.insert(c).inserted {
                ordered.append(c)
            }
        }

        return SymbolDeduplicator(
            canonicalSymbols: ordered,
            canonicalToMembers: canonicalMap,
            memberToCanonical: reverseMap
        )
    }

    func canonical(for symbol: String) -> String {
        memberToCanonical[symbol] ?? symbol
    }

    private static func computeCanonical(for symbol: String, squareExceptions: Set<String>) -> String {
        var name = symbol

        // Strip .fill suffix
        if name.hasSuffix(".fill") {
            name = String(name.dropLast(5))
        }

        // Collapse .circle variants to representative
        if name.hasSuffix(".circle") {
            let base = String(name.dropLast(7)) // drop ".circle"
            // Only collapse single-character or simple letter/number circles
            if base.count <= 2 || base.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." }) {
                // Check if it looks like a container variant (a.circle, b.circle, 1.circle, etc.)
                let components = base.split(separator: ".")
                if components.count == 1 && components[0].count <= 2 {
                    return "circle" // canonical representative
                }
            }
        }

        // Collapse .square variants to representative (with exceptions)
        if name.hasSuffix(".square") {
            let base = String(name.dropLast(7)) // drop ".square"
            if !squareExceptions.contains(name) {
                let components = base.split(separator: ".")
                if components.count == 1 && components[0].count <= 2 {
                    return "square" // canonical representative
                }
            }
        }

        return name
    }
}

// MARK: - Calibration Icon View

/// Renders our icon with raw calibration parameters — no recipe lookup, no recipeScaleFactor.
struct CalibratingIconView: View {
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

// MARK: - Comparison Modes

private enum ComparisonMode: String, CaseIterable {
    case overlay = "Overlay"
    case tintedOverlay = "Tinted Overlay"
    case sideBySide = "Side by Side"
    case difference = "Difference"
}

private enum FilterMode: String, CaseIterable {
    case all = "All"
    case uncalibrated = "Uncalibrated"
    case calibrated = "Calibrated"
    case skipped = "Skipped"
}

// MARK: - Main Playground

struct AppleReferenceCalibrationPlayground: View {
    @State private var store = ReferenceCalibrationStore()
    @State private var service = AppexReferenceService()
    @State private var deduplicator: SymbolDeduplicator
    @State private var allSymbols: [String]

    @State private var selectedIndex = 0
    @State private var multiplier = 0.55
    @State private var xOffset = 0.0
    @State private var yOffset = 0.0
    @State private var weight: Font.Weight = .regular
    @State private var comparisonMode: ComparisonMode = .overlay
    @State private var overlayOpacity = 0.5
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all
    @State private var referenceImage: NSImage?
    @State private var isLoadingReference = false
    @State private var errorMessage: String?

    private let displaySize: CGFloat = 512

    init() {
        let symbols = Self.loadSymbols()
        let dedup = SymbolDeduplicator.build(from: symbols)
        _allSymbols = State(initialValue: symbols)
        _deduplicator = State(initialValue: dedup)
    }

    private static func loadSymbols() -> [String] {
        guard let url = Bundle.main.url(forResource: "sf-symbols", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    // MARK: - Filtered Symbol List

    private var filteredSymbols: [String] {
        var list = deduplicator.canonicalSymbols

        if !searchText.isEmpty {
            list = list.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }

        switch filterMode {
        case .all: break
        case .uncalibrated:
            list = list.filter { store.entry(for: $0)?.status != "calibrated" && store.entry(for: $0)?.status != "skipped" }
        case .calibrated:
            list = list.filter { store.entry(for: $0)?.status == "calibrated" }
        case .skipped:
            list = list.filter { store.entry(for: $0)?.status == "skipped" }
        }

        return list
    }

    private var currentSymbol: String? {
        let list = filteredSymbols
        guard list.indices.contains(selectedIndex) else { return nil }
        return list[selectedIndex]
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .onAppear { loadCurrentSymbol() }
            .onChange(of: selectedIndex) { _, _ in loadCurrentSymbol() }
            .focusable()
            .onKeyPress(.space) { markCalibratedAndAdvance(); return .handled }
            .onKeyPress(.escape) { markSkippedAndAdvance(); return .handled }
            .onKeyPress(.tab) { copyPreviousAndAdvance(); return .handled }
            .onKeyPress(phases: .down) { press in
                handleKeyPress(press)
            }
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
                symbolInfo
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

            TextField("Filter symbols...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in
                    selectedIndex = 0
                    loadCurrentSymbol()
                }

            Picker("Filter", selection: $filterMode) {
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: filterMode) { _, _ in
                selectedIndex = 0
                loadCurrentSymbol()
            }

            Text("\(filteredSymbols.count) symbols")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var symbolInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Symbol")
                .font(.headline)

            if let symbol = currentSymbol {
                HStack {
                    Image(systemName: symbol)
                        .font(.title2)
                    Text(symbol)
                        .font(.body.monospaced())
                }

                let members = deduplicator.canonicalToMembers[symbol] ?? [symbol]
                if members.count > 1 {
                    Text("Applies to \(members.count) variants: \(members.prefix(5).joined(separator: ", "))\(members.count > 5 ? "..." : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let status = store.entry(for: symbol)?.status ?? "uncalibrated"
                Label(status.capitalized, systemImage: statusIcon(for: status))
                    .font(.caption)
                    .foregroundStyle(statusColor(for: status))
            } else {
                Text("No symbols match filter")
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

            // Show computed font size for reference
            if let symbol = currentSymbol {
                let view = CalibratingIconView(
                    symbolName: symbol, displaySize: displaySize,
                    multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
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

            let total = deduplicator.canonicalSymbols.count
            let calibrated = store.calibratedCount
            let skipped = store.skippedCount
            let remaining = total - calibrated - skipped

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Total:")
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
            }
            .font(.caption)

            if total > 0 {
                ProgressView(value: Double(calibrated + skipped), total: Double(total))
            }
        }
    }

    private var keyboardShortcutsHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow { Text("←/→"); Text("Previous / Next symbol") }
                GridRow { Text("Space"); Text("Mark calibrated + advance") }
                GridRow { Text("Tab"); Text("Same as previous + advance") }
                GridRow { Text("Escape"); Text("Mark skipped + advance") }
                GridRow { Text("⌘↑/↓"); Text("Nudge multiplier ±0.001") }
                GridRow { Text("⇧←/→"); Text("Nudge X offset ±0.001") }
                GridRow { Text("⇧↑/↓"); Text("Nudge Y offset ±0.001") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Comparison Area

    private var comparisonArea: some View {
        VStack(spacing: 0) {
            if let symbol = currentSymbol {
                VStack(spacing: 12) {
                    Text(symbol)
                        .font(.title3.bold())

                    comparisonContent(for: symbol)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Picker("Mode", selection: $comparisonMode) {
                        ForEach(ComparisonMode.allCases, id: \.self) { mode in
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
                ContentUnavailableView("No Symbols", systemImage: "magnifyingglass",
                    description: Text("No symbols match the current filter"))
            }

            Divider()

            // Navigation bar
            HStack {
                Button(action: navigatePrevious) {
                    Image(systemName: "chevron.left")
                }
                .disabled(selectedIndex <= 0)

                Spacer()

                Text("\(selectedIndex + 1) / \(filteredSymbols.count)")
                    .font(.caption.monospacedDigit())

                Spacer()

                Button(action: navigateNext) {
                    Image(systemName: "chevron.right")
                }
                .disabled(selectedIndex >= filteredSymbols.count - 1)
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
        CalibratingIconView(
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
        guard selectedIndex < filteredSymbols.count - 1 else { return }
        saveCurrentValues()
        selectedIndex += 1
    }

    private func markCalibratedAndAdvance() {
        guard let symbol = currentSymbol else { return }
        let entry = ReferenceCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "calibrated"
        )
        store.setEntry(entry, for: symbol)

        if selectedIndex < filteredSymbols.count - 1 {
            selectedIndex += 1
        }
    }

    private func markSkippedAndAdvance() {
        guard let symbol = currentSymbol else { return }
        let entry = ReferenceCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "skipped"
        )
        store.setEntry(entry, for: symbol)

        if selectedIndex < filteredSymbols.count - 1 {
            selectedIndex += 1
        }
    }

    private func copyPreviousAndAdvance() {
        guard selectedIndex > 0, let symbol = currentSymbol else { return }
        let previousSymbol = filteredSymbols[selectedIndex - 1]
        if let previous = store.entry(for: previousSymbol) {
            multiplier = previous.multiplier
            xOffset = previous.xOffset
            yOffset = previous.yOffset
            weight = previous.weight == "medium" ? .medium : .regular
        }
        let entry = ReferenceCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: "calibrated"
        )
        store.setEntry(entry, for: symbol)

        if selectedIndex < filteredSymbols.count - 1 {
            selectedIndex += 1
        }
    }

    // MARK: - Load / Save

    private func loadCurrentSymbol() {
        guard let symbol = currentSymbol else {
            referenceImage = nil
            return
        }

        // Load saved values or defaults
        if let existing = store.entry(for: symbol) {
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

        // Load reference image
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

            // Prefetch next few
            let list = filteredSymbols
            let nextStart = selectedIndex + 1
            let nextEnd = min(nextStart + 3, list.count)
            if nextStart < nextEnd {
                service.prefetch(Array(list[nextStart..<nextEnd]))
            }
        }
    }

    private func saveCurrentValues() {
        guard let symbol = currentSymbol else { return }
        let existingStatus = store.entry(for: symbol)?.status ?? "needs-review"
        let entry = ReferenceCalibrationEntry(
            multiplier: multiplier, xOffset: xOffset, yOffset: yOffset,
            weight: weight == .medium ? "medium" : "regular",
            status: existingStatus
        )
        store.setEntry(entry, for: symbol)
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
    AppleReferenceCalibrationPlayground()
        .frame(width: 1100, height: 700)
}
