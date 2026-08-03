// ImportedImageDefaultsTests.swift
// Mirrors the GUI's imported-image defaults in the CLI: when an image source is
// used, padding compensation defaults on (fill the frame) for backgrounds and
// the imported-image shadow defaults off, while the inverse flags keep both
// fully overridable. SF Symbol sources keep shadows on.

import Testing
import Foundation

@Suite
@MainActor
struct ImportedImageDefaultsTests {

    // MARK: - Resolved defaults on the parsed options (no file needed)

    @Test("Background shadow defaults off for image backgrounds, macOS 26 otherwise")
    func effectiveShadowStyle_imageAware() throws {
        #expect(try parseCommand(["star.fill"]).background.effectiveShadowStyle == "macos26")
        #expect(try parseCommand(["star.fill", "--icon-bg", "/tmp/bg.png"]).background.effectiveShadowStyle == "off")
    }

    @Test("Explicit --icon-bg-shadow overrides the image-background default")
    func effectiveShadowStyle_explicitOverride() throws {
        let command = try parseCommand(["star.fill", "--icon-bg", "/tmp/bg.png", "--icon-bg-shadow", "macos26"])
        #expect(command.background.effectiveShadowStyle == "macos26")
    }

    // The user-facing flag mirrors the GUI "Icon Padding" toggle, so it is
    // INVERSE to the compensation bool: padding "on" keeps the image's padding
    // (compensation off); padding "off" or unspecified fills the frame
    // (compensation on).
    @Test("--icon-bg-padding on disables compensation; off/unspecified fill the frame")
    func effectivePaddingCompensation_default() throws {
        #expect(try parseCommand(["star.fill"]).background.effectivePaddingCompensation == true)
        #expect(try parseCommand(["star.fill", "--icon-bg-padding", "off"]).background.effectivePaddingCompensation == true)
        #expect(try parseCommand(["star.fill", "--icon-bg-padding", "on"]).background.effectivePaddingCompensation == false)
    }

    @Test("--badge-bg-padding on disables compensation; off/unspecified fill the frame")
    func effectiveBadgePaddingCompensation_default() throws {
        #expect(try parseCommand(["star.fill", "--badge-fg", "symbol:gear"]).badge.effectiveBackgroundPaddingCompensation == true)
        #expect(try parseCommand(["star.fill", "--badge-fg", "symbol:gear", "--badge-bg-padding", "off"]).badge.effectiveBackgroundPaddingCompensation == true)
        #expect(try parseCommand(["star.fill", "--badge-fg", "symbol:gear", "--badge-bg-padding", "on"]).badge.effectiveBackgroundPaddingCompensation == false)
    }

    @Test("--icon-fg-shadow parses to an on|off toggle, unspecified is nil")
    func iconForegroundShadowFlag_toggle() throws {
        #expect(try parseCommand(["star.fill"]).iconForeground.shadow == nil)
        #expect(try parseCommand(["star.fill", "--icon-fg-shadow", "off"]).iconForeground.shadow == .off)
        #expect(try parseCommand(["star.fill", "--icon-fg-shadow", "on"]).iconForeground.shadow == .on)
    }

    // MARK: - End-to-end through buildIconSettings

