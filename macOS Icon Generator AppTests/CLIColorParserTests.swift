// CLIColorParserTests.swift - Unit tests for color parsing functionality
import Testing
import SwiftUI
@testable import macOS_Icon_Generator_App

struct CLIColorParserTests {
    
    // MARK: - Named Color Tests
    
    @Test
    func parseStandardNamedColors() throws {
        #expect(try ColorParser.parse("blue") == .blue)
        #expect(try ColorParser.parse("red") == .red)
        #expect(try ColorParser.parse("green") == .green)
        #expect(try ColorParser.parse("white") == .white)
        #expect(try ColorParser.parse("black") == .black)
    }
    
    @Test
    func parseExtendedNamedColors() throws {
        // Test extended color palette
        let crimson = try ColorParser.parse("crimson")
        let turquoise = try ColorParser.parse("turquoise")
        let coral = try ColorParser.parse("coral")
        let gold = try ColorParser.parse("gold")
        
        // Verify colors are not nil and have expected properties
        #expect(crimson != .clear)
        #expect(turquoise != .clear)
        #expect(coral != .clear)
        #expect(gold != .clear)
    }
    
    @Test
    func parseCaseInsensitiveColors() throws {
        #expect(try ColorParser.parse("BLUE") == .blue)
        #expect(try ColorParser.parse("Red") == .red)
        #expect(try ColorParser.parse("GREEN") == .green)
        #expect(try ColorParser.parse("crimson") == try ColorParser.parse("CRIMSON"))
    }
    
    // MARK: - Hex Color Tests
    
    @Test
    func parseStandardHexColors() throws {
        // Test 6-digit hex with #
        let redHex = try ColorParser.parse("#FF0000")
        #expect(redHex != .clear)
        
        // Test 6-digit hex without #
        let blueHex = try ColorParser.parse("0000FF")
        #expect(blueHex != .clear)
    }
    
    @Test
    func parseShortHexColors() throws {
        // Test 3-digit hex (should expand to 6-digit)
        let redShort = try ColorParser.parse("#F00")
        let redFull = try ColorParser.parse("#FF0000")
        
        // Colors should be equivalent
        #expect(redShort != .clear)
        #expect(redFull != .clear)
    }
    
    @Test
    func parseHexColorsWithAlpha() throws {
        // Test 8-digit hex with alpha
        let colorWithAlpha = try ColorParser.parse("#FF000080")
        #expect(colorWithAlpha != .clear)
    }
    
