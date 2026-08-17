import Testing
import SwiftUI
import AppKit

@Suite struct ColorParserTests {

    // MARK: - Value assertion helper

    /// Resolve a SwiftUI Color to sRGB components so tests can assert actual
    /// values, not just "didn't throw".
    private func srgb(_ color: Color) throws -> (r: Double, g: Double, b: Double, a: Double) {
        let nsColor = try #require(ColorParser.nsColor(from: color).usingColorSpace(.sRGB))
        return (Double(nsColor.redComponent), Double(nsColor.greenComponent),
                Double(nsColor.blueComponent), Double(nsColor.alphaComponent))
    }

    private func expectColor(
        _ input: String,
        _ expected: (r: Double, g: Double, b: Double, a: Double),
        tolerance: Double = 0.005,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let got = try srgb(try ColorParser.parse(input))
        #expect(abs(got.r - expected.r) <= tolerance, "\(input): r \(got.r) != \(expected.r)", sourceLocation: sourceLocation)
        #expect(abs(got.g - expected.g) <= tolerance, "\(input): g \(got.g) != \(expected.g)", sourceLocation: sourceLocation)
        #expect(abs(got.b - expected.b) <= tolerance, "\(input): b \(got.b) != \(expected.b)", sourceLocation: sourceLocation)
        #expect(abs(got.a - expected.a) <= tolerance, "\(input): a \(got.a) != \(expected.a)", sourceLocation: sourceLocation)
    }

    // MARK: - Named colors

    @Test(arguments: [
        "blue", "red", "green", "orange", "yellow", "pink", "purple",
        "indigo", "teal", "mint", "cyan", "brown", "white", "black",
        "gray", "grey", "clear", "transparent"
    ])
    func parsesNamedColor(_ name: String) throws {
        _ = try ColorParser.parse(name)
    }

    @Test func namedColorIsCaseInsensitive() throws {
        _ = try ColorParser.parse("BLUE")
        _ = try ColorParser.parse("BlUe")
    }

    @Test func trimsWhitespaceAroundNamedColor() throws {
        _ = try ColorParser.parse("  blue  ")
    }

    // MARK: - Hex

    @Test(arguments: [
        "#FF5733", "FF5733",
        "#F53", "F53",
        "#FF573380", "FF573380",
        "#ffffff", "000000"
    ])
    func parsesHexVariation(_ hex: String) throws {
        _ = try ColorParser.parse(hex)
    }

    @Test(arguments: ["#FFFF", "#GGGGGG", "#12345", "#1234567", "#"])
    func rejectsInvalidHex(_ hex: String) {
        #expect(throws: ColorParseError.self) { try ColorParser.parse(hex) }
    }

    // MARK: - rgb() / hsl()

    @Test func parsesRGB() throws { _ = try ColorParser.parse("rgb(255,128,0)") }
    @Test func parsesHSL() throws { _ = try ColorParser.parse("hsl(180,50%,50%)") }

    /// Alpha is a 4th argument to `rgb()`/`hsl()` rather than an `rgba()`/`hsla()
    /// spelling of its own — one function, one name (§4.3 of the colour plan).
    @Test func rgbAndHSLTakeAFourthAlphaArgument() throws {
        try expectColor("rgb(255,0,0,0.5)", (1, 0, 0, 0.5))
        try expectColor("hsl(0,100%,50%,0.25)", (1, 0, 0, 0.25))
    }

