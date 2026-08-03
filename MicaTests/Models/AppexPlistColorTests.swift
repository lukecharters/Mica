// AppexPlistColorTests.swift
//
// §1.1 of `docs/plans/colour-resolution.md` as a unit test on the writer.
//
// This suite exists because **the render cannot be the check.** IconServices
// discards a plist colour it does not recognise and draws its fallback tile at
// 248,247,247, which is indistinguishable from `white` — so a rejected value looks
// like a deliberate choice, and an assertion on the rendered image passes either
// way. Every rule below was measured against the real pipeline (~50 candidates) and
// can only be defended here, one step before the write.
//
// Phase 4, 2026-08-03.

import Testing
import SwiftUI
import AppKit
@testable import Mica

@Suite struct AppexPlistColorTests {

    // MARK: - The accepted grammar

    @Test("the 15 named tokens pass verbatim, for either key",
          arguments: AppexNamedColor.allCases.map(\.rawValue), AppexPlistColor.Role.allCases)
    func namedTokensPass(_ name: String, _ role: AppexPlistColor.Role) throws {
        let color = try AppexPlistColor(validating: name, role: role)
        #expect(color.stringValue == name)
    }

    @Test("exactly 15 tokens are native, no more and no fewer")
    func tokenCountIsFifteen() {
        #expect(AppexNamedColor.allCases.count == 15)
    }

    @Test("four plain decimals pass", arguments: [
        "1,0,0,1", "0,0,0,1", "1,1,1,1",
        "0.5,0.5,0.5,1", "1,0.0902,0.2118,1", "0.0001,0,0,1",
    ])
    func componentsPass(_ value: String) throws {
        #expect(try AppexPlistColor(validating: value, role: .symbol).stringValue == value)
    }

    // MARK: - The rejected grammar

