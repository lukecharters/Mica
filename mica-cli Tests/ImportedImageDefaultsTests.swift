// ImportedImageDefaultsTests.swift
// Mirrors the GUI's imported-image defaults in the CLI. An imported background
// that is an app icon (transparent edges) gets padding compensation with its
// shadow off; artwork that reaches its edges keeps both. Corners go off for
// either.
// Foreground imports keep their shadow. Explicit flags override every default.

import Testing
import Foundation

@Suite
@MainActor
struct ImportedImageDefaultsTests {

    @Test("--icon-fg-shadow parses to a shadow style, unspecified is nil")
    func iconForegroundShadowFlag_style() throws {
        #expect(try parseCommand(["--icon-symbol", "star.fill"]).iconForeground.shadow == nil)
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--icon-fg-shadow", "off"]).iconForeground.shadow == .off)
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--icon-fg-shadow", "macos15"]).iconForeground.shadow == .macOS15)
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--icon-fg-shadow", "macos26"]).iconForeground.shadow == .macOS26)
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--icon-fg-shadow", "macos27"]).iconForeground.shadow == .macOS27)
    }

    @Test("--icon-fg-shadow and --badge-fg-shadow still take on, as macos27")
    func foregroundShadowFlags_acceptOn() throws {
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--icon-fg-shadow", "on"]).iconForeground.shadow == .macOS27)
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--badge-symbol", "plus", "--badge-fg-shadow", "on"]).badge.foregroundShadow == .macOS27)
    }

