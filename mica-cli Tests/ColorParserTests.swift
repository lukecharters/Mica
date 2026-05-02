import Testing
@testable import mica_cli

@Suite struct ColorParserTests {

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

    // MARK: - Grayscale

    @Test func parsesGrayscale0To1() throws { _ = try ColorParser.parse("0.5") }
    @Test func parsesGrayscale0To255() throws { _ = try ColorParser.parse("128") }

    @Test func rejectsGrayscaleOutOfRange() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("300") }
    }

    // MARK: - Empty / invalid

    @Test func rejectsEmpty() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("") }
    }

    @Test func rejectsGibberish() {
        #expect(throws: ColorParseError.self) { try ColorParser.parse("notacolor") }
    }
}
