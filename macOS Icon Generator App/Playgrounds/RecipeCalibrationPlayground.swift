//
//  RecipeCalibrationPlayground.swift
//  macOS Icon Generator App
//
//  Calibration playground for tuning recipeScaleFactor and offsets
//  by comparing our rendered icons against Apple's reference icons.
//  Uses AppexReferenceService for dynamic Apple ground-truth references.
//

import SwiftUI

// MARK: - Calibration Icon View
/// Replicates IconContentView's sizing math with adjustable parameters.
struct CalibrationIconView: View {
    let symbolName: String
    let displaySize: CGFloat
    let recipeScaleFactor: CGFloat
    let xOffsetAdjust: CGFloat
    let yOffsetAdjust: CGFloat
    let symbolOnly: Bool
    /// Override for recipe lookup when the plist uses a different key than the SF Symbol name.
    var recipeName: String?
    /// When true, uses glyph-metrics-predicted multiplier as fallback instead of flat 0.607.
    var useGlyphMetricsFallback: Bool = false

    private let baseSize: CGFloat = 256
    private let baseCornerRadius: CGFloat = 53
    private let baseBackgroundInset: CGFloat = 25

    private var scale: CGFloat { displaySize / baseSize }
    private var backgroundInset: CGFloat { baseBackgroundInset * scale }
    private var cornerRadius: CGFloat { baseCornerRadius * scale }
    var enclosureSize: CGFloat { displaySize - (2 * backgroundInset) }

    private var recipe: SymbolRecipe? {
        SymbolRecipeService.recipe(for: recipeName ?? symbolName)
    }

    /// The predicted multiplier from glyph metrics, if available.
    var glyphMetricsMul: Double? {
        GlyphMetricsService.predictedMultiplier(for: symbolName)
    }

    var computedSymbolSize: CGFloat {
        if let recipe {
            return enclosureSize * recipe.pointsizeToShapeMul * recipeScaleFactor
        }
        if useGlyphMetricsFallback, let predicted = glyphMetricsMul {
            return enclosureSize * predicted * recipeScaleFactor
        }
        return enclosureSize * 0.607
    }

    private var symbolWeight: Font.Weight {
        recipe?.symbolWeight ?? .regular
    }

    private var totalXOffset: CGFloat {
        guard let recipe else { return xOffsetAdjust }
        return enclosureSize * recipe.xOffset + xOffsetAdjust
    }

    private var totalYOffset: CGFloat {
        guard let recipe else { return yOffsetAdjust }
        return enclosureSize * recipe.yOffset + yOffsetAdjust
    }

