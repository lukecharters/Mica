// ColorOpacityFlagsTests.swift
// Every option taking a colour accepts the same set of forms, including a
// `:opacity` suffix. That was not true until 2026-07-29: only palette slots 2 and
// 3 went through `parseWithOpacity`, so `--icon-symbol-color white:0.5` and even
// `--icon-symbol-palette 'blue:0.8,…'` were rejected while the GUI's colour wells
// allowed alpha on every one of them.
//
// The flag list below is the anti-drift device. A new colour option, or one that
// quietly reverts to `ColorParser.parse`, shows up here rather than as a user
// discovering the inconsistency.

import Testing
import SwiftUI
import AppKit
@testable import Mica

@Suite struct ColorOpacityFlagsTests {

    /// Alpha of a colour as the settings hold it.
    private func alpha(_ color: Color) -> Double {
        Double(NSColor(color).usingColorSpace(.extendedSRGB)?.alphaComponent ?? -1)
    }

    /// The alpha a stored colour renders at. Reads through `resolved`, so it
    /// measures what reaches the canvas whether the value kept a token plus an
    /// alpha modifier or folded everything into components.
    private func alpha(_ value: MicaColorValue) -> Double {
        alpha(value.resolved)
    }

    // MARK: - Every single-colour option

    /// One colour option: the args that set it to 50% opacity, and how to read that
    /// colour back out of the built settings.
    private struct ColorFlagCase: Sendable {
        let flag: String
        let args: [String]
        let read: @Sendable (IconSettings) -> MicaColorValue
    }

    private static let singleColorFlags: [ColorFlagCase] = [
        ColorFlagCase(flag: "--icon-symbol-color",
                      args: ["star.fill", "--icon-symbol-color", "white:0.5"],
                      read: { $0.icon.foreground.color }),
        ColorFlagCase(flag: "--icon-symbol-color (hierarchical)",
                      args: ["star.fill", "--icon-symbol-rendering", "hierarchical", "--icon-symbol-color", "white:0.5"],
                      read: { $0.icon.foreground.hierarchicalColor }),
        ColorFlagCase(flag: "--icon-bg-color",
                      args: ["star.fill", "--icon-bg-color", "blue:0.5"],
                      read: { $0.icon.background.color }),
        ColorFlagCase(flag: "--badge-symbol-color",
                      args: ["star.fill", "--badge-fg", "symbol:plus", "--badge-symbol-color", "white:0.5"],
                      read: { $0.badge.foreground.color }),
        ColorFlagCase(flag: "--badge-bg-color",
                      args: ["star.fill", "--badge-fg", "symbol:plus", "--badge-bg-color", "gray:0.5"],
                      read: { $0.badge.background.color }),
    ]

    @Test("every single-colour option accepts a :opacity suffix and keeps the alpha",
          arguments: singleColorFlags.map(\.flag))
    func singleColorFlagsAcceptOpacity(_ flag: String) throws {
        let entry = try #require(Self.singleColorFlags.first { $0.flag == flag })
        let command = try parseCommand(entry.args)
        // Both halves must agree: validation rejects nothing the builder accepts.
        try command.performValidationForTesting()
        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(abs(alpha(entry.read(settings)) - 0.5) < 0.001, "\(flag) dropped the opacity")
    }

    // MARK: - Palette slots

    @Test("all three icon palette slots accept a :opacity suffix")
    func iconPaletteSlotsAcceptOpacity() throws {
        let command = try parseCommand([
            "gear", "--icon-symbol-rendering", "palette",
            "--icon-symbol-palette", "blue:0.8,white:0.5,white:0.25",
        ])
        try command.performValidationForTesting()
        let fg = try IconGenerationRunner().buildTestSettings(from: command).icon.foreground
        #expect(abs(alpha(fg.palettePrimaryColor) - 0.8) < 0.001, "primary dropped its opacity")
        #expect(abs(alpha(fg.paletteSecondaryColor) - 0.5) < 0.001)
        #expect(abs(alpha(fg.paletteTertiaryColor) - 0.25) < 0.001)
    }

