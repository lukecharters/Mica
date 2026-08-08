// IconForegroundFlagsTests.swift
// Covers the Phase 2 `generate` redesign: the generation-mode token mapping and
// the consolidated --icon-fg / --icon-symbol-* foreground namespace, exercised
// through argument parsing and the buildIconSettings mapping.

import Testing
import Foundation
import ArgumentParser

@Suite
@MainActor
struct IconForegroundFlagsTests {

    // MARK: - Generation-mode token mapping

    @Test("Generation-mode tokens parse directly to GenerationMode")
    func generationModeMapping() throws {
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--icon-generation-mode", "mica"]).generation.iconGenerationMode == .mica)
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--icon-generation-mode", "system"]).generation.iconGenerationMode == .system)
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--badge-generation-mode", "system"]).generation.badgeGenerationMode == .system)
    }

    @Test("Omitted generation modes are nil, and resolve to mica through the effective accessors")
    func generationModeDefaults() throws {
        // The stored properties are Optional so `--config` can tell "not passed"
        // from "passed mica"; the effective accessors carry the default, and are
        // what every read site uses.
        let command = try parseCommand(["--icon-symbol", "star.fill"])
        #expect(command.generation.iconGenerationMode == nil)
        #expect(command.generation.badgeGenerationMode == nil)
        #expect(command.generation.effectiveIconMode == .mica)
        #expect(command.generation.effectiveBadgeMode == .mica)
    }

    @Test("Omitted icon-foreground flags are nil, leaving the ForegroundSpec defaults")
    func omittedIconForegroundFlagsAreNil() throws {
        // Optional so `--config` can leave a document's stored value alone.
        // The settings-level defaults are asserted by the other tests here.
        let fg = try parseCommand(["--icon-symbol", "star.fill"]).iconForeground
        #expect(fg.scale == nil)
        #expect(fg.symbolRendering == nil)
        #expect(fg.symbolWeight == nil)
        #expect(fg.symbolGradient == nil)
        #expect(fg.visibility == nil)
    }

    // MARK: - Foreground resolution

    @Test("Positional name is shorthand for a symbol foreground")
    func positionalShorthand() throws {
        guard case .symbol(let name) = try parseCommand(["--icon-symbol", "star.fill"]).resolvedForeground() else {
            Issue.record("expected a symbol foreground"); return
        }
        #expect(name == "star.fill")
    }

    @Test("--icon-fg and --icon-symbol cannot both be given")
    func twoForegroundsAreRefused() throws {
        // This replaces a test that asserted --icon-fg *won* over the positional
        // symbol name. Nothing wins any more: the two flags say the same thing, so
        // a run naming both was more likely a mistake than a precedence question,
        // and losing silently is what the positional did wrong. The full error
        // wording is pinned by SymbolFlagTests.
        #expect(throws: ValidationError.self) {
            try parseCommand(["--icon-symbol", "gear", "--icon-fg", "symbol:bolt.fill"])
                .performValidationForTesting()
        }
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
        #expect(try parseCommand(["--icon-symbol", "star.fill"]).defaultOutputBasename() == "star.fill")
        #expect(try parseCommand(["--icon-fg", "/tmp/My Icon.png"]).defaultOutputBasename() == "My Icon")
    }

    // MARK: - Merged colour / palette through buildIconSettings

    @Test("--icon-symbol-color feeds both the monochrome and hierarchical colors")
    func mergedSymbolColor() throws {
        let red = try MicaColorValue(parsing: "red")
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-symbol-color", "red"]))
        #expect(settings.icon.foreground.color == red)
        #expect(settings.icon.foreground.hierarchicalColor == red)
    }

    @Test("--icon-symbol-palette splits into the three palette colors")
    func paletteSingleFlag() throws {
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["--icon-symbol", "gear", "--icon-symbol-rendering", "palette", "--icon-symbol-palette", "red,green,blue"])
        )
        #expect(settings.icon.foreground.renderingStyle == .palette)
        #expect(settings.icon.foreground.palettePrimaryColor == (try MicaColorValue(parsing: "red")))
        #expect(settings.icon.foreground.paletteSecondaryColor == (try MicaColorValue(parsing: "green")))
        #expect(settings.icon.foreground.paletteTertiaryColor == (try MicaColorValue(parsing: "blue")))
    }

    // MARK: - Toggles

    @Test("--icon-symbol-gradient on selects the gradient color-rendering mode")
    func gradientToggle() throws {
        let flat = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill"]))
        #expect(flat.icon.foreground.fillStyle == .flat)
        let gradient = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-symbol-gradient", "on"]))
        #expect(gradient.icon.foreground.fillStyle == .gradient)
    }

    @Test("--icon-fg-visibility off hides the foreground")
    func visibilityToggle() throws {
        let visible = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill"]))
        #expect(visible.icon.foreground.isHidden == false)
        let hidden = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-fg-visibility", "off"]))
        #expect(hidden.icon.foreground.isHidden == true)
    }

    @Test("--icon-fg-scale drives the symbol scale")
    func fgScaleSymbol() throws {
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill", "--icon-fg-scale", "1.5"]))
        #expect(settings.icon.foreground.symbolScale == 1.5)
    }

    // MARK: - Validation

    @Test("A palette without exactly three colors is rejected")
    func paletteCountValidation() {
        #expect(throws: (any Error).self) {
            try parseCommand(["--icon-symbol", "gear", "--icon-symbol-rendering", "palette", "--icon-symbol-palette", "red,green"]).performValidationForTesting()
        }
    }

    @Test("Missing foreground (no positional name, no --icon-fg) is rejected")
    func missingForegroundValidation() {
        #expect(throws: (any Error).self) {
            try parseCommand([]).performValidationForTesting()
        }
    }
}
