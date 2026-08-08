// BadgeFlagsTests.swift
// Covers the Phase 4 `generate` redesign: the consolidated --badge-fg / --badge-bg
// badge namespace (mirroring the icon foreground/background flags), exercised
// through argument parsing, the resolvers, and the buildIconSettings mapping.

import Testing
import Foundation

@Suite
@MainActor
struct BadgeFlagsTests {

    // MARK: - Absent flags

    @Test("Omitted badge flags are nil, leaving the BadgeSpec defaults")
    func omittedBadgeFlagsAreNil() throws {
        let badge = try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus"]).badge
        #expect(badge.foregroundScale == nil)
        #expect(badge.symbolRendering == nil)
        #expect(badge.symbolWeight == nil)
        #expect(badge.symbolGradient == nil)
        #expect(badge.foregroundVisibility == nil)
        #expect(badge.background == nil)
        #expect(badge.backgroundGradient == nil)
        #expect(badge.backgroundScale == nil)
        #expect(badge.backgroundVisibility == nil)
        #expect(badge.position == nil)
        #expect(badge.scale == nil)
        #expect(badge.offsetX == nil)
        #expect(badge.offsetY == nil)
        #expect(badge.isImageBackground == false)
    }

    // MARK: - Activation

    @Test("The badge is inactive unless --badge-fg is supplied")
    func activation() throws {
        #expect(try parseCommand(["--icon-symbol", "star.fill"]).badgeIsActive == false)
        #expect(try parseCommand(["--icon-symbol", "star.fill"]).resolvedBadgeForeground() == nil)
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus"]).badgeIsActive == true)
    }

    @Test("--badge-fg presence activates both badge layers (visible by default)")
    func activationVisibility() throws {
        let off = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill"]))
        #expect(off.badge.isVisible == false)
        let on = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus"]))
        #expect(on.badge.isVisible == true)
        #expect(on.badge.foreground.isHidden == false)
        #expect(on.badge.background.isHidden == false)
        #expect(on.badge.foreground.symbolName == "plus")
    }

    // MARK: - Foreground resolution

