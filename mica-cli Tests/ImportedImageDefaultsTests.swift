// ImportedImageDefaultsTests.swift
// Mirrors the GUI's imported-image defaults in the CLI: when an image source is
// used, padding compensation defaults on (fill the frame) for backgrounds and
// the imported-image shadow defaults off, while the inverse flags keep both
// fully overridable. SF Symbol sources keep shadows on.

import Testing
import Foundation
@testable import mica_cli

@Suite
@MainActor
struct ImportedImageDefaultsTests {

    // MARK: - Resolved defaults on the parsed options (no file needed)

    @Test("Background shadow defaults off for imported backgrounds, macOS 26 otherwise")
    func effectiveShadowStyle_imageAware() throws {
        #expect(try parseCommand(["star.fill"]).background.effectiveShadowStyle == "macos26")
        #expect(try parseCommand(["star.fill", "--background-mode", "image"]).background.effectiveShadowStyle == "off")
    }

    @Test("Explicit --background-shadow-style overrides the imported-background default")
    func effectiveShadowStyle_explicitOverride() throws {
        let command = try parseCommand(["star.fill", "--background-mode", "image", "--background-shadow-style", "macos26"])
        #expect(command.background.effectiveShadowStyle == "macos26")
    }

    @Test("Background padding compensation defaults on and is opt-out")
    func effectivePaddingCompensation_default() throws {
        #expect(try parseCommand(["star.fill"]).background.effectivePaddingCompensation == true)
        #expect(try parseCommand(["star.fill", "--no-imported-background-padding-compensation"]).background.effectivePaddingCompensation == false)
        #expect(try parseCommand(["star.fill", "--imported-background-padding-compensation"]).background.effectivePaddingCompensation == true)
    }

    @Test("Badge background padding compensation defaults on and is opt-out")
    func effectiveBadgePaddingCompensation_default() throws {
        #expect(try parseCommand(["star.fill", "--badge", "gear"]).badge.effectiveBadgePaddingCompensation == true)
        #expect(try parseCommand(["star.fill", "--badge", "gear", "--no-badge-imported-background-padding-compensation"]).badge.effectiveBadgePaddingCompensation == false)
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
        let settings = try IconGeneratorCLI().buildTestSettings(from: command)
        #expect(settings.iconSource == .customImage)
        #expect(settings.enableSymbolShadow == false)
    }

    @Test("SF Symbol icon keeps its shadow on")
    func iconSymbol_shadowOn() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill"]))
        #expect(settings.enableSymbolShadow == true)
    }

    @Test("--icon-fg-shadow on forces the shadow back on for an imported image")
    func iconForegroundImage_explicitShadowOn() throws {
        let path = try makeTempImageFile().path
        let command = try parseCommand(["--icon-fg", path, "--icon-fg-shadow", "on"])
        let settings = try IconGeneratorCLI().buildTestSettings(from: command)
        #expect(settings.enableSymbolShadow == true)
    }

    @Test("Imported icon background fills the frame and drops its shadow")
    func iconBackgroundImage_defaults() throws {
        let path = try makeTempImageFile().path
        let command = try parseCommand(["star.fill", "--background-mode", "image", "--imported-background", path])
        let settings = try IconGeneratorCLI().buildTestSettings(from: command)
        #expect(settings.backgroundMode == .importedImage)
        #expect(settings.importedBackgroundPaddingCompensation == true)
        #expect(settings.backgroundShadowStyle == .off)
    }

    @Test("Imported badge foreground turns the badge symbol shadow off")
    func badgeForegroundImage_shadowOff() throws {
        let path = try makeTempImageFile().path
        let command = try parseCommand(["star.fill", "--badge", "gear", "--badge-icon-source", "image", "--badge-imported-image", path])
        let settings = try IconGeneratorCLI().buildTestSettings(from: command)
        #expect(settings.badgeIconSource == .customImage)
        #expect(settings.badgeEnableSymbolShadow == false)
    }

    @Test("Imported badge background fills the frame and drops its shadow")
    func badgeBackgroundImage_defaults() throws {
        let path = try makeTempImageFile().path
        let command = try parseCommand(["star.fill", "--badge", "gear", "--badge-imported-background", path])
        let settings = try IconGeneratorCLI().buildTestSettings(from: command)
        #expect(settings.badgeUseImportedBackground == true)
        #expect(settings.badgeImportedBackgroundPaddingCompensation == true)
        #expect(settings.badgeEnableBackgroundShadow == false)
    }
}
