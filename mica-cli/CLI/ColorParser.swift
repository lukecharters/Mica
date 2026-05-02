import SwiftUI
import Foundation

/// Enhanced color parser supporting multiple formats with comprehensive validation
/// Supports: Named colors, Hex codes, RGB values, HSL, CSS colors, system colors, and opacity notation
struct ColorParser {
    
    // MARK: - Public Interface
    
    /// Parse a color string that may include opacity (e.g., "white:0.5", "rgba(255,255,255,0.5)")
    static func parseWithOpacity(_ input: String) throws -> Color {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle CSS-style rgba/hsla formats with built-in opacity
        if trimmed.lowercased().hasPrefix("rgba(") {
            return try parseRGBAColor(trimmed)
        }
        
        if trimmed.lowercased().hasPrefix("hsla(") {
            return try parseHSLAColor(trimmed)
        }
        
        // Handle opacity notation with colon separator
        let components = trimmed.split(separator: ":")
        let colorString = String(components[0])
        
        let baseColor = try parse(colorString)
        
        if components.count > 1 {
            let opacityString = String(components[1])
            guard let opacity = Double(opacityString), opacity >= 0.0 && opacity <= 1.0 else {
                throw ColorParseError.invalidOpacity(opacityString, "Opacity must be between 0.0 and 1.0")
            }
            return baseColor.opacity(opacity)
        }
        
        return baseColor
    }
    
    /// Parse a color string into a SwiftUI Color
    /// Supports multiple formats: named colors, hex, RGB, HSL, CSS colors, system colors
    static func parse(_ input: String) throws -> Color {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ColorParseError.emptyInput("Color string cannot be empty")
        }
        
        // Try different parsing strategies in order of specificity
        
        // 1. CSS-style functions (rgb, hsl)
        if let color = try? parseCSSStyleColor(trimmed) {
            return color
        }
        
        // 2. System color references
        if let color = try? parseSystemColor(trimmed) {
            return color
        }
        
        // 3. Named colors (including extended set)
        if let namedColor = parseNamedColor(trimmed) {
            return namedColor
        }
        
        // 4. Hex color formats (with multiple variations)
        if let color = try? parseHexColorVariations(trimmed) {
            return color
        }
        
        // 5. RGB format variations
        if trimmed.contains(",") && !trimmed.contains("(") {
            return try parseRGBVariations(trimmed)
        }
        
        // 6. Single number grayscale
        if let color = try? parseGrayscaleColor(trimmed) {
            return color
        }
        