    @Test func rejectsRGBOutOfRange() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("rgb(256,0,0)") }
    }

    @Test(arguments: ["rgb(1,2)", "rgb(1,2,3,4,5)"])
    func rejectsRGBWrongArity(_ input: String) {
        #expect(throws: ColorParseError.self) { try ColorParser.parse(input) }
    }

    @Test func rejectsHSLWithoutPercentage() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("hsl(180,50,50)") }
    }

    @Test func rejectsAlphaOutOfRange() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("rgb(0,0,0,1.5)") }
    }

    // MARK: - Semantic colors

    @Test(arguments: [
        "primary", "secondary",
    ])
    func parsesSemanticColor(_ name: String) throws {
        _ = try ColorParser.parse(name)
    }

    // MARK: - Opacity notation via parseWithOpacity

    @Test func parsesOpacitySuffix() throws {
        _ = try ColorParser.parseWithOpacity("white:0.5")
    }

    @Test func parseWithOpacityHandlesPlainNamedColor() throws {
        _ = try ColorParser.parseWithOpacity("white")
    }

    @Test func parseWithOpacityHandlesFunctionForms() throws {
        _ = try ColorParser.parseWithOpacity("rgb(255,0,0):0.5")
        _ = try ColorParser.parseWithOpacity("hsl(180,50%,50%):0.5")
    }

    @Test(arguments: ["white:1.5", "white:-0.1", "white:abc"])
    func rejectsOpacityOutOfRange(_ input: String) {
        #expect(throws: ColorParseError.self) {
            try ColorParser.parseWithOpacity(input)
        }
    }

    // MARK: - Value assertions (hex, rgb(), hsl())

    @Test func hexParsesToExpectedComponents() throws {
        try expectColor("#FF5733", (255.0 / 255, 87.0 / 255, 51.0 / 255, 1))
        try expectColor("#F53", (255.0 / 255, 85.0 / 255, 51.0 / 255, 1))
        try expectColor("#FF573380", (255.0 / 255, 87.0 / 255, 51.0 / 255, 128.0 / 255))
    }

    @Test func rgbFunctionParsesToExpectedComponents() throws {
        try expectColor("rgb(255,128,0)", (1, 128.0 / 255, 0, 1))
        try expectColor("rgb(0,136,255)", (0, 136.0 / 255, 1, 1))
    }

    /// CSS HSL, not HSB: hsl(0,100%,50%) is pure red (#FF0000), and lightness
    /// 100% is white regardless of saturation.
    @Test func hslParsesAsCSSHSLNotHSB() throws {
        try expectColor("hsl(0,100%,50%)", (1, 0, 0, 1))
        try expectColor("hsl(120,100%,25%)", (0, 0.5, 0, 1))
        try expectColor("hsl(240,100%,50%)", (0, 0, 1, 1))
        try expectColor("hsl(0,100%,100%)", (1, 1, 1, 1))
        try expectColor("hsl(0,0%,50%)", (0.5, 0.5, 0.5, 1))
    }

    // MARK: - Space-prefixed components

    @Test func srgbPrefixParsesToExpectedComponents() throws {
        try expectColor("srgb:1,0,0", (1, 0, 0, 1))
        try expectColor("srgb:0.2,0.42,0.9", (0.2, 0.42, 0.9, 1))
        try expectColor("srgb:1,0,0,0.5", (1, 0, 0, 0.5))
    }

    /// The alpha is optional, because `srgb:` replaced a bare 3-component form
    /// and requiring a trailing `,1` for the common case would be gratuitous.
    @Test func srgbAlphaDefaultsToOpaque() throws {
        try expectColor("srgb:0.5,0.5,0.5", (0.5, 0.5, 0.5, 1))
    }

    @Test func srgbPrefixIsCaseInsensitiveAndTrimsSpaces() throws {
        try expectColor("  SRGB: 0.2 , 0.42 , 0.9  ", (0.2, 0.42, 0.9, 1))
    }

    /// Display P3 is converted to extended sRGB at the door, so everything
    /// downstream stores one space — and the conversion is what makes the two
    /// spellings of a P3 red the same colour.
    @Test func displayP3ConvertsToExtendedSRGB() throws {
        let components = try #require(try ColorParser.spacePrefixedComponents(parsing: "display-p3:1,0,0"))
        guard case .srgb(let r, let g, let b, let a) = components else {
            Issue.record("display-p3: should store as extended sRGB")
            return
        }
        #expect(abs(r - 1.093) < 0.01, "got r \(r)")
        #expect(abs(g - -0.2267) < 0.01, "got g \(g)")
        #expect(abs(b - -0.1501) < 0.01, "got b \(b)")
        #expect(a == 1)
    }

    @Test func displayP3AndItsExtendedSpellingAgree() throws {
        let viaP3 = try #require(try ColorParser.spacePrefixedComponents(parsing: "display-p3:1,0,0"))
        let viaExtended = try #require(
            try ColorParser.spacePrefixedComponents(parsing: "extended-srgb:1.09300,-0.22670,-0.15010,1.00000")
        )
        #expect(viaP3.rounded(to: 3) == viaExtended.rounded(to: 3))
    }

    /// A P3 colour inside sRGB's gamut converts to ordinary 0–1 components, so
    /// most P3 picks are not out-of-gamut at all — which is why the appex
    /// projection only has to refuse the ones that are.
    @Test func displayP3InsideSRGBGamutStaysInRange() throws {
        let components = try #require(try ColorParser.spacePrefixedComponents(parsing: "display-p3:0.5,0.5,0.5"))
        guard case .srgb(let r, let g, let b, _) = components else {
            Issue.record("expected sRGB components")
            return
        }
        for value in [r, g, b] {
            #expect((0.0...1.0).contains(value), "\(value) should be in gamut")
        }
    }

    /// Bounded spaces report an out-of-range component instead of clamping it.
    /// Clamping is exactly the silent-desaturation failure the grammar exists to
    /// end, and the error names the unbounded form that *can* carry it.
    @Test(arguments: ["srgb:1.2,0,0", "srgb:-0.1,0,0", "display-p3:0,0,1.5", "srgb:0,0,0,2"])
    func rejectsOutOfRangeBoundedComponents(_ input: String) throws {
        let error = #expect(throws: ColorParseError.self) { try ColorParser.parse(input) }
        let message = try #require(error?.errorDescription)
        #expect(message.contains("extended-srgb"), "should point at the unbounded form: \(message)")
    }

    @Test(arguments: ["srgb:1,0", "srgb:1,0,0,1,1", "srgb:oops", "display-p3:a,b,c", "srgb:"])
    func rejectsMalformedBoundedComponents(_ input: String) {
        #expect(throws: ColorParseError.self) { try ColorParser.parse(input) }
    }

    /// A space prefix contains a colon, so it must be recognised before the
    /// `name:opacity` split — otherwise `display-p3` reads as a colour name and
    /// `1,0.2,0` as an opacity. This is the trap `ColorParser`'s header names.
    @Test(arguments: ["srgb:0.2,0.42,0.9", "display-p3:1,0.2,0", "extended-srgb:1,0,0,1", "extended-gray:1,1"])
    func spacePrefixSurvivesParseWithOpacity(_ input: String) throws {
        _ = try ColorParser.parseWithOpacity(input)
    }

    /// The space-prefixed forms already end in an alpha, so a suffix on top of
    /// one is rejected rather than silently taking the first components.
    @Test func rejectsOpacitySuffixOnASpacePrefixedForm() {
        #expect(throws: ColorParseError.self) { try ColorParser.parseWithOpacity("srgb:1,0,0,1:0.5") }
    }

    // MARK: - Empty / invalid

    @Test func rejectsEmpty() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("") }
    }

    @Test func rejectsGibberish() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("notacolor") }
    }

    /// Precedence pin: a bare 3-digit number is short hex. It was ambiguous with
    /// single-number grayscale until Phase 3 dropped that form; hex won then too,
    /// so `parse("300")` has always meant `#330000`.
    @Test func threeDigitNumberIsShortHex() throws {
        try expectColor("300", (0x33 / 255.0, 0, 0, 1))
    }
}
