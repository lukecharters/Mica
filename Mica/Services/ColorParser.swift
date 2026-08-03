import SwiftUI
import Foundation
import AppKit

/// Serialises SwiftUI's `Color` → `NSColor` bridge.
///
/// **This is not defensive tidiness.** `NSColor.init(_: Color)` memoises through a
/// process-global `NSMapTable` of `ObjcColor` boxes with no synchronisation of its
/// own, so two threads converting at the same time can over-release a box and take
/// the process down with `EXC_BAD_ACCESS` inside `objc_release` — which is exactly
/// what happened on 2026-08-02, when `MicaColorValue.init(resolving:)` started
/// converting the whole token table on each call and Swift Testing ran two suites
/// in parallel.
///
/// The hazard predates that change; it was just rare enough not to have fired.
/// Every conversion in Mica goes through `ColorParser.nsColor(from:)` so there is
/// one place to hold the line.
private let colorBridgeLock = NSLock()

/// Mica's colour syntax, in one place: the string forms the CLI, the JSON reader
/// and any GUI text entry all accept.
///
/// Five families, and nothing else (§4.3 of `docs/plans/colour-resolution.md`):
/// a token from `ColorTokenTable`, hex, `rgb()`/`hsl()`, a *space-prefixed*
/// component list, and any of the first three with a `:opacity` suffix.
///
/// Six forms were dropped in Phase 3 on 2026-08-03, all of them footguns or
/// duplicates: bare `r,g,b(,a)`, 18 CSS-ish colour names, percentage `rgb()`
/// components, single-number grayscale, `systemblue`-style no-dot aliases, and
/// `rgba()`/`hsla()`. **Do not reinstate one to make a string parse** — the point
/// is that a colour has one spelling, so two surfaces cannot disagree about what
/// it means. The bare triple is the one worth remembering: it read as 0–1 unless
/// a component exceeded 1 and then as 0–255, so `1,1,1` was white and `2,2,2`
/// was dark gray. `srgb:` says the same thing without the guess.
struct ColorParser {

    /// Bounded-space prefixes, accepted as **input only**. Nothing writes them:
    /// a stored colour is a token or `extended-srgb:` (§4.4 of the plan), so
    /// there is one spelling in a configuration however it was typed.
    static let srgbSpaceName = "srgb"
    static let displayP3SpaceName = "display-p3"

    /// Convert a SwiftUI `Color` to an `NSColor`, safely from any thread.
    /// See `colorBridgeLock` — call this rather than `NSColor(color)` directly.
    static func nsColor(from color: Color) -> NSColor {
        colorBridgeLock.lock()
        defer { colorBridgeLock.unlock() }
        return NSColor(color)
    }
    
    // MARK: - Public Interface
    
