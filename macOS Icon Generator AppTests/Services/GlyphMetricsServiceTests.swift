// GlyphMetricsServiceTests.swift
// GlyphMetricsService provides F3-predicted multipliers as a fallback
// when a symbol is absent from container_recipes.plist. Tests verify
// bundled plist loads and known values are returned.

import Testing
@testable import macOS_Icon_Generator_App

@Suite(.tags(.unit))
@MainActor
struct GlyphMetricsServiceTests {

    @Test("Known symbol returns the bundled F3 multiplier")
    func knownSymbol_starFill() throws {
        let mul = try #require(GlyphMetricsService.predictedMultiplier(for: "star.fill"))
        // Exact bundled value is 1.707979 — loose epsilon tolerates plist regen.
        #expect(abs(mul - 1.707979) < 0.01)
    }

    @Test("Known folder.fill returns its F3 multiplier")
    func knownSymbol_folderFill() throws {
        let mul = try #require(GlyphMetricsService.predictedMultiplier(for: "folder.fill"))
        #expect(abs(mul - 1.729573) < 0.01)
    }

    @Test("Unknown symbol returns nil")
    func unknownSymbol_returnsNil() {
        #expect(GlyphMetricsService.predictedMultiplier(for: "definitely_not_a_real_symbol_xyz123") == nil)
        #expect(GlyphMetricsService.predictedMultiplier(for: "") == nil)
    }

    @Test("F3 multipliers are in a plausible range for a shipped-symbol corpus",
          arguments: ["star.fill", "folder.fill", "gear", "plus", "heart.fill", "circle"])
    func corpus_reasonableRange(_ symbol: String) throws {
        let mul = try #require(
            GlyphMetricsService.predictedMultiplier(for: symbol),
            "Expected bundled F3 multiplier for \(symbol)"
        )
        // F3 values cluster around 1.0–2.0; anything outside that range is
        // likely a loader bug. Wide bounds to survive future retraining.
        #expect(mul > 0.5 && mul < 3.0,
                "\(symbol) predicted multiplier \(mul) is outside plausible range")
    }
}