    @Test("all three badge palette slots accept a :opacity suffix")
    func badgePaletteSlotsAcceptOpacity() throws {
        let command = try parseCommand([
            "star.fill", "--badge-fg", "symbol:plus", "--badge-symbol-rendering", "palette",
            "--badge-symbol-palette", "blue:0.8,white:0.5,white:0.25",
        ])
        try command.performValidationForTesting()
        let fg = try IconGenerationRunner().buildTestSettings(from: command).badge.foreground
        #expect(abs(alpha(fg.palettePrimaryColor) - 0.8) < 0.001, "primary dropped its opacity")
        #expect(abs(alpha(fg.paletteSecondaryColor) - 0.5) < 0.001)
        #expect(abs(alpha(fg.paletteTertiaryColor) - 0.25) < 0.001)
    }

    // MARK: - Gradient colours

    @Test("both icon gradient colours accept a :opacity suffix")
    func iconGradientColorsAcceptOpacity() throws {
        let command = try parseCommand([
            "star.fill", "--icon-bg", "custom-gradient",
            "--icon-bg-gradient-colors", "red:0.8,orange:0.4",
        ])
        try command.performValidationForTesting()
        let bg = try IconGenerationRunner().buildTestSettings(from: command).icon.background
        #expect(abs(alpha(bg.gradientStartColor) - 0.8) < 0.001)
        #expect(abs(alpha(bg.gradientEndColor) - 0.4) < 0.001)
    }

    @Test("both badge gradient colours accept a :opacity suffix")
    func badgeGradientColorsAcceptOpacity() throws {
        let command = try parseCommand([
            "star.fill", "--badge-fg", "symbol:plus", "--badge-bg", "custom-gradient",
            "--badge-bg-gradient-colors", "red:0.8,orange:0.4",
        ])
        try command.performValidationForTesting()
        let bg = try IconGenerationRunner().buildTestSettings(from: command).badge.background
        #expect(abs(alpha(bg.gradientStartColor) - 0.8) < 0.001)
        #expect(abs(alpha(bg.gradientEndColor) - 0.4) < 0.001)
    }

    // MARK: - Which forms take a suffix

    /// The alpha `--icon-bg-color <value>` ends up storing.
    private func storedAlpha(of value: String) throws -> Double {
        let command = try parseCommand(["star.fill", "--icon-bg-color", value])
        try command.performValidationForTesting()
        return alpha(try IconGenerationRunner().buildTestSettings(from: command).icon.background.color)
    }

    @Test("the suffix works on top of every comma-free form", arguments: [
        "white", "#0088FF", "0088FF", "system.blue", "label",
        "rgb(0,136,255)", "hsl(180,50%,50%)",
    ])
    func suffixComposesWithOtherForms(_ value: String) throws {
        let base = try storedAlpha(of: value)
        let halved = try storedAlpha(of: "\(value):0.5")
        #expect(abs(halved - base * 0.5) < 0.001, "\(value) did not take the opacity suffix")
    }

    @Test("a suffix multiplies the colour's own alpha rather than replacing it")
    func suffixMultipliesRatherThanReplaces() throws {
        // SwiftUI's `.opacity()` scales what is already there, so the rule only
        // becomes visible on a token that is not fully opaque to begin with:
        // NSColor.labelColor is ~85%, making `label:0.5` ~42.5% and not 50%.
        let base = try storedAlpha(of: "label")
        #expect(base < 0.95, "labelColor is now opaque — this test's premise is gone, not its subject")
        #expect(abs(try storedAlpha(of: "label:0.5") - base * 0.5) < 0.001)

        // An opaque base makes the two readings coincide, which is why this went
        // unnoticed: white:0.5 is 50% either way.
        #expect(abs(try storedAlpha(of: "white") - 1.0) < 0.001)
        #expect(abs(try storedAlpha(of: "white:0.5") - 0.5) < 0.001)
    }

    @Test("an extended form takes no suffix — it already ends in an alpha component")
    func extendedFormRejectsASuffix() throws {
        // Accepted without one…
        let ok = try parseCommand(["star.fill", "--icon-bg-color", "extended-srgb:0,0.5,1,0.5"])
        try ok.performValidationForTesting()
        let settings = try IconGenerationRunner().buildTestSettings(from: ok)
        #expect(abs(alpha(settings.icon.background.color) - 0.5) < 0.001)

        // …and rejected with one, rather than silently taking the first four values.
        let bad = try parseCommand(["star.fill", "--icon-bg-color", "extended-srgb:0,0.5,1,1:0.5"])
        #expect(throws: (any Error).self) { try bad.performValidationForTesting() }
    }

    @Test("a bad opacity is still rejected", arguments: ["white:5.0", "white:-1", "white:abc", "notacolor:0.5"])
    func badOpacityStillRejected(_ value: String) throws {
        let command = try parseCommand(["star.fill", "--icon-bg-color", value])
        #expect(throws: (any Error).self) { try command.performValidationForTesting() }
    }