    @Test("An unknown foreground shadow style is refused")
    func foregroundShadowFlags_refuseUnknown() {
        #expect(throws: (any Error).self) {
            try parseCommand(["--icon-symbol", "star.fill", "--icon-fg-shadow", "macos14"])
        }
        #expect(throws: (any Error).self) {
            try parseCommand(["--icon-symbol", "star.fill", "--badge-symbol", "plus", "--badge-fg-shadow", "yes"])
        }
    }

    // MARK: - End-to-end through buildIconSettings

    @Test("Imported icon foreground (--icon-fg <path>) keeps the shadow")
    func iconForegroundImage_keepsShadow() throws {
        let path = try makeTempImageFile(inset: 0.1).path
        let command = try parseCommand(["--icon-fg", path])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.icon.foreground.source == .image)
        #expect(settings.icon.foreground.shadowStyle == ForegroundSpec.iconDefault.shadowStyle)
    }

    @Test("SF Symbol icon keeps its shadow on")
    func iconSymbol_shadowOn() throws {
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill"]))
        #expect(settings.icon.foreground.shadowStyle == .macOS27)
    }

    @Test("--icon-fg-shadow off turns the shadow off for an imported image")
    func iconForegroundImage_explicitShadowOff() throws {
        let path = try makeTempImageFile(inset: 0.1).path
        let command = try parseCommand(["--icon-fg", path, "--icon-fg-shadow", "off"])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.icon.foreground.shadowStyle == .off)
    }

    @Test("An app icon as --icon-bg fills the frame and drops its shadow")
    func iconBackgroundAppIcon_defaults() throws {
        let path = try makeTempImageFile(inset: 0.1).path
        let command = try parseCommand(["--icon-symbol", "star.fill", "--icon-bg", path])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.icon.background.source == .image)
        #expect(settings.icon.background.compensatesForPadding == true)
        #expect(settings.icon.background.shadowStyle == .off)
    }

    @Test("Full-bleed artwork as --icon-bg keeps its edges and shadow")
    func iconBackgroundFullBleed_defaults() throws {
        let path = try makeTempImageFile(inset: 0).path
        let command = try parseCommand(["--icon-symbol", "star.fill", "--icon-bg", path])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.icon.background.source == .image)
        #expect(settings.icon.background.compensatesForPadding == false)
        #expect(settings.icon.background.shadowStyle == IconBackgroundSpec().shadowStyle)
    }

    @Test("Explicit --icon-bg-padding and --icon-bg-shadow beat the detected defaults")
    func iconBackground_explicitFlagsWin() throws {
        let appIcon = try makeTempImageFile(inset: 0.1).path
        let keepPadding = try IconGenerationRunner().buildTestSettings(from: parseCommand(
            ["--icon-bg", appIcon, "--icon-bg-padding", "on", "--icon-bg-shadow", "macos26"]))
        #expect(keepPadding.icon.background.compensatesForPadding == false)
        #expect(keepPadding.icon.background.shadowStyle == .macOS26)

        let artwork = try makeTempImageFile(inset: 0).path
        let fillFrame = try IconGenerationRunner().buildTestSettings(from: parseCommand(
            ["--icon-bg", artwork, "--icon-bg-padding", "off", "--icon-bg-shadow", "off"]))
        #expect(fillFrame.icon.background.compensatesForPadding == true)
        #expect(fillFrame.icon.background.shadowStyle == .off)
    }

    // MARK: - The two seam defaults reach the CLI, at `.fixed`
    //
    // The CLI routes `--icon-bg`/`--badge-bg` through
    // `IconSpec.applyBackgroundImage(_:defaults:)`, taking the default argument
    // `.fixed`. It cannot do otherwise: `ImportDefaults.fromPreferences` lives in
    // `Mica/App/`, which this target does not compile — so a GUI preference is
    // structurally unable to change what `mica-cli` renders. These tests pin the
    // resulting values so the routing cannot be quietly undone.

    @Test("Any image as --icon-bg turns the corner radius off", arguments: [0.1, 0])
    func iconBackgroundImage_turnsCornerRadiusOff(inset: Double) throws {
        let path = try makeTempImageFile(inset: inset).path
        let settings = try IconGenerationRunner()
            .buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-bg", path]))
        #expect(settings.icon.background.cornerRadiusStyle == .off)
    }

    @Test("An explicit --icon-bg-corner-radius beats the import default")
    func iconBackgroundImage_explicitCornerRadiusWins() throws {
        let path = try makeTempImageFile().path
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--icon-bg", path, "--icon-bg-corner-radius", "macos26"]))
        #expect(settings.icon.background.cornerRadiusStyle == .macOS26)
    }

    @Test("--icon-bg <path> alone hides the icon foreground")
    func iconBackgroundImage_hidesForeground() throws {
        // "Alone" is the operative word, and it is new: this invocation used to
        // carry a positional symbol name that did not count towards rule 2. With
        // `--icon-symbol` it would count, so the import case is now spelled with no
        // foreground argument at all — which is also the shape a user reaches for.
        let path = try makeTempImageFile().path
        let settings = try IconGenerationRunner()
            .buildTestSettings(from: parseCommand(["--icon-bg", path]))
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
            from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:gear", "--badge-bg", path]))
        #expect(settings.badge.background.source == .image)
        #expect(settings.badge.foreground.isHidden == false)
    }

    @Test("Imported badge foreground (--badge-fg <path>) keeps the badge symbol shadow")
    func badgeForegroundImage_keepsShadow() throws {
        let path = try makeTempImageFile(inset: 0.1).path
        let command = try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", path])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.badge.foreground.source == .image)
        #expect(settings.badge.foreground.shadowStyle == ForegroundSpec.badgeDefault.shadowStyle)
    }

    @Test("An app icon as --badge-bg fills the frame and drops its shadow")
    func badgeBackgroundAppIcon_defaults() throws {
        let path = try makeTempImageFile(inset: 0.1).path
        let command = try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:gear", "--badge-bg", path])
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.badge.background.source == .image)
        #expect(settings.badge.background.compensatesForPadding == true)
        #expect(settings.badge.background.drawsShadow == false)
    }

    @Test("Full-bleed artwork as --badge-bg keeps its edges and shadow, and flags still win")
    func badgeBackgroundFullBleed_defaults() throws {
        let path = try makeTempImageFile(inset: 0).path
        let defaults = try IconGenerationRunner().buildTestSettings(from: parseCommand(
            ["--icon-symbol", "star.fill", "--badge-fg", "symbol:gear", "--badge-bg", path]))
        #expect(defaults.badge.background.compensatesForPadding == false)
        #expect(defaults.badge.background.drawsShadow == true)

        let explicit = try IconGenerationRunner().buildTestSettings(from: parseCommand(
            ["--icon-symbol", "star.fill", "--badge-fg", "symbol:gear", "--badge-bg", path,
             "--badge-bg-padding", "off", "--badge-bg-shadow", "off"]))
        #expect(explicit.badge.background.compensatesForPadding == true)
        #expect(explicit.badge.background.drawsShadow == false)
    }
}
