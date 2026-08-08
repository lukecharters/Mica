// ResolvedShadowTests.swift
// Unit tests pinning the ResolvedShadow presets to the shipped shadow constants
// and the preset(for:) resolution rules. The macOS26 values were lightened in
// 1b1a985 ("tweak to macos26 shadows"); macOS15 was left as it was, so the two
// presets now differ in the symbol shadow as well as the background.

import Testing
import CoreGraphics
@testable import Mica

@Suite(.tags(.unit))
struct ResolvedShadowTests {

    // MARK: - Preset values

    @Test("macOS26 preset matches its shipped constants")
    func macOS26_matchesShippedConstants() {
        let style = ResolvedShadow.macOS26
        // Background and symbol opacities were lightened from 0.30 and 0.23 in 1b1a985.
        #expect(style.background == ResolvedShadow.CanvasShadow(radius: 3.6, offsetY: 2.5, opacity: 0.23))
        #expect(style.symbol == ResolvedShadow.CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.15))
        #expect(style.badgeBackground == ResolvedShadow.BadgeShadow(radiusMultiplier: 0.03, offsetYMultiplier: 0.04, opacity: 0.23))
        #expect(style.badgeSymbol == ResolvedShadow.BadgeShadow(radiusMultiplier: 0.02, offsetYMultiplier: 0.025, opacity: 0.15))
    }

    @Test("macOS15 preset matches its shipped constants")
    func macOS15_matchesShippedConstants() {
        let style = ResolvedShadow.macOS15
        #expect(style.background == ResolvedShadow.CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.31))
        // macOS15 keeps the heavier pre-1b1a985 symbol shadow, so it now differs
        // from macOS26 on the symbol too — not just the background.
        #expect(style.symbol == ResolvedShadow.CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.23))
        #expect(style.symbol != ResolvedShadow.macOS26.symbol)
        // Badge shadows remain uniform across presets.
        #expect(style.badgeBackground == ResolvedShadow.macOS26.badgeBackground)
        #expect(style.badgeSymbol == ResolvedShadow.macOS26.badgeSymbol)
    }

    // MARK: - preset(for:) resolution

    @Test("preset(for:) maps the settings styles to their presets")
    func preset_mapsStyles() {
        #expect(ResolvedShadow.preset(for: .macOS26) == .macOS26)
        #expect(ResolvedShadow.preset(for: .macOS15) == .macOS15)
    }

    @Test(".off zeroes only the background shadow")
    func preset_offZeroesOnlyBackground() {
        let style = ResolvedShadow.preset(for: .off)
        #expect(style.background == .none)
        // Symbol and badge shadows stay live — they are gated solely by
        // their own enable flags, matching the pre-refactor behavior.
        #expect(style.symbol == ResolvedShadow.macOS26.symbol)
        #expect(style.badgeBackground == ResolvedShadow.macOS26.badgeBackground)
        #expect(style.badgeSymbol == ResolvedShadow.macOS26.badgeSymbol)
    }
}
