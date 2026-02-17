// MetricsSizingPlayground.swift
//
// Compares auto-sizing derived from symbol_metrics.json against Apple's
// ground-truth reference icons (generated via .appex manipulation).
// The goal: determine if intrinsic symbol dimensions can replace
// hand-tuned per-symbol multipliers from container_recipes.plist.

import SwiftUI

// MARK: - Metrics-Based Sizing

/// Loads symbol_metrics.json and computes sizing multipliers from intrinsic dimensions.
@Observable
class MetricsSizingService {
    private(set) var metrics: SymbolMetricsFile?
    private(set) var isLoaded = false
    private(set) var errorMessage: String?

    /// Tunable: what fraction of the enclosure the symbol's largest dimension should fill.
    var targetFillFraction: Double = 0.58

    func load() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = appSupport
            .appendingPathComponent("Icon Generator", isDirectory: true)
            .appendingPathComponent("symbol_metrics.json")

        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "symbol_metrics.json not found. Run Generate Symbol Metrics first."
            return
        }

        do {
            let data = try Data(contentsOf: url)
            metrics = try JSONDecoder().decode(SymbolMetricsFile.self, from: data)
            isLoaded = true
        } catch {
            errorMessage = "Failed to load metrics: \(error.localizedDescription)"
        }
    }

    /// Compute the multiplier for a symbol based on its intrinsic metrics.
    /// Formula: multiplier = targetFillFraction * referencePointSize / max(width, height)
    func multiplier(for symbol: String) -> CGFloat? {
        guard let file = metrics, let m = file.symbols[symbol] else { return nil }
        let maxDim = max(m.width, m.height)
        guard maxDim > 0 else { return nil }
        return targetFillFraction * file.referencePointSize / maxDim
    }

    /// Returns the raw metrics for a symbol.
    func symbolMetrics(for symbol: String) -> SymbolMetrics? {
        metrics?.symbols[symbol]
    }
}

// MARK: - Metrics Icon View

/// Renders an icon using the metrics-derived multiplier.
private struct MetricsIconView: View {
    let symbolName: String
    let displaySize: CGFloat
    let multiplier: CGFloat

    private let baseSize: CGFloat = 256
    private let baseBackgroundInset: CGFloat = 25
    private let baseCornerRadiusLG: CGFloat = 53

    private var scale: CGFloat { displaySize / baseSize }
    private var backgroundInset: CGFloat { baseBackgroundInset * scale }
    private var cornerRadius: CGFloat { baseCornerRadiusLG * scale }
    var enclosureSize: CGFloat { displaySize - (2 * backgroundInset) }

    private var fontSize: CGFloat { enclosureSize * multiplier }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.blue.gradient)
                .padding(backgroundInset)

            Image(systemName: symbolName)
                .font(.system(size: fontSize, weight: .regular))
                .foregroundColor(.white)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

/// Tinted symbol-only overlay for comparison.
private struct MetricsSymbolOverlay: View {
    let symbolName: String
    let displaySize: CGFloat
    let multiplier: CGFloat

    private let baseSize: CGFloat = 256
    private let baseBackgroundInset: CGFloat = 25

    private var scale: CGFloat { displaySize / baseSize }
    private var backgroundInset: CGFloat { baseBackgroundInset * scale }
    var enclosureSize: CGFloat { displaySize - (2 * backgroundInset) }
    private var fontSize: CGFloat { enclosureSize * multiplier }

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: fontSize, weight: .regular))
            .foregroundColor(.red)
            .frame(width: displaySize, height: displaySize)
    }
}

// MARK: - Comparison Mode

private enum MetricsComparisonMode: String, CaseIterable {
    case overlay = "Overlay"
    case tintedOverlay = "Tinted Overlay"
    case sideBySide = "Side by Side"
    case difference = "Difference"
}

// MARK: - Main Playground

struct MetricsSizingPlayground: View {
    @State private var sizingService = MetricsSizingService()
    @State private var referenceService = AppexReferenceService()

    @State private var allSymbols: [String] = []
    @State private var selectedIndex = 0
    @State private var searchText = ""
    @State private var comparisonMode: MetricsComparisonMode = .sideBySide
    @State private var overlayOpacity = 0.5

    @State private var referenceImage: NSImage?
    @State private var isLoadingReference = false
    @State private var loadError: String?

    private let displaySize: CGFloat = 512

    init() {
        let symbols = Self.loadSymbols()
        _allSymbols = State(initialValue: symbols)
    }

