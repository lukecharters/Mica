// BaseOverrideTests.swift
// Covers `buildIconSettings(from:onto:)` — the seam `--config` uses to apply
// command-line flags onto a decoded configuration.
//
// The contract these tests exist to defend: **an absent flag must leave the base
// untouched.** Every other CLI test builds settings from the model defaults, so a
// site that writes eagerly with an inline `?? "literal"` looks correct there — the
// literal equals the default. It is only visible against a base that differs, which
// is what `distinctiveBase` below is for. Without these tests, reintroducing an
// eager write would keep all 165 other cases green while silently discarding what
// the user saved.

import Testing
import Foundation
import SwiftUI

@Suite
@MainActor
struct BaseOverrideTests {

    // MARK: - Fixture

    /// A base whose every relevant field differs from `IconSettings()`, so that any
    /// unconditional write in the builder shows up as a changed field rather than
    /// coinciding with a default.
    static func distinctiveBase() -> IconSettings {
        var settings = IconSettings()

        settings.export.size = 256
        settings.export.isRetina = true
        settings.export.colorSpace = .displayP3

        settings.icon.foreground.symbolName = "bolt.fill"
        settings.icon.foreground.symbolScale = 1.4
        settings.icon.foreground.color = .orange
        settings.icon.foreground.hierarchicalColor = .orange
        settings.icon.foreground.renderingStyle = .hierarchical
        settings.icon.foreground.fillStyle = .gradient
        settings.icon.foreground.symbolWeight = .bold
        settings.icon.foreground.drawsShadow = false
        settings.icon.foreground.palettePrimaryColor = .red
        settings.icon.foreground.paletteSecondaryColor = .green
        settings.icon.foreground.paletteTertiaryColor = .blue

        settings.icon.background.color = .teal
        settings.icon.background.usesGradient = false
        settings.icon.background.gradientStartColor = .pink
        settings.icon.background.gradientEndColor = .brown
        settings.icon.background.cornerRadiusStyle = .macOS15
        settings.icon.background.shadowStyle = .macOS15

        settings.badge.isVisible = true
        settings.badge.position = .topLeft
        settings.badge.scale = 1.3
        settings.badge.offsetX = 0.2
        settings.badge.offsetY = -0.1
        settings.badge.foreground.symbolName = "bell.fill"
        settings.badge.foreground.symbolScale = 0.8
        settings.badge.foreground.color = .yellow
        settings.badge.foreground.drawsShadow = false
        settings.badge.foreground.palettePrimaryColor = .cyan
        settings.badge.foreground.paletteSecondaryColor = .indigo
        settings.badge.foreground.paletteTertiaryColor = .mint
        settings.badge.background.color = .purple
        settings.badge.background.usesGradient = false
        settings.badge.background.drawsShadow = false

        return settings
    }

    private static func build(_ args: [String], onto base: IconSettings) throws -> IconSettings {
        try IconGenerationRunner().buildTestSettings(from: parseCommand(args), onto: base)
    }

    // MARK: - The core contract

    @Test("No flags at all leaves every field of the base untouched")
    func noFlags_leaveTheBaseEntirelyUntouched() throws {
        let base = Self.distinctiveBase()
        let result = try Self.build([], onto: base)
        #expect(result == base)
    }

    @Test("A single unrelated flag changes only its own field")
    func oneFlag_changesOnlyItsOwnField() throws {
        let base = Self.distinctiveBase()
        let result = try Self.build(["--size", "1024"], onto: base)

        var expected = base
        expected.export.size = 1024
        #expect(result == expected)
    }

    // MARK: - Sites that used to write eagerly
    //
    // One test per eager assignment found when Phase 5 started. Each of these
    // failed before the conversion.

    @Test("An absent --icon-symbol-palette keeps the base's palette")
    func absentPalette_keepsTheBasePalette() throws {
        // This was the sharpest case while the CLI seeded a palette of its own that
        // differed from the model's, because the site could not be fixed by matching
        // a literal to a spec default. That seed is gone (there is one default now),
        // so what this defends is the ordinary contract: the base's palette differs
        // from `ForegroundSpec.defaultPalette`, so an eager write would show here.
        let result = try Self.build([], onto: Self.distinctiveBase())
        #expect(result.icon.foreground.palettePrimaryColor == .red)
        #expect(result.icon.foreground.paletteSecondaryColor == .green)
        #expect(result.icon.foreground.paletteTertiaryColor == .blue)
    }

    @Test("An absent --badge-symbol-palette keeps the base's badge palette")
    func absentBadgePalette_keepsTheBasePalette() throws {
        let result = try Self.build([], onto: Self.distinctiveBase())
        #expect(result.badge.foreground.palettePrimaryColor == .cyan)
        #expect(result.badge.foreground.paletteSecondaryColor == .indigo)
        #expect(result.badge.foreground.paletteTertiaryColor == .mint)
    }