    /// Parse a colour string that may carry a `:opacity` suffix — `"white:0.5"`,
    /// `"#0088FF:0.5"`, `"rgb(0,136,255):0.5"`.
    ///
    /// The suffix **scales** the colour's own alpha rather than replacing it
    /// (decision D4), so `label:0.5` is ~42% because `labelColor` is only ~85%
    /// opaque. Every colour flag in the CLI goes through here rather than through
    /// `parse`; `ColorOpacityFlagsTests` pins that.
    static func parseWithOpacity(_ input: String) throws -> Color {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Space-prefixed forms carry their own alpha and contain a colon, so they
        // must be recognised before the `name:opacity` split below — which would
        // otherwise read "display-p3" as a colour name and "1,0.2,0" as an
        // opacity. Do not reorder these.
        if let components = try spacePrefixedComponents(parsing: trimmed) {
            return components.color
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
    
    /// Parse a colour string with no opacity suffix. Four families, tried in
    /// order of how unambiguously each one identifies itself.
    static func parse(_ input: String) throws -> Color {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ColorParseError.emptyInput("Color string cannot be empty")
        }

        // Try different parsing strategies in order of specificity

        // 0. A form that names its own colour space — `srgb:`, `display-p3:`,
        //    `extended-srgb:`, `extended-gray:`. Tried first because naming the
        //    space is what makes a match unambiguous.
        if let components = try spacePrefixedComponents(parsing: trimmed) {
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

        // 3. Hex color formats (with multiple variations)
        if let color = try? parseHexColorVariations(trimmed) {
            return color
        }

        // If nothing worked, provide helpful error with suggestions
        throw ColorParseError.invalidFormat(trimmed, generateSuggestions(for: trimmed))
    }

    // MARK: - Space-Prefixed Components

    /// The `space:components` forms — every colour that names its own colour
    /// space, parsed in one place. Four space names in two pairs, which differ in
    /// what they promise:
    ///
    /// - **`srgb:` and `display-p3:`** name *bounded* spaces, so components must
    ///   be 0–1 and anything outside is a mistake worth reporting rather than a
    ///   colour to quietly clamp. Alpha is optional and defaults to 1. A
    ///   `display-p3:` colour is converted here, at the door, so everything
    ///   downstream stores one space.
    /// - **`extended-srgb:` and `extended-gray:`** name *extended* spaces, where
    ///   components legitimately fall outside 0–1 — that is how a wide-gamut
    ///   colour is carried. `extended-srgb:` is what Mica writes;
    ///   `extended-gray:` is read-only, because Icon Composer writes it.
    ///
    /// Returns `nil` when `input` names no space at all, so callers fall through
    /// to the other syntaxes. Throws when the space name matches but the
    /// components do not — `"srgb:oops"` is a mistake worth reporting, not a
    /// colour name to keep guessing at.
    ///
    /// **Every caller must try this before splitting on `:` for an opacity
    /// suffix.** `parse`, `parseWithOpacity` and `MicaColorValue.init(parsing:)`
    /// all do; reordering any of them makes `display-p3` read as a colour name.
    static func spacePrefixedComponents(parsing input: String) throws -> ExtendedComponents? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = trimmed.firstIndex(of: ":") else { return nil }
        let space = String(trimmed[trimmed.startIndex..<separator]).lowercased()

        switch space {
        case ExtendedComponents.srgbSpaceName, ExtendedComponents.graySpaceName:
            return try ExtendedComponents(parsing: trimmed)
        case srgbSpaceName, displayP3SpaceName:
            return try boundedComponents(
                space: space,
                body: String(trimmed[trimmed.index(after: separator)...]),
                source: trimmed
            )
        default:
            return nil
        }
    }

    /// `srgb:r,g,b(,a)` or `display-p3:r,g,b(,a)`, every component in 0–1.
    private static func boundedComponents(
        space: String,
        body: String,
        source: String
    ) throws -> ExtendedComponents {
        let parts = body
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard parts.count == 3 || parts.count == 4 else {
            throw ColorParseError.invalidSpaceComponents(
                source,
                "\(space): takes 3 or 4 components (r,g,b or r,g,b,a), got \(parts.count)"
            )
        }

        var values: [Double] = []
        for part in parts {
            guard let value = Double(part), value.isFinite else {
                throw ColorParseError.invalidSpaceComponents(
                    source,
                    "Components must be numbers, e.g. \"\(space):0.2,0.6,0.9\""
                )
            }
            // Bounded space, so an out-of-range component is reported rather than
            // clamped: silently desaturating someone's colour is the failure mode
            // this whole grammar exists to end. `extended-srgb:` is the escape.
            guard (0.0...1.0).contains(value) else {
                throw ColorParseError.invalidSpaceComponents(
                    source,
                    "\(space): components are 0-1, and \(value) is outside that. "
                        + "Use \(ExtendedComponents.srgbSpaceName): for a colour beyond the gamut."
                )
            }
            values.append(value)
        }

        let alpha = values.count == 4 ? values[3] : 1.0
        if space == displayP3SpaceName {
            return .convertingDisplayP3(r: values[0], g: values[1], b: values[2], a: alpha)
        }
        return .srgb(r: values[0], g: values[1], b: values[2], a: alpha)
    }

    // MARK: - CSS-Style Color Parsing

    private static func parseCSSStyleColor(_ input: String) throws -> Color {
        let lowercased = input.lowercased()

        if lowercased.hasPrefix("rgb(") {
            return try parseRGBFunctionColor(input)
        }

        if lowercased.hasPrefix("hsl(") {
            return try parseHSLColor(input)
        }

        throw ColorParseError.unsupportedCSSFormat(input)
    }

    /// `rgb(r,g,b)` or `rgb(r,g,b,a)`. Alpha folds into `rgb()` rather than
    /// earning a separate `rgba()` spelling — one function, one name.
    private static func parseRGBFunctionColor(_ input: String) throws -> Color {
        let content = try extractFunctionContent(input, functionName: "rgb")
        let components = parseCommaSeparatedValues(content)

        guard components.count == 3 || components.count == 4 else {
            throw ColorParseError.invalidRGBFormat(input, "rgb() takes 3 or 4 values (r,g,b or r,g,b,a)")
        }

        let rgb = try parseRGBComponents(Array(components[0..<3]), source: input)
        let alpha = components.count == 4 ? try parseAlphaComponent(components[3], source: input) : 1.0
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2, opacity: alpha)
    }

