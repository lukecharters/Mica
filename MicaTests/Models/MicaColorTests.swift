// MicaColorTests.swift
// MicaColor is the JSON configuration format's colour field: one JSON string holding either
// a semantic token or resolved extended components. These tests pin the two
// properties the format depends on — that a written token always reads back as the
// colour it replaced, and that components survive a round trip — plus a palette pin
// that keeps Mica's colours tracking the system's rather than a frozen literal.

import Testing
import SwiftUI
import AppKit
@testable import Mica

@Suite(.tags(.unit))
struct MicaColorTests {

    /// Resolve inside a fixed appearance. Every adaptive colour resolves
    /// differently in Aqua and Dark Aqua, so any test asserting components must say
    /// which one it means.
    @MainActor
    private func inAppearance<T>(_ name: NSAppearance.Name = .aqua, _ body: () -> T) -> T {
        var result: T!
        NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
            result = body()
        }
        return result
    }

    private func srgbComponents(
        _ components: ColorParser.ExtendedComponents
    ) throws -> (r: Double, g: Double, b: Double, a: Double) {
        guard case .srgb(let r, let g, let b, let a) = components else {
            throw TestError.notSRGB(components)
        }
        return (r, g, b, a)
    }

    enum TestError: Error { case notSRGB(ColorParser.ExtendedComponents) }

    // MARK: - Parsing the extended-component form

    @Test("extended-srgb parses four components")
    func parsesExtendedSRGB() throws {
        let parsed = try #require(
            try ColorParser.ExtendedComponents(parsing: "extended-srgb:0.00000,0.47843,1.00000,1.00000")
        )
        #expect(parsed == .srgb(r: 0.0, g: 0.47843, b: 1.0, a: 1.0))
    }

    @Test("extended-gray parses two components")
    func parsesExtendedGray() throws {
        let parsed = try #require(try ColorParser.ExtendedComponents(parsing: "extended-gray:1.00000,1.00000"))
        #expect(parsed == .gray(white: 1.0, alpha: 1.0))
    }

    @Test("components outside 0–1 are kept, so wide-gamut colours survive")
    func keepsOutOfRangeComponents() throws {
        // Display P3 red expressed in extended sRGB.
        let parsed = try #require(
            try ColorParser.ExtendedComponents(parsing: "extended-srgb:1.09300,-0.22670,-0.15010,1.00000")
        )
        let c = try srgbComponents(parsed)
        #expect(c.r > 1.0)
        #expect(c.g < 0.0)
        #expect(c.b < 0.0)
    }

    @Test("a non-extended string is not this form", arguments: [
        "blue", "#0088FF", "rgb(255,128,0)", "white:0.5", "0.5", "255,0,0",
        "hsl(180,50%,50%)", "system.blue", "srgb:1,1,1,1", "",
    ])
    func returnsNilForOtherSyntaxes(_ input: String) throws {
        #expect(try ColorParser.ExtendedComponents(parsing: input) == nil)
    }

    @Test("a matching space name with bad components throws", arguments: [
        "extended-srgb:oops",
        "extended-srgb:1,1,1",          // 3 components, needs 4
        "extended-srgb:1,1,1,1,1",      // 5 components
        "extended-gray:1",              // 1 component, needs 2
        "extended-gray:1,1,1",          // 3 components
        "extended-srgb:",
        "extended-srgb:nan,0,0,1",
    ])
    func throwsForMalformedComponents(_ input: String) {
        #expect(throws: ColorParseError.self) {
            try ColorParser.ExtendedComponents(parsing: input)
        }
    }

    @Test("whitespace and case in the space name are tolerated")
    func tolerantOfWhitespaceAndCase() throws {
        let spaced = try #require(try ColorParser.ExtendedComponents(parsing: "  extended-srgb: 0.5 , 0.5 , 0.5 , 1  "))
        let upper = try #require(try ColorParser.ExtendedComponents(parsing: "EXTENDED-SRGB:0.5,0.5,0.5,1"))
        #expect(spaced == .srgb(r: 0.5, g: 0.5, b: 0.5, a: 1.0))
        #expect(spaced == upper)
    }

    // MARK: - Writing the extended-component form

    @Test("stringValue writes five decimal places")
    func writesFiveDecimals() {
        #expect(ColorParser.ExtendedComponents.srgb(r: 0, g: 0.47843, b: 1, a: 1).stringValue
                == "extended-srgb:0.00000,0.47843,1.00000,1.00000")
        #expect(ColorParser.ExtendedComponents.gray(white: 1, alpha: 1).stringValue
                == "extended-gray:1.00000,1.00000")
    }

    @Test("negative components write with their sign")
    func writesNegatives() {
        #expect(ColorParser.ExtendedComponents.srgb(r: 1.093, g: -0.2267, b: -0.1501, a: 1).stringValue
                == "extended-srgb:1.09300,-0.22670,-0.15010,1.00000")
    }

    @Test("string → components → string is stable")
    func stringRoundTrips() throws {
        for input in [
            "extended-srgb:0.00000,0.47843,1.00000,1.00000",
            "extended-srgb:1.09300,-0.22670,-0.15010,1.00000",
            "extended-gray:1.00000,1.00000",
            "extended-gray:0.00000,0.50000",
        ] {
            let parsed = try #require(try ColorParser.ExtendedComponents(parsing: input))
            #expect(parsed.stringValue == input, "\(input) did not round-trip")
        }
    }

    // MARK: - Colour → components → colour

    @Test("a picked sRGB colour round-trips within 8-bit precision")
    @MainActor
    func pickedColourRoundTrips() throws {
        let picked = Color(.sRGB, red: 0.2, green: 0.6, blue: 0.9, opacity: 0.75)
        let components = inAppearance() { ColorParser.ExtendedComponents.resolving(picked) }
        let c = try srgbComponents(components)
        #expect(abs(c.r - 0.2) < 0.0001)
        #expect(abs(c.g - 0.6) < 0.0001)
        #expect(abs(c.b - 0.9) < 0.0001)
        #expect(abs(c.a - 0.75) < 0.0001)

        // And back again, via the string, unchanged.
        let reparsed = try #require(try ColorParser.ExtendedComponents(parsing: components.stringValue))
        let back = try srgbComponents(inAppearance() { ColorParser.ExtendedComponents.resolving(reparsed.color) })
        #expect(abs(back.r - c.r) < 0.0001)
        #expect(abs(back.g - c.g) < 0.0001)
        #expect(abs(back.b - c.b) < 0.0001)
        #expect(abs(back.a - c.a) < 0.0001)
    }

    @Test("a Display P3 colour keeps its gamut through the string")
    @MainActor
    func p3ColourKeepsGamut() throws {
        let p3Red = Color(.displayP3, red: 1, green: 0, blue: 0, opacity: 1)
        let components = inAppearance() { ColorParser.ExtendedComponents.resolving(p3Red) }
        let c = try srgbComponents(components)
        // Out of sRGB gamut, which is the whole point of the extended space.
        #expect(c.r > 1.0)
        #expect(c.g < 0.0)

        let reparsed = try #require(try ColorParser.ExtendedComponents(parsing: components.stringValue))
        let back = try srgbComponents(inAppearance() { ColorParser.ExtendedComponents.resolving(reparsed.color) })
        #expect(abs(back.r - c.r) < 0.0001)
        #expect(abs(back.g - c.g) < 0.0001)
        #expect(abs(back.b - c.b) < 0.0001)
    }

    @Test("extended-gray white and black cross to sRGB exactly")
    @MainActor
    func grayCrossesToSRGB() throws {
        let white = try #require(try ColorParser.ExtendedComponents(parsing: "extended-gray:1.00000,1.00000"))
        let black = try #require(try ColorParser.ExtendedComponents(parsing: "extended-gray:0.00000,1.00000"))
        let w = try srgbComponents(inAppearance() { ColorParser.ExtendedComponents.resolving(white.color) })
        let b = try srgbComponents(inAppearance() { ColorParser.ExtendedComponents.resolving(black.color) })
        #expect(abs(w.r - 1) < 0.0001)
        #expect(abs(w.g - 1) < 0.0001)
        #expect(abs(w.b - 1) < 0.0001)
        #expect(abs(b.r - 0) < 0.0001)
        #expect(abs(b.g - 0) < 0.0001)
        #expect(abs(b.b - 0) < 0.0001)
    }

    // MARK: - The palette pin

    // The design doc says `0.53333` (#0088FF) is Icon Composer's palette blue and
    // "not NSColor.systemBlue", whose value it gives as #007AFF. That was true on
    // macOS 15 and is **false on macOS 26.6**, where systemBlue measures exactly
    // #0088FF in Aqua and #0091FF in Dark Aqua — Apple moved it in Tahoe, and Icon
    // Composer was using systemBlue all along.
    //
    // So a literal pin would only record which OS ran the test. These two pin the
    // thing that actually has to hold: Mica's blue tracks the system's blue,
    // whatever that currently is, and it is genuinely appearance-dependent — which
    // is the whole justification for writing a token instead of components.

    @Test("Mica's blue is the system's blue, whatever the OS currently says that is")
    @MainActor
    func blueTracksSystemBlue() {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let mica = inAppearance(appearance) { ColorParser.ExtendedComponents.resolving(.blue) }
            let system = inAppearance(appearance) {
                ColorParser.ExtendedComponents.resolving(Color(nsColor: .systemBlue))
            }
            #expect(mica == system, "diverged from systemBlue in \(appearance.rawValue)")
        }
    }

    @Test("an adaptive colour resolves differently per appearance, which is why tokens exist")
    @MainActor
    func adaptiveColoursAreAppearanceDependent() {
        let light = inAppearance(.aqua) { ColorParser.ExtendedComponents.resolving(.blue) }
        let dark = inAppearance(.darkAqua) { ColorParser.ExtendedComponents.resolving(.blue) }
        #expect(light != dark, "blue resolved identically in both appearances — freezing it would be lossless, and it is not")

        // And the token path loses nothing: the same token re-resolves per appearance.
        #expect(MicaColor(resolving: .blue) == .token("blue"))
    }

    // MARK: - Semantic tokens

    @Test("every emittable token parses back to the colour it was matched on")
    func everySemanticTokenReparsesToItsOwnColour() throws {
        for token in MicaColor.semanticTokens {
            let color = try ColorParser.parse(token)
            #expect(MicaColor.semanticToken(for: color) != nil, "\(token) resolves to no token at all")
            let matched = try #require(MicaColor.semanticToken(for: color))
            #expect(try ColorParser.parse(matched) == color, "\(token) matched \(matched), a different colour")
        }
    }

    @Test("a token colour is written as its token, not as components")
    func tokenColoursWriteAsTokens() throws {
        #expect(MicaColor(resolving: .white) == .token("white"))
        #expect(MicaColor(resolving: .black) == .token("black"))
        #expect(MicaColor(resolving: .blue).stringValue == "blue")
        #expect(MicaColor(resolving: Color(.labelColor)) == .token("label"))
    }

    @Test("a plain name wins over the system.* spelling of the same colour")
    func plainNamesWin() {
        // If .blue and Color(.systemBlue) hold the same value, the short token is
        // the one worth writing — configurations stay readable and portable.
        let token = MicaColor.semanticToken(for: Color(.systemBlue))
        #expect(token == "blue" || token == "system.blue")
        if Color.blue == Color(.systemBlue) {
            #expect(token == "blue")
        }
    }

    @Test("a picked colour with no token is written as components")
    @MainActor
    func pickedColoursWriteAsComponents() {
        let picked = Color(.sRGB, red: 0.2, green: 0.6, blue: 0.9, opacity: 1)
        let written = inAppearance() { MicaColor(resolving: picked) }
        guard case .components = written else {
            Issue.record("expected components, got \(written)")
            return
        }
        #expect(written.stringValue.hasPrefix("extended-srgb:"))
    }

    @Test("an opacity-modified token falls through to components")
    @MainActor
    func opacityBreaksTokenMatch() {
        let written = inAppearance() { MicaColor(resolving: Color.blue.opacity(0.5)) }
        guard case .components = written else {
            Issue.record("expected components for a half-opacity blue, got \(written)")
            return
        }
    }

    @Test("a token round-trips as the same dynamic colour, not a frozen one")
    func tokenStaysDynamic() throws {
        let written = MicaColor(resolving: .blue)
        let read = try MicaColor(parsing: written.stringValue)
        #expect(read == written)
        #expect(try read.resolvedColor() == Color.blue)
    }

    // MARK: - Tolerant reading

    @Test("an unrecognised token decodes, and only fails when resolved")
    func unknownTokenDefersItsFailure() throws {
        let parsed = try MicaColor(parsing: "chartreuse-ish")
        #expect(parsed == .token("chartreuse-ish"))
        #expect(throws: ColorParseError.self) { try parsed.resolvedColor() }
    }

    @Test("a malformed extended value fails at parse, because its intent is clear")
    func malformedExtendedValueFailsEarly() {
        #expect(throws: ColorParseError.self) { try MicaColor(parsing: "extended-srgb:1,1") }
    }

    @Test("surrounding whitespace is trimmed from a token")
    func trimsTokenWhitespace() throws {
        #expect(try MicaColor(parsing: "  blue  ") == .token("blue"))
    }

    // MARK: - Codable

    @Test("encodes as a bare JSON string, not an object")
    func encodesAsBareString() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(["color": MicaColor.token("blue")])
        #expect(String(decoding: data, as: UTF8.self) == #"{"color":"blue"}"#)
    }

    @Test("components encode as their string form")
    func encodesComponentsAsString() throws {
        let value = MicaColor.components(.srgb(r: 0, g: 0.47843, b: 1, a: 1))
        let data = try JSONEncoder().encode(["color": value])
        #expect(String(decoding: data, as: UTF8.self)
                == #"{"color":"extended-srgb:0.00000,0.47843,1.00000,1.00000"}"#)
    }

    @Test("decodes both forms from JSON")
    func decodesBothForms() throws {
        let json = #"{"a":"blue","b":"extended-srgb:0.00000,0.47843,1.00000,1.00000"}"#
        let decoded = try JSONDecoder().decode([String: MicaColor].self, from: Data(json.utf8))
        #expect(decoded["a"] == .token("blue"))
        #expect(decoded["b"] == .components(.srgb(r: 0, g: 0.47843, b: 1, a: 1)))
    }

    @Test("JSON → MicaColor → JSON is stable for both forms")
    func codableRoundTrips() throws {
        for input in [#""blue""#, #""extended-srgb:0.20000,0.60000,0.90000,0.75000""#, #""extended-gray:1.00000,1.00000""#] {
            let decoded = try JSONDecoder().decode(MicaColor.self, from: Data(input.utf8))
            let encoded = try JSONEncoder().encode(decoded)
            #expect(String(decoding: encoded, as: UTF8.self) == input, "\(input) did not round-trip")
        }
    }

    // MARK: - ColorParser integration

    @Test("ColorParser.parse accepts the extended form")
    @MainActor
    func colorParserAcceptsExtendedForm() throws {
        let parsed = try ColorParser.parse("extended-srgb:0.20000,0.60000,0.90000,1.00000")
        let c = try srgbComponents(inAppearance() { ColorParser.ExtendedComponents.resolving(parsed) })
        #expect(abs(c.r - 0.2) < 0.0001)
        #expect(abs(c.g - 0.6) < 0.0001)
        #expect(abs(c.b - 0.9) < 0.0001)
    }

    @Test("parseWithOpacity does not mistake the space name for a colour name")
    @MainActor
    func parseWithOpacityHandlesTheColon() throws {
        // The `name:opacity` split would otherwise see "extended-srgb" and
        // "0.20000,0.60000,0.90000,0.50000".
        let parsed = try ColorParser.parseWithOpacity("extended-srgb:0.20000,0.60000,0.90000,0.50000")
        let c = try srgbComponents(inAppearance() { ColorParser.ExtendedComponents.resolving(parsed) })
        #expect(abs(c.r - 0.2) < 0.0001)
        #expect(abs(c.a - 0.5) < 0.0001)
    }

    @Test("existing name:opacity syntax still works")
    @MainActor
    func opacitySyntaxUnaffected() throws {
        let parsed = try ColorParser.parseWithOpacity("white:0.5")
        let c = try srgbComponents(inAppearance() { ColorParser.ExtendedComponents.resolving(parsed) })
        #expect(abs(c.a - 0.5) < 0.0001)
    }
}
