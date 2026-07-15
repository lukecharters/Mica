import Testing
import SwiftUI
import AppKit

@Suite struct ColorParserTests {

    // MARK: - Value assertion helper

    /// Resolve a SwiftUI Color to sRGB components so tests can assert actual
    /// values, not just "didn't throw".
    private func srgb(_ color: Color) throws -> (r: Double, g: Double, b: Double, a: Double) {
        let nsColor = try #require(NSColor(color).usingColorSpace(.sRGB))
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
        "gray", "grey", "clear", "transparent",
        "lightgray", "darkgray", "magenta", "lime", "navy", "maroon",
        "olive", "silver", "gold", "crimson", "violet", "turquoise",
        "coral", "salmon", "khaki", "plum", "orchid"
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

    // MARK: - CSS functions

    @Test func parsesRGB() throws { _ = try ColorParser.parse("rgb(255,128,0)") }
    @Test func parsesRGBA() throws { _ = try ColorParser.parse("rgba(255,128,0,0.5)") }
    @Test func parsesHSL() throws { _ = try ColorParser.parse("hsl(180,50%,50%)") }
    @Test func parsesHSLA() throws { _ = try ColorParser.parse("hsla(180,50%,50%,0.5)") }
    @Test func parsesRGBPercentages() throws { _ = try ColorParser.parse("rgb(100%,50%,0%)") }

    @Test func rejectsRGBOutOfRange() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("rgb(256,0,0)") }
    }

    @Test func rejectsRGBWrongArity() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("rgb(1,2)") }
    }

    @Test func rejectsRGBAWrongArity() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("rgba(1,2,3)") }
    }

    @Test func rejectsHSLWithoutPercentage() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("hsl(180,50,50)") }
    }

    @Test func rejectsAlphaOutOfRange() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("rgba(0,0,0,1.5)") }
    }

    // MARK: - System colors

    @Test(arguments: [
        "system.blue", "systemBlue",
        "system.red", "systemRed",
        "label", "secondary.label", "tertiary.label", "quaternary.label"
    ])
    func parsesSystemColor(_ name: String) throws {
        _ = try ColorParser.parse(name)
    }

    // MARK: - Opacity notation via parseWithOpacity

    @Test func parsesOpacitySuffix() throws {
        _ = try ColorParser.parseWithOpacity("white:0.5")
    }

    @Test func parseWithOpacityHandlesPlainNamedColor() throws {
        _ = try ColorParser.parseWithOpacity("white")
    }

    @Test func parseWithOpacityHandlesRGBA() throws {
        _ = try ColorParser.parseWithOpacity("rgba(255,0,0,0.5)")
    }

    @Test func parseWithOpacityHandlesHSLA() throws {
        _ = try ColorParser.parseWithOpacity("hsla(180,50%,50%,0.5)")
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
        try expectColor("rgb(100%,50%,0%)", (1, 0.5, 0, 1))
        try expectColor("rgba(255,0,0,0.5)", (1, 0, 0, 0.5))
    }

    /// CSS HSL, not HSB: hsl(0,100%,50%) is pure red (#FF0000), and lightness
    /// 100% is white regardless of saturation.
    @Test func hslParsesAsCSSHSLNotHSB() throws {
        try expectColor("hsl(0,100%,50%)", (1, 0, 0, 1))
        try expectColor("hsl(120,100%,25%)", (0, 0.5, 0, 1))
        try expectColor("hsl(240,100%,50%)", (0, 0, 1, 1))
        try expectColor("hsl(0,100%,100%)", (1, 1, 1, 1))
        try expectColor("hsl(0,0%,50%)", (0.5, 0.5, 0.5, 1))
        try expectColor("hsla(0,100%,50%,0.25)", (1, 0, 0, 0.25))
    }

    // MARK: - Bare r,g,b(,a) — semantics shared with the System-mode resolver

    /// Components are 0-1 floats, or 0-255 when any of r/g/b exceeds 1 —
    /// the same rule as AppexColor.plistValue(fromCLIString:), so a color
    /// string means the same thing in both generation modes.
    @Test func bareRGBTreatsAllLEQOneAsFloats() throws {
        try expectColor("1,1,1", (1, 1, 1, 1))
        try expectColor("0.5,0.5,0.5", (0.5, 0.5, 0.5, 1))
        try expectColor("0,0,1", (0, 0, 1, 1))
    }

    @Test func bareRGBTreatsAnyGreaterThanOneAs255Scale() throws {
        try expectColor("255,0,0", (1, 0, 0, 1))
        try expectColor("255,128,0", (1, 128.0 / 255, 0, 1))
        try expectColor("255,0.5,0", (1, 0.5 / 255, 0, 1))
    }

    @Test func bareRGBAcceptsDocumentedAlphaForm() throws {
        try expectColor("255,0,0,0.5", (1, 0, 0, 0.5))
        try expectColor("1,0,0,0.25", (1, 0, 0, 0.25))
    }

    @Test func bareRGBAcceptsPercentages() throws {
        try expectColor("100%,50%,0%", (1, 0.5, 0, 1))
    }

    @Test(arguments: ["256,0,0", "1,2", "1,2,3,4,5", "-1,0,0", "a,b,c"])
    func bareRGBRejectsInvalidComponents(_ input: String) {
        #expect(throws: ColorParseError.self) { try ColorParser.parse(input) }
    }

    @Test func bareRGBRejectsAlphaOutOfRange() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("255,0,0,1.5") }
    }

    // MARK: - Grayscale

    @Test func parsesGrayscale0To1() throws { _ = try ColorParser.parse("0.5") }
    @Test func parsesGrayscale0To255() throws { _ = try ColorParser.parse("128") }

    @Test func rejectsGrayscaleOutOfRange() {
        // "300.0" not "300": any bare 3-digit number is consumed by the
        // short-hex parser first (see hexWinsOverGrayscaleForThreeDigits).
        #expect(throws: ColorParseError.self) { try ColorParser.parse("300.0") }
    }

    @Test func hexWinsOverGrayscaleForThreeDigits() throws {
        // Precedence pin: a bare 3-digit number is short hex, never grayscale.
        _ = try ColorParser.parse("300") // #330000, not out-of-range grayscale
    }

    // MARK: - Empty / invalid

    @Test func rejectsEmpty() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("") }
    }

    @Test func rejectsGibberish() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("notacolor") }
    }
}
