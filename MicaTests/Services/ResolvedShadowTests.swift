// ResolvedShadowTests.swift
// Unit tests pinning the ResolvedShadow presets to the shipped shadow constants
// and the preset(for:) resolution rules.

import Testing
import CoreGraphics
@testable import Mica

@Suite(.tags(.unit))
struct ResolvedShadowTests {

    // MARK: - Preset values

    @Test("macOS26 preset matches its shipped constants")
    func macOS26_matchesShippedConstants() {
        let style = ResolvedShadow.macOS26
        #expect(style.background == ResolvedShadow.CanvasShadow(radius: 4, offsetY: 2, opacity: 0.255))
        #expect(style.symbol == ResolvedShadow.CanvasShadow(radius: 5, offsetY: 3.5, opacity: 0.03))
        #expect(style.badgeBackground == ResolvedShadow.BadgeShadow(radiusMultiplier: 0.03, offsetYMultiplier: 0.04, opacity: 0.23))
        #expect(style.badgeSymbol == ResolvedShadow.BadgeShadow(radiusMultiplier: 0.02, offsetYMultiplier: 0.025, opacity: 0.15))
    }

    @Test("macOS27 preset matches its shipped constants")
    func macOS27_matchesShippedConstants() {
        let style = ResolvedShadow.macOS27
        #expect(style.background == ResolvedShadow.CanvasShadow(radius: 4, offsetY: 2, opacity: 0.255))
        #expect(style.symbol == ResolvedShadow.CanvasShadow(radius: 4.4, offsetY: 7.3, opacity: 0.11))
        #expect(style.badgeBackground == ResolvedShadow.macOS26.badgeBackground)
        #expect(style.badgeSymbol == ResolvedShadow.macOS26.badgeSymbol)
    }

    @Test("macOS15 preset matches its shipped constants")
    func macOS15_matchesShippedConstants() {
        let style = ResolvedShadow.macOS15
        #expect(style.background == ResolvedShadow.CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.31))
        #expect(style.symbol == ResolvedShadow.CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.21))
        // Badge shadows remain uniform across presets.
        #expect(style.badgeBackground == ResolvedShadow.macOS26.badgeBackground)
        #expect(style.badgeSymbol == ResolvedShadow.macOS26.badgeSymbol)
    }

    // MARK: - preset(for:) resolution

    @Test("preset(for:) maps the settings styles to their presets")
    func preset_mapsStyles() {
        #expect(ResolvedShadow.preset(for: .macOS27) == .macOS27)
        #expect(ResolvedShadow.preset(for: .macOS26) == .macOS26)
        #expect(ResolvedShadow.preset(for: .macOS15) == .macOS15)
    }

    @Test(".off zeroes only the background shadow")
    func preset_offZeroesOnlyBackground() {
        let style = ResolvedShadow.preset(for: .off)
        #expect(style.background == .none)
        #expect(style.symbol == ResolvedShadow.macOS27.symbol)
        #expect(style.badgeBackground == ResolvedShadow.macOS27.badgeBackground)
        #expect(style.badgeSymbol == ResolvedShadow.macOS27.badgeSymbol)
    }

    // MARK: - Foreground styles

    @Test("a foreground style resolves to its own preset's symbol shadows",
          arguments: [DropShadowStyle.macOS15, .macOS26, .macOS27])
    func foregroundStyle_resolvesItsPreset(_ style: DropShadowStyle) {
        #expect(ResolvedShadow.symbol(for: style) == ResolvedShadow.preset(for: style).symbol)
        #expect(ResolvedShadow.badgeSymbol(for: style) == ResolvedShadow.preset(for: style).badgeSymbol)
    }

    @Test("a foreground style of .off draws no shadow")
    func foregroundStyle_offIsNone() {
        #expect(ResolvedShadow.symbol(for: .off) == .none)
        #expect(ResolvedShadow.badgeSymbol(for: .off) == .none)
    }
}