        // If nothing worked, provide helpful error with suggestions
        throw ColorParseError.invalidFormat(trimmed, generateSuggestions(for: trimmed))
    }
    
    // MARK: - CSS-Style Color Parsing
    
    private static func parseCSSStyleColor(_ input: String) throws -> Color {
        let lowercased = input.lowercased()
        
        if lowercased.hasPrefix("rgb(") {
            return try parseRGBFunctionColor(input)
        }
        
        if lowercased.hasPrefix("rgba(") {
            return try parseRGBAColor(input)
        }
        
        if lowercased.hasPrefix("hsl(") {
            return try parseHSLColor(input)
        }
        
        if lowercased.hasPrefix("hsla(") {
            return try parseHSLAColor(input)
        }
        
        throw ColorParseError.unsupportedCSSFormat(input)
    }
    
    private static func parseRGBFunctionColor(_ input: String) throws -> Color {
        let content = try extractFunctionContent(input, functionName: "rgb")
        let components = parseCommaSeparatedValues(content)
        
        guard components.count == 3 else {
            throw ColorParseError.invalidRGBFormat(input, "rgb() requires exactly 3 values")
        }
        
        let rgb = try parseRGBComponents(components, source: input)
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
    
    private static func parseRGBAColor(_ input: String) throws -> Color {
        let content = try extractFunctionContent(input, functionName: "rgba")
        let components = parseCommaSeparatedValues(content)
        
        guard components.count == 4 else {
            throw ColorParseError.invalidRGBAFormat(input, "rgba() requires exactly 4 values")
        }
        
        let rgb = try parseRGBComponents(Array(components[0..<3]), source: input)
        let alpha = try parseAlphaComponent(components[3], source: input)
        
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2, opacity: alpha)
    }
    
    private static func parseHSLColor(_ input: String) throws -> Color {
        let content = try extractFunctionContent(input, functionName: "hsl")
        let components = parseCommaSeparatedValues(content)
        
        guard components.count == 3 else {
            throw ColorParseError.invalidHSLFormat(input, "hsl() requires exactly 3 values")
        }
        
        return try parseHSLComponents(components, alpha: 1.0, source: input)
    }
    
    private static func parseHSLAColor(_ input: String) throws -> Color {
        let content = try extractFunctionContent(input, functionName: "hsla")
        let components = parseCommaSeparatedValues(content)
        
        guard components.count == 4 else {
            throw ColorParseError.invalidHSLAFormat(input, "hsla() requires exactly 4 values")
        }
        
        let alpha = try parseAlphaComponent(components[3], source: input)
        return try parseHSLComponents(Array(components[0..<3]), alpha: alpha, source: input)
    }
    
    // MARK: - System Color Parsing
    
    private static func parseSystemColor(_ input: String) throws -> Color {
        let lowercased = input.lowercased()
        
        switch lowercased {
        case "system.blue", "systemblue": return Color(.systemBlue)
        case "system.red", "systemred": return Color(.systemRed)
        case "system.green", "systemgreen": return Color(.systemGreen)
        case "system.orange", "systemorange": return Color(.systemOrange)
        case "system.yellow", "systemyellow": return Color(.systemYellow)
        case "system.pink", "systempink": return Color(.systemPink)
        case "system.purple", "systempurple": return Color(.systemPurple)
        case "system.teal", "systemteal": return Color(.systemTeal)
        case "system.indigo", "systemindigo": return Color(.systemIndigo)
        case "system.mint", "systemmint": return Color(.systemMint)
        case "system.cyan", "systemcyan": return Color(.systemCyan)
        case "system.brown", "systembrown": return Color(.systemBrown)
        case "system.gray", "systemgray", "system.grey", "systemgrey": return Color(.systemGray)
        case "label": return Color(.labelColor)
        case "secondary.label", "secondarylabel": return Color(.secondaryLabelColor)
        case "tertiary.label", "tertiarylabel": return Color(.tertiaryLabelColor)
        case "quaternary.label", "quaternarylabel": return Color(.quaternaryLabelColor)
        default:
            throw ColorParseError.unknownSystemColor(input)
        }
    }
    
    // MARK: - Enhanced Named Color Parsing
    
    private static func parseNamedColor(_ name: String) -> Color? {
        let lowercased = name.lowercased()
        
        // Standard SwiftUI colors
        switch lowercased {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "yellow": return .yellow
        case "pink": return .pink
        case "purple": return .purple
        case "indigo": return .indigo
        case "teal": return .teal
        case "mint": return .mint
        case "cyan": return .cyan
        case "brown": return .brown
        case "white": return .white
        case "black": return .black
        case "gray", "grey": return .gray
        case "clear", "transparent": return .clear
        
        // Extended color names
        case "lightgray", "lightgrey": return Color(.lightGray)
        case "darkgray", "darkgrey": return Color(.darkGray)
        case "magenta": return Color(.magenta)
        case "lime": return Color(red: 0, green: 1, blue: 0)
        case "navy": return Color(red: 0, green: 0, blue: 0.5)
        case "maroon": return Color(red: 0.5, green: 0, blue: 0)
        case "olive": return Color(red: 0.5, green: 0.5, blue: 0)
        case "silver": return Color(red: 0.75, green: 0.75, blue: 0.75)
        case "gold": return Color(red: 1, green: 0.84, blue: 0)
        case "crimson": return Color(red: 0.86, green: 0.08, blue: 0.24)
        case "violet": return Color(red: 0.93, green: 0.51, blue: 0.93)
        case "turquoise": return Color(red: 0.25, green: 0.88, blue: 0.82)
        case "coral": return Color(red: 1, green: 0.5, blue: 0.31)
        case "salmon": return Color(red: 0.98, green: 0.5, blue: 0.45)
        case "khaki": return Color(red: 0.94, green: 0.9, blue: 0.55)
        case "plum": return Color(red: 0.87, green: 0.63, blue: 0.87)
        case "orchid": return Color(red: 0.85, green: 0.44, blue: 0.84)
        
        default: return nil
        }
    }
    
    // MARK: - Enhanced Hex Color Parsing
    
    private static func parseHexColorVariations(_ input: String) throws -> Color {
        var hex = input
        
        // Remove # prefix if present
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }
        
        // Handle different hex formats
        switch hex.count {
        case 3: // Short hex: RGB -> RRGGBB
            return try parseShortHex(hex)
        case 6: // Standard hex: RRGGBB
            return try parseStandardHex(hex)
        case 8: // Hex with alpha: RRGGBBAA
            return try parseHexWithAlpha(hex)
        default:
            throw ColorParseError.invalidHexLength(input, "Hex colors must be 3, 6, or 8 characters (optionally prefixed with #)")
        }
    }
    
    private static func parseShortHex(_ hex: String) throws -> Color {
        guard hex.count == 3 else {
            throw ColorParseError.invalidHexLength("#" + hex, "Short hex format requires exactly 3 characters")
        }
        
        let chars = Array(hex)
        let expandedHex = "\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])"
        
        return try parseStandardHex(expandedHex)
    }
    
    private static func parseStandardHex(_ hex: String) throws -> Color {
        guard hex.count == 6 else {
            throw ColorParseError.invalidHexLength("#" + hex, "Standard hex format requires exactly 6 characters")
        }
        
        guard let value = UInt32(hex, radix: 16) else {
            throw ColorParseError.invalidHexValue("#" + hex, "Must contain valid hex digits (0-9, A-F)")
        }
        
        let red = Double((value & 0xFF0000) >> 16) / 255.0
        let green = Double((value & 0x00FF00) >> 8) / 255.0
        let blue = Double(value & 0x0000FF) / 255.0
        
        return Color(red: red, green: green, blue: blue)
    }
    
    private static func parseHexWithAlpha(_ hex: String) throws -> Color {
        guard hex.count == 8 else {
            throw ColorParseError.invalidHexLength("#" + hex, "Hex with alpha requires exactly 8 characters")
        }
        
        guard let value = UInt64(hex, radix: 16) else {
            throw ColorParseError.invalidHexValue("#" + hex, "Must contain valid hex digits (0-9, A-F)")
        }
        
        let red = Double((value & 0xFF000000) >> 24) / 255.0
        let green = Double((value & 0x00FF0000) >> 16) / 255.0
        let blue = Double((value & 0x0000FF00) >> 8) / 255.0
        let alpha = Double(value & 0x000000FF) / 255.0
        
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    // MARK: - Enhanced RGB Parsing
    
    private static func parseRGBVariations(_ input: String) throws -> Color {
        let components = parseCommaSeparatedValues(input)
        
        guard components.count == 3 else {
            throw ColorParseError.invalidRGBFormat(input, "RGB format requires exactly 3 comma-separated values")
        }
        
        let rgb = try parseRGBComponents(components, source: input)
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
    
    private static func parseRGBComponents(_ components: [String], source: String) throws -> (Double, Double, Double) {
        var rgbValues: [Double] = []
        
        for (_, component) in components.enumerated() {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle percentage values (0-100%)
            if trimmed.hasSuffix("%") {
                let percentString = String(trimmed.dropLast())
                guard let percent = Double(percentString), percent >= 0 && percent <= 100 else {
                    throw ColorParseError.invalidRGBPercentage(source, "RGB percentage values must be 0-100%")
                }
                rgbValues.append(percent / 100.0)
            }
            // Handle regular values (0-255)
            else {
                guard let intValue = Int(trimmed), intValue >= 0 && intValue <= 255 else {
                    throw ColorParseError.invalidRGBValues(source, "RGB values must be integers 0-255 or percentages 0-100%")
                }
                rgbValues.append(Double(intValue) / 255.0)
            }
        }
        
        return (rgbValues[0], rgbValues[1], rgbValues[2])
    }
    
    // MARK: - HSL Color Parsing
    
    private static func parseHSLComponents(_ components: [String], alpha: Double, source: String) throws -> Color {
        guard components.count == 3 else {
            throw ColorParseError.invalidHSLFormat(source, "HSL requires exactly 3 values: hue, saturation, lightness")
        }
        
        // Parse hue (0-360 degrees)
        let hueString = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let hue = try parseHueComponent(hueString, source: source)
        
        // Parse saturation (0-100%)
        let satString = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let saturation = try parsePercentageComponent(satString, componentName: "saturation", source: source)
        
        // Parse lightness (0-100%)
        let lightString = components[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let lightness = try parsePercentageComponent(lightString, componentName: "lightness", source: source)
        
        return Color(hue: hue, saturation: saturation, brightness: lightness, opacity: alpha)
    }
    
    private static func parseHueComponent(_ input: String, source: String) throws -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let hue = Double(trimmed), hue >= 0 && hue <= 360 else {
            throw ColorParseError.invalidHue(source, "Hue must be 0-360 degrees")
        }
        return hue / 360.0
    }
    
    private static func parsePercentageComponent(_ input: String, componentName: String, source: String) throws -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasSuffix("%") {
            let percentString = String(trimmed.dropLast())
            guard let percent = Double(percentString), percent >= 0 && percent <= 100 else {
                throw ColorParseError.invalidPercentage(source, "\(componentName.capitalized) must be 0-100%")
            }
            return percent / 100.0
        } else {
            throw ColorParseError.missingPercentageSign(source, "\(componentName.capitalized) must include % sign")
        }
    }
    
    private static func parseAlphaComponent(_ input: String, source: String) throws -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let alpha = Double(trimmed), alpha >= 0.0 && alpha <= 1.0 else {
            throw ColorParseError.invalidAlpha(source, "Alpha must be 0.0-1.0")
        }
        return alpha
    }
    
    // MARK: - Grayscale Parsing
    
    private static func parseGrayscaleColor(_ input: String) throws -> Color {
        guard let value = Double(input) else {
            throw ColorParseError.invalidGrayscale(input)
        }
        
        // Support both 0-1 and 0-255 ranges
        let normalizedValue: Double
        if value <= 1.0 {
            normalizedValue = value
        } else if value <= 255.0 {
            normalizedValue = value / 255.0
        } else {
            throw ColorParseError.invalidGrayscale(input, "Grayscale values must be 0-1 or 0-255")
        }
        
        return Color(red: normalizedValue, green: normalizedValue, blue: normalizedValue)
    }
    
    // MARK: - Helper Functions
    
    private static func extractFunctionContent(_ input: String, functionName: String) throws -> String {
        let prefix = functionName + "("
        let suffix = ")"
        
        guard input.lowercased().hasPrefix(prefix.lowercased()) && input.hasSuffix(suffix) else {
            throw ColorParseError.invalidFunctionFormat(input, "Must be in format: \(functionName)(...)")
        }
        
        let startIndex = input.index(input.startIndex, offsetBy: prefix.count)
        let endIndex = input.index(input.endIndex, offsetBy: -suffix.count)
        
        return String(input[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func parseCommaSeparatedValues(_ content: String) -> [String] {
        return content.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    private static func generateSuggestions(for input: String) -> String {
        var suggestions: [String] = []
        
        // Suggest similar named colors
        let namedColors = ["blue", "red", "green", "orange", "yellow", "pink", "purple", "indigo", "teal", "mint", "cyan", "brown", "white", "black", "gray"]
        let lowercasedInput = input.lowercased()
        
        for color in namedColors {
            if color.contains(lowercasedInput) || lowercasedInput.contains(color) {
                suggestions.append(color)
            }
        }
        
        // Add format suggestions
        if suggestions.isEmpty {
            suggestions = [
                "Named colors: blue, red, green, etc.",
                "Hex: #FF5733 or FF5733",
                "RGB: 255,87,51 or rgb(255,87,51)",
                "HSL: hsl(9,100%,60%)",
                "With opacity: blue:0.5"
            ]
        }
        
        return "Try: " + suggestions.joined(separator: " | ")
    }
}

// MARK: - Enhanced Error Types

enum ColorParseError: LocalizedError {
    case emptyInput(String)
    case invalidFormat(String, String)
    case invalidHexLength(String, String)
    case invalidHexValue(String, String)
    case invalidRGBFormat(String, String)
    case invalidRGBAFormat(String, String)
    case invalidRGBValues(String, String)
    case invalidRGBPercentage(String, String)
    case invalidHSLFormat(String, String)
    case invalidHSLAFormat(String, String)
    case invalidHue(String, String)
    case invalidPercentage(String, String)
    case invalidAlpha(String, String)
    case invalidOpacity(String, String)
    case invalidGrayscale(String, String = "Invalid grayscale value")
    case invalidFunctionFormat(String, String)
    case missingPercentageSign(String, String)
    case unknownSystemColor(String)
    case unsupportedCSSFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyInput(let message):
            return message
        case .invalidFormat(let input, let suggestion):
            return "Invalid color format: '\(input)'. \(suggestion)"
        case .invalidHexLength(let hex, let message):
            return "Invalid hex color length: '\(hex)'. \(message)"
        case .invalidHexValue(let hex, let message):
            return "Invalid hex color value: '\(hex)'. \(message)"
        case .invalidRGBFormat(let rgb, let message):
            return "Invalid RGB format: '\(rgb)'. \(message)"
        case .invalidRGBAFormat(let rgba, let message):
            return "Invalid RGBA format: '\(rgba)'. \(message)"
        case .invalidRGBValues(let rgb, let message):
            return "Invalid RGB values: '\(rgb)'. \(message)"
        case .invalidRGBPercentage(let source, let message):
            return "Invalid RGB percentage in '\(source)'. \(message)"
        case .invalidHSLFormat(let hsl, let message):
            return "Invalid HSL format: '\(hsl)'. \(message)"
        case .invalidHSLAFormat(let hsla, let message):
            return "Invalid HSLA format: '\(hsla)'. \(message)"
        case .invalidHue(let source, let message):
            return "Invalid hue in '\(source)'. \(message)"
        case .invalidPercentage(let source, let message):
            return "Invalid percentage in '\(source)'. \(message)"
        case .invalidAlpha(let source, let message):
            return "Invalid alpha in '\(source)'. \(message)"
        case .invalidOpacity(let opacity, let message):
            return "Invalid opacity value: '\(opacity)'. \(message)"
        case .invalidGrayscale(let input, let message):
            return "Invalid grayscale: '\(input)'. \(message)"
        case .invalidFunctionFormat(let input, let message):
            return "Invalid function format: '\(input)'. \(message)"
        case .missingPercentageSign(let source, let message):
            return "Missing percentage sign in '\(source)'. \(message)"
        case .unknownSystemColor(let color):
            return "Unknown system color: '\(color)'. Try: system.blue, system.red, label, etc."
        case .unsupportedCSSFormat(let format):
            return "Unsupported CSS color format: '\(format)'. Supported: rgb(), rgba(), hsl(), hsla()"
        }
    }
}
