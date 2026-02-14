// GlyphMetricsService.swift - Fallback symbol sizing from Assets.car glyph metrics
//
// When a symbol has no entry in container_recipes.plist, this service provides
// a predicted multiplier derived from the symbol's typographic metrics (baseline/capline)
// and pixel aspect ratio in the compiled asset catalog.
//
// The multiplier is computed via linear regression trained on the 514 symbols that have
// both container_recipes entries and Assets.car vector glyph data:
//   mul = 1.7731 - 0.3641 * heightRatio + 0.2103 * aspectRatio
// where heightRatio = (capline - baseline) / capline, aspectRatio = pixelWidth / pixelHeight.
//
// Mean absolute error vs hand-tuned container_recipes values: ~0.095 (~5%).

import Foundation

struct GlyphMetricsService {
    /// Returns a predicted pointsize_to_shape_mul for the given symbol, or nil if unknown.
    static func predictedMultiplier(for symbolName: String) -> Double? {
        metricsStore[symbolName]
    }

    // MARK: - Private

    /// Lazy-loaded lookup of precomputed F3 multipliers for ~9,200 symbols (including aliases).
    private static let metricsStore: [String: Double] = {
        // Try bundled glyph_metrics.plist
        guard let url = Bundle.main.url(forResource: "glyph_metrics", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Double]
        else {
            return [:]
        }
        return plist
    }()
}
