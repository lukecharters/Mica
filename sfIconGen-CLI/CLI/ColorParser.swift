import SwiftUI
import Foundation

/// Parses color strings in various formats into SwiftUI Color objects
struct ColorParser {
    
    /// Parse a color string that may include opacity (e.g., "white:0.5")
    static func parseWithOpacity(_ input: String) throws -> Color {
        let components = input.split(separator: ":")
        let colorString = String(components[0])
        
        let baseColor = try parse(colorString)
        
        if components.count > 1 {
            guard let opacity = Double(components[1]), opacity >= 0.0 && opacity <= 1.0 else {
                throw ColorParseError.invalidOpacity(String(components[1]))
            }
            return baseColor.opacity(opacity)
        }
        
        return baseColor
    }
    
    /// Parse a color string into a SwiftUI Color
    static func parse(_ input: String) throws -> Color {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try named colors first
        if let namedColor = parseNamedColor(trimmed) {
            return namedColor
        }
        
        // Try hex format
        if trimmed.hasPrefix("#") || trimmed.count == 6 {
            return try parseHexColor(trimmed)
        }
        
        // Try RGB format (r,g,b)
        if trimmed.contains(",") {
            return try parseRGBColor(trimmed)
        }
        
        throw ColorParseError.invalidFormat(trimmed)
    }
    
    // MARK: - Private Parsing Methods
    
    private static func parseNamedColor(_ name: String) -> Color? {
        switch name.lowercased() {
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
        case "clear": return .clear
        default: return nil
        }
    }
    
    private static func parseHexColor(_ hex: String) throws -> Color {
        let cleanHex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        
        guard cleanHex.count == 6 else {
            throw ColorParseError.invalidHexLength(hex)
        }
        
        guard let value = UInt32(cleanHex, radix: 16) else {
            throw ColorParseError.invalidHexValue(hex)
        }
        
        let red = Double((value & 0xFF0000) >> 16) / 255.0
        let green = Double((value & 0x00FF00) >> 8) / 255.0
        let blue = Double(value & 0x0000FF) / 255.0
        
        return Color(red: red, green: green, blue: blue)
    }
    
    private static func parseRGBColor(_ rgb: String) throws -> Color {
        let components = rgb.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard components.count == 3 else {
            throw ColorParseError.invalidRGBFormat(rgb)
        }
        
        guard let r = Int(components[0]), r >= 0 && r <= 255,
              let g = Int(components[1]), g >= 0 && g <= 255,
              let b = Int(components[2]), b >= 0 && b <= 255 else {
            throw ColorParseError.invalidRGBValues(rgb)
        }
        
        return Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}

// MARK: - Error Types

enum ColorParseError: LocalizedError {
    case invalidFormat(String)
    case invalidHexLength(String)
    case invalidHexValue(String)
    case invalidRGBFormat(String)
    case invalidRGBValues(String)
    case invalidOpacity(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let input):
            return "Invalid color format: '\(input)'. Use: name, #RRGGBB, or r,g,b"
        case .invalidHexLength(let hex):
            return "Invalid hex color length: '\(hex)'. Must be 6 characters after #"
        case .invalidHexValue(let hex):
            return "Invalid hex color value: '\(hex)'. Must contain valid hex digits (0-9, A-F)"
        case .invalidRGBFormat(let rgb):
            return "Invalid RGB format: '\(rgb)'. Must be 'r,g,b' with three comma-separated values"
        case .invalidRGBValues(let rgb):
            return "Invalid RGB values: '\(rgb)'. Each value must be 0-255"
        case .invalidOpacity(let opacity):
            return "Invalid opacity value: '\(opacity)'. Must be 0.0-1.0"
        }
    }
}
