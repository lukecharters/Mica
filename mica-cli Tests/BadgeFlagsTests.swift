// BadgeFlagsTests.swift
// Covers the Phase 4 `generate` redesign: the consolidated --badge-fg / --badge-bg
// badge namespace (mirroring the icon foreground/background flags), exercised
// through argument parsing, the resolvers, and the buildIconSettings mapping.

import Testing
import Foundation

@Suite
@MainActor
struct BadgeFlagsTests {

    // MARK: - Activation

    @Test("The badge is inactive unless --badge-fg is supplied")
    func activation() throws {
        #expect(try parseCommand(["star.fill"]).badgeIsActive == false)
        #expect(try parseCommand(["star.fill"]).resolvedBadgeForeground() == nil)
        #expect(try parseCommand(["star.fill", "--badge-fg", "symbol:plus"]).badgeIsActive == true)
    }

    @Test("--badge-fg presence activates both badge layers (visible by default)")
    func activationVisibility() throws {
        let off = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill"]))
        #expect(off.showBadge == false)
        let on = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus"]))
        #expect(on.showBadge == true)
        #expect(on.badgeForegroundHidden == false)
        #expect(on.badgeBackgroundHidden == false)
        #expect(on.badgeSymbolName == "plus")
    }

    // MARK: - Foreground resolution

    @Test("--badge-fg symbol: resolves to an SF Symbol foreground")
    func foregroundSymbol() throws {
        guard case .symbol(let name)? = try parseCommand(["star.fill", "--badge-fg", "symbol:bell.fill"]).resolvedBadgeForeground() else {
            Issue.record("expected a symbol badge foreground"); return
        }
        #expect(name == "bell.fill")
    }

    @Test("A non-symbol --badge-fg value is treated as an image path")
    func foregroundImage() throws {
        guard case .image(let path)? = try parseCommand(["star.fill", "--badge-fg", "/tmp/pic.png"]).resolvedBadgeForeground() else {
            Issue.record("expected an image badge foreground"); return
        }
        #expect(path == "/tmp/pic.png")
    }

    // MARK: - Background resolution