    @Test("--badge-fg symbol: resolves to an SF Symbol foreground")
    func foregroundSymbol() throws {
        guard case .symbol(let name)? = try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:bell.fill"]).resolvedBadgeForeground() else {
            Issue.record("expected a symbol badge foreground"); return
        }
        #expect(name == "bell.fill")
    }

    @Test("A non-symbol --badge-fg value is treated as an image path")
    func foregroundImage() throws {
        guard case .image(let path)? = try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "/tmp/pic.png"]).resolvedBadgeForeground() else {
            Issue.record("expected an image badge foreground"); return
        }
        #expect(path == "/tmp/pic.png")
    }

    // MARK: - Background resolution

    @Test("--badge-bg keywords resolve to the matching generated background; else image")
    func backgroundResolution() throws {
        if case .standard = try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus"]).resolvedBadgeBackground() {} else {
            Issue.record("expected a standard badge background")
        }
        if case .customGradient = try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-bg", "custom-gradient"]).resolvedBadgeBackground() {} else {
            Issue.record("expected a custom-gradient badge background")
        }
        guard case .image(let path) = try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-bg", "/tmp/bg.png"]).resolvedBadgeBackground() else {
            Issue.record("expected an image badge background"); return
        }
        #expect(path == "/tmp/bg.png")
    }

    // MARK: - Merged colour / palette through buildIconSettings

    @Test("--badge-symbol-color feeds both the monochrome and hierarchical colors")
    func mergedSymbolColor() throws {
        let red = try MicaColorValue(parsing: "red")
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-symbol-color", "red"]))
        #expect(settings.badge.foreground.color == red)
        #expect(settings.badge.foreground.hierarchicalColor == red)
    }

    @Test("--badge-symbol-palette splits into the three palette colors")
    func paletteSingleFlag() throws {
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-symbol-rendering", "palette", "--badge-symbol-palette", "red,green,blue"])
        )
        #expect(settings.badge.foreground.renderingStyle == .palette)
        #expect(settings.badge.foreground.palettePrimaryColor == (try MicaColorValue(parsing: "red")))
        #expect(settings.badge.foreground.paletteSecondaryColor == (try MicaColorValue(parsing: "green")))
        #expect(settings.badge.foreground.paletteTertiaryColor == (try MicaColorValue(parsing: "blue")))
    }

    @Test("--badge-bg-color drives the badge base color in mica mode")
    func backgroundColor() throws {
        let green = try MicaColorValue(parsing: "green")
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-bg-color", "green"]))
        #expect(settings.badge.background.usesCustomGradient == false)
        #expect(settings.badge.background.color == green)
    }

    @Test("--badge-bg custom-gradient maps the two colors and enables custom colors")
    func customGradient() throws {
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-bg", "custom-gradient", "--badge-bg-gradient-colors", "red,orange"])
        )
        #expect(settings.badge.background.usesCustomGradient == true)
        #expect(settings.badge.background.gradientStartColor == (try MicaColorValue(parsing: "red")))
        #expect(settings.badge.background.gradientEndColor == (try MicaColorValue(parsing: "orange")))
    }

    // MARK: - Toggles

    @Test("--badge-symbol-gradient on selects the gradient color-rendering mode")
    func gradientToggle() throws {
        let flat = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus"]))
        #expect(flat.badge.foreground.fillStyle == .flat)
        let gradient = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-symbol-gradient", "on"]))
        #expect(gradient.badge.foreground.fillStyle == .gradient)
    }

    @Test("--badge-fg-visibility / --badge-bg-visibility off hide their layers")
    func visibilityToggles() throws {
        let fgHidden = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-fg-visibility", "off"]))
        #expect(fgHidden.badge.foreground.isHidden == true)
        #expect(fgHidden.badge.background.isHidden == false)
        let bgHidden = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-bg-visibility", "off"]))
        #expect(bgHidden.badge.background.isHidden == true)
        #expect(bgHidden.badge.foreground.isHidden == false)
    }

    @Test("--badge-fg-scale drives the badge symbol scale")
    func fgScaleSymbol() throws {
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-fg-scale", "1.5"]))
        #expect(settings.badge.foreground.symbolScale == 1.5)
    }

    /// Size and offset are stored verbatim, however extreme. Keeping the badge on
    /// the canvas is `BadgeGeometry`'s job at render time, so the CLI neither
    /// rejects nor silently rewrites what the user asked for.
    @Test("--badge-scale and --badge-offset-* are stored unclamped")
    func scaleAndOffsetStoredVerbatim() throws {
        // `--badge-offset-y=-1.0`, not a space: ArgumentParser reads a
        // space-separated leading-dash value as another option name.
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand([
            "--icon-symbol", "star.fill", "--badge-fg", "symbol:plus",
            "--badge-scale", "2.0",
            "--badge-offset-x", "1.0",
            "--badge-offset-y=-1.0"
        ]))
        #expect(settings.badge.scale == 2.0)
        #expect(settings.badge.offsetX == 1.0)
        #expect(settings.badge.offsetY == -1.0)
    }

    @Test("--badge-bg-gradient off disables the badge background gradient")
    func bgGradientToggle() throws {
        let on = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus"]))
        #expect(on.badge.background.usesGradient == true)
        let off = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-bg-gradient", "off"]))
        #expect(off.badge.background.usesGradient == false)
    }

    @Test("Badge background shadow defaults on for generated backgrounds, off for image backgrounds")
    func bgShadowDefaults() throws {
        let symbolBg = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus"]))
        #expect(symbolBg.badge.background.drawsShadow == true)
        let path = try makeTempImageFile().path
        let imageBg = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-bg", path]))
        #expect(imageBg.badge.background.drawsShadow == false)
        let forcedOn = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-bg", path, "--badge-bg-shadow", "on"]))
        #expect(forcedOn.badge.background.drawsShadow == true)
    }

    // MARK: - System (appex) badge mode

    @Test("--badge-generation-mode system locks the badge source to Apple Reference")
    func systemBadgeSource() throws {
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-generation-mode", "system"])
        )
        #expect(settings.badge.foreground.source == .system)
    }

    @Test("System badge appex colors resolve from --badge-bg-color / --badge-symbol-color")
    func systemBadgeAppexColors() throws {
        let command = try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-generation-mode", "system", "--badge-bg-color", "red", "--badge-symbol-color", "white"])
        #expect(try command.resolvedBadgeAppexEnclosureColor(in: .none).stringValue == (try AppexColor.plistValue(fromCLIString: "red")))
        #expect(try command.resolvedBadgeAppexSymbolColor(in: .none).stringValue == (try AppexColor.plistValue(fromCLIString: "white")))
    }

    // MARK: - Validation

    @Test("--badge-bg custom-gradient without --badge-bg-gradient-colors is rejected")
    func customGradientRequiresColors() {
        #expect(throws: (any Error).self) {
            try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-bg", "custom-gradient"]).performValidationForTesting()
        }
    }

    @Test("A badge palette without exactly three colors is rejected")
    func paletteCountValidation() {
        #expect(throws: (any Error).self) {
            try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus", "--badge-symbol-rendering", "palette", "--badge-symbol-palette", "red,green"]).performValidationForTesting()
        }
    }

    @Test("System badge mode with an image foreground is rejected")
    func systemBadgeImageRejected() {
        #expect(throws: (any Error).self) {
            try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "/tmp/pic.png", "--badge-generation-mode", "system"]).performValidationForTesting()
        }
    }

    @Test("An empty 'symbol:' badge foreground is rejected")
    func emptySymbolRejected() {
        #expect(throws: (any Error).self) {
            try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:"]).performValidationForTesting()
        }
    }
}
