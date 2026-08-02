import SwiftUI
import Foundation
import AppKit

/// Enhanced color parser supporting multiple formats with comprehensive validation
/// Supports: Named colors, Hex codes, RGB values, HSL, CSS colors, system colors, and opacity notation
struct ColorParser {
    
    // MARK: - Public Interface
    
    /// Parse a color string that may include opacity (e.g., "white:0.5", "rgba(255,255,255,0.5)")
    static func parseWithOpacity(_ input: String) throws -> Color {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extended-component forms carry their own alpha and contain a colon, so
        // they must be recognised before the `name:opacity` split below — which
        // would otherwise read "extended-srgb" as a colour name.
        if let components = try ExtendedComponents(parsing: trimmed) {
            return components.color
        }

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

        // 0. Extended-component form (`extended-srgb:` / `extended-gray:`), the
        //    form `.mica` documents store. Tried first because it is the only one
        //    that names its colour space, so a match is unambiguous.
        if let components = try ExtendedComponents(parsing: trimmed) {
            return components.color
        }

        // 1. CSS-style functions (rgb, hsl)
        if let color = try? parseCSSStyleColor(trimmed) {
            return color
        }

        // 2. A token from `ColorTokenTable` — the one vocabulary the GUI presets,
        //    the JSON writer and the appex pipeline also read. Canonical names and
        //    aliases, case-insensitively.
        if let color = ColorTokenTable.color(forToken: trimmed) {
            return color
        }

        // 3. Legacy CSS-ish colour names that exist in no other Mica vocabulary.
        if let namedColor = parseLegacyNamedColor(trimmed) {
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
    
    // MARK: - Legacy Named Color Parsing

    /// CSS-ish colour names that appear in no other Mica vocabulary — not in the
    /// GUI presets, not in the JSON writer's tokens, not in the appex grammar. They
    /// are kept only because they already parse; §4.3 of
    /// `docs/plans/colour-resolution.md` drops them in Phase 3, since hex says the
    /// same thing unambiguously. **Do not add to this list** — a new colour name
    /// belongs in `ColorTokenTable`.
    private static func parseLegacyNamedColor(_ name: String) -> Color? {
        switch name.lowercased() {
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
    
    /// Bare comma-separated `r,g,b(,a)`. Component semantics deliberately match
    /// the System-mode resolver (`AppexColor.plistValue(fromCLIString:)`) so the
    /// same string means the same color in both generation modes: components are
    /// 0–1 floats, or 0–255 when any of r/g/b exceeds 1; percentages are also
    /// accepted; alpha is always 0–1.
    private static func parseRGBVariations(_ input: String) throws -> Color {
        let components = parseCommaSeparatedValues(input)

        guard components.count == 3 || components.count == 4 else {
            throw ColorParseError.invalidRGBFormat(input, "RGB format requires 3 or 4 comma-separated values (r,g,b or r,g,b,a)")
        }

        let rgb = try parseBareRGBComponents(Array(components[0..<3]), source: input)
        let alpha = components.count == 4 ? try parseAlphaComponent(components[3], source: input) : 1.0
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2, opacity: alpha)
    }

    private static func parseBareRGBComponents(_ components: [String], source: String) throws -> (Double, Double, Double) {
        var values: [Double] = []
        var isPercentage: [Bool] = []

        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasSuffix("%") {
                let percentString = String(trimmed.dropLast())
                guard let percent = Double(percentString), percent >= 0 && percent <= 100 else {
                    throw ColorParseError.invalidRGBPercentage(source, "RGB percentage values must be 0-100%")
                }
                values.append(percent / 100.0)
                isPercentage.append(true)
            } else {
                guard let value = Double(trimmed), value >= 0 && value <= 255 else {
                    throw ColorParseError.invalidRGBValues(source, "RGB values must be 0-1 floats, 0-255, or percentages 0-100%")
                }
                values.append(value)
                isPercentage.append(false)
            }
        }

        // Scale rule (mirrors AppexColorResolver): if any non-percentage
        // component exceeds 1, all non-percentage components are 0-255.
        let treatAs255 = zip(values, isPercentage).contains { value, isPercent in !isPercent && value > 1.0 }
        let normalized = zip(values, isPercentage).map { value, isPercent in
            (treatAs255 && !isPercent) ? value / 255.0 : value
        }

        return (normalized[0], normalized[1], normalized[2])
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

        // CSS HSL ≠ HSB: SwiftUI's Color(hue:saturation:brightness:) takes HSB,
        // so convert (e.g. hsl(0,100%,50%) is pure red — brightness 1, not 0.5).
        let brightness = lightness + saturation * min(lightness, 1 - lightness)
        let hsbSaturation = brightness == 0 ? 0 : 2 * (1 - lightness / brightness)

        return Color(hue: hue, saturation: hsbSaturation, brightness: brightness, opacity: alpha)
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
        
        // Suggest similar named colors, from the one token table — so a token
        // added there is suggestible without a second list being remembered.
        let namedColors = ColorTokenTable.presentable.map(\.name)
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

// MARK: - Extended Component Form

extension ColorParser {
    /// A colour written as its colour space's name, a colon, then components —
    /// `"extended-srgb:0.00000,0.47843,1.00000,1.00000"` or
    /// `"extended-gray:1.00000,1.00000"`. This is Icon Composer's encoding, and the
    /// resolved form a `.mica` document stores (see `MicaColor`).
    ///
    /// Both spaces are *extended*, so components legitimately fall outside 0–1: a
    /// Display P3 red is `extended-srgb:1.09300,-0.22670,-0.15010,1.00000`. That is
    /// what lets one space name carry wide-gamut colours, and why nothing here
    /// clamps — clamping would quietly desaturate every P3 colour it round-tripped.
    enum ExtendedComponents: Equatable, Hashable, Sendable {
        /// Red, green, blue and alpha in extended sRGB.
        case srgb(r: Double, g: Double, b: Double, a: Double)
        /// White and alpha in extended gamma-2.2 gray — two components, as Icon
        /// Composer writes for pure white and black.
        case gray(white: Double, alpha: Double)

        static let srgbSpaceName = "extended-srgb"
        static let graySpaceName = "extended-gray"

        // MARK: Parsing

        /// Parse the extended-component form.
        ///
        /// Returns `nil` when `input` is not in this form at all, so callers can
        /// fall through to the other colour syntaxes. Throws when the space name
        /// matches but the components do not — `"extended-srgb:oops"` is a mistake
        /// worth reporting, not a colour name to keep guessing at.
        init?(parsing input: String) throws {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let separator = trimmed.firstIndex(of: ":") else { return nil }
            let space = String(trimmed[trimmed.startIndex..<separator]).lowercased()
            guard space == Self.srgbSpaceName || space == Self.graySpaceName else { return nil }

            let body = trimmed[trimmed.index(after: separator)...]
            let parts = body
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            var values: [Double] = []
            for part in parts {
                guard let value = Double(part), value.isFinite else {
                    throw ColorParseError.invalidExtendedComponents(
                        trimmed,
                        "Components must be finite numbers, e.g. \"\(Self.srgbSpaceName):0.00000,0.47843,1.00000,1.00000\""
                    )
                }
                values.append(value)
            }

            switch (space, values.count) {
            case (Self.srgbSpaceName, 4):
                self = .srgb(r: values[0], g: values[1], b: values[2], a: values[3])
            case (Self.graySpaceName, 2):
                self = .gray(white: values[0], alpha: values[1])
            case (Self.srgbSpaceName, let count):
                throw ColorParseError.invalidExtendedComponents(
                    trimmed, "\(Self.srgbSpaceName) requires 4 components (r,g,b,a), got \(count)"
                )
            case (_, let count):
                throw ColorParseError.invalidExtendedComponents(
                    trimmed, "\(Self.graySpaceName) requires 2 components (white,alpha), got \(count)"
                )
            }
        }

        // MARK: Writing

        /// The string form, at five decimal places to match Icon Composer — more
        /// than enough to survive an 8-bit-per-channel round trip.
        ///
        /// `String(format:)` is deliberately called without a locale, so the decimal
        /// separator is always `.` regardless of the user's region.
        var stringValue: String {
            switch self {
            case .srgb(let r, let g, let b, let a):
                return "\(Self.srgbSpaceName):\(Self.format(r)),\(Self.format(g)),\(Self.format(b)),\(Self.format(a))"
            case .gray(let white, let alpha):
                return "\(Self.graySpaceName):\(Self.format(white)),\(Self.format(alpha))"
            }
        }

        private static func format(_ value: Double) -> String {
            String(format: "%.5f", value)
        }

        /// Resolve a `Color` to extended sRGB components.
        ///
        /// Always `.srgb`, never `.gray`: extended sRGB represents everything the
        /// gray space can, so one output form keeps the writer's behaviour
        /// predictable. `.gray` exists to *read* what Icon Composer writes.
        ///
        /// A dynamic colour is resolved against the current drawing appearance and
        /// stops being dynamic. That loss is why `MicaColor` prefers a semantic
        /// token and only falls back to this.
        static func resolving(_ color: Color) -> ExtendedComponents {
            let nsColor = NSColor(color)
            // `usingColorSpace` returns nil only for pattern colours, which cannot
            // reach here — every Mica colour is a component colour.
            guard let resolved = nsColor.usingColorSpace(.extendedSRGB) ?? nsColor.usingColorSpace(.sRGB) else {
                return .srgb(r: 0, g: 0, b: 0, a: 0)
            }
            return .srgb(
                r: Double(resolved.redComponent),
                g: Double(resolved.greenComponent),
                b: Double(resolved.blueComponent),
                a: Double(resolved.alphaComponent)
            )
        }

        /// The colour these components describe.
        var color: Color {
            switch self {
            case .srgb(let r, let g, let b, let a):
                return Color(nsColor: NSColor(
                    colorSpace: .extendedSRGB,
                    components: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)],
                    count: 4
                ))
            case .gray(let white, let alpha):
                return Color(nsColor: NSColor(
                    colorSpace: .extendedGenericGamma22Gray,
                    components: [CGFloat(white), CGFloat(alpha)],
                    count: 2
                ))
            }
        }
    }
}

// MARK: - Spelling Normalisation

/// Accept British/Australian spellings in CLI token values by normalising
/// `colour` → `color` and `grey` → `gray`. Returns a lowercased string, so use
/// only where the consumer compares against lowercased US-spelled tokens
/// (rendering modes, prerendered asset colour names, appex colour tokens) —
/// not on free-form colour strings, which `ColorParser` already handles.
func normalizeBritishSpelling(_ input: String) -> String {
    input.lowercased()
        .replacingOccurrences(of: "colour", with: "color")
        .replacingOccurrences(of: "grey", with: "gray")
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
    case invalidExtendedComponents(String, String)
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
        case .invalidExtendedComponents(let input, let message):
            return "Invalid extended color components: '\(input)'. \(message)"
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
