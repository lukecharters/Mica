// ShadowStyleTests.swift
// Unit tests pinning the ShadowStyle presets to the shadow constants that
// lived in IconContentView/BadgeView before the extraction, and the
// preset(for:) resolution rules.

import Testing
import CoreGraphics
@testable import Mica

@Suite(.tags(.unit))
struct ShadowStyleTests {

    // MARK: - Preset values (pre-refactor constants)

    @Test("macOS26 preset matches the pre-refactor render constants")
    func macOS26_matchesLegacyConstants() {
        let style = ShadowStyle.macOS26
        #expect(style.background == ShadowStyle.CanvasShadow(radius: 3.6, offsetY: 2.5, opacity: 0.30))
        #expect(style.symbol == ShadowStyle.CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.23))
        #expect(style.badgeBackground == ShadowStyle.BadgeShadow(radiusMultiplier: 0.03, offsetYMultiplier: 0.04, opacity: 0.23))
        #expect(style.badgeSymbol == ShadowStyle.BadgeShadow(radiusMultiplier: 0.02, offsetYMultiplier: 0.025, opacity: 0.15))
    }

    @Test("sequoia preset differs from macOS26 only in the background shadow")
    func sequoia_differsOnlyInBackground() {
        let style = ShadowStyle.sequoia
        #expect(style.background == ShadowStyle.CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.31))
        // Symbol and badge shadows are intentionally uniform across presets
        // today — a future .macOS27 preset is where they would diverge.
        #expect(style.symbol == ShadowStyle.macOS26.symbol)
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