    @Test("An absent --icon-symbol-color keeps the base's symbol colour")
    func absentSymbolColor_keepsTheBaseColor() throws {
        let result = try Self.build([], onto: Self.distinctiveBase())
        #expect(result.icon.foreground.color == .orange)
        #expect(result.icon.foreground.hierarchicalColor == .orange)
    }

    @Test("An absent --icon-bg-shadow keeps the base's shadow style")
    func absentBackgroundShadow_keepsTheBaseStyle() throws {
        let result = try Self.build([], onto: Self.distinctiveBase())
        #expect(result.icon.background.shadowStyle == .macOS15)
    }

    @Test("An absent --icon-fg-shadow keeps the base's symbol shadow")
    func absentForegroundShadow_keepsTheBaseSetting() throws {
        let result = try Self.build([], onto: Self.distinctiveBase())
        #expect(result.icon.foreground.drawsShadow == false)
    }

    @Test("An absent --icon-generation-mode keeps a base in system mode")
    func absentGenerationMode_keepsSystemMode() throws {
        var base = Self.distinctiveBase()
        base.icon.mode = .system

        let result = try Self.build([], onto: base)
        #expect(result.icon.mode == .system)
    }

    @Test("An absent --icon-fg keeps the base's foreground")
    func absentForeground_keepsTheBaseSymbol() throws {
        let result = try Self.build([], onto: Self.distinctiveBase())
        #expect(result.icon.foreground.symbolName == "bolt.fill")
        #expect(result.icon.foreground.source == .symbol)
    }

    // MARK: - `--icon-bg-color` must not flatten a non-colour background
    //
    // `resolvedBackground()` reports `.standard` both for an explicit
    // `--icon-bg standard` and for an absent `--icon-bg`, so the builder has to
    // check the flag itself before asserting a source.

    @Test("--icon-bg-color alone tints an imported background without flattening it")
    func backgroundColorAlone_doesNotFlattenTheSource() throws {
        var base = Self.distinctiveBase()
        base.icon.background.source = .image

        let result = try Self.build(["--icon-bg-color", "red"], onto: base)
        #expect(result.icon.background.source == .image)
        #expect(result.icon.background.color == .red)
    }

    @Test("An explicit --icon-bg standard does flatten it")
    func explicitStandardBackground_doesFlattenTheSource() throws {
        var base = Self.distinctiveBase()
        base.icon.background.source = .image

        let result = try Self.build(["--icon-bg", "standard"], onto: base)
        #expect(result.icon.background.source == .color)
    }

    @Test("An absent --icon-bg-gradient-colors keeps a base's custom gradient")
    func explicitCustomGradient_keepsTheBaseColors() throws {
        let result = try Self.build(["--icon-bg", "custom-gradient"], onto: Self.distinctiveBase())
        #expect(result.icon.background.usesCustomGradient == true)
        #expect(result.icon.background.gradientStartColor == .pink)
        #expect(result.icon.background.gradientEndColor == .brown)
    }

    // MARK: - The badge gate
    //
    // The badge block used to be gated purely on `--badge-fg`, so on a base
    // that already had a badge every other badge flag did nothing at all.

    @Test("Badge flags apply to a base's badge without --badge-fg")
    func badgeFlags_applyToABaseBadge() throws {
        let result = try Self.build(
            ["--badge-position", "bottom-left", "--badge-scale", "1.75", "--badge-offset-x=-0.25"],
            onto: Self.distinctiveBase()
        )
        #expect(result.badge.position == .bottomLeft)
        #expect(result.badge.scale == 1.75)
        #expect(result.badge.offsetX == -0.25)
        // The base's own badge foreground survives.
        #expect(result.badge.foreground.symbolName == "bell.fill")
    }

    @Test("Badge flags still do nothing when the base has no badge")
    func badgeFlags_areInertWithoutABadge() throws {
        var base = Self.distinctiveBase()
        base.badge.isVisible = false

        let result = try Self.build(["--badge-position", "bottom-left"], onto: base)
        #expect(result.badge.isVisible == false)
        #expect(result.badge.position == .topLeft, "an inactive badge takes no layout overrides")
    }

    @Test("--badge-fg activates a badge the base had hidden")
    func badgeForegroundFlag_activatesAHiddenBadge() throws {
        var base = Self.distinctiveBase()
        base.badge.isVisible = false

        let result = try Self.build(["--badge-fg", "symbol:plus"], onto: base)
        #expect(result.badge.isVisible == true)
        #expect(result.badge.foreground.symbolName == "plus")
    }

    @Test("A base's per-layer badge visibility survives when no flag touches it")
    func perLayerBadgeVisibility_survives() throws {
        // The activation rule writes *both* layers visible, which would resurrect a
        // background the user had deliberately hidden on one layer only.
        var base = Self.distinctiveBase()
        base.badge.foreground.isHidden = false
        base.badge.background.isHidden = true

        let result = try Self.build([], onto: base)
        #expect(result.badge.foreground.isHidden == false)
        #expect(result.badge.background.isHidden == true)
    }

