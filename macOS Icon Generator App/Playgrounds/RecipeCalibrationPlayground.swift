//
//  RecipeCalibrationPlayground.swift
//  macOS Icon Generator App
//
//  Calibration playground for tuning recipeScaleFactor and offsets
//  by comparing our rendered icons against Apple's reference icons.
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

// MARK: - Reference Symbol
/// Pairs an SF Symbol name with its CFBundle asset name.
/// `recipeName` overrides the recipe lookup when the plist uses a different key.
struct ReferenceSymbol: Identifiable {
    let id: String  // SF Symbol name
    let asset: String  // Asset catalog name
    let recipeName: String?  // Override for plist lookup (nil = use id)

    init(_ name: String, recipeName: String? = nil) {
        self.id = name
        self.asset = "CFBundle-\(name)"
        self.recipeName = recipeName
    }

    var effectiveRecipeName: String { recipeName ?? id }
    var recipe: SymbolRecipe? { SymbolRecipeService.recipe(for: effectiveRecipeName) }
    var hasRecipe: Bool { recipe != nil }
    var hasGlyphMetrics: Bool { GlyphMetricsService.predictedMultiplier(for: id) != nil }
}

// MARK: - Main Playground View
struct RecipeCalibrationPlayground: View {
    static let referenceSymbols: [ReferenceSymbol] = [
        ReferenceSymbol("gearshape.fill", recipeName: "gear"),
        ReferenceSymbol("square.fill"),
        ReferenceSymbol("square.and.arrow.up"),
        ReferenceSymbol("square.and.arrow.up.trianglebadge.exclamationmark"),
        ReferenceSymbol("folder.fill.badge.plus", recipeName: "folder.fill"),
        ReferenceSymbol("doc.text.magnifyingglass"),
        ReferenceSymbol("bell.and.waves.left.and.right.fill"),
        ReferenceSymbol("person.crop.circle"),
        ReferenceSymbol("person.crop.circle.badge.plus"),
        ReferenceSymbol("phone.fill"),
        ReferenceSymbol("phone.fill.badge.checkmark"),
        ReferenceSymbol("accessibility.badge.arrow.up.right", recipeName: "accessibility.badge.arrow.up.right")
    ]

    @State private var selectedIndex = 0
    @State private var scaleFactor = 0.39
    @State private var xOffsetAdjust = 0.0
    @State private var yOffsetAdjust = 0.0
    @State private var comparisonMode: ComparisonMode = .overlay
    @State private var overlayOpacity = 0.5
    @State private var showGallery = false
    @State private var useGlyphMetricsFallback = false

    private let displaySize: CGFloat = 200

    enum ComparisonMode: String, CaseIterable {
        case overlay = "Overlay"
        case tintedOverlay = "Tinted Overlay"
        case sideBySide = "Side by Side"
        case difference = "Difference"
    }

    private var selected: ReferenceSymbol { Self.referenceSymbols[selectedIndex] }

    var body: some View {
        HStack(spacing: 0) {
            // Controls sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    symbolPicker
                    Divider()
                    fallbackSizingToggle
                    Divider()
                    comparisonControls
                    Divider()
                    parameterSliders
                    Divider()
                    recipeInfoPanel
                }
                .padding()
            }
            .frame(width: 500)

            Divider()

