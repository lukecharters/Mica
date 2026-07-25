// ShadowStyleTests.swift
// Unit tests pinning the ShadowStyle presets to the shipped shadow constants
// and the preset(for:) resolution rules. The macOS26 values were lightened in
// 1b1a985 ("tweak to macos26 shadows"); sequoia was left as it was, so the two
// presets now differ in the symbol shadow as well as the background.

import Testing
import CoreGraphics
@testable import Mica

@Suite(.tags(.unit))
struct ShadowStyleTests {

    // MARK: - Preset values

    @Test("macOS26 preset matches its shipped constants")
    func macOS26_matchesShippedConstants() {
        let style = ShadowStyle.macOS26
        // Background and symbol opacities were lightened from 0.30 and 0.23 in 1b1a985.
        #expect(style.background == ShadowStyle.CanvasShadow(radius: 3.6, offsetY: 2.5, opacity: 0.23))
        #expect(style.symbol == ShadowStyle.CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.15))
        #expect(style.badgeBackground == ShadowStyle.BadgeShadow(radiusMultiplier: 0.03, offsetYMultiplier: 0.04, opacity: 0.23))
        #expect(style.badgeSymbol == ShadowStyle.BadgeShadow(radiusMultiplier: 0.02, offsetYMultiplier: 0.025, opacity: 0.15))
    }

    @Test("sequoia preset matches its shipped constants")
    func sequoia_matchesShippedConstants() {
        let style = ShadowStyle.sequoia
        #expect(style.background == ShadowStyle.CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.31))
        // Sequoia keeps the heavier pre-1b1a985 symbol shadow, so it now differs
        // from macOS26 on the symbol too — not just the background.
        #expect(style.symbol == ShadowStyle.CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.23))
        #expect(style.symbol != ShadowStyle.macOS26.symbol)
        // Badge shadows remain uniform across presets.
        #expect(style.badgeBackground == ShadowStyle.macOS26.badgeBackground)
        #expect(style.badgeSymbol == ShadowStyle.macOS26.badgeSymbol)
    }

    // MARK: - preset(for:) resolution

    @Test("preset(for:) maps the settings styles to their presets")
    func preset_mapsStyles() {
        #expect(ShadowStyle.preset(for: .macOS26) == .macOS26)
        #expect(ShadowStyle.preset(for: .sequoia) == .sequoia)
    }

    @Test(".off zeroes only the background shadow")
    func preset_offZeroesOnlyBackground() {
        let style = ShadowStyle.preset(for: .off)
        #expect(style.background == .none)
        // Symbol and badge shadows stay live — they are gated solely by
        // their own enable flags, matching the pre-refactor behavior.
        #expect(style.symbol == ShadowStyle.macOS26.symbol)
        #expect(style.badgeBackground == ShadowStyle.macOS26.badgeBackground)
        #expect(style.badgeSymbol == ShadowStyle.macOS26.badgeSymbol)
    }
}