    /// `hsl(h,s%,l%)` or `hsl(h,s%,l%,a)`. Saturation and lightness keep their
    /// `%` signs — they are percentages by definition, which is why dropping
    /// percentage components from `rgb()` does not touch them.
    private static func parseHSLColor(_ input: String) throws -> Color {
        let content = try extractFunctionContent(input, functionName: "hsl")
        let components = parseCommaSeparatedValues(content)

        guard components.count == 3 || components.count == 4 else {
            throw ColorParseError.invalidHSLFormat(input, "hsl() takes 3 or 4 values (h,s%,l% or h,s%,l%,a)")
        }

        let alpha = components.count == 4 ? try parseAlphaComponent(components[3], source: input) : 1.0
        return try parseHSLComponents(Array(components[0..<3]), alpha: alpha, source: input)
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
    
    // MARK: - RGB Components

    /// The integer components inside `rgb()`, 0–255.
    ///
    /// Percentages were dropped in Phase 3: `rgb(100%,50%,0%)` and
    /// `srgb:1,0.5,0` said the same thing, and one of them names its colour
    /// space. The error points at the survivor.
    private static func parseRGBComponents(_ components: [String], source: String) throws -> (Double, Double, Double) {
        var rgbValues: [Double] = []

        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let intValue = Int(trimmed), intValue >= 0 && intValue <= 255 else {
                throw ColorParseError.invalidRGBValues(
                    source,
                    "rgb() values are integers 0-255. For fractional components use \"\(srgbSpaceName):r,g,b\"."
                )
            }
            rgbValues.append(Double(intValue) / 255.0)
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
                "Named colors: blue, red, label, system.blue",
                "Hex: #FF5733, #F53, #FF5733CC",
                "Functions: rgb(255,87,51), hsl(9,100%,60%)",
                "Components: srgb:1,0.34,0.2 or display-p3:1,0.34,0.2",
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
    /// `"extended-gray:1.00000,1.00000"`. This is Icon Composer's encoding, and
    /// the form `MicaColorValue` stores when a colour has no token to name it.
    ///
    /// It is also the type the bounded `srgb:`/`display-p3:` input forms resolve
    /// *to*, so there is one stored space however a colour was typed. See
    /// `ColorParser.spacePrefixedComponents(parsing:)`.
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

        /// Rounded to `places` decimal places. `MicaColorValue` applies this at
        /// construction so that equality means "writes the same string" — see D5
        /// in `docs/plans/colour-resolution.md`.
        ///
        /// Deliberately rounds the components rather than clamping them: an
        /// out-of-gamut Display P3 pick has to survive this.
        func rounded(to places: Int) -> ExtendedComponents {
            let scale = pow(10.0, Double(places))
            func round(_ value: Double) -> Double {
                guard value.isFinite else { return value }
                return (value * scale).rounded() / scale
            }
            switch self {
            case .srgb(let r, let g, let b, let a):
                return .srgb(r: round(r), g: round(g), b: round(b), a: round(a))
            case .gray(let white, let alpha):
                return .gray(white: round(white), alpha: round(alpha))
            }
        }

        /// The same colour with its alpha scaled — how `MicaColorValue` folds an
        /// opacity modifier into a components source, so `alpha` is only ever a
        /// modifier on a *token*.
        func multiplyingAlpha(by factor: Double) -> ExtendedComponents {
            guard factor != 1 else { return self }
            switch self {
            case .srgb(let r, let g, let b, let a):
                return .srgb(r: r, g: g, b: b, a: a * factor)
            case .gray(let white, let alpha):
                return .gray(white: white, alpha: alpha * factor)
            }
        }

        /// Display P3 components (0–1), converted to the extended sRGB Mica
        /// stores — the `display-p3:` input form's destination.
        ///
        /// P3 is the wider gamut, so most of it lands *outside* 0–1 here: a P3 red
        /// is `extended-srgb:1.09300,-0.22670,-0.15010,1.00000`. Nothing clamps,
        /// because that conversion is exactly how a wide-gamut colour survives to
        /// the Display P3 export path (§1.2 of the plan). Storing one space is
        /// what lets the JSON writer, the renderer and the appex projection each
        /// have a single case to handle.
        static func convertingDisplayP3(r: Double, g: Double, b: Double, a: Double) -> ExtendedComponents {
            let p3 = NSColor(
                colorSpace: .displayP3,
                components: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)],
                count: 4
            )
            // `usingColorSpace` returns nil only for pattern colours, which a
            // component colour never is.
            guard let extended = p3.usingColorSpace(.extendedSRGB) else {
                return .srgb(r: r, g: g, b: b, a: a)
            }
            return .srgb(
                r: Double(extended.redComponent),
                g: Double(extended.greenComponent),
                b: Double(extended.blueComponent),
                a: Double(extended.alphaComponent)
            )
        }

