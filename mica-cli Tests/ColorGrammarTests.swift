// ColorGrammarTests.swift
//
// One grammar, enumerated. §4.3 of the colour-resolution plan narrowed
// Mica's colour syntax to five families in Phase 3 (2026-08-03) and dropped six
// forms; this file is the list, and it asserts the two things the plan actually
// claims:
//
// 1. Every surviving form parses, everywhere.
// 2. Every dropped form is refused, **at all three entry points**. That second
//    half is the one worth having. Each dropped form had a mirror somewhere —
//    `ColorParser` and `AppexColorResolver` both hand-parsed bare `r,g,b(,a)` so
//    a string would mean the same in Mica and System mode — so removing it from
//    one place and not the other does not produce a compile error or a visible
//    failure. It produces `--icon-bg-color 1,0.5,0` working in System mode and
//    erroring in Mica mode, which is precisely the divergence the plan exists to
//    end. A single-entry-point test cannot see that.
//
// Deliberately **not** asserted: that a dropped form's error names its
// replacement. Decision D1 took the drops without migration hints, because the
// app is unreleased and nobody has those strings saved. What *is* asserted is the
// guidance on a live form's misuse — `srgb:1.2,0,0` naming `extended-srgb:` —
// which is in ColorParserTests.

import Testing
import SwiftUI

@Suite struct ColorGrammarTests {

    // MARK: - The three entry points

    /// The ways a colour string reaches Mica. Every one has to agree, because a
    /// user types one string and does not know which of them will read it.
    enum EntryPoint: String, CaseIterable, Sendable {
        /// What every CLI colour flag and the GUI's text entry use.
        case parser
        /// What `IconSettings` stores — the CLI's validating entry point.
        case storedValue
        /// System mode's projection onto Apple's plist grammar.
        case appex

        func parse(_ input: String) throws {
            switch self {
            case .parser: _ = try ColorParser.parseWithOpacity(input)
            case .storedValue: _ = try MicaColorValue(strictlyParsing: input)
            case .appex: _ = try AppexColor.plistValue(fromCLIString: input)
            }
        }
    }

    // MARK: - Accepted

    /// The five surviving families, from §4.3's table.
    private static let accepted: [String] = [
        // Tokens: canonical names, the `system.*` palette, the label ladder, and
        // the three aliases that survive (British spellings and one synonym).
        "blue", "red", "mint", "white", "black", "clear",
        "gray", "grey", "transparent",
        "system.blue", "system.gray", "system.grey",
        "label", "secondary.label", "tertiary.label", "quaternary.label",
        "BLUE", "System.Blue", "  blue  ",

        // Hex, 3/6/8 digits, `#` optional.
        "#FF0000", "FF0000", "#F00", "F00", "#FF0000CC", "FF0000CC",

        // Functions, with the alpha as a 4th argument rather than an rgba() name.
        "rgb(255,0,0)", "rgb(255,0,0,0.5)",
        "hsl(0,100%,50%)", "hsl(0,100%,50%,0.5)",

        // Bounded spaces, alpha optional.
        "srgb:1,0,0", "srgb:1,0,0,1", "srgb:0.2,0.42,0.9", "srgb:0.2,0.42,0.9,0.8",
        "display-p3:1,0,0", "display-p3:1,0.2,0,0.5",
        "SRGB:1,0,0", "Display-P3:1,0,0",

        // Unbounded spaces — the wide-gamut carriers. `extended-gray:` is
        // read-only, because Icon Composer writes it and Mica never does.
        "extended-srgb:0,0.53333,1,1",
        "extended-srgb:1.09300,-0.22670,-0.15010,1.00000",
        "extended-gray:1,1",

        // The opacity suffix, on each family that takes one.
        "blue:0.5", "label:0.5", "system.blue:0.25",
        "#FF0000:0.5", "rgb(255,0,0):0.5", "hsl(0,100%,50%):0.5",
    ]

    @Test("every surviving form parses at every entry point",
          arguments: accepted, EntryPoint.allCases)
    func acceptedFormParses(_ input: String, _ entry: EntryPoint) throws {
        try entry.parse(input)
    }

    // MARK: - Dropped

    /// Bare comma-separated components. The biggest single break, and the reason
    /// is in the values: the form read its numbers as 0–1 unless one exceeded 1
    /// and then as 0–255, so `1,1,1` was white while `2,2,2` was dark gray, and
    /// the dark gray `0.008,0.008,0.008` was unsayable. `srgb:` and `rgb()` each
    /// say exactly one thing.
    private static let droppedBareComponents = [
        "0,136,255", "0.2,0.42,0.9", "1,1,1", "2,2,2",
        "255,0,0,0.5", "1,0,0,0.25", "100%,50%,0%",
    ]

