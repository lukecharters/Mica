// IconForegroundFlagsTests.swift
// Covers the Phase 2 `generate` redesign: the generation-mode token mapping and
// the consolidated --icon-fg / --icon-symbol-* foreground namespace, exercised
// through argument parsing and the buildIconSettings mapping.

import Testing
import Foundation

@Suite
@MainActor
struct IconForegroundFlagsTests {

    // MARK: - Generation-mode token mapping

    @Test("Generation-mode tokens map mica→custom, system→apple-reference")
    func generationModeMapping() throws {
        #expect(try parseCommand(["star.fill"]).generation.resolvedIconMode == "custom")
        #expect(try parseCommand(["star.fill", "--icon-generation-mode", "mica"]).generation.resolvedIconMode == "custom")
        #expect(try parseCommand(["star.fill", "--icon-generation-mode", "system"]).generation.resolvedIconMode == "apple-reference")
        #expect(try parseCommand(["star.fill", "--badge-generation-mode", "system"]).generation.resolvedBadgeMode == "apple-reference")
    }

    // MARK: - Foreground resolution

    @Test("Positional name is shorthand for a symbol foreground")
    func positionalShorthand() throws {
        guard case .symbol(let name) = try parseCommand(["star.fill"]).resolvedForeground() else {
            Issue.record("expected a symbol foreground"); return
        }
        #expect(name == "star.fill")
    }

    @Test("Explicit --icon-fg symbol: wins over the positional name")
    func explicitForegroundWins() throws {
        guard case .symbol(let name) = try parseCommand(["gear", "--icon-fg", "symbol:bolt.fill"]).resolvedForeground() else {
            Issue.record("expected a symbol foreground"); return
        }
        #expect(name == "bolt.fill")
    }

    @Test("A non-symbol --icon-fg value is treated as an image path")
    func imageForeground() throws {
        guard case .image(let path) = try parseCommand(["--icon-fg", "/tmp/pic.png"]).resolvedForeground() else {
            Issue.record("expected an image foreground"); return
        }
        #expect(path == "/tmp/pic.png")
    }

    @Test("Default output basename comes from the symbol name or the image basename")
    func defaultBasename() throws {
        #expect(try parseCommand(["star.fill"]).defaultOutputBasename() == "star.fill")
        #expect(try parseCommand(["--icon-fg", "/tmp/My Icon.png"]).defaultOutputBasename() == "My Icon")
    }

    // MARK: - Merged colour / palette through buildIconSettings

    @Test("--icon-symbol-color feeds both the monochrome and hierarchical colors")
    func mergedSymbolColor() throws {
        let red = try ColorParser.parse("red")
        let settings = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--icon-symbol-color", "red"]))
        #expect(settings.symbolColor == red)
        #expect(settings.hierarchicalSymbolColor == red)
    }

    @Test("--icon-symbol-palette splits into the three palette colors")
    func paletteSingleFlag() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(
            from: parseCommand(["gear", "--icon-symbol-rendering", "palette", "--icon-symbol-palette", "red,green,blue"])
        )
        #expect(settings.symbolRenderingMode == .palette)
        #expect(settings.paletteSymbolPrimaryColor == (try ColorParser.parse("red")))
        #expect(settings.paletteSymbolSecondaryColor == (try ColorParser.parseWithOpacity("green")))
        #expect(settings.paletteSymbolTertiaryColor == (try ColorParser.parseWithOpacity("blue")))
    }

    // MARK: - Toggles

    @Test("--icon-symbol-gradient on selects the gradient color-rendering mode")
    func gradientToggle() throws {
        let flat = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill"]))
        #expect(flat.symbolColorRenderingMode == .flat)
        let gradient = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--icon-symbol-gradient", "on"]))
        #expect(gradient.symbolColorRenderingMode == .gradient)
    }

    @Test("--icon-fg-visibility off hides the foreground")
    func visibilityToggle() throws {
        let visible = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill"]))
        #expect(visible.iconForegroundHidden == false)
        let hidden = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--icon-fg-visibility", "off"]))
        #expect(hidden.iconForegroundHidden == true)
    }

    @Test("--icon-fg-scale drives the symbol scale")
    func fgScaleSymbol() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill", "--icon-fg-scale", "1.5"]))
        #expect(settings.manualSymbolScale == 1.5)
    }

    // MARK: - Validation

    @Test("A palette without exactly three colors is rejected")
    func paletteCountValidation() {
        #expect(throws: (any Error).self) {
            try parseCommand(["gear", "--icon-symbol-rendering", "palette", "--icon-symbol-palette", "red,green"]).performValidationForTesting()
        }
    }

    @Test("Missing foreground (no positional name, no --icon-fg) is rejected")
    func missingForegroundValidation() {
        #expect(throws: (any Error).self) {
            try parseCommand([]).performValidationForTesting()
        }
    }
}
