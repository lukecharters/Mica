// ResizableSizingPlayground.swift
//
// Tests the hypothesis that .resizable().scaledToFit().frame() can produce
// more accurate SF Symbol sizing than .font(.system(size:)) by computing
// exact glyph frame sizes from container_recipes.plist multipliers and
// intrinsic dimensions from symbol_metrics.json.
//
// The key insight: .resizable() strips all built-in font metric padding,
// letting us set the visual bounding box directly — bypassing the
// approximate recipeScaleFactor = 0.39 correction.

import SwiftUI

// MARK: - Sizing Method

private enum SizingMethod: String, CaseIterable {
    case resizable = "Resizable"
    case fontRecipe = "Font (Recipe)"
    case fontDimCal = "Font (Dim-Cal)"
}

// MARK: - Comparison Mode

private enum ResizableComparisonMode: String, CaseIterable {
    case sideBySide = "Side by Side"
    case overlay = "Overlay"
    case tintedOverlay = "Tinted Overlay"
    case tripleCompare = "Triple Compare"
}

// MARK: - Resizable Icon View

/// Renders an SF Symbol using .resizable().scaledToFit().frame() with dimensions
/// computed from recipe multiplier × intrinsic metrics.
private struct ResizableIconView: View {
    let symbolName: String
    let displaySize: CGFloat
    let frameWidth: CGFloat
    let frameHeight: CGFloat
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
                .frame(width: frameWidth, height: frameHeight)
                .foregroundColor(symbolOnly ? .red : .white)
                .offset(x: xOffset, y: yOffset)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

// MARK: - Font-Based Icon View (for comparison)

/// Renders using the traditional .font(.system(size:)) approach.
private struct FontIconView: View {
    let symbolName: String
    let displaySize: CGFloat
    let fontSize: CGFloat
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
                .offset(x: xOffset, y: yOffset)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

// MARK: - Main Playground

struct ResizableSizingPlayground: View {
    @State private var referenceService = AppexReferenceService()

    // Symbol data
    @State private var allSymbols: [String] = []
    @State private var symbolMetrics: [String: SymbolMetrics] = [:]
    @State private var dimCalStore = DimCalibrationStore()

    // Navigation
    @State private var selectedIndex = 0
    @State private var searchText = ""
    @State private var filterHasRecipe = false

    // Display
    @State private var comparisonMode: ResizableComparisonMode = .tripleCompare
    @State private var overlayOpacity = 0.5
    @State private var referenceImage: NSImage?
    @State private var isLoadingReference = false
    @State private var errorMessage: String?

    // Tuning
    @State private var resizableScale: Double = 1.0  // Fine-tune multiplier for resizable approach

    private let displaySize: CGFloat = 512
    private let recipeScaleFactor: CGFloat = 0.39

    init() {
        let (symbols, metrics) = Self.loadData()
        _allSymbols = State(initialValue: symbols)
        _symbolMetrics = State(initialValue: metrics)
    }

    private static func loadData() -> ([String], [String: SymbolMetrics]) {
        // Load symbol list
        let symbols: [String] = {
            guard let url = Bundle.main.url(forResource: "sf_symbols", withExtension: "txt"),
                  let contents = try? String(contentsOf: url, encoding: .utf8)
            else { return [] }
            return contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        }()

        // Load intrinsic dimensions
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let metricsURL = appSupport
            .appendingPathComponent("Icon Generator", isDirectory: true)
            .appendingPathComponent("symbol_metrics.json")

        let metrics: [String: SymbolMetrics] = {
            guard let data = try? Data(contentsOf: metricsURL),
                  let file = try? JSONDecoder().decode(SymbolMetricsFile.self, from: data)
            else { return [:] }
            return file.symbols
        }()

        return (symbols, metrics)
    }

    // MARK: - Computed Properties

    private var enclosureSize: CGFloat {
        let baseSize: CGFloat = 256
        let baseBackgroundInset: CGFloat = 25
        let scale = displaySize / baseSize
        let backgroundInset = baseBackgroundInset * scale
        return displaySize - (2 * backgroundInset)
    }