    private static func loadSymbols() -> [String] {
        guard let url = Bundle.main.url(forResource: "sf_symbols", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    // MARK: - Filtered List

    private var filteredSymbols: [String] {
        var list = allSymbols
        if !searchText.isEmpty {
            list = list.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
        // Only show symbols that have metrics data
        list = list.filter { sizingService.symbolMetrics(for: $0) != nil }
        return list
    }

    private var currentSymbol: String? {
        let list = filteredSymbols
        guard list.indices.contains(selectedIndex) else { return nil }
        return list[selectedIndex]
    }

    private var currentMultiplier: CGFloat? {
        guard let symbol = currentSymbol else { return nil }
        return sizingService.multiplier(for: symbol)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if sizingService.isLoaded {
                mainContent
            } else if let error = sizingService.errorMessage {
                ContentUnavailableView("Metrics Not Available", systemImage: "exclamationmark.triangle",
                    description: Text(error))
            } else {
                ProgressView("Loading metrics...")
            }
        }
        .onAppear {
            sizingService.load()
            if sizingService.isLoaded {
                loadCurrentSymbol()
            }
        }
        .onChange(of: sizingService.isLoaded) { _, loaded in
            if loaded { loadCurrentSymbol() }
        }
        .focusable()
        .onKeyPress(phases: .down) { press in handleKeyPress(press) }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let hasCommand = press.modifiers.contains(.command)

        switch press.key {
        case .leftArrow:
            navigatePrevious(); return .handled
        case .rightArrow:
            navigateNext(); return .handled
        case .upArrow where hasCommand:
            sizingService.targetFillFraction = min(1.0, sizingService.targetFillFraction + 0.01)
            return .handled
        case .downArrow where hasCommand:
            sizingService.targetFillFraction = max(0.1, sizingService.targetFillFraction - 0.01)
            return .handled
        default:
            return .ignored
        }
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            controlsSidebar
                .frame(width: 460)

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
                searchSection
                Divider()
                symbolInfoSection
                Divider()
                sizingParametersSection
                Divider()
                metricsDetailSection
                Divider()
                keyboardShortcutsSection
            }
            .padding()
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search")
                .font(.headline)

            TextField("Filter symbols...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in
                    selectedIndex = 0
                    loadCurrentSymbol()
                }

            Text("\(filteredSymbols.count) symbols with metrics")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var symbolInfoSection: some View {
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
            } else {
                Text("No symbols match filter")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sizingParametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sizing Parameters")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Target Fill Fraction")
                    Spacer()
                    Text(String(format: "%.2f", sizingService.targetFillFraction))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $sizingService.targetFillFraction, in: 0.2...1.0, step: 0.01)
                Text("How much of the enclosure the symbol's largest dimension should fill.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let mult = currentMultiplier {
                HStack {
                    Text("Computed Multiplier")
                    Spacer()
                    Text(String(format: "%.4f", mult))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.blue)
                }

                let enclosure = displaySize - (2 * 25 * displaySize / 256)
                Text("Font size: \(String(format: "%.1f", enclosure * mult)) pt (enclosure: \(String(format: "%.1f", enclosure)) pt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metricsDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Symbol Metrics (at 100pt)")
                .font(.headline)

            if let symbol = currentSymbol, let m = sizingService.symbolMetrics(for: symbol) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Text("Width:")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f", m.width))
                            .monospacedDigit()
                    }
                    GridRow {
                        Text("Height:")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f", m.height))
                            .monospacedDigit()
                    }
                    GridRow {
                        Text("Aspect Ratio:")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.3f", m.aspectRatio))
                            .monospacedDigit()
                    }
                    GridRow {
                        Text("Max Dim:")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f", max(m.width, m.height)))
                            .monospacedDigit()
                    }
                }
                .font(.caption)
            } else {
                Text("No metrics available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow { Text("Left/Right"); Text("Previous / Next symbol") }
                GridRow { Text("Cmd+Up/Down"); Text("Nudge fill fraction +/- 0.01") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Comparison Area

    private var comparisonArea: some View {
        VStack(spacing: 0) {
            if let symbol = currentSymbol, let mult = currentMultiplier {
                VStack(spacing: 12) {
                    Text(symbol)
                        .font(.title3.bold())

                    comparisonContent(for: symbol, multiplier: mult)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Picker("Mode", selection: $comparisonMode) {
                        ForEach(MetricsComparisonMode.allCases, id: \.self) { mode in
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

                    if let error = loadError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            } else {
                ContentUnavailableView("No Symbol Selected", systemImage: "magnifyingglass",
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
    private func comparisonContent(for symbol: String, multiplier: CGFloat) -> some View {
        switch comparisonMode {
        case .overlay:
            overlayView(for: symbol, multiplier: multiplier, tinted: false)
        case .tintedOverlay:
            overlayView(for: symbol, multiplier: multiplier, tinted: true)
        case .sideBySide:
            sideBySideView(for: symbol, multiplier: multiplier)
        case .difference:
            differenceView(for: symbol, multiplier: multiplier)
        }
    }

    private func overlayView(for symbol: String, multiplier: CGFloat, tinted: Bool) -> some View {
        ZStack {
            referenceImageView
            if tinted {
                MetricsSymbolOverlay(symbolName: symbol, displaySize: displaySize, multiplier: multiplier)
                    .opacity(overlayOpacity)
            } else {
                MetricsIconView(symbolName: symbol, displaySize: displaySize, multiplier: multiplier)
                    .opacity(overlayOpacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4, y: 2)
    }

    private func sideBySideView(for symbol: String, multiplier: CGFloat) -> some View {
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
                MetricsIconView(symbolName: symbol, displaySize: displaySize, multiplier: multiplier)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4, y: 2)
                Text("Metrics-Based")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func differenceView(for symbol: String, multiplier: CGFloat) -> some View {
        ZStack {
            referenceImageView
            MetricsIconView(symbolName: symbol, displaySize: displaySize, multiplier: multiplier)
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

    // MARK: - Navigation

    private func navigatePrevious() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
        loadCurrentSymbol()
    }

    private func navigateNext() {
        guard selectedIndex < filteredSymbols.count - 1 else { return }
        selectedIndex += 1
        loadCurrentSymbol()
    }

    // MARK: - Loading

    private func loadCurrentSymbol() {
        guard let symbol = currentSymbol else {
            referenceImage = nil
            return
        }

        isLoadingReference = true
        loadError = nil
        referenceImage = nil

        Task {
            do {
                let image = try await referenceService.referenceIcon(for: symbol)
                await MainActor.run {
                    referenceImage = image
                    isLoadingReference = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoadingReference = false
                }
            }

            // Prefetch next few
            let list = filteredSymbols
            let nextStart = selectedIndex + 1
            let nextEnd = min(nextStart + 3, list.count)
            if nextStart < nextEnd {
                referenceService.prefetch(Array(list[nextStart..<nextEnd]))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MetricsSizingPlayground()
        .frame(width: 1100, height: 700)
}
