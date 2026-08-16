// IconBackgroundFlagsTests.swift
// Covers the Phase 3 `generate` redesign: the consolidated --icon-bg /
// --icon-bg-* background namespace, exercised through argument parsing and the
// buildIconSettings mapping.

import Testing
import Foundation
import ArgumentParser

@Suite
@MainActor
struct IconBackgroundFlagsTests {

    // MARK: - Absent flags

    @Test("Omitted icon-background flags are nil, leaving the IconBackgroundSpec defaults")
    func omittedIconBackgroundFlagsAreNil() throws {
        let bg = try parseCommand(["--icon-symbol", "star.fill"]).background
        #expect(bg.selection == nil)
        #expect(bg.gradient == nil)
        #expect(bg.cornerRadius == nil)
        #expect(bg.scale == nil)
        #expect(bg.visibility == nil)
        // A nil --icon-bg still resolves to the generated background, not a path.
        #expect(bg.isImageBackground == false)
    }

    // MARK: - Background resolution

    @Test("--icon-bg resolves the three background kinds")
    func backgroundResolution() throws {
        if case .standard = try parseCommand(["--icon-symbol", "star.fill"]).resolvedBackground() {} else { Issue.record("expected standard") }
        if case .customGradient = try parseCommand(["--icon-symbol", "star.fill", "--icon-bg", "custom-gradient", "--icon-bg-gradient-colors", "red,blue"]).resolvedBackground() {} else { Issue.record("expected custom-gradient") }
        guard case .image(let path) = try parseCommand(["--icon-symbol", "star.fill", "--icon-bg", "/tmp/bg.png"]).resolvedBackground() else {
            Issue.record("expected image"); return
        }
        #expect(path == "/tmp/bg.png")
    }

    // MARK: - Standard background

    @Test("Standard background uses --icon-bg-color as the base color")
    func standardBaseColor() throws {
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-bg-color", "red"]))
        #expect(settings.icon.background.source == .color)
        #expect(settings.icon.background.usesCustomGradient == false)
        #expect(settings.icon.background.color == (try MicaColorValue(parsing: "red")))
    }

    // MARK: - Custom gradient

    @Test("custom-gradient maps --icon-bg-gradient-colors to the two custom colors")
    func customGradientColors() throws {
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--icon-bg", "custom-gradient", "--icon-bg-gradient-colors", "red,blue"])
        )
        #expect(settings.icon.background.source == .color)
        #expect(settings.icon.background.usesCustomGradient == true)
        #expect(settings.icon.background.gradientStartColor == (try MicaColorValue(parsing: "red")))
        #expect(settings.icon.background.gradientEndColor == (try MicaColorValue(parsing: "blue")))
    }

    // MARK: - The retired pre-rendered background

    /// Removed on 2026-08-16. The flag has to fail by *name*: `IconBackgroundValue`
    /// no longer has a case for it, so an unscreened value would parse as an image
    /// path and be reported as a missing file the user never wrote.
    @Test("prerendered-liquid-glass is refused, and the error names it",
          arguments: ["prerendered-liquid-glass", "PreRendered-Liquid-Glass"])
    func preRenderedIsRetired(_ token: String) throws {
        let command = try parseCommand(["--icon-symbol", "star.fill", "--icon-bg", token])
        let error = #expect(throws: ValidationError.self) {
            try command.performValidationForTesting()
        }
        let message = try #require(error).description
        #expect(message.contains(token))
        #expect(message.contains("no longer available"))
        #expect(!message.lowercased().contains("file not found"))
    }

    /// The retired keyword is not a path, so nothing downstream may treat it as one
    /// — `validate()` throwing is the only thing that should happen to it.
    @Test("the retired keyword is not read as an image background")
    func preRenderedIsNotAnImagePath() throws {
        let command = try parseCommand(["--icon-symbol", "star.fill", "--icon-bg", "prerendered-liquid-glass"])
        #expect(command.background.isImageBackground == false)
    }

    // MARK: - Style toggles

    @Test("--icon-bg-gradient toggles the background gradient")
    func gradientToggle() throws {
        #expect(try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill"])).icon.background.usesGradient == true)
        #expect(try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-bg-gradient", "off"])).icon.background.usesGradient == false)
    }

    @Test("--icon-bg-corner-radius maps to the corner-radius style")
    func cornerRadius() throws {
        #expect(try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill"])).icon.background.cornerRadiusStyle == .macOS26)
        #expect(try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-bg-corner-radius", "macos15"])).icon.background.cornerRadiusStyle == .macOS15)
        #expect(try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-bg-corner-radius", "off"])).icon.background.cornerRadiusStyle == .off)
    }

    // "macos15" replaced "macos11" as the token for the macOS 11–15 design on
    // 2026-08-08. The old spelling is still accepted on both flags so scripts
    // and exported configurations written before then keep working; it is never
    // written back — `SettingsTokensTests` pins that half.
    @Test("The superseded macos11 token still parses on both style flags")
    func supersededTokenStillParses() throws {
        let radius = try IconGenerationRunner()
            .buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-bg-corner-radius", "macos11"]))
        #expect(radius.icon.background.cornerRadiusStyle == .macOS15)

        let shadow = try IconGenerationRunner()
            .buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-bg-shadow", "macos11"]))
        #expect(shadow.icon.background.shadowStyle == .macOS15)
    }

    @Test("--icon-bg-visibility off hides the background")
    func visibilityToggle() throws {
        #expect(try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill"])).icon.background.isHidden == false)
        #expect(try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-bg-visibility", "off"])).icon.background.isHidden == true)
    }

    // MARK: - Validation

    @Test("custom-gradient without --icon-bg-gradient-colors is rejected")
    func customGradientRequiresColors() {
        #expect(throws: (any Error).self) {
            try parseCommand(["--icon-symbol", "star.fill", "--icon-bg", "custom-gradient"]).performValidationForTesting()
        }
    }

    @Test("--icon-bg-gradient-colors requires exactly two colors")
    func gradientColorsCountValidation() {
        #expect(throws: (any Error).self) {
            try parseCommand(["--icon-symbol", "star.fill", "--icon-bg", "custom-gradient", "--icon-bg-gradient-colors", "red,green,blue"]).performValidationForTesting()
        }
    }
}