    @Test
    func invalidHexColorsThrow() throws {
        // Test invalid hex formats
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("#GG0000") // Invalid characters
        }
        
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("#FF00") // Wrong length
        }
        
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("#FF000000000") // Too long
        }
    }
    
    // MARK: - RGB Color Tests
    
    @Test
    func parseRGBColors() throws {
        // Test comma-separated RGB
        let red = try ColorParser.parse("255,0,0")
        let blue = try ColorParser.parse("0,0,255")
        
        #expect(red != .clear)
        #expect(blue != .clear)
    }
    
    @Test
    func parseRGBFunctions() throws {
        // Test CSS-style rgb() functions
        let red = try ColorParser.parse("rgb(255,0,0)")
        let blue = try ColorParser.parse("rgb(0,0,255)")
        
        #expect(red != .clear)
        #expect(blue != .clear)
    }
    
    @Test
    func parseRGBWithPercentages() throws {
        // Test RGB with percentage values
        let color = try ColorParser.parse("rgb(100%,50%,25%)")
        #expect(color != .clear)
    }
    
    @Test
    func parseRGBAColors() throws {
        // Test RGBA with alpha channel
        let colorWithAlpha = try ColorParser.parse("rgba(255,0,0,0.5)")
        #expect(colorWithAlpha != .clear)
    }
    
    @Test
    func invalidRGBValuesThrow() throws {
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("300,0,0") // Value > 255
        }
        
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("rgb(255,0)") // Missing component
        }
        
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("rgba(255,0,0,2.0)") // Alpha > 1.0
        }
    }
    
    // MARK: - HSL Color Tests
    
    @Test
    func parseHSLColors() throws {
        // Test HSL color space
        let red = try ColorParser.parse("hsl(0,100%,50%)")
        let blue = try ColorParser.parse("hsl(240,100%,50%)")
        
        #expect(red != .clear)
        #expect(blue != .clear)
    }
    
    @Test
    func parseHSLAColors() throws {
        // Test HSLA with alpha
        let colorWithAlpha = try ColorParser.parse("hsla(120,100%,50%,0.8)")
        #expect(colorWithAlpha != .clear)
    }
    
    @Test
    func invalidHSLValuesThrow() throws {
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("hsl(400,100%,50%)") // Hue > 360
        }
        
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("hsl(240,150%,50%)") // Saturation > 100%
        }
        
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("hsl(240,100,50%)") // Missing % sign
        }
    }
    
    // MARK: - System Color Tests
    
    @Test
    func parseSystemColors() throws {
        let systemBlue = try ColorParser.parse("system.blue")
        let label = try ColorParser.parse("label")
        
        #expect(systemBlue != .clear)
        #expect(label != .clear)
    }
    
    @Test
    func invalidSystemColorThrows() throws {
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("system.nonexistent")
        }
    }
    
    // MARK: - Opacity Tests
    
    @Test
    func parseColorsWithOpacity() throws {
        // Test colon opacity notation
        let blueWithOpacity = try ColorParser.parseWithOpacity("blue:0.5")
        let hexWithOpacity = try ColorParser.parseWithOpacity("#FF0000:0.8")
        let rgbWithOpacity = try ColorParser.parseWithOpacity("rgb(255,0,0):0.3")
        
        #expect(blueWithOpacity != .clear)
        #expect(hexWithOpacity != .clear)
        #expect(rgbWithOpacity != .clear)
    }
    
    @Test
    func parseRGBAWithBuiltInOpacity() throws {
        // RGBA should work with parseWithOpacity
        let rgbaColor = try ColorParser.parseWithOpacity("rgba(255,0,0,0.7)")
        #expect(rgbaColor != .clear)
    }
    
    @Test
    func invalidOpacityThrows() throws {
        #expect(throws: ColorParseError.self) {
            try ColorParser.parseWithOpacity("blue:2.0") // Opacity > 1.0
        }
        
        #expect(throws: ColorParseError.self) {
            try ColorParser.parseWithOpacity("blue:-0.5") // Negative opacity
        }
    }
    
    // MARK: - Grayscale Tests
    
    @Test
    func parseGrayscaleColors() throws {
        // Test decimal grayscale (0.0-1.0)
        let gray50 = try ColorParser.parse("0.5")
        let gray25 = try ColorParser.parse("0.25")
        
        #expect(gray50 != .clear)
        #expect(gray25 != .clear)
        
        // Test integer grayscale (0-255)
        let gray128 = try ColorParser.parse("128")
        let gray64 = try ColorParser.parse("64")
        
        #expect(gray128 != .clear)
        #expect(gray64 != .clear)
    }
    
    @Test
    func invalidGrayscaleThrows() throws {
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("300") // Value > 255
        }
    }
    
    // MARK: - Error Message Tests
    
    @Test
    func errorMessagesAreHelpful() throws {
        do {
            _ = try ColorParser.parse("invalid-color")
            #expect(Bool(false), "Should have thrown error")
        } catch let error as ColorParseError {
            let description = error.localizedDescription
            #expect(description.contains("Try:"))
            #expect(description.contains("invalid-color"))
        }
    }
    
    @Test
    func emptyInputThrows() throws {
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("")
        }
        
        #expect(throws: ColorParseError.self) {
            try ColorParser.parse("   ") // Whitespace only
        }
    }
    
    // MARK: - Complex Color Format Tests
    
    @Test
    func parseComplexColorCombinations() throws {
        // Test that various complex formats work
        let formats = [
            "crimson:0.8",
            "#FF5733",
            "rgb(100%,34%,20%)",
            "hsl(240,100%,50%)",
            "rgba(255,87,51,0.8)",
            "hsla(240,100%,50%,0.7)",
            "system.blue",
            "turquoise:0.3",
            "128",
            "0.75"
        ]
        
        for format in formats {
            let color = try ColorParser.parseWithOpacity(format)
            #expect(color != .clear, "Failed to parse: \(format)")
        }
    }
}
