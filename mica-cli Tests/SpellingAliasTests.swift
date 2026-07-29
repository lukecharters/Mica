// SpellingAliasTests.swift
// Covers the British/Australian English spelling accommodations: the
// --…-colour flag aliases on generate and extract, grey→gray value
// normalisation (prerendered asset names and appex tokens), and the
// multicolour rendering-mode spelling.

import Testing
import Foundation
import ArgumentParser

@Suite
@MainActor
struct SpellingAliasTests {

    // MARK: - normalizeBritishSpelling helper

    @Test("normalizeBritishSpelling maps colour→color and grey→gray", arguments: [
        ("multicolour", "multicolor"),
        ("grey", "gray"),
        ("darkgrey", "darkgray"),
        ("LightGrey", "lightgray"),
        ("blue", "blue"),
        ("Multicolor", "multicolor"),
    ])
    func normalisesSpelling(_ pair: (String, String)) {
        #expect(normalizeBritishSpelling(pair.0) == pair.1)
    }

    // MARK: - generate: flag aliases parse identically to US spellings

    @Test("--colour-space is an alias for --color-space")
    func colourSpaceAlias() throws {
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["star.fill", "--colour-space", "displayP3"]))
        #expect(settings.export.colorSpace == .displayP3)
    }

    @Test("--icon-symbol-colour is an alias for --icon-symbol-color")
    func iconSymbolColourAlias() throws {
        let command = try parseCommand(["star.fill", "--icon-symbol-colour", "red"])
        #expect(command.iconForeground.symbolColor == "red")
    }

    @Test("--icon-bg-colour is an alias for --icon-bg-color")
    func iconBackgroundColourAlias() throws {
        let command = try parseCommand(["star.fill", "--icon-bg-colour", "red"])
        #expect(command.background.color == "red")
    }

    @Test("--icon-bg-gradient-colours is an alias for --icon-bg-gradient-colors")
    func iconGradientColoursAlias() throws {
        let command = try parseCommand([
            "star.fill", "--icon-bg", "custom-gradient",
            "--icon-bg-gradient-colours", "red,blue",
        ])
        #expect(command.background.gradientColors == "red,blue")
    }

    @Test("--badge-symbol-colour is an alias for --badge-symbol-color")
    func badgeSymbolColourAlias() throws {
        let command = try parseCommand([
            "star.fill", "--badge-fg", "symbol:plus.circle",
            "--badge-symbol-colour", "yellow",
        ])
        #expect(command.badge.symbolColor == "yellow")
    }

    @Test("--badge-bg-colour is an alias for --badge-bg-color")
    func badgeBackgroundColourAlias() throws {
        let command = try parseCommand([
            "star.fill", "--badge-fg", "symbol:plus.circle",
            "--badge-bg-colour", "teal",
        ])
        #expect(command.badge.backgroundColor == "teal")
    }

    @Test("--badge-bg-gradient-colours is an alias for --badge-bg-gradient-colors")
    func badgeGradientColoursAlias() throws {
        let command = try parseCommand([
            "star.fill", "--badge-fg", "symbol:plus.circle",
            "--badge-bg", "custom-gradient",
            "--badge-bg-gradient-colours", "red,orange",
        ])
        #expect(command.badge.backgroundGradientColors == "red,orange")
    }

    // MARK: - Rendering-mode value spelling

    @Test("--icon-symbol-rendering accepts multicolour")
    func iconRenderingMulticolour() throws {
        let command = try parseCommand(["star.fill", "--icon-symbol-rendering", "multicolour"])
        #expect(command.iconForeground.symbolRendering == "multicolor")
    }

    @Test("--badge-symbol-rendering accepts multicolour")
    func badgeRenderingMulticolour() throws {
        let command = try parseCommand([
            "star.fill", "--badge-fg", "symbol:plus.circle",
            "--badge-symbol-rendering", "multicolour",
        ])
        #expect(command.badge.symbolRendering == "multicolor")
    }

    // MARK: - Prerendered colour names accept grey spellings

    @Test("prerendered-liquid-glass accepts grey colour names", arguments: ["grey", "darkgrey", "lightgrey"])
    func preRenderedGreyValidates(_ name: String) throws {
        let command = try parseCommand([
            "star.fill", "--icon-bg", "prerendered-liquid-glass",
            "--icon-bg-colour", name,
        ])
        try command.performValidationForTesting()
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.icon.background.preRenderedColorName == normalizeBritishSpelling(name))
    }

    // MARK: - Appex tokens accept grey

    @Test("appex colour resolution maps grey to Apple's gray token")
    func appexGreyToken() throws {
        #expect(try AppexColor.plistValue(fromCLIString: "grey") == "gray")
        #expect(try AppexColor.plistValue(fromCLIString: "gray") == "gray")
    }

    // MARK: - extract: --colour-space alias

    @Test("extract accepts --colour-space as an alias for --color-space")
    func extractColourSpaceAlias() throws {
        let command = try ExtractCommand.parse(["/some/path", "--colour-space", "displayP3"])
        #expect(command.colorSpace == .displayP3)
    }
}