    // MARK: - System (appex) mode

    @Test("a bare token keeps Apple's curated rendering")
    func systemModeBareTokenStaysAToken() throws {
        #expect(try AppexColor.plistValue(fromCLIString: "white") == "white")
        #expect(try AppexColor.plistValue(fromCLIString: "blue") == "blue")
    }

    @Test("a token with an opacity suffix becomes a custom colour, not a token")
    func systemModeOpacityBecomesComponents() throws {
        // A translucent white is no longer Apple's white, so it resolves to
        // components — the same branch hex and rgb() already took.
        #expect(try AppexColor.plistValue(fromCLIString: "white:0.5") == "1,1,1,0.5")
        #expect(try AppexColor.plistValue(fromCLIString: "black:0.25") == "0,0,0,0.25")
    }

    /// System-mode *symbol* colours take an opacity suffix, because the OS honours
    /// `ISSymbolColor`'s alpha. Background colours do not — see below.
    @Test("system-mode symbol colour flags accept a :opacity suffix")
    func systemModeSymbolFlagsAcceptOpacity() throws {
        let command = try parseCommand([
            "star.fill", "--icon-generation-mode", "system",
            "--badge-fg", "symbol:plus", "--badge-generation-mode", "system",
            "--icon-symbol-color", "white:0.5", "--badge-symbol-color", "white:0.5",
        ])
        try command.performValidationForTesting()
        // The four resolvers are what IconGenerationRunner fills the appex plist
        // from; `.none` is the flags-only context, so only the flags speak here.
        #expect(try command.resolvedIconAppexSymbolColor(in: .none).stringValue == "1,1,1,0.5")
        #expect(try command.resolvedBadgeAppexSymbolColor(in: .none).stringValue == "1,1,1,0.5")
    }

    /// **Changed in Phase 4 (decision D2), deliberately.** These two flags used to
    /// accept `:opacity` in System mode and write it — and the OS then discarded
    /// it, because `ISEnclosureColor`'s alpha is ignored (0.01 through 0.99 all
    /// render fully opaque). The icon came out opaque with nothing said. Refusing
    /// at validation costs the user nothing and explains the limit.
    @Test("system-mode background colours refuse a :opacity suffix", arguments: [
        ["star.fill", "--icon-generation-mode", "system", "--icon-bg-color", "blue:0.5"],
        ["star.fill", "--badge-fg", "symbol:plus", "--badge-generation-mode", "system",
         "--badge-bg-color", "blue:0.5"],
    ])
    func systemModeBackgroundRefusesOpacity(_ args: [String]) throws {
        let command = try parseCommand(args)
        // Interpolated, not `localizedDescription`: ArgumentParser's
        // `ValidationError` is not a `LocalizedError`, so the localized form is
        // Foundation's generic "operation couldn't be completed" and would make
        // any message assertion vacuous.
        let message = try #require(Self.validationMessage(command))
        #expect(message.contains("opacity"), "should explain the limit: \(message)")
    }

    /// The same colour without the suffix still works, so the rejection is about
    /// the alpha rather than about the flag.
    @Test("the same background colour is fine when it is opaque")
    func systemModeBackgroundAcceptsOpaque() throws {
        let command = try parseCommand([
            "star.fill", "--icon-generation-mode", "system", "--icon-bg-color", "blue",
        ])
        try command.performValidationForTesting()
        #expect(try command.resolvedIconAppexEnclosureColor(in: .none).stringValue == "blue")
    }

    /// A colour beyond sRGB is refused for either key, because the appex pipeline
    /// rejects out-of-range components and clamping would desaturate it silently.
    @Test("system mode refuses a wide-gamut colour", arguments: [
        "--icon-bg-color", "--icon-symbol-color",
    ])
    func systemModeRefusesWideGamut(_ flag: String) throws {
        let command = try parseCommand([
            "star.fill", "--icon-generation-mode", "system", flag, "display-p3:1,0,0",
        ])
        let message = try #require(Self.validationMessage(command))
        #expect(message.contains("srgb:"), "should offer the nearest sRGB colour: \(message)")
    }

    /// The text a validation failure produced, or nil if it did not fail.
    private static func validationMessage(_ command: GenerateCommand) -> String? {
        do {
            try command.performValidationForTesting()
            return nil
        } catch {
            return "\(error)"
        }
    }
}