    @Test("Imported icon foreground (--icon-fg <path>) turns the symbol shadow off")
    func iconForegroundImage_shadowOff() throws {
        let path = try makeTempImageFile().path
        let command = try parseCommand(["--icon-fg", path])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.icon.foreground.source == .image)
        #expect(settings.icon.foreground.drawsShadow == false)
    }

    @Test("SF Symbol icon keeps its shadow on")
    func iconSymbol_shadowOn() throws {
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand(["star.fill"]))
        #expect(settings.icon.foreground.drawsShadow == true)
    }

    @Test("--icon-fg-shadow on forces the shadow back on for an imported image")
    func iconForegroundImage_explicitShadowOn() throws {
        let path = try makeTempImageFile().path
        let command = try parseCommand(["--icon-fg", path, "--icon-fg-shadow", "on"])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.icon.foreground.drawsShadow == true)
    }

    @Test("Image icon background (--icon-bg <path>) fills the frame and drops its shadow")
    func iconBackgroundImage_defaults() throws {
        let path = try makeTempImageFile().path
        let command = try parseCommand(["star.fill", "--icon-bg", path])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.icon.background.source == .image)
        #expect(settings.icon.background.compensatesForPadding == true)
        #expect(settings.icon.background.shadowStyle == .off)
    }

    // MARK: - The two seam defaults reach the CLI, at `.fixed`
    //
    // The CLI routes `--icon-bg`/`--badge-bg` through
    // `IconSpec.applyBackgroundImage(_:defaults:)`, taking the default argument
    // `.fixed`. It cannot do otherwise: `ImportDefaults.fromPreferences` lives in
    // `Mica/App/`, which this target does not compile — so a GUI preference is
    // structurally unable to change what `mica-cli` renders. These tests pin the
    // resulting values so the routing cannot be quietly undone.

    @Test("--icon-bg <path> turns the corner radius off")
    func iconBackgroundImage_turnsCornerRadiusOff() throws {
        let path = try makeTempImageFile().path
        let settings = try IconGenerationRunner()
            .buildTestSettings(from: parseCommand(["star.fill", "--icon-bg", path]))
        #expect(settings.icon.background.cornerRadiusStyle == .off)
    }

    @Test("An explicit --icon-bg-corner-radius beats the import default")
    func iconBackgroundImage_explicitCornerRadiusWins() throws {
        let path = try makeTempImageFile().path
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["star.fill", "--icon-bg", path, "--icon-bg-corner-radius", "macos26"]))
        #expect(settings.icon.background.cornerRadiusStyle == .macOS26)
    }

    @Test("--icon-bg <path> hides the icon foreground")
    func iconBackgroundImage_hidesForeground() throws {
        let path = try makeTempImageFile().path
        let settings = try IconGenerationRunner()
            .buildTestSettings(from: parseCommand(["star.fill", "--icon-bg", path]))
        #expect(settings.icon.foreground.isHidden == true)
    }

    // The badge's bare-import case — `--badge-bg <path>` on its own, with the
    // foreground hidden — is not reachable from the CLI yet: `--badge-bg` does not
    // activate the badge until phase 5 of the plan. What *is* assertable now is
    // that naming a badge symbol keeps it, which is rule 2 of the foreground rule
    // ("any other foreground flag in that group → foreground visible") and holds
    // both before and after phase 6 changes why.
    @Test("--badge-fg beside an imported --badge-bg keeps the badge symbol")
    func badgeBackgroundImage_keepsAnExplicitlyNamedForeground() throws {
        let path = try makeTempImageFile().path
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["star.fill", "--badge-fg", "symbol:gear", "--badge-bg", path]))
        #expect(settings.badge.background.source == .image)
        #expect(settings.badge.foreground.isHidden == false)
    }

    @Test("Imported badge foreground (--badge-fg <path>) turns the badge symbol shadow off")
    func badgeForegroundImage_shadowOff() throws {
        let path = try makeTempImageFile().path
        let command = try parseCommand(["star.fill", "--badge-fg", path])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.badge.foreground.source == .image)
        #expect(settings.badge.foreground.drawsShadow == false)
    }

    @Test("Image badge background (--badge-bg <path>) fills the frame and drops its shadow")
    func badgeBackgroundImage_defaults() throws {
        let path = try makeTempImageFile().path
        let command = try parseCommand(["star.fill", "--badge-fg", "symbol:gear", "--badge-bg", path])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.badge.background.source == .image)
        #expect(settings.badge.background.compensatesForPadding == true)
        #expect(settings.badge.background.drawsShadow == false)
    }
}