    /// The 18 CSS-ish names that appeared in no other Mica vocabulary — not in the
    /// GUI presets, not in the JSON writer's tokens, not in the appex grammar.
    /// Three of them (`darkgray`, `lightgray`) also name pre-rendered background
    /// *assets*, which is a separate fixed list and is unaffected — see
    /// `IconBackgroundFlagsTests`, where `--icon-bg-color darkgray` still resolves
    /// `background-darkgray-gradient`.
    private static let droppedLegacyNames = [
        "lightgray", "lightgrey", "darkgray", "darkgrey", "magenta", "lime",
        "navy", "maroon", "olive", "silver", "gold", "crimson", "violet",
        "turquoise", "coral", "salmon", "khaki", "plum", "orchid",
    ]

    /// One spelling per token: the no-dot forms were the canonical name with its
    /// dot deleted, which is a second spelling rather than a second name.
    private static let droppedNoDotAliases = [
        "systemblue", "systemred", "systemgreen", "systemorange", "systemyellow",
        "systempink", "systempurple", "systemteal", "systemindigo", "systemmint",
        "systemcyan", "systembrown", "systemgray", "systemgrey",
        "secondarylabel", "tertiarylabel", "quaternarylabel",
    ]

    /// Percentages inside `rgb()`, a lone number for gray, and the `rgba()`/
    /// `hsla()` spellings — each a duplicate of something above.
    ///
    /// The grayscale cases all carry a decimal point on purpose: a bare 3-digit
    /// integer such as `128` or `300` is short hex and always was, so it is not
    /// evidence either way about grayscale.
    private static let droppedDuplicates = [
        "rgb(50%,20%,0%)", "rgb(100%,50%,0%)",
        "0.5", "0.75", "128.0", "1.0",
        "rgba(255,0,0,0.5)", "hsla(0,100%,50%,0.5)",
    ]

    private static let allDropped =
        droppedBareComponents + droppedLegacyNames + droppedNoDotAliases + droppedDuplicates

    @Test("every dropped form is refused at every entry point",
          arguments: allDropped, EntryPoint.allCases)
    func droppedFormIsRefused(_ input: String, _ entry: EntryPoint) {
        #expect(throws: (any Error).self) { try entry.parse(input) }
    }

    // MARK: - The drops did not take a live form with them

    /// `srgb:` has to actually replace the bare triple, or the drop is a
    /// regression dressed up as a cleanup. Same colour, one spelling.
    @Test("srgb: expresses what the bare triple used to")
    func srgbReplacesTheBareTriple() throws {
        let viaPrefix = try MicaColorValue(strictlyParsing: "srgb:0.2,0.42,0.9")
        let viaFunction = try MicaColorValue(strictlyParsing: "rgb(51,107,230)")
        // Not identical — rgb() quantises to 1/255 — but the same colour to the
        // precision 8-bit output can carry.
        let a = try #require(components(of: viaPrefix))
        let b = try #require(components(of: viaFunction))
        #expect(abs(a.0 - b.0) < 0.005 && abs(a.1 - b.1) < 0.005 && abs(a.2 - b.2) < 0.005,
                "\(a) vs \(b)")
    }

    /// The whole point of a *token* is that it is not components, so the two
    /// spellings of Apple's blue must not collapse into each other.
    @Test("a token stays a token through the strict entry point")
    func tokenKeepsItsProvenance() throws {
        #expect(try MicaColorValue(strictlyParsing: "blue").tokenName == "blue")
        #expect(try MicaColorValue(strictlyParsing: "system.blue").tokenName == "system.blue")
        #expect(try MicaColorValue(strictlyParsing: "label:0.5").tokenName == "label")
        #expect(try MicaColorValue(strictlyParsing: "srgb:1,0,0").tokenName == nil)
    }

    /// System mode's one special branch: an appex-native token stays a name so
    /// Apple's curated rendering survives, and everything else becomes components.
    @Test("System mode keeps Apple's tokens and resolves the rest")
    func appexTokenBranch() throws {
        #expect(try AppexColor.plistValue(fromCLIString: "blue") == "blue")
        #expect(try AppexColor.plistValue(fromCLIString: "mint") == "mint")
        #expect(try AppexColor.plistValue(fromCLIString: "grey") == "gray")
        // A translucent white is no longer Apple's white.
        #expect(try AppexColor.plistValue(fromCLIString: "white:0.5") == "1,1,1,0.5")
        // `label` has no appex spelling, so it resolves.
        #expect(try AppexColor.plistValue(fromCLIString: "label").contains(","))
        // And so does anything given in components.
        #expect(try AppexColor.plistValue(fromCLIString: "srgb:1,0,0") == "1,0,0,1")
    }

    // MARK: - Helper

    private func components(of value: MicaColorValue) -> (Double, Double, Double)? {
        guard case .components(let extended) = value.source,
              case .srgb(let r, let g, let b, _) = extended else { return nil }
        return (r, g, b)
    }
}
