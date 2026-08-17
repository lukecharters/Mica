// MicaColorValueTests.swift
// `MicaColorValue` is the colour Mica stores — a token or components, plus an alpha
// modifier — and the one JSON string it writes. These tests pin the properties the
// format depends on: that a written token always reads back as the colour it
// replaced, that components survive a round trip, and that a token stays a token
// through everything that used to flatten it. Plus a palette pin that keeps Mica's
// colours tracking the system's rather than a frozen literal.

import Testing
import SwiftUI
import AppKit
@testable import Mica

@Suite(.tags(.unit))
struct MicaColorValueTests {

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
        "hsl(180,50%,50%)", "primary", "srgb:1,1,1,1", "",
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
        #expect(MicaColorValue(resolving: .blue) == .token("blue"))
    }

    // MARK: - Provenance (Phase 2)

    @Test("a token with an opacity keeps both, so it still follows the appearance")
    func tokenWithOpacitySurvivesAsAToken() throws {
        // The bug this type exists to fix: `primary` at 50% used to match no token,
        // so a configuration saved in Aqua reopened wrong in Dark Aqua.
        let value = try MicaColorValue(parsing: "primary:0.5")
        #expect(value.source == .token("primary"))
        #expect(value.alpha == 0.5)
        #expect(value.stringValue == "primary:0.5")
    }

    @Test("the opacity suffix multiplies rather than replaces (D4)")
    @MainActor
    func opacitySuffixMultiplies() throws {
        // `Color.primary` is ~84.7% opaque, so `primary:0.5` renders at ~42% — the
        // behaviour mica-cli has always had, kept deliberately on 2026-08-02.
        let value = try MicaColorValue(parsing: "primary:0.5")
        let alpha = try srgbComponents(
            inAppearance() { ColorParser.ExtendedComponents.resolving(value.resolved) }
        ).a
        #expect(abs(alpha - 0.847 * 0.5) < 0.01, "resolved alpha was \(alpha)")
    }

    @Test("a components source folds its alpha in, so there is one spelling")
    func componentsFoldAlpha() {
        let value = MicaColorValue(source: .components(.srgb(r: 1, g: 0, b: 0, a: 1)), alpha: 0.5)
        #expect(value.alpha == 1)
        #expect(value.stringValue == "extended-srgb:1.00000,0.00000,0.00000,0.50000")
    }

    @Test("equality means writing the same string (D5)")
    func equalityMatchesTheWrittenString() {
        // Rounded at construction, so a sixth decimal place cannot make two values
        // that write identically compare unequal — which is what would let undo
        // grouping disagree with the file.
        let a = MicaColorValue.components(.srgb(r: 0.2000001, g: 0.6, b: 0.9, a: 1))
        let b = MicaColorValue.components(.srgb(r: 0.2, g: 0.6, b: 0.9, a: 1))
        #expect(a == b)
        #expect(a.stringValue == b.stringValue)
    }

    @Test("a wide-gamut pick is never clamped by the rounding")
    func wideGamutSurvivesRounding() throws {
        let value = try MicaColorValue(parsing: "extended-srgb:1.09300,-0.22670,-0.15010,1.00000")
        let c = try srgbComponents(#require(
            { if case .components(let c) = value.source { return c } else { return nil } }()
        ))
        #expect(c.r > 1.0)
        #expect(c.g < 0.0)
        #expect(value.stringValue == "extended-srgb:1.09300,-0.22670,-0.15010,1.00000")
    }

    /// A name outside `ColorTokenTable` — which is every name, since Phase 3
    /// dropped the 18 CSS-ish ones — is kept verbatim as an unresolvable token
    /// rather than guessed at. That is what lets an error quote the offending
    /// string, and it is why a hand-edited configuration surfaces its own typo
    /// instead of loading as some nearby colour.
    @Test("a name the table does not hold stays quotable and does not resolve")
    @MainActor
    func unknownNameIsKeptButDoesNotResolve() throws {
        let value = try MicaColorValue(parsing: "crimson")
        #expect(value.source == .token("crimson"))
        #expect(value.tokenName == nil, "not a name the table holds")
        #expect(value.stringValue == "crimson", "the string survives so an error can quote it")
        #expect(throws: (any Error).self) { try value.resolvedColor() }
        // And the CLI's entry point refuses it up front rather than at a render.
        #expect(throws: (any Error).self) { try MicaColorValue(strictlyParsing: "crimson") }
    }

    @Test("the static conveniences are all presentable tokens")
    func staticConveniencesArePresentableTokens() {
        let all: [MicaColorValue] = [
            .black, .blue, .brown, .cyan, .gray, .green, .indigo, .mint,
            .orange, .pink, .purple, .red, .teal, .white, .yellow,
        ]
        for value in all {
            #expect(value.isPresentableToken, "\(value.stringValue) is not a preset")
        }
        #expect(MicaColorValue.clear.isToken)
        #expect(!MicaColorValue.clear.isPresentableToken)
    }

    @Test("strict parsing refuses a name nothing understands")
    func strictParsingRefusesUnknownNames() {
        #expect(throws: (any Error).self) { try MicaColorValue(strictlyParsing: "notacolour") }
        #expect(throws: Never.self) { try MicaColorValue(strictlyParsing: "mint") }
        #expect(throws: Never.self) { try MicaColorValue(strictlyParsing: "#FF0000") }
    }

    // MARK: - Semantic tokens

    @Test("every emittable token parses back to the colour it was matched on")
    func everySemanticTokenReparsesToItsOwnColour() throws {
        // Compared on *resolved components*, not on `Color` identity. `Color.blue`
        // and `Color(.systemBlue)` are distinct instances that resolve to the same
        // bytes, so identity would call the substitution a failure when it is
        // exactly what the writer's ordering is for: the short, portable token
        // wins, and `plainNamesWin` below pins that direction.
        for token in ColorTokenTable.names {
            let color = try ColorParser.parse(token)
            let matched = try #require(MicaColorValue(resolving: color).tokenName,
                                       "\(token) resolves to no token at all")
            // Rounded to the stored precision, for the same reason `MicaColorValue`
            // rounds: `green` and `system.green` differ in the seventh decimal
            // place, which is below anything a render can express.
            let before = ColorParser.ExtendedComponents.resolving(color).rounded(to: MicaColorValue.precision)
            let after = ColorParser.ExtendedComponents.resolving(try ColorParser.parse(matched)).rounded(to: MicaColorValue.precision)
            #expect(before == after, "\(token) matched \(matched), a different colour")
        }
    }

    @Test("a token colour is written as its token, not as components")
    func tokenColoursWriteAsTokens() throws {
        #expect(MicaColorValue(resolving: .white) == .token("white"))
        #expect(MicaColorValue(resolving: .black) == .token("black"))
        #expect(MicaColorValue(resolving: .blue).stringValue == "blue")
        #expect(MicaColorValue(resolving: Color.primary) == .token("primary"))
    }

    @Test("an AppKit system colour is captured as the plain token")
    func appKitSystemColoursCaptureAsPlainTokens() {
        // The `system.*` spellings were removed on 2026-08-17, so there is no
        // longer a second name to lose to — but a colour arriving *as* an AppKit
        // system colour (from a well, a paste, a preview) must still land on the
        // one token that names it, rather than freezing to components.
        #expect(MicaColorValue(resolving: Color(.systemBlue)).tokenName == "blue")
    }

    @Test("a picked colour with no token is written as components")
    @MainActor
    func pickedColoursWriteAsComponents() {
        let picked = Color(.sRGB, red: 0.2, green: 0.6, blue: 0.9, opacity: 1)
        let written = inAppearance() { MicaColorValue(resolving: picked) }
        guard case .components = written.source else {
            Issue.record("expected components, got \(written)")
            return
        }
        #expect(written.stringValue.hasPrefix("extended-srgb:"))
    }

    @Test("by-value capture of a faded token gives components, deliberately")
    @MainActor
    func opacityBreaksTokenMatch() {
        // `init(resolving:)` matches on all four components, so a faded token is
        // not recovered as token-plus-alpha. That is not a gap: in Aqua
        // `Color.primary` is black at 84.7%, so black at 42% is byte-identical to
        // `primary` at 50% and no by-value rule could tell them apart. Provenance
        // with an alpha comes from where the colour is *set* —
        // `tokenWithOpacitySurvivesAsAToken` below is that path.
        let written = inAppearance() { MicaColorValue(resolving: Color.blue.opacity(0.5)) }
        guard case .components = written.source else {
            Issue.record("expected components for a half-opacity blue, got \(written)")
            return
        }
    }

    @Test("a token round-trips as the same dynamic colour, not a frozen one")
    func tokenStaysDynamic() throws {
        let written = MicaColorValue(resolving: .blue)
        let read = try MicaColorValue(parsing: written.stringValue)
        #expect(read == written)
        #expect(try read.resolvedColor() == Color.blue)
    }

    // MARK: - Tolerant reading

    @Test("an unrecognised token decodes, and only fails when resolved")
    func unknownTokenDefersItsFailure() throws {
        let parsed = try MicaColorValue(parsing: "chartreuse-ish")
        #expect(parsed == .token("chartreuse-ish"))
        #expect(throws: ColorParseError.self) { try parsed.resolvedColor() }
    }

    @Test("a malformed extended value fails at parse, because its intent is clear")
    func malformedExtendedValueFailsEarly() {
        #expect(throws: ColorParseError.self) { try MicaColorValue(parsing: "extended-srgb:1,1") }
    }

    @Test("surrounding whitespace is trimmed from a token")
    func trimsTokenWhitespace() throws {
        #expect(try MicaColorValue(parsing: "  blue  ") == .token("blue"))
    }

    // MARK: - Codable

    @Test("encodes as a bare JSON string, not an object")
    func encodesAsBareString() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(["color": MicaColorValue.token("blue")])
        #expect(String(decoding: data, as: UTF8.self) == #"{"color":"blue"}"#)
    }

    @Test("components encode as their string form")
    func encodesComponentsAsString() throws {
        let value = MicaColorValue.components(.srgb(r: 0, g: 0.47843, b: 1, a: 1))
        let data = try JSONEncoder().encode(["color": value])
        #expect(String(decoding: data, as: UTF8.self)
                == #"{"color":"extended-srgb:0.00000,0.47843,1.00000,1.00000"}"#)
    }

    @Test("decodes both forms from JSON")
    func decodesBothForms() throws {
        let json = #"{"a":"blue","b":"extended-srgb:0.00000,0.47843,1.00000,1.00000"}"#
        let decoded = try JSONDecoder().decode([String: MicaColorValue].self, from: Data(json.utf8))
        #expect(decoded["a"] == .token("blue"))
        #expect(decoded["b"] == .components(.srgb(r: 0, g: 0.47843, b: 1, a: 1)))
    }

    @Test("JSON → MicaColorValue → JSON is stable for both forms")
    func codableRoundTrips() throws {
        for input in [#""blue""#, #""extended-srgb:0.20000,0.60000,0.90000,0.75000""#, #""extended-gray:1.00000,1.00000""#] {
            let decoded = try JSONDecoder().decode(MicaColorValue.self, from: Data(input.utf8))
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
