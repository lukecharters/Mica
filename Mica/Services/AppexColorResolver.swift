import Foundation
import SwiftUI

extension AppexColor {
    /// Resolve a CLI or configuration colour string to a plist colour value for
    /// the appex (Apple Reference) pipeline. Two branches:
    ///
    /// 1. A named appex token (`"blue"`, `"white"`, …) → returned as-is, so
    ///    Apple's curated rendering for that token is used.
    /// 2. Anything else `ColorParser` understands → resolved and written as an
    ///    sRGB `"r,g,b,a"` string, the format real system icon plists use (e.g.
    ///    `1,0.0902,0.2118,1`).
    ///
    /// `white` and `white:0.5` deliberately take different branches: a bare token
    /// is Apple's curated colour, while a translucent white is no longer that
    /// colour, so it resolves to custom components like any other non-token input.
    ///
    /// **There is no third branch, and adding one would split the grammar.** Until
    /// Phase 3 (2026-08-03) this function parsed bare comma-separated `r,g,b(,a)`
    /// itself, mirroring `ColorParser`'s 0–1-or-0–255 heuristic so that a string
    /// meant the same thing in both generation modes. `ColorParser` dropped that
    /// form, so the mirror had to go with it — otherwise `--icon-bg-color 1,0.5,0`
    /// would work in System mode and fail in Mica mode, which is precisely the
    /// per-surface divergence the colour-resolution plan exists to end.
    /// The `"r,g,b,a"` string remains what gets *written* to the plist; `srgb:` is
    /// how one is typed.
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

        // 2. Anything ColorParser understands (hex, rgb(), srgb:, display-p3:, …).
        let color = try ColorParser.parseWithOpacity(trimmed)
        return rgbaString(from: color)
    }

    /// Resolve a CLI/config colour string to an `AppexColor` value — the form the
    /// configuration codec stores on `MicaAppexColors`. Same first branch as
    /// `plistValue(fromCLIString:)`, and validated *through* it so the two can
    /// never disagree about what resolves at all: a named token keeps Apple's
    /// curated rendering, anything else becomes a custom colour.
    ///
    /// The custom colour keeps its **provenance** rather than the plist's
    /// components. Reading a value back through `plistValue` and re-splitting it
    /// would clamp to sRGB and discard the token here, one step before the plist
    /// clamps anyway — so `white:0.5` came back as `1,1,1,0.5` and stopped
    /// following the appearance. Clamping belongs at the plist and nowhere else.
    static func parsing(cliString input: String) throws -> AppexColor {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let token = AppexNamedColor(rawValue: normalizeBritishSpelling(trimmed)) {
            return .named(token)
        }
        // Fails here, with ColorParser's suggestions, rather than at a render that
        // would draw a plausible white.
        _ = try plistValue(fromCLIString: trimmed)
        return .custom(try MicaColorValue(strictlyParsing: trimmed))
    }
}