    /// Every one of these was tried against the live pipeline and discarded.
    /// Whitespace is **not** trimmed by IconServices, so `" blue "` is genuinely
    /// invalid rather than merely untidy — which is why the gate does not trim
    /// either.
    @Test("everything the pipeline discards is refused here", arguments: [
        // Not one of the 15 names.
        "grey", "magenta", "silver", "lightblue", "systemBlue", "graphite",
        "clear", "labelColor", "default", "accent", "multicolor", "label",
        // Case and whitespace.
        "Blue", "BLUE", " blue", "blue ", " blue ",
        // Wrong component count.
        "1,0,0", "1,0,0,1,1", "1,0,0,", ",1,0,0",
        // Wrong range or scale.
        "255,0,0,255", "255,0,0,1", "1.5,0,0,1", "-1,0,0,1",
        // Not plain decimals.
        " 1, 0, 0, 1 ", "#FF0000", "FF0000", "0xFF0000",
        "rgb(255,0,0)", "srgb:1,0,0,1", "extended-srgb:1,0,0,1",
        "1e0,0,0,1", "1e-05,0,0,1", "+1,0,0,1", "1,0,0,1.0e0",
        // Empty.
        "", ",,,",
    ])
    func rejectedFormsAreRefused(_ value: String) {
        #expect(throws: (any Error).self) {
            try AppexPlistColor(validating: value, role: .symbol)
        }
    }

    /// `String(format: "%g")` switches to exponent notation once the exponent drops
    /// below -4, and `AppexColor.rgbaString` is only a rounding-precision change
    /// away from that. `1e-05` in a plist is a silent white, so the gate refuses
    /// the notation outright and this pins the boundary that keeps it unreachable.
    @Test("the writer never emits exponent notation, at any 4 dp value")
    func writerNeverEmitsExponents() throws {
        // 0.0001 is the smallest non-zero the 4 dp rounding can produce; the next
        // value down rounds to 0. Both must stay plain.
        let smallest = AppexColor.rgbaString(r: 0.0001, g: 0.00004, b: 0, a: 1)
        #expect(smallest == "0.0001,0,0,1", "got \(smallest)")
        _ = try AppexPlistColor(validating: smallest, role: .symbol)

        // A sweep of the whole 0–1 range at a step that lands on and between
        // quantisation boundaries.
        for step in stride(from: 0.0, through: 1.0, by: 0.00013) {
            let written = AppexColor.rgbaString(r: CGFloat(step), g: 0, b: 0, a: 1)
            #expect(!written.lowercased().contains("e"), "\(step) wrote \(written)")
            _ = try AppexPlistColor(validating: written, role: .symbol)
        }
    }

    // MARK: - Alpha is per-key (§1.1)

    /// The OS honours alpha for `ISSymbolColor` and ignores it for
    /// `ISEnclosureColor` — 0.01 through 0.99 all render fully opaque there. So a
    /// translucent enclosure is refused rather than written and forgotten.
    @Test("a symbol keeps its alpha and an enclosure refuses one")
    func alphaIsPerKey() throws {
        #expect(try AppexPlistColor(validating: "1,1,1,0.5", role: .symbol).stringValue == "1,1,1,0.5")
        #expect(throws: AppexColorError.enclosureAlphaIgnored("1,1,1,0.5")) {
            try AppexPlistColor(validating: "1,1,1,0.5", role: .enclosure)
        }
        // Opaque is fine either way.
        #expect(try AppexPlistColor(validating: "1,1,1,1", role: .enclosure).stringValue == "1,1,1,1")
    }

    @Test("a translucent colour is refused as a background, projected as well as validated")
    func translucentEnclosureIsRefusedOnProjection() throws {
        let translucent = AppexColor.custom(MicaColorValue.token("white", alpha: 0.5))
        #expect(throws: (any Error).self) {
            try AppexPlistColor(projecting: translucent, role: .enclosure)
        }
        let asSymbol = try AppexPlistColor(projecting: translucent, role: .symbol)
        #expect(asSymbol.stringValue == "1,1,1,0.5")
    }

    /// `label` is ~85% opaque in Aqua, so it is a translucent colour that does not
    /// look like one. As an enclosure the OS would drop that alpha and render an
    /// opaque tile, which is why this is refused rather than quietly accepted.
    @Test("a token that is translucent without looking it is caught too")
    func labelIsTranslucent() throws {
        let label = AppexColor.custom(MicaColorValue.token("label"))
        // Only assert the rejection if the OS really does report label as
        // translucent — the point is the rule, not this OS's exact alpha.
        let alpha = ColorParser.nsColor(from: MicaColorValue.token("label").resolved)
            .usingColorSpace(.extendedSRGB)?.alphaComponent ?? 1
        if abs(Double(alpha) - 1) > 0.0001 {
            #expect(throws: (any Error).self) {
                try AppexPlistColor(projecting: label, role: .enclosure)
            }
        }
        // As a symbol colour it is representable either way.
        _ = try AppexPlistColor(projecting: label, role: .symbol)
    }

    // MARK: - Gamut (decision D2)

    /// The rejection is narrower than "not sRGB": a Display P3 pick *inside* the
    /// sRGB gamut converts exactly and must keep working, because that is most of
    /// what the colour wheel produces.
    @Test("an in-gamut Display P3 colour projects cleanly", arguments: [
        "display-p3:0.5,0.5,0.5", "display-p3:0.2,0.4,0.6", "display-p3:0,0,0",
    ])
    func inGamutP3Projects(_ input: String) throws {
        let color = AppexColor.custom(try MicaColorValue(strictlyParsing: input))
        let projected = try AppexPlistColor(projecting: color, role: .enclosure)
        #expect(projected.stringValue.split(separator: ",").count == 4)
    }

    /// A colour genuinely beyond sRGB is refused, not clamped — clamping would
    /// desaturate it with nothing said, which is what D2 rules out.
    @Test("a wide-gamut colour is refused, for either key", arguments: [
        "display-p3:1,0,0", "display-p3:0,1,0", "extended-srgb:1.09300,-0.22670,-0.15010,1.00000",
    ])
    func wideGamutIsRefused(_ input: String) throws {
        let color = AppexColor.custom(try MicaColorValue(strictlyParsing: input))
        for role in AppexPlistColor.Role.allCases {
            #expect(throws: (any Error).self) {
                try AppexPlistColor(projecting: color, role: role)
            }
        }
    }

    /// The message has to be actionable in both places it appears — `mica-cli`
    /// stderr and the System-mode preview pane — so it names the nearest sRGB
    /// colour it computed rather than only stating the limit.
    @Test("the out-of-gamut message offers the nearest sRGB colour and the token list")
    func outOfGamutMessageIsActionable() throws {
        let color = AppexColor.custom(try MicaColorValue(strictlyParsing: "display-p3:1,0,0"))
        let error = #expect(throws: AppexColorError.self) {
            try AppexPlistColor(projecting: color, role: .enclosure)
        }
        let message = try #require(error?.errorDescription)
        #expect(message.contains("srgb:"), "should name the nearest sRGB colour: \(message)")
        #expect(message.contains("blue"), "should list the tokens: \(message)")
    }

    // MARK: - Presets keep Apple's curated rendering

    /// A named token is not interchangeable with its own components: a named `red`
    /// tile is ≈235,85,80 and `1,0,0,1` gives ≈234,51,36. So a preset must project
    /// to its *name*, never be helpfully resolved.
    @Test("a preset projects to its name, not to components",
          arguments: AppexNamedColor.allCases, AppexPlistColor.Role.allCases)
    func presetProjectsToItsName(_ preset: AppexNamedColor, _ role: AppexPlistColor.Role) throws {
        let projected = try AppexPlistColor(projecting: .named(preset), role: role)
        #expect(projected.stringValue == preset.rawValue)
        #expect(!projected.stringValue.contains(","))
    }

    // MARK: - Invariants

    @Test("the role's raw value is the plist key it writes")
    func rolesAreThePlistKeys() {
        #expect(AppexPlistColor.Role.enclosure.rawValue == "ISEnclosureColor")
        #expect(AppexPlistColor.Role.symbol.rawValue == "ISSymbolColor")
        #expect(AppexPlistColor.Role.symbol.honoursAlpha)
        #expect(!AppexPlistColor.Role.enclosure.honoursAlpha)
    }

    /// The two defaults skip the gate to stay non-throwing, so this is what keeps
    /// them honest.
    @Test("the defaults would pass the gate")
    func defaults_wouldPassTheGate() throws {
        let enclosure = AppexPlistColor.defaultEnclosure
        let symbol = AppexPlistColor.defaultSymbol
        #expect(try AppexPlistColor(validating: enclosure.stringValue, role: .enclosure) == enclosure)
        #expect(try AppexPlistColor(validating: symbol.stringValue, role: .symbol) == symbol)
        #expect(enclosure.stringValue == "blue")
        #expect(symbol.stringValue == "white")
    }

    /// Whatever `AppexColor.plistValue` produces has to survive the gate for the
    /// key it is bound for — the two must not be able to disagree about what is
    /// writable. The enclosure case is deliberately restricted to opaque colours,
    /// which is the one place they legitimately differ.
    @Test("plistValue and the gate agree", arguments: [
        "blue", "mint", "#FF1736", "srgb:1,0.0902,0.2118", "display-p3:0.4,0.4,0.4",
    ])
    func plistValueSurvivesTheGate(_ input: String) throws {
        let color = try AppexColor.parsing(cliString: input)
        for role in AppexPlistColor.Role.allCases {
            let projected = try AppexPlistColor(projecting: color, role: role)
            #expect(projected.stringValue == color.plistValue,
                    "\(input) as \(role): \(projected.stringValue) != \(color.plistValue)")
        }
    }
}