    var body: some View {
        ZStack {
            if !symbolOnly {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.blue.gradient)
                    .padding(backgroundInset)
            }

            Image(systemName: symbolName)
                .font(.system(size: computedSymbolSize, weight: symbolWeight))
                .foregroundColor(symbolOnly ? .red : .white)
                .offset(x: totalXOffset, y: totalYOffset)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

// MARK: - Comparison & Filter Modes

private enum RecipeComparisonMode: String, CaseIterable {
    case overlay = "Overlay"
    case tintedOverlay = "Tinted Overlay"
    case sideBySide = "Side by Side"
    case difference = "Difference"
    case gallery = "Gallery"
}

private enum RecipeFilterMode: String, CaseIterable {
    case all = "All"
    case hasRecipe = "Has Recipe"
    case noRecipe = "No Recipe"
}

// MARK: - Main Playground View
struct RecipeCalibrationPlayground: View {
    @State private var service = AppexReferenceService()

    /// All SF Symbols sorted, with recipe symbols first
    @State private var allSymbols: [String] = []
    @State private var recipeSymbolSet: Set<String> = []

    @State private var selectedIndex = 0
    @State private var scaleFactor = 0.39
    @State private var xOffsetAdjust = 0.0
    @State private var yOffsetAdjust = 0.0
    @State private var comparisonMode: RecipeComparisonMode = .overlay
    @State private var overlayOpacity = 0.5
    @State private var filterMode: RecipeFilterMode = .hasRecipe
    @State private var searchText = ""
    @State private var useGlyphMetricsFallback = false
    @State private var referenceImage: NSImage?
    @State private var isLoadingReference = false
    @State private var errorMessage: String?
    @State private var galleryThumbSize: CGFloat = 96
    @State private var galleryTintOverlay = false
    @State private var galleryReferenceImages: [String: NSImage] = [:]
    @State private var galleryLoadingSymbols: Set<String> = []
    @State private var galleryLoadTask: Task<Void, Never>?

    private let displaySize: CGFloat = 512

    init() {
        let recipeNames = Set(SymbolRecipeService.allSymbolNames)

        // Load all SF Symbols from sf_symbols.txt
        let allNames: [String]
        if let url = Bundle.main.url(forResource: "sf_symbols", withExtension: "txt"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            allNames = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        } else {
            allNames = Array(recipeNames).sorted()
        }

        // Sort: recipe symbols first (alphabetical), then non-recipe (alphabetical)
        let sorted = allNames.sorted { a, b in
            let aHas = recipeNames.contains(a)
            let bHas = recipeNames.contains(b)
            if aHas != bHas { return aHas }
            return a < b
        }

        _allSymbols = State(initialValue: sorted)
        _recipeSymbolSet = State(initialValue: recipeNames)
    }

    // MARK: - Filtered Symbols

    private var filteredSymbols: [String] {
        var list = allSymbols

        switch filterMode {
        case .all: break
        case .hasRecipe:
            list = list.filter { recipeSymbolSet.contains($0) }
        case .noRecipe:
            list = list.filter { !recipeSymbolSet.contains($0) }
        }

        if !searchText.isEmpty {
            list = list.filter { $0.localizedCaseInsensitiveContains(searchText) }
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
        Group {
            if allSymbols.isEmpty {
                ContentUnavailableView("No Symbols", systemImage: "exclamationmark.triangle",
                    description: Text("sf_symbols.txt not found and no recipes loaded."))
            } else {
                mainContent
            }
        }
        .onAppear { loadReferenceImage() }
        .onChange(of: selectedIndex) { _, _ in loadReferenceImage() }
        .focusable()
        .onKeyPress(.leftArrow) { navigatePrevious(); return .handled }
        .onKeyPress(.rightArrow) { navigateNext(); return .handled }
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
                if comparisonMode != .gallery {
                    Divider()
                    fallbackSizingToggle
                    Divider()
                    parameterSliders
                }
                Divider()
                recipeInfoPanel
            }
            .padding()
        }
    }

    private var searchAndFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search")
                .font(.headline)

            TextField("Filter by symbol name...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in
                    selectedIndex = 0
                    loadReferenceImage()
                }

            Picker("Filter", selection: $filterMode) {
                ForEach(RecipeFilterMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: filterMode) { _, _ in
                selectedIndex = 0
                loadReferenceImage()
            }

            HStack {
                Text("\(filteredSymbols.count) symbols")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(recipeSymbolSet.count) have recipes")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
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
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if recipeSymbolSet.contains(symbol) {
                        Text("Has Recipe")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    } else {
                        Text("No Recipe")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Text("No symbols match filter")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Fallback Sizing Toggle

    private var fallbackSizingToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No-Recipe Fallback")
                .font(.headline)

            Toggle("Use glyph metrics (F3)", isOn: $useGlyphMetricsFallback)
                .help("Use predicted multiplier from Assets.car glyph metrics instead of flat 0.607 default")

            Text(useGlyphMetricsFallback
                ? "Fallback: mul = 1.773 \u{2212} 0.364\u{00B7}hRatio + 0.210\u{00B7}aspect"
                : "Fallback: flat 0.607 multiplier")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label("Recipe", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Label("F3 Metrics", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Label("Flat Default", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
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
                    scaleFactor = 0.39
                    xOffsetAdjust = 0
                    yOffsetAdjust = 0
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Scale Factor")
                    Spacer()
                    Text(String(format: "%.4f", scaleFactor))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $scaleFactor, in: 0.25...0.55, step: 0.001)

                Text("Production value: 0.39")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("X Offset Adjust")
                    Spacer()
                    Text(String(format: "%+.1f pt", xOffsetAdjust))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $xOffsetAdjust, in: -10...10, step: 0.5)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Y Offset Adjust")
                    Spacer()
                    Text(String(format: "%+.1f pt", yOffsetAdjust))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $yOffsetAdjust, in: -10...10, step: 0.5)
            }

            if let symbol = currentSymbol {
                let icon = CalibrationIconView(
                    symbolName: symbol, displaySize: displaySize,
                    recipeScaleFactor: scaleFactor,
                    xOffsetAdjust: xOffsetAdjust, yOffsetAdjust: yOffsetAdjust,
                    symbolOnly: false, useGlyphMetricsFallback: useGlyphMetricsFallback
                )
                Text("Font size: \(String(format: "%.1f", icon.computedSymbolSize)) pt (enclosure: \(String(format: "%.1f", icon.enclosureSize)) pt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Recipe Info

    private var recipeInfoPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recipe Info")
                .font(.headline)

            if let symbol = currentSymbol {
                let recipe = SymbolRecipeService.recipe(for: symbol)
                let icon = CalibrationIconView(
                    symbolName: symbol, displaySize: displaySize,
                    recipeScaleFactor: scaleFactor,
                    xOffsetAdjust: xOffsetAdjust, yOffsetAdjust: yOffsetAdjust,
                    symbolOnly: false, useGlyphMetricsFallback: useGlyphMetricsFallback
                )

                if let recipe {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                        GridRow {
                            Text("Multiplier:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.6f", recipe.pointsizeToShapeMul))
                                .monospacedDigit()
                        }
                        GridRow {
                            Text("Weight:")
                                .foregroundStyle(.secondary)
                            Text(recipe.symbolWeight == .medium ? "Medium" : "Regular")
                        }
                        GridRow {
                            Text("X Offset:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.4f", recipe.xOffset))
                                .monospacedDigit()
                        }
                        GridRow {
                            Text("Y Offset:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.4f", recipe.yOffset))
                                .monospacedDigit()
                        }
                        Divider()
                            .gridCellUnsizedAxes(.horizontal)
                        GridRow {
                            Text("Enclosure:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f pt", icon.enclosureSize))
                                .monospacedDigit()
                        }
                        GridRow {
                            Text("Font Size:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f pt", icon.computedSymbolSize))
                                .monospacedDigit()
                        }
                    }
                    .font(.caption)
                } else {
                    if let predicted = icon.glyphMetricsMul {
                        if useGlyphMetricsFallback {
                            Text("Using glyph metrics fallback (F3)")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else {
                            Text("No recipe — using flat 0.607 (F3 available: \(String(format: "%.4f", predicted)))")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("No recipe found — using default 0.607 multiplier")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                        if let predicted = icon.glyphMetricsMul {
                            GridRow {
                                Text("F3 Multiplier:")
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.6f", predicted))
                                    .monospacedDigit()
                                    .foregroundStyle(useGlyphMetricsFallback ? .blue : .secondary)
                            }
                            GridRow {
                                Text("Effective:")
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.4f (mul \u{00D7} %.2f)",
                                            predicted * scaleFactor, scaleFactor))
                                    .monospacedDigit()
                                    .foregroundStyle(useGlyphMetricsFallback ? .blue : .secondary)
                            }
                        }
                        GridRow {
                            Text("Flat Default:")
                                .foregroundStyle(.secondary)
                            Text("0.6070")
                                .monospacedDigit()
                                .foregroundStyle(!useGlyphMetricsFallback ? .primary : .secondary)
                        }
                        Divider()
                            .gridCellUnsizedAxes(.horizontal)
                        GridRow {
                            Text("Enclosure:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f pt", icon.enclosureSize))
                                .monospacedDigit()
                        }
                        GridRow {
                            Text("Font Size:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f pt", icon.computedSymbolSize))
                                .monospacedDigit()
                        }
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Comparison Area