        /// Resolve a `Color` to extended sRGB components.
        ///
        /// Always `.srgb`, never `.gray`: extended sRGB represents everything the
        /// gray space can, so one output form keeps the writer's behaviour
        /// predictable. `.gray` exists to *read* what Icon Composer writes.
        ///
        /// A dynamic colour is resolved against the current drawing appearance and
        /// stops being dynamic. That loss is why `MicaColorValue` keeps a token
        /// whenever it has one and only falls back to this.
        static func resolving(_ color: Color) -> ExtendedComponents {
            let nsColor = ColorParser.nsColor(from: color)
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
    case invalidRGBValues(String, String)
    case invalidHSLFormat(String, String)
    case invalidHue(String, String)
    case invalidPercentage(String, String)
    case invalidAlpha(String, String)
    case invalidOpacity(String, String)
    case invalidExtendedComponents(String, String)
    case invalidSpaceComponents(String, String)
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
        case .invalidRGBValues(let rgb, let message):
            return "Invalid RGB values: '\(rgb)'. \(message)"
        case .invalidHSLFormat(let hsl, let message):
            return "Invalid HSL format: '\(hsl)'. \(message)"
        case .invalidHue(let source, let message):
            return "Invalid hue in '\(source)'. \(message)"
        case .invalidPercentage(let source, let message):
            return "Invalid percentage in '\(source)'. \(message)"
        case .invalidAlpha(let source, let message):
            return "Invalid alpha in '\(source)'. \(message)"
        case .invalidOpacity(let opacity, let message):
            return "Invalid opacity value: '\(opacity)'. \(message)"
        case .invalidExtendedComponents(let input, let message):
            return "Invalid extended color components: '\(input)'. \(message)"
        case .invalidSpaceComponents(let input, let message):
            return "Invalid color components: '\(input)'. \(message)"
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