    @Test("--badge-bg keywords resolve to the matching generated background; else image")
    func backgroundResolution() throws {
        if case .standard = try parseCommand(["star.fill", "--badge-fg", "symbol:plus"]).resolvedBadgeBackground() {} else {
            Issue.record("expected a standard badge background")
        }
        if case .customGradient = try parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-bg", "custom-gradient"]).resolvedBadgeBackground() {} else {
            Issue.record("expected a custom-gradient badge background")
        }
        guard case .image(let path) = try parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-bg", "/tmp/bg.png"]).resolvedBadgeBackground() else {
            Issue.record("expected an image badge background"); return
        }
        #expect(path == "/tmp/bg.png")
    }

    // MARK: - Merged colour / palette through buildIconSettings

    @Test("--badge-symbol-color feeds both the monochrome and hierarchical colors")
    func mergedSymbolColor() throws {
        let red = try ColorParser.parse("red")
        let settings = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-symbol-color", "red"]))
        #expect(settings.badgeSymbolColor == red)
        #expect(settings.badgeHierarchicalSymbolColor == red)
    }

    @Test("--badge-symbol-palette splits into the three palette colors")
    func paletteSingleFlag() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(
            from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-symbol-rendering", "palette", "--badge-symbol-palette", "red,green,blue"])
        )
        #expect(settings.badgeSymbolRenderingMode == .palette)
        #expect(settings.badgePaletteSymbolPrimaryColor == (try ColorParser.parse("red")))
        #expect(settings.badgePaletteSymbolSecondaryColor == (try ColorParser.parseWithOpacity("green")))
        #expect(settings.badgePaletteSymbolTertiaryColor == (try ColorParser.parseWithOpacity("blue")))
    }

    @Test("--badge-bg-color drives the badge base color in mica mode")
    func backgroundColor() throws {
        let green = try ColorParser.parse("green")
        let settings = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-bg-color", "green"]))
        #expect(settings.badgeUseCustomColors == false)
        #expect(settings.badgeBaseColor == green)
    }

    @Test("--badge-bg custom-gradient maps the two colors and enables custom colors")
    func customGradient() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(
            from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-bg", "custom-gradient", "--badge-bg-gradient-colors", "red,orange"])
        )
        #expect(settings.badgeUseCustomColors == true)
        #expect(settings.badgeCustomPrimaryColor == (try ColorParser.parse("red")))
        #expect(settings.badgeCustomSecondaryColor == (try ColorParser.parse("orange")))
    }

    // MARK: - Toggles

    @Test("--badge-symbol-gradient on selects the gradient color-rendering mode")
    func gradientToggle() throws {
        let flat = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus"]))
        #expect(flat.badgeSymbolColorRenderingMode == .flat)
        let gradient = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-symbol-gradient", "on"]))
        #expect(gradient.badgeSymbolColorRenderingMode == .gradient)
    }

    @Test("--badge-fg-visibility / --badge-bg-visibility off hide their layers")
    func visibilityToggles() throws {
        let fgHidden = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-fg-visibility", "off"]))
        #expect(fgHidden.badgeForegroundHidden == true)
        #expect(fgHidden.badgeBackgroundHidden == false)
        let bgHidden = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-bg-visibility", "off"]))
        #expect(bgHidden.badgeBackgroundHidden == true)
        #expect(bgHidden.badgeForegroundHidden == false)
    }

    @Test("--badge-fg-scale drives the badge symbol scale")
    func fgScaleSymbol() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-fg-scale", "1.5"]))
        #expect(settings.badgeSymbolScale == 1.5)
    }

    /// Size and offset are stored verbatim, however extreme. Keeping the badge on
    /// the canvas is `BadgeGeometry`'s job at render time, so the CLI neither
    /// rejects nor silently rewrites what the user asked for.
    @Test("--badge-scale and --badge-offset-* are stored unclamped")
    func scaleAndOffsetStoredVerbatim() throws {
        // `--badge-offset-y=-1.0`, not a space: ArgumentParser reads a
        // space-separated leading-dash value as another option name.
        let settings = try IconGeneratorCLI().buildTestSettings(from: parseCommand([
            "star.fill", "--badge-fg", "symbol:plus",
            "--badge-scale", "2.0",
            "--badge-offset-x", "1.0",
            "--badge-offset-y=-1.0"
        ]))
        #expect(settings.badgeScale == 2.0)
        #expect(settings.badgeManualOffsetX == 1.0)
        #expect(settings.badgeManualOffsetY == -1.0)
    }

    @Test("--badge-bg-gradient off disables the badge background gradient")
    func bgGradientToggle() throws {
        let on = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus"]))
        #expect(on.badgeEnableBackgroundGradient == true)
        let off = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-bg-gradient", "off"]))
        #expect(off.badgeEnableBackgroundGradient == false)
    }

    @Test("Badge background shadow defaults on for generated backgrounds, off for image backgrounds")
    func bgShadowDefaults() throws {
        let symbolBg = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus"]))
        #expect(symbolBg.badgeEnableBackgroundShadow == true)
        let path = try makeTempImageFile().path
        let imageBg = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-bg", path]))
        #expect(imageBg.badgeEnableBackgroundShadow == false)
        let forcedOn = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-bg", path, "--badge-bg-shadow", "on"]))
        #expect(forcedOn.badgeEnableBackgroundShadow == true)
    }

    // MARK: - System (appex) badge mode

    @Test("--badge-generation-mode system locks the badge source to Apple Reference")
    func systemBadgeSource() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(
            from: parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-generation-mode", "system"])
        )
        #expect(settings.badgeIconSource == .system)
    }

    @Test("System badge appex colors resolve from --badge-bg-color / --badge-symbol-color")
    func systemBadgeAppexColors() throws {
        let command = try parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-generation-mode", "system", "--badge-bg-color", "red", "--badge-symbol-color", "white"])
        #expect(try command.resolvedBadgeAppexEnclosureColor() == (try AppexColor.plistValue(fromCLIString: "red")))
        #expect(try command.resolvedBadgeAppexSymbolColor() == (try AppexColor.plistValue(fromCLIString: "white")))
    }

    // MARK: - Validation

    @Test("--badge-bg custom-gradient without --badge-bg-gradient-colors is rejected")
    func customGradientRequiresColors() {
        #expect(throws: (any Error).self) {
            try parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-bg", "custom-gradient"]).performValidationForTesting()
        }
    }

    @Test("A badge palette without exactly three colors is rejected")
    func paletteCountValidation() {
        #expect(throws: (any Error).self) {
            try parseCommand(["star.fill", "--badge-fg", "symbol:plus", "--badge-symbol-rendering", "palette", "--badge-symbol-palette", "red,green"]).performValidationForTesting()
        }
    }

    @Test("System badge mode with an image foreground is rejected")
    func systemBadgeImageRejected() {
        #expect(throws: (any Error).self) {
            try parseCommand(["star.fill", "--badge-fg", "/tmp/pic.png", "--badge-generation-mode", "system"]).performValidationForTesting()
        }
    }

    @Test("An empty 'symbol:' badge foreground is rejected")
    func emptySymbolRejected() {
        #expect(throws: (any Error).self) {
            try parseCommand(["star.fill", "--badge-fg", "symbol:"]).performValidationForTesting()
        }
    }
}
