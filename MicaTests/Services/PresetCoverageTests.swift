// PresetCoverageTests.swift
// The preset option space, exercised through synthetic presets.
//
// **Why these are not asserted over `PresetCatalog`.** They used to be, and every one of
// them was a hidden constraint on curation: the badge set could not be re-curated without
// keeping a custom gradient, a non-default scale and a non-zero offset among the shipping
// presets, and the failure arrived as three broken tests rather than as a design
// conversation. The catalogue answers to taste and will churn; the decoder's option space
// does not. Splitting them lets `PresetCatalogTests` assert what is true of *any*
// catalogue, and lets this file assert what must stay true of the *decoder* — that each
// axis a preset can reach still survives the decode-over-defaults round trip.
//
// What is checked here is the pipeline in `PresetApplication.previewSettings`: a preset's
// keys, decoded against a fresh `IconSettings`. If an axis stops arriving, a preset that
// sets it silently renders as though it had not — the same invisible failure that
// scope-completeness has, and the reason each of these names the key it is proving.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct PresetCoverageTests {

    // MARK: - Fixtures

    /// An icon preset carrying `keys` on top of the one key that activates the layer.
    private func iconPreset(_ keys: [String: MicaPresetValue]) -> MicaPreset {
        MicaPreset(
            name: "Fixture",
            scope: .icon,
            keys: keys.merging(["icon-fg": .string("symbol:star.fill")]) { current, _ in current }
        )
    }

    /// A badge preset, likewise. `badge-fg` is one of the three activating keys, so a
    /// fixture without it decodes to a badge that never draws.
    private func badgePreset(_ keys: [String: MicaPresetValue]) -> MicaPreset {
        MicaPreset(
            name: "Fixture",
            scope: .badge,
            keys: keys.merging(["badge-fg": .string("symbol:plus")]) { current, _ in current }
        )
    }

    private func iconSettings(_ keys: [String: MicaPresetValue]) -> IconSettings {
        PresetApplication.previewSettings(for: iconPreset(keys))
    }

    private func badgeSettings(_ keys: [String: MicaPresetValue]) -> IconSettings {
        PresetApplication.previewSettings(for: badgePreset(keys))
    }

    // MARK: - Icon backgrounds

    @Test("Both gradient kinds and a genuinely flat background each arrive")
    func iconBackgrounds() {
        // A custom two-colour gradient — the list-encoded form.
        let custom = iconSettings([
            "icon-bg": .string("custom-gradient"),
            "icon-bg-gradient-colors": .strings(["orange", "pink"]),
        ])
        #expect(custom.icon.background.usesCustomGradient)

        // The derived gradient, which is a different thing and is the default.
        let derived = iconSettings(["icon-bg-color": .string("blue")])
        #expect(derived.icon.background.usesGradient)
        #expect(!derived.icon.background.usesCustomGradient)

        // **Flat**, which needs `icon-bg-gradient: false` spelled out:
        // `IconBackgroundSpec().usesGradient` is `true`, so under scope-completeness an
        // omitted key means the default, which is *on*. This is the assertion that
        // catches someone "tidying away" that explicit false.
        let flat = iconSettings([
            "icon-bg": .string("standard"),
            "icon-bg-color": .string("blue"),
            "icon-bg-gradient": .bool(false),
        ])
        #expect(!flat.icon.background.usesGradient)
    }

    // MARK: - Icon foreground

    @Test("Monochrome and a non-monochrome rendering mode each arrive")
    func iconRendering() {
        #expect(iconSettings(["icon-symbol-rendering": .string("monochrome")])
            .icon.foreground.renderingStyle == .monochrome)

        for mode in ["hierarchical", "multicolor"] {
            let style = iconSettings(["icon-symbol-rendering": .string(mode)])
                .icon.foreground.renderingStyle
            #expect(style != .monochrome, "\(mode) decoded as monochrome")
        }
    }

    @Test("A white symbol and a coloured one each arrive")
    func iconSymbolColours() {
        #expect(iconSettings(["icon-symbol-color": .string("white")])
            .icon.foreground.color == .white)
        #expect(iconSettings(["icon-symbol-color": .string("orange")])
            .icon.foreground.color != .white)
    }

    @Test("A non-default corner style, shadow and weight each arrive")
    func iconHiddenButApplied() {
        // The three axes `resetToSimpleControls()` does *not* fold. They matter because
        // they are the ones that survive the simple pane unrepresented — applied, but
        // with no control showing them — so a preset is the only way a user meets them.
        let settings = iconSettings([
            "icon-bg-corner-radius": .string("off"),
            "icon-bg-shadow": .string("off"),
            "icon-symbol-weight": .string("bold"),
        ])
        #expect(settings.icon.background.cornerRadiusStyle != IconBackgroundSpec().cornerRadiusStyle)
        #expect(settings.icon.background.shadowStyle != IconBackgroundSpec().shadowStyle)
        #expect(settings.icon.foreground.symbolWeight != .auto)
    }

    // MARK: - Badge

    @Test("Every corner arrives", arguments: [
        ("top-left", BadgePosition.topLeft),
        ("top-right", BadgePosition.topRight),
        ("bottom-left", BadgePosition.bottomLeft),
        ("bottom-right", BadgePosition.bottomRight),
    ])
    func badgeCorners(name: String, expected: BadgePosition) {
        // The corner is what the thumbnail's arrow points to, so a corner that failed to
        // decode would draw the wrong arrow rather than error.
        #expect(badgeSettings(["badge-position": .string(name)]).badge.position == expected)
    }

    @Test("A non-default scale and non-zero offsets arrive")
    func badgeLayout() {
        // The offsets are fractions of the badge, not points: `BadgeSpec.offsetRange`
        // is -1.0...1.0 and `badge-scale` answers to `ForegroundSpec.symbolScaleRange`,
        // 0.3...2.0. A value outside either is dropped with a warning rather than
        // clamped, so an out-of-range fixture would decode to the default and assert
        // nothing — which is what `fixturesDecodeCleanly` below is here to catch.
        let settings = badgeSettings([
            "badge-scale": .number(1.3),
            "badge-offset-x": .number(-0.4),
            "badge-offset-y": .number(0.6),
        ])
        #expect(settings.badge.scale != BadgeSpec().scale)
        #expect(settings.badge.offsetX != 0)
        #expect(settings.badge.offsetY != 0)
    }

    @Test("Both badge background kinds arrive")
    func badgeBackgrounds() {
        let custom = badgeSettings([
            "badge-bg": .string("custom-gradient"),
            "badge-bg-gradient-colors": .strings(["red", "orange"]),
        ])
        #expect(custom.badge.background.usesCustomGradient)

        let plain = badgeSettings(["badge-bg-color": .string("green")])
        #expect(!plain.badge.background.usesCustomGradient)
    }

    // MARK: - The axes decode without complaint

    @Test("No fixture in this file decodes with a warning")
    func fixturesDecodeCleanly() throws {
        // The same guarantee `PresetCatalogTests` gives the built-ins. Without it a
        // fixture could be asserting against a value the decoder rejected and replaced
        // with a default that happens to satisfy the expectation.
        let presets = [
            iconPreset(["icon-bg": .string("custom-gradient"),
                        "icon-bg-gradient-colors": .strings(["orange", "pink"])]),
            iconPreset(["icon-bg-corner-radius": .string("off"),
                        "icon-bg-shadow": .string("off"),
                        "icon-symbol-weight": .string("bold")]),
            iconPreset(["icon-symbol-color": .string("orange")]),
            badgePreset(["badge-scale": .number(1.3),
                         "badge-offset-x": .number(-0.4),
                         "badge-offset-y": .number(0.6)]),
            badgePreset(["badge-bg": .string("custom-gradient"),
                         "badge-bg-gradient-colors": .strings(["red", "orange"])]),
        ]
        for preset in presets {
            let decoded = try PresetApplication.decode(preset)
            #expect(decoded.warnings.isEmpty,
                    "\(decoded.warnings.map(\.message).joined(separator: "; "))")
        }
    }
}