    private var filteredSymbols: [String] {
        var list = allSymbols
        if !searchText.isEmpty {
            list = list.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
        // Must have metrics for the resizable approach
        list = list.filter { symbolMetrics[$0] != nil }
        if filterHasRecipe {
            list = list.filter { SymbolRecipeService.recipe(for: $0) != nil }
        }
        return list
    }

    private var currentSymbol: String? {
        let list = filteredSymbols
        guard list.indices.contains(selectedIndex) else { return nil }
        return list[selectedIndex]
    }

    /// Recipe from container_recipes.plist (if available)
    private func recipe(for symbol: String) -> SymbolRecipe? {
        SymbolRecipeService.recipe(for: symbol)
    }

    /// Metrics from symbol_metrics.json
    private func metrics(for symbol: String) -> SymbolMetrics? {
        symbolMetrics[symbol]
    }

    /// Dim-calibration entry (if available)
    private func dimCalEntry(for symbol: String) -> DimCalibrationEntry? {
        guard let m = metrics(for: symbol) else { return nil }
        let dimKey = String(format: "%.4f_%.4f", m.width, m.height)
        return dimCalStore.entry(for: dimKey)
    }

    // MARK: - Frame Size Computation (The Core Hypothesis)

    /// Computes the resizable frame size from recipe multiplier + intrinsic dimensions.
    private func resizableFrameSize(for symbol: String) -> (width: CGFloat, height: CGFloat)? {
        guard let m = metrics(for: symbol) else { return nil }

        // Try recipe first, then dim-cal, then glyph metrics fallback
        let mul: Double
        if let recipe = recipe(for: symbol) {
            mul = recipe.pointsizeToShapeMul
        } else if let dimCal = dimCalEntry(for: symbol) {
            // dim-cal multipliers are already in the "font approach" coordinate space
            // (they were calibrated using .font(.system(size: enclosure * mul)))
            // We need to reverse-engineer what the equivalent recipe mul would be
            // dim-cal mul goes through .font() → visual size
            // We need to convert to the private pipeline's coordinate space
            // Since dimCal.multiplier ≈ recipe.mul * recipeScaleFactor (0.39),
            // the equivalent recipe mul ≈ dimCal.multiplier / 0.39
            mul = dimCal.multiplier / recipeScaleFactor
        } else if let glyphMul = GlyphMetricsService.predictedMultiplier(for: symbol) {
            mul = glyphMul
        } else {
            return nil
        }

        // Core formula: what font size the private pipeline uses
        let fontSize = enclosureSize * CGFloat(mul)
        // Scale intrinsic dimensions to that font size
        let scale = CGFloat(resizableScale)
        let frameW = CGFloat(m.width) * fontSize / 100.0 * scale
        let frameH = CGFloat(m.height) * fontSize / 100.0 * scale
        return (frameW, frameH)
    }

    /// Offsets for the current symbol
    private func offsets(for symbol: String) -> (x: CGFloat, y: CGFloat) {
        if let recipe = recipe(for: symbol) {
            return (enclosureSize * recipe.xOffset, enclosureSize * recipe.yOffset)
        }
        if let dimCal = dimCalEntry(for: symbol) {
            return (enclosureSize * dimCal.xOffset, enclosureSize * dimCal.yOffset)
        }
        return (0, 0)
    }

    /// Font weight for the current symbol
    private func fontWeight(for symbol: String) -> Font.Weight {
        if let recipe = recipe(for: symbol) {
            return recipe.symbolWeight
        }
        if let dimCal = dimCalEntry(for: symbol) {
            return dimCal.weight == "medium" ? .medium : .regular
        }
        return .regular
    }

    /// Font size for the recipe-based .font() approach
    private func recipeFontSize(for symbol: String) -> CGFloat? {
        guard let recipe = recipe(for: symbol) else { return nil }
        return enclosureSize * recipe.pointsizeToShapeMul * recipeScaleFactor
    }

    /// Font size for the dim-cal-based .font() approach
    private func dimCalFontSize(for symbol: String) -> CGFloat? {
        guard let dimCal = dimCalEntry(for: symbol) else { return nil }
        return enclosureSize * dimCal.multiplier
    }

    // MARK: - Body

    var body: some View {
        Group {
            if symbolMetrics.isEmpty {
                ContentUnavailableView("Metrics Not Available", systemImage: "exclamationmark.triangle",
                    description: Text("symbol_metrics.json not found. Run Generate Symbol Metrics first."))
            } else {
                mainContent
            }
        }
        .onAppear { loadCurrentSymbol() }
        .onChange(of: selectedIndex) { _, _ in loadCurrentSymbol() }
        .focusable()
        .onKeyPress(phases: .down) { press in handleKeyPress(press) }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let hasCommand = press.modifiers.contains(.command)
        switch press.key {
        case .leftArrow: navigatePrevious(); return .handled
        case .rightArrow: navigateNext(); return .handled
        case .upArrow where hasCommand:
            resizableScale = min(2.0, resizableScale + 0.01); return .handled
        case .downArrow where hasCommand:
            resizableScale = max(0.1, resizableScale - 0.01); return .handled
        default: return .ignored
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
                searchSection
                Divider()
                symbolInfoSection
                Divider()
                computedValuesSection
                Divider()
                tuningSection
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

            Toggle("Only symbols with recipes", isOn: $filterHasRecipe)
                .onChange(of: filterHasRecipe) { _, _ in
                    selectedIndex = 0
                    loadCurrentSymbol()
                }

            Text("\(filteredSymbols.count) symbols")
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
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let m = metrics(for: symbol) {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                        GridRow {
                            Text("Intrinsic (100pt):")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f × %.1f", m.width, m.height))
                                .monospacedDigit()
                        }
                        GridRow {
                            Text("Aspect Ratio:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.3f", m.aspectRatio))
                                .monospacedDigit()
                        }
                    }
                    .font(.caption)
                }

                // Data source badges
                HStack(spacing: 8) {
                    if recipe(for: symbol) != nil {
                        Text("Recipe")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.2), in: Capsule())
                    }
                    if dimCalEntry(for: symbol) != nil {
                        Text("Dim-Cal")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.2), in: Capsule())
                    }
                    if GlyphMetricsService.predictedMultiplier(for: symbol) != nil {
                        Text("Glyph F3")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2), in: Capsule())
                    }
                }
            } else {
                Text("No symbols match filter")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var computedValuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Computed Values")
                .font(.headline)

            if let symbol = currentSymbol {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    // Resizable approach
                    if let frame = resizableFrameSize(for: symbol) {
                        GridRow {
                            Text("Resizable frame:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f × %.1f pt", frame.width, frame.height))
                                .monospacedDigit()
                                .foregroundStyle(.purple)
                        }
                    }

                    // Recipe font size
                    if let fontSize = recipeFontSize(for: symbol) {
                        GridRow {
                            Text("Font (Recipe):")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f pt", fontSize))
                                .monospacedDigit()
                                .foregroundStyle(.green)
                        }
                        if let r = recipe(for: symbol) {
                            GridRow {
                                Text("  recipe.mul:")
                                    .foregroundStyle(.tertiary)
                                Text(String(format: "%.4f", r.pointsizeToShapeMul))
                                    .monospacedDigit()
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    // Dim-cal font size
                    if let fontSize = dimCalFontSize(for: symbol) {
                        GridRow {
                            Text("Font (Dim-Cal):")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f pt", fontSize))
                                .monospacedDigit()
                                .foregroundStyle(.blue)
                        }
                        if let dc = dimCalEntry(for: symbol) {
                            GridRow {
                                Text("  dimCal.mul:")
                                    .foregroundStyle(.tertiary)
                                Text(String(format: "%.4f", dc.multiplier))
                                    .monospacedDigit()
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    // Offsets
                    let off = offsets(for: symbol)
                    if off.x != 0 || off.y != 0 {
                        GridRow {
                            Text("Offsets:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "x: %+.1f, y: %+.1f", off.x, off.y))
                                .monospacedDigit()
                        }
                    }

                    GridRow {
                        Text("Enclosure:")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f pt", enclosureSize))
                            .monospacedDigit()
                    }
                }
                .font(.caption)
            }
        }
    }

    private var tuningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resizable Scale Tuning")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Scale Factor")
                    Spacer()
                    Text(String(format: "%.3f", resizableScale))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $resizableScale, in: 0.1...1.0, step: 0.005)
                Text("Fine-tune the resizable frame scale. 1.0 = raw formula, adjust to match Apple's reference.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Button("Reset to 1.0") {
                resizableScale = 1.0
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow { Text("Left/Right"); Text("Previous / Next symbol") }
                GridRow { Text("Cmd+Up/Down"); Text("Nudge resizable scale +/- 0.01") }
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
                        .font(.title3.bold().monospaced())

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
                ContentUnavailableView("No Symbol Selected", systemImage: "magnifyingglass",
                    description: Text("No symbols match the current filter"))
            }

            Divider()

            // Mode picker + navigation
            VStack(spacing: 8) {
                Picker("Mode", selection: $comparisonMode) {
                    ForEach(ResizableComparisonMode.allCases, id: \.self) { mode in
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
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func comparisonContent(for symbol: String) -> some View {
        switch comparisonMode {
        case .sideBySide:
            sideBySideView(for: symbol)
        case .overlay:
            overlayView(for: symbol, tinted: false)
        case .tintedOverlay:
            overlayView(for: symbol, tinted: true)
        case .tripleCompare:
            tripleCompareView(for: symbol)
        }
    }

    /// Shows Apple reference + resizable side by side
    private func sideBySideView(for symbol: String) -> some View {
        HStack(spacing: 24) {
            VStack(spacing: 6) {
                referenceImageView()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4, y: 2)
                Text("Apple Reference")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                resizableIconView(for: symbol, symbolOnly: false)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4, y: 2)
                Text("Resizable")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
        }
    }

    /// Overlays resizable on top of Apple reference
    private func overlayView(for symbol: String, tinted: Bool) -> some View {
        ZStack {
            referenceImageView()
            resizableIconView(for: symbol, symbolOnly: tinted)
                .opacity(overlayOpacity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4, y: 2)
    }

    /// Shows all three approaches + Apple reference
    private func tripleCompareView(for symbol: String) -> some View {
        let thumbSize: CGFloat = min(displaySize * 0.65, 340)

        return ScrollView {
            HStack(spacing: 16) {
                // Apple Reference
                VStack(spacing: 6) {
                    referenceImageView(size: thumbSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4, y: 2)
                    Text("Apple Reference")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Resizable approach
                VStack(spacing: 6) {
                    resizableIconView(for: symbol, symbolOnly: false, size: thumbSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4, y: 2)
                    Text("Resizable")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    if let frame = resizableFrameSize(for: symbol) {
                        Text(String(format: "%.0f×%.0f", frame.width * thumbSize / displaySize, frame.height * thumbSize / displaySize))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }

                // Font (Recipe) approach
                VStack(spacing: 6) {
                    if let fontSize = recipeFontSize(for: symbol) {
                        fontIconView(for: symbol, fontSize: fontSize * thumbSize / displaySize, size: thumbSize)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 4, y: 2)
                        Text("Font (Recipe)")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text(String(format: "%.0fpt", fontSize * thumbSize / displaySize))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    } else {
                        placeholderView(size: thumbSize, label: "No Recipe")
                    }
                }

                // Font (Dim-Cal) approach
                VStack(spacing: 6) {
                    if let fontSize = dimCalFontSize(for: symbol) {
                        fontIconView(for: symbol, fontSize: fontSize * thumbSize / displaySize, size: thumbSize)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 4, y: 2)
                        Text("Font (Dim-Cal)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text(String(format: "%.0fpt", fontSize * thumbSize / displaySize))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    } else {
                        placeholderView(size: thumbSize, label: "No Dim-Cal")
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func placeholderView(size: CGFloat, label: String) -> some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    Text("N/A")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func resizableIconView(for symbol: String, symbolOnly: Bool, size: CGFloat? = nil) -> some View {
        let sz = size ?? displaySize
        if let frame = resizableFrameSize(for: symbol) {
            let scaledW = frame.width * sz / displaySize
            let scaledH = frame.height * sz / displaySize
            let off = offsets(for: symbol)
            let scaledOffX = off.x * sz / displaySize
            let scaledOffY = off.y * sz / displaySize

            ResizableIconView(
                symbolName: symbol,
                displaySize: sz,
                frameWidth: scaledW,
                frameHeight: scaledH,
                xOffset: scaledOffX,
                yOffset: scaledOffY,
                weight: fontWeight(for: symbol),
                symbolOnly: symbolOnly
            )
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: sz, height: sz)
                .overlay {
                    Text("No data")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func fontIconView(for symbol: String, fontSize: CGFloat, size: CGFloat) -> some View {
        let off = offsets(for: symbol)
        let scaledOffX = off.x * size / displaySize
        let scaledOffY = off.y * size / displaySize

        return FontIconView(
            symbolName: symbol,
            displaySize: size,
            fontSize: fontSize,
            xOffset: scaledOffX,
            yOffset: scaledOffY,
            weight: fontWeight(for: symbol),
            symbolOnly: false
        )
    }

    @ViewBuilder
    private func referenceImageView(size: CGFloat? = nil) -> some View {
        let sz = size ?? displaySize
        if isLoadingReference {
            ProgressView()
                .frame(width: sz, height: sz)
        } else if let image = referenceImage {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: sz, height: sz)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: sz, height: sz)
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
    }

    private func navigateNext() {
        guard selectedIndex < filteredSymbols.count - 1 else { return }
        selectedIndex += 1
    }

    // MARK: - Loading

    private func loadCurrentSymbol() {
        guard let symbol = currentSymbol else {
            referenceImage = nil
            return
        }

        isLoadingReference = true
        errorMessage = nil
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
                    errorMessage = error.localizedDescription
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
    ResizableSizingPlayground()
        .frame(width: 1400, height: 800)
}
