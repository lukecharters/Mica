// DevTools/BoxFitPredictions.swift
//
// The box-fit review half of the Symbol Calibration tool: measure every SF
// Symbol's tight bounds, predict a sizing multiplier from them
// (`SymbolAutoSizingService`), and compare that against what
// symbol-calibration.json actually says.
//
// This was `AutoSizingReviewTool`, a second window that could only *report*
// disagreement — accepting a prediction was one click, but disagreeing with it
// meant switching tools and finding the symbol again in a differently-sorted
// list. The review moved into the calibration tool, which already read the cache
// this file writes and already had an Outliers filter over it. What stayed here
// is the measurement, the model and the small views, so that a 2,597-line view
// file did not grow by another 250 lines.
//
// Two things that came across unchanged, because they were right:
//
// - **Apple's hand-tuned symbols are excluded from batch accept.** A symbol in
//   `container_recipes.plist` is not *expected* to match the rule, so accepting
//   a prediction for it overwrites a measured truth with an estimate. They still
//   bucket like any other symbol for review, and carry an `apple.logo` badge.
// - **The measurement writes a cache**, because it is ~7k `NSImage` renders and
//   a per-launch cost nobody would pay twice.
//
// Research: docs/research/automated-sizing-and-system-resources-2026-07.md

import SwiftUI

// MARK: - Measurement Cache

private struct TightBoundsCacheFile: Codable {
    var version: Int = 1
    var generatedAt: String
    var bounds: [String: SymbolTightBounds]
}

/// `auto-tight-bounds.json`, beside the calibration file in Application Support.
/// Separate from `symbol-calibration.json` on purpose: it is a *measurement* of
/// the installed SF Symbols, reproducible from scratch, and nothing ships it.
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

// MARK: - Apple Family Map (informational)

enum AppleFamilyMap {
    static let candidatePaths = [
        "/Applications/SF Symbols.app/Contents/Resources/Metadata/base_symbols_map.json",
        "/Applications/SF Symbols Beta.app/Contents/Resources/Metadata/base_symbols_map.json",
    ]

    /// variant -> base symbol, from Apple's own grouping. Empty if the
    /// SF Symbols app is not installed — which is why nothing depends on it.
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

// MARK: - Model

/// The box-fit rule's predictions, and the state of measuring them.
///
/// `@MainActor` and `@Observable`: the calibration tool holds one as `@State`,
/// reads `predictions` from its body, and the measurement pass hops back here to
/// report progress. Global-actor isolation is also what makes it `Sendable`
/// enough to be captured by the detached measuring task.
@MainActor
@Observable
final class BoxFitReview {
    /// One entry per symbol that rendered. Empty until measured or loaded.
    var predictions: [String: AutoSizingPrediction] = [:]

    /// Symbols Apple hand-tuned in `container_recipes.plist`. The rule is not
    /// expected to match these.
    var recipeSymbols: Set<String> = []

    /// Apple's own variant -> base grouping, for the detail line only.
    var appleFamilyOf: [String: String] = [:]

    var isMeasuring = false
    var progress = 0.0
    var measuredCount = 0
    var errorMessage: String?

    /// Disagreement past which a calibrated symbol counts as an outlier. The
    /// 0.02 default is the one the review tool shipped with.
    var threshold = 0.02

    var hasMeasurements: Bool { !predictions.isEmpty }

    func multiplier(for symbol: String) -> Double? {
        predictions[symbol]?.multiplier
    }

    func isAppleTuned(_ symbol: String) -> Bool {
        recipeSymbols.contains(symbol)
    }

    // MARK: Loading

    /// The two optional catalogs. Both degrade to empty rather than failing:
    /// `container_recipes.plist` is inside a private framework and
    /// `base_symbols_map.json` needs the SF Symbols app installed.
    func loadCatalogs() {
        recipeSymbols = ContainerRecipeCatalog.loadSymbolNames()
        appleFamilyOf = AppleFamilyMap.load()
    }

    /// Reads the cache if it exists. Returns whether anything was loaded.
    @discardableResult
    func loadCachedMeasurements() -> Bool {
        guard let bounds = TightBoundsCache.load() else { return false }
        predictions = Self.predictions(from: bounds)
        return true
    }

    private static func predictions(from bounds: [String: SymbolTightBounds]) -> [String: AutoSizingPrediction] {
        bounds.reduce(into: [:]) { result, pair in
            result[pair.key] = SymbolAutoSizingService.prediction(
                for: pair.value, isBadge: SymbolAutoSizingService.isBadgeVariant(pair.key))
        }
    }

    // MARK: Measuring