            // Main comparison area
            VStack(spacing: 0) {
                if showGallery {
                    galleryView
                } else {
                    comparisonView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                HStack {
                    Toggle("Gallery", isOn: $showGallery)
                    Spacer()
                    if !showGallery {
                        navigationButtons
                    }
                }
                .padding(12)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    // MARK: - Symbol Picker

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Symbol")
                .font(.headline)

            Picker("Symbol", selection: $selectedIndex) {
                ForEach(0..<Self.referenceSymbols.count, id: \.self) { i in
                    let ref = Self.referenceSymbols[i]
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(ref.hasRecipe ? .green : ref.hasGlyphMetrics ? .blue : .orange)
                        Text(ref.id)
                    }
                    .tag(i)
                }
            }
            .labelsHidden()

            if !selected.hasRecipe {
                if selected.hasGlyphMetrics {
                    Label(useGlyphMetricsFallback
                        ? "Using glyph metrics fallback (F3)"
                        : "No plist recipe — glyph metrics available",
                        systemImage: useGlyphMetricsFallback ? "function" : "info.circle")
                        .font(.caption)
                        .foregroundStyle(useGlyphMetricsFallback ? .blue : .orange)
                } else {
                    Label("No plist recipe — using flat default", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } else if let recipeName = selected.recipeName {
                Label("Plist key: \"\(recipeName)\"", systemImage: "info.circle")
                    .font(.caption)
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

    // MARK: - Comparison Controls

    private var comparisonControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comparison Mode")
                .font(.headline)

            Picker("Mode", selection: $comparisonMode) {
                ForEach(ComparisonMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if comparisonMode == .overlay || comparisonMode == .tintedOverlay {
                HStack {
                    Text("Opacity")
                    Slider(value: $overlayOpacity, in: 0...1)
                    Text(String(format: "%.0f%%", overlayOpacity * 100))
                        .font(.caption.monospacedDigit())
                        .frame(width: 36, alignment: .trailing)
                }
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
        }
    }

    // MARK: - Recipe Info

    private var recipeInfoPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recipe Info")
                .font(.headline)

            let recipe = selected.recipe
            let icon = CalibrationIconView(
                symbolName: selected.id,
                displaySize: displaySize,
                recipeScaleFactor: scaleFactor,
                xOffsetAdjust: xOffsetAdjust,
                yOffsetAdjust: yOffsetAdjust,
                symbolOnly: false,
                recipeName: selected.recipeName,
                useGlyphMetricsFallback: useGlyphMetricsFallback
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

    // MARK: - Comparison View

    @ViewBuilder
    private var comparisonView: some View {
        VStack(spacing: 12) {
            Text(selected.id)
                .font(.title3.bold())

            switch comparisonMode {
            case .overlay:
                overlayView(tinted: false)
            case .tintedOverlay:
                overlayView(tinted: true)
            case .sideBySide:
                sideBySideView
            case .difference:
                differenceView
            }

            Text(comparisonMode == .tintedOverlay
                ? "Red = our symbol, overlaid on Apple's reference"
                : comparisonMode == .difference
                    ? "Black = matching pixels, bright = differences"
                    : "")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func overlayView(tinted: Bool) -> some View {
        ZStack {
            // Apple's reference (base layer)
            Image(selected.asset)
                .resizable()
                .interpolation(.high)
                .frame(width: displaySize, height: displaySize)

            // Our rendered icon (overlay)
            CalibrationIconView(
                symbolName: selected.id,
                displaySize: displaySize,
                recipeScaleFactor: scaleFactor,
                xOffsetAdjust: xOffsetAdjust,
                yOffsetAdjust: yOffsetAdjust,
                symbolOnly: tinted,
                recipeName: selected.recipeName,
                useGlyphMetricsFallback: useGlyphMetricsFallback
            )
            .opacity(overlayOpacity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4, y: 2)
    }

    private var sideBySideView: some View {
        HStack(spacing: 24) {
            VStack(spacing: 6) {
                Image(selected.asset)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: displaySize, height: displaySize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4, y: 2)

                Text("Apple Reference")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                CalibrationIconView(
                    symbolName: selected.id,
                    displaySize: displaySize,
                    recipeScaleFactor: scaleFactor,
                    xOffsetAdjust: xOffsetAdjust,
                    yOffsetAdjust: yOffsetAdjust,
                    symbolOnly: false,
                    recipeName: selected.recipeName,
                    useGlyphMetricsFallback: useGlyphMetricsFallback
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4, y: 2)

                Text("Our Rendering")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var differenceView: some View {
        ZStack {
            Image(selected.asset)
                .resizable()
                .interpolation(.high)
                .frame(width: displaySize, height: displaySize)

            CalibrationIconView(
                symbolName: selected.id,
                displaySize: displaySize,
                recipeScaleFactor: scaleFactor,
                xOffsetAdjust: xOffsetAdjust,
                yOffsetAdjust: yOffsetAdjust,
                symbolOnly: false,
                recipeName: selected.recipeName,
                useGlyphMetricsFallback: useGlyphMetricsFallback
            )
            .blendMode(.difference)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4, y: 2)
    }

    // MARK: - Gallery View

    private var galleryView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                ForEach(0..<Self.referenceSymbols.count, id: \.self) { i in
                    let ref = Self.referenceSymbols[i]

                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            // Apple reference
                            VStack(spacing: 4) {
                                Image(ref.asset)
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: 100, height: 100)

                                Text("Apple")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            // Our rendering
                            VStack(spacing: 4) {
                                CalibrationIconView(
                                    symbolName: ref.id,
                                    displaySize: 100,
                                    recipeScaleFactor: scaleFactor,
                                    xOffsetAdjust: 0,
                                    yOffsetAdjust: 0,
                                    symbolOnly: false,
                                    recipeName: ref.recipeName,
                                    useGlyphMetricsFallback: useGlyphMetricsFallback
                                )

                                Text("Ours")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(ref.hasRecipe ? .green : ref.hasGlyphMetrics ? .blue : .orange)
                            Text(ref.id)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(i == selectedIndex
                                ? Color.accentColor.opacity(0.1)
                                : Color.clear)
                    )
                    .onTapGesture {
                        selectedIndex = i
                        showGallery = false
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                selectedIndex = (selectedIndex - 1 + Self.referenceSymbols.count) % Self.referenceSymbols.count
            }) {
                Image(systemName: "chevron.left")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])

            Text("\(selectedIndex + 1) / \(Self.referenceSymbols.count)")
                .font(.caption.monospacedDigit())

            Button(action: {
                selectedIndex = (selectedIndex + 1) % Self.referenceSymbols.count
            }) {
                Image(systemName: "chevron.right")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
    }
}

// MARK: - Preview
#Preview {
    RecipeCalibrationPlayground()
        .frame(minWidth: 900, minHeight: 600)
}