    @Test("An explicit --badge-bg-visibility still overrides the base")
    func badgeBackgroundVisibilityFlag_overridesTheBase() throws {
        var base = Self.distinctiveBase()
        base.badge.foreground.isHidden = false
        base.badge.background.isHidden = true

        let result = try Self.build(["--badge-bg-visibility", "on"], onto: base)
        #expect(result.badge.background.isHidden == false)
    }

    // MARK: - Overrides that must still work

    @Test("Export flags override the base")
    func exportFlags_override() throws {
        let result = try Self.build(
            ["--size", "128", "--scale", "1x", "--color-space", "sRGB"],
            onto: Self.distinctiveBase()
        )
        #expect(result.export.size == 128)
        #expect(result.export.isRetina == false)
        #expect(result.export.colorSpace == .sRGB)
    }

    @Test("--icon-fg-scale applies to the base's source rather than a flag's")
    func foregroundScale_appliesToTheBaseSource() throws {
        var base = Self.distinctiveBase()
        base.icon.foreground.source = .image
        base.icon.foreground.imageScale = 1.0

        let result = try Self.build(["--icon-fg-scale", "1.9"], onto: base)
        #expect(result.icon.foreground.imageScale == 1.9)
        #expect(result.icon.foreground.symbolScale == 1.4, "the symbol scale is untouched")
    }

    @Test("Icon foreground and background flags override the base")
    func iconFlags_override() throws {
        let result = try Self.build(
            [
                "--icon-fg", "symbol:heart.fill",
                "--icon-symbol-color", "white",
                "--icon-symbol-rendering", "monochrome",
                "--icon-bg-color", "green",
                "--icon-bg-corner-radius", "macos26",
                "--icon-bg-shadow", "off",
            ],
            onto: Self.distinctiveBase()
        )
        #expect(result.icon.foreground.symbolName == "heart.fill")
        #expect(result.icon.foreground.color == .white)
        #expect(result.icon.foreground.renderingStyle == .monochrome)
        #expect(result.icon.background.color == .green)
        #expect(result.icon.background.cornerRadiusStyle == .macOS26)
        #expect(result.icon.background.shadowStyle == .off)
    }

    @Test("Palette and symbol-palette flags override the base")
    func paletteFlags_override() throws {
        let result = try Self.build(
            ["--icon-symbol-rendering", "palette", "--icon-symbol-palette", "red,green,blue"],
            onto: Self.distinctiveBase()
        )
        #expect(result.icon.foreground.renderingStyle == .palette)
        #expect(result.icon.foreground.palettePrimaryColor == .red)
        #expect(result.icon.foreground.paletteSecondaryColor == .green)
        #expect(result.icon.foreground.paletteTertiaryColor == .blue)
    }

    @Test("--badge-generation-mode system switches a base's badge to the appex source")
    func badgeGenerationMode_overrides() throws {
        let result = try Self.build(["--badge-generation-mode", "system"], onto: Self.distinctiveBase())
        #expect(result.badge.mode == .system)
        #expect(result.badge.foreground.source == .system)
    }

    // MARK: - `generate` is unaffected
    //
    // The same builder with no base must still produce the model's defaults.

    // Asserts against `ForegroundSpec.defaultPalette` rather than three literals,
    // deliberately: the claim is that the CLI and the model agree on the palette,
    // and a literal here would let them drift apart while the test still passed.
    // There were two palette defaults until 2026-08-18 — the CLI seeded
    // white/white:0.5/white:0.26 over the model's white/mint/yellow — and this is
    // the test that would have caught a re-divergence.
    @Test("a flags-only generate leaves the model's palette default in place")
    func generateUsesTheModelPaletteDefault() throws {
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill"]))
        #expect(settings.icon.foreground.palettePrimaryColor == ForegroundSpec.defaultPalette[0])
        #expect(settings.icon.foreground.paletteSecondaryColor == ForegroundSpec.defaultPalette[1])
        #expect(settings.icon.foreground.paletteTertiaryColor == ForegroundSpec.defaultPalette[2])
        #expect(settings.badge.foreground.palettePrimaryColor == ForegroundSpec.defaultPalette[0])
        #expect(settings.badge.foreground.paletteSecondaryColor == ForegroundSpec.defaultPalette[1])
        #expect(settings.badge.foreground.paletteTertiaryColor == ForegroundSpec.defaultPalette[2])
    }

    // The reason the default is three hues and not three tints of one. Palette at
    // its default used to render *identically* to hierarchical, because
    // white/white:0.5/white:0.26 is exactly what hierarchical draws — so choosing
    // palette and seeing no change was all a reader learned. This pins the fix at
    // the level that matters: the three slots must be three different colours.
    @Test("the default palette is three distinct colours, so palette differs from hierarchical")
    func defaultPaletteIsThreeDistinctColours() throws {
        let palette = ForegroundSpec.defaultPalette
        #expect(palette.count == 3)
        #expect(Set(palette.map(\.stringValue)).count == 3, "the default palette must not be three tints of one colour")
        #expect(ForegroundSpec.defaultPaletteCLIValue == "white,green,yellow")
    }
}