    /// Measures every symbol in `sf-symbols.txt` and rewrites the cache.
    ///
    /// Detached because it is ~7k `NSImage` renders — on the main actor it would
    /// hang the window for the whole pass rather than showing the progress bar
    /// this reports to.
    func measureAll() {
        guard !isMeasuring else { return }
        let symbols = Self.loadSymbolList()
        guard !symbols.isEmpty else {
            errorMessage = "sf-symbols.txt not found in the bundle"
            return
        }

        isMeasuring = true
        progress = 0
        measuredCount = 0
        errorMessage = nil

        Task.detached(priority: .userInitiated) { [self] in
            var results: [String: SymbolTightBounds] = [:]
            results.reserveCapacity(symbols.count)
            for (index, symbol) in symbols.enumerated() {
                if let bounds = SymbolAutoSizingService.measureTightBounds(symbol: symbol) {
                    results[symbol] = bounds
                }
                if index % 100 == 0 {
                    await report(progress: Double(index) / Double(symbols.count), count: results.count)
                }
            }
            TightBoundsCache.save(results)
            await finish(with: results)
        }
    }

    private func report(progress: Double, count: Int) {
        self.progress = progress
        self.measuredCount = count
    }

    private func finish(with bounds: [String: SymbolTightBounds]) {
        predictions = Self.predictions(from: bounds)
        measuredCount = bounds.count
        progress = 1
        isMeasuring = false
    }

    private static func loadSymbolList() -> [String] {
        guard let url = Bundle.main.url(forResource: "sf-symbols", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
}

// MARK: - Prediction Row

/// The line under the multiplier slider: what the rule predicts, how far off the
/// stored value is, and the two buttons that adopt it.
///
/// **Two separate adopt buttons, because they are two separate claims.** The
/// multiplier is the rule's actual output; `suggestedYOffset` is a
/// content-centring hint the service itself marks advisory, and offsets are
/// partly optical. One button doing both would silently move a glyph the
/// reviewer only meant to resize.
struct BoxFitPredictionRow: View {
    let prediction: AutoSizingPrediction
    let calibratedMultiplier: Double?
    let threshold: Double
    let isAppleTuned: Bool
    let currentMultiplier: Double
    let currentYOffset: Double
    let acceptMultiplier: () -> Void
    let acceptYOffset: () -> Void

    private var delta: Double? {
        calibratedMultiplier.map { prediction.multiplier - $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(String(format: "Box-fit prediction: %.3f", prediction.multiplier))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.blue)

                if let delta {
                    Text(String(format: "(Δ %+.3f)", delta))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(abs(delta) > threshold ? .red : .green)
                }

                if prediction.isClamped {
                    Text("clamped")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help("The rule hit its clamp, so it had less confidence for this shape")
                }

                if isAppleTuned {
                    Image(systemName: "apple.logo")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help("In Apple's container_recipes.plist — hand-tuned, the rule is not expected to match")
                }

                Button("Use") { acceptMultiplier() }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(abs(currentMultiplier - prediction.multiplier) < 0.0005)
                    .help("Adopt the predicted multiplier and mark the symbol calibrated from the rule")
            }

            HStack(spacing: 6) {
                Text(String(format: "Suggested Y offset: %+.4f", prediction.suggestedYOffset))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button("Use") { acceptYOffset() }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(abs(currentYOffset - prediction.suggestedYOffset) < 0.0005)
                    .help("Advisory content-centring hint — not the same estimator as Baseline Y Correction")
            }
        }
    }
}

// MARK: - Bounds Grid

/// What the prediction was computed from. Worth showing because a surprising
/// prediction is nearly always a surprising measurement.
struct BoxFitBoundsGrid: View {
    let bounds: SymbolTightBounds

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 2) {
            GridRow {
                Text("Tight bounds:").foregroundStyle(.secondary)
                Text(String(format: "%.1f × %.1f pt @100pt", bounds.tightWidth, bounds.tightHeight))
            }
            GridRow {
                Text("Frame:").foregroundStyle(.secondary)
                Text(String(format: "%.1f × %.1f pt", bounds.frameWidth, bounds.frameHeight))
            }
            GridRow {
                Text("Content centre:").foregroundStyle(.secondary)
                Text(String(format: "%+.1f, %+.1f pt", bounds.centerXOffset, bounds.centerYOffset))
            }
        }
        .font(.caption2.monospacedDigit())
    }
}

// MARK: - Agreement Summary

/// How well the rule agrees with the whole calibrated set: the one readout that
/// says whether the *rule* needs work rather than a symbol.
struct BoxFitAgreementSummary: View {
    let deltas: [Double]
    let threshold: Double

    var body: some View {
        let within = deltas.filter { abs($0) <= threshold }.count
        let mae = deltas.isEmpty ? 0 : deltas.map(abs).reduce(0, +) / Double(deltas.count)
        return VStack(alignment: .leading, spacing: 1) {
            Text("\(deltas.count) calibrated symbols compared")
            HStack(spacing: 10) {
                Text(String(format: "MAE %.4f", mae))
                    .monospacedDigit()
                if !deltas.isEmpty {
                    Text(String(format: "%.0f%% within threshold", Double(within) / Double(deltas.count) * 100))
                        .monospacedDigit()
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}