    private var comparisonArea: some View {
        VStack(spacing: 0) {
            if comparisonMode == .gallery {
                galleryView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let symbol = currentSymbol {
                VStack(spacing: 12) {
                    HStack {
                        Text(symbol)
                            .font(.title3.bold().monospaced())
                        if recipeSymbolSet.contains(symbol) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .help("Has container_recipes.plist entry")
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
                ContentUnavailableView("No Symbols", systemImage: "magnifyingglass",
                    description: Text("No symbols match the current filter"))
            }

            Divider()

            // Mode picker + navigation
            VStack(spacing: 8) {
                Picker("Mode", selection: $comparisonMode) {
                    ForEach(RecipeComparisonMode.allCases, id: \.self) { mode in
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

                if comparisonMode != .gallery {
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

    private var galleryView: some View {
        let symbols = filteredSymbols
        let columns = [GridItem(.adaptive(minimum: galleryThumbSize + 8), spacing: 8)]

        return VStack(spacing: 0) {
            ScrollView {
                if galleryTintOverlay && !galleryLoadingSymbols.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading references: \(symbols.count - galleryLoadingSymbols.count)/\(symbols.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(symbols.enumerated()), id: \.element) { idx, symbol in
                        VStack(spacing: 2) {
                            galleryThumbView(for: symbol, size: galleryThumbSize)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay {
                                    if idx == selectedIndex {
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(.blue, lineWidth: 2)
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    if recipeSymbolSet.contains(symbol) {
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 6, height: 6)
                                            .offset(x: -2, y: 2)
                                    }
                                }

                            Text(symbol)
                                .font(.system(size: max(8, galleryThumbSize * 0.08)).monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(width: galleryThumbSize)
                        }
                        .onTapGesture {
                            selectedIndex = idx
                            comparisonMode = .overlay
                        }
                    }
                }
                .padding(8)
            }

            Divider()

            HStack(spacing: 16) {
                Toggle("Tint Overlay", isOn: $galleryTintOverlay)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: galleryTintOverlay) { _, newValue in
                        if newValue {
                            loadGalleryReferences(for: symbols)
                        } else {
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

    @ViewBuilder
    private func galleryThumbView(for symbol: String, size: CGFloat) -> some View {
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
                CalibrationIconView(
                    symbolName: symbol, displaySize: size,
                    recipeScaleFactor: scaleFactor,
                    xOffsetAdjust: 0, yOffsetAdjust: 0,
                    symbolOnly: true,
                    useGlyphMetricsFallback: useGlyphMetricsFallback
                )
                .opacity(overlayOpacity)
            }
        } else {
            CalibrationIconView(
                symbolName: symbol, displaySize: size,
                recipeScaleFactor: scaleFactor,
                xOffsetAdjust: 0, yOffsetAdjust: 0,
                symbolOnly: false,
                useGlyphMetricsFallback: useGlyphMetricsFallback
            )
        }
    }

    // MARK: - Reference Image / Our Icon

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
        CalibrationIconView(
            symbolName: symbol,
            displaySize: displaySize,
            recipeScaleFactor: scaleFactor,
            xOffsetAdjust: xOffsetAdjust,
            yOffsetAdjust: yOffsetAdjust,
            symbolOnly: symbolOnly,
            useGlyphMetricsFallback: useGlyphMetricsFallback
        )
    }

    // MARK: - Reference Loading

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

            // Prefetch next few
            let list = filteredSymbols
            let nextStart = selectedIndex + 1
            let nextEnd = min(nextStart + 3, list.count)
            if nextStart < nextEnd {
                let names = Array(list[nextStart..<nextEnd])
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

    // MARK: - Navigation

    private func navigatePrevious() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    private func navigateNext() {
        guard selectedIndex < filteredSymbols.count - 1 else { return }
        selectedIndex += 1
    }
}

// MARK: - Preview
#Preview {
    RecipeCalibrationPlayground()
        .frame(minWidth: 1000, minHeight: 700)
}
