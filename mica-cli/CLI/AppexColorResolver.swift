import Foundation
import SwiftUI

extension AppexColor {
    /// Resolve a CLI argument string to a plist colour value for the appex
    /// (Apple Reference) pipeline. Accepts:
    /// - a named appex token (`"blue"`, `"white"`, …) → returned as-is so Apple's
    ///   curated rendering for that token is used,
    /// - bare comma-separated `r,g,b` or `r,g,b,a` components (0–1 floats, or
    ///   0–255 when any of r/g/b exceeds 1) → normalised to an `"r,g,b,a"`
    ///   string (the format real system icon plists use, e.g. `1,0.0902,0.2118,1`),
    /// - any format `ColorParser` understands (hex, `rgb()`, CSS names, …) →
    ///   converted to an sRGB `"r,g,b,a"` string.
    ///
    /// Throws `ColorParseError` when the input cannot be resolved.
    static func plistValue(fromCLIString input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ColorParseError.emptyInput("Color string cannot be empty")
        }

        // 1. Named appex token ("grey" resolves to Apple's curated "gray").
        if let token = AppexNamedColor(rawValue: normalizeBritishSpelling(trimmed)) {
            return token.rawValue
        }

        // 2. Bare comma-separated components (the format seen in real plists).
        if trimmed.contains(","), !trimmed.contains("(") {
            let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 3 || parts.count == 4 {
                let numbers = parts.compactMap { Double($0) }
                if numbers.count == parts.count {
                    var values = numbers
                    // If any of r/g/b exceeds 1, treat the triple as 0–255.
                    if values.prefix(3).contains(where: { $0 > 1.0 }) {
                        values = values.enumerated().map { index, value in
                            index < 3 ? value / 255.0 : value
                        }
                    }
                    if values.count == 3 { values.append(1.0) }
                    return rgbaString(
                        r: CGFloat(values[0]),
                        g: CGFloat(values[1]),
                        b: CGFloat(values[2]),
                        a: CGFloat(values[3])
                    )
                }
            }
        }

        // 3. Anything ColorParser understands (hex, rgb(), CSS names, …).
        let color = try ColorParser.parse(trimmed)
        return rgbaString(from: color)
    }
}
