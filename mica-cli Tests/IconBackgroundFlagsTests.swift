// IconBackgroundFlagsTests.swift
// Covers the Phase 3 `generate` redesign: the consolidated --icon-bg /
// --icon-bg-* background namespace, exercised through argument parsing and the
// buildIconSettings mapping.

import Testing
import Foundation

@Suite
@MainActor
struct IconBackgroundFlagsTests {

    // MARK: - Background resolution

    @Test("--icon-bg resolves the four background kinds")
    func backgroundResolution() throws {
        if case .standard = try parseCommand(["star.fill"]).resolvedBackground() {} else { Issue.record("expected standard") }
        if case .customGradient = try parseCommand(["star.fill", "--icon-bg", "custom-gradient", "--icon-bg-gradient-colors", "red,blue"]).resolvedBackground() {} else { Issue.record("expected custom-gradient") }
        if case .preRendered = try parseCommand(["star.fill", "--icon-bg", "prerendered-liquid-glass"]).resolvedBackground() {} else { Issue.record("expected preRendered") }
        guard case .image(let path) = try parseCommand(["star.fill", "--icon-bg", "/tmp/bg.png"]).resolvedBackground() else {
            Issue.record("expected image"); return
        }
        #expect(path == "/tmp/bg.png")
    }

    // MARK: - Standard background

    @Test("Standard background uses --icon-bg-color as the base color")
    func standardBaseColor() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--icon-bg-color", "red"]))
        #expect(settings.backgroundMode == .custom)
        #expect(settings.useCustomColors == false)
        #expect(settings.baseColor == (try ColorParser.parse("red")))
    }

    // MARK: - Custom gradient

    @Test("custom-gradient maps --icon-bg-gradient-colors to the two custom colors")
    func customGradientColors() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(
            from: parseCommand(["star.fill", "--icon-bg", "custom-gradient", "--icon-bg-gradient-colors", "red,blue"])
        )
        #expect(settings.backgroundMode == .custom)
        #expect(settings.useCustomColors == true)
        #expect(settings.customPrimaryColor == (try ColorParser.parse("red")))
        #expect(settings.customSecondaryColor == (try ColorParser.parse("blue")))
    }

    // MARK: - Pre-rendered (Liquid Glass)

    @Test("prerendered-liquid-glass selects the named gradient/solid asset")
    func preRenderedAsset() throws {
        let gradient = try IconGeneratorCLI().buildTestSettings(
            from: parseCommand(["star.fill", "--icon-bg", "prerendered-liquid-glass", "--icon-bg-color", "darkgray"])
        )
        #expect(gradient.backgroundMode == .preRendered)
        #expect(gradient.preRenderedAssetName == "background-darkgray-gradient")

        let solid = try IconGeneratorCLI().buildTestSettings(
            from: parseCommand(["star.fill", "--icon-bg", "prerendered-liquid-glass", "--icon-bg-color", "darkgray", "--icon-bg-gradient", "off"])
        )
        #expect(solid.preRenderedAssetName == "background-darkgray-solid")
    }

    // MARK: - Style toggles

    @Test("--icon-bg-gradient toggles the background gradient")
    func gradientToggle() throws {
        #expect(try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill"])).enableBackgroundGradient == true)
        #expect(try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--icon-bg-gradient", "off"])).enableBackgroundGradient == false)
    }

    @Test("--icon-bg-corner-radius maps to the corner-radius style")
    func cornerRadius() throws {
        #expect(try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill"])).cornerRadiusStyle == .macOS26)
        #expect(try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--icon-bg-corner-radius", "macos11"])).cornerRadiusStyle == .macOS11)
    }

    @Test("--icon-bg-visibility off hides the background")
    func visibilityToggle() throws {
        #expect(try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill"])).iconBackgroundHidden == false)
        #expect(try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--icon-bg-visibility", "off"])).iconBackgroundHidden == true)
    }

    // MARK: - Validation

    @Test("custom-gradient without --icon-bg-gradient-colors is rejected")
    func customGradientRequiresColors() {
        #expect(throws: (any Error).self) {
            try parseCommand(["star.fill", "--icon-bg", "custom-gradient"]).performValidationForTesting()
        }
    }

    @Test("prerendered-liquid-glass rejects a non-asset color")
    func preRenderedColorValidation() {
        #expect(throws: (any Error).self) {
            try parseCommand(["star.fill", "--icon-bg", "prerendered-liquid-glass", "--icon-bg-color", "maroon"]).performValidationForTesting()
        }
    }

    @Test("--icon-bg-gradient-colors requires exactly two colors")
    func gradientColorsCountValidation() {
        #expect(throws: (any Error).self) {
            try parseCommand(["star.fill", "--icon-bg", "custom-gradient", "--icon-bg-gradient-colors", "red,green,blue"]).performValidationForTesting()
        }
    }
}
