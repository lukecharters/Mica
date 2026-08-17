// ColorTokenTests.swift
//
// `ColorTokenTable` exists to stop four independent colour vocabularies drifting
// apart — the GUI presets, the parser, the JSON writer and the appex plist. These
// tests are what make "derived" mean something: each one fails if a consumer
// grows a second list, or if the table gains a token a consumer cannot honour.

import Testing
import SwiftUI
import AppKit
@testable import Mica

/// The AppKit-backed spellings removed on 2026-08-17, deliberately **without**
/// aliases: an alias would have kept two names for one colour alive indefinitely,
/// which is what the table exists to prevent. A configuration naming one now
/// fails loudly rather than resolving to a second spelling.
private let retiredAppKitNames = [
    "system.blue", "system.red", "system.green", "system.orange",
    "system.yellow", "system.pink", "system.purple", "system.teal",
    "system.indigo", "system.mint", "system.cyan", "system.brown",
    "system.gray", "system.grey",
    "label", "secondary.label", "tertiary.label", "quaternary.label",
]

@Suite(.tags(.unit))
@MainActor
struct ColorTokenTests {

    private func inAppearance<T>(_ name: NSAppearance.Name, _ body: () -> T) -> T {
        var result: T!
        NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
            result = body()
        }
        return result
    }

    private func srgbBytes(_ color: Color) -> AppleTokenRGB {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        func byte(_ v: CGFloat) -> Int { Int((v * 255).rounded()) }
        return AppleTokenRGB(byte(ns.redComponent), byte(ns.greenComponent), byte(ns.blueComponent))
    }

    // MARK: - The table's own invariants

    @Test("canonical names are lowercase, unique and non-empty")
    func names_areWellFormed() {
        var seen = Set<String>()
        for token in ColorTokenTable.all {
            #expect(!token.name.isEmpty)
            #expect(token.name == token.name.lowercased(), "\(token.name) is not lowercase")
            #expect(seen.insert(token.name).inserted, "\(token.name) appears twice")
        }
    }

    @Test("no alias collides with a canonical name or another alias")
    func aliases_areUnambiguous() {
        var owners: [String: String] = [:]
        for token in ColorTokenTable.all {
            for spelling in [token.name] + token.aliases {
                let key = spelling.lowercased()
                if let existing = owners[key] {
                    Issue.record("'\(spelling)' is claimed by both \(existing) and \(token.name)")
                }
                owners[key] = token.name
            }
        }
    }

    @Test("every token, and every alias, looks up to the same token")
    func lookup_findsCanonicalAndAliases() throws {
        for token in ColorTokenTable.all {
            for spelling in [token.name] + token.aliases {
                let found = try #require(ColorTokenTable.token(named: spelling), "\(spelling) does not look up")
                #expect(found.name == token.name)
            }
            // Case-insensitive, and whitespace-tolerant, matching the parser.
            #expect(ColorTokenTable.token(named: token.name.uppercased())?.name == token.name)
            #expect(ColorTokenTable.token(named: "  \(token.name)  ")?.name == token.name)
        }
    }

    @Test("an unknown name is not a token")
    func lookup_rejectsUnknown() {
        #expect(ColorTokenTable.token(named: "") == nil)
        #expect(ColorTokenTable.token(named: "not-a-colour") == nil)
        // A legacy CSS-ish name the parser still accepts is deliberately not a
        // token — §4.3 of the plan drops those in Phase 3.
        #expect(ColorTokenTable.token(named: "crimson") == nil)
        #expect(ColorTokenTable.token(named: "magenta") == nil)
    }

    // MARK: - Every token parses back to itself

    @Test("every token parses to its own colour", arguments: ColorTokenTable.all.map(\.name))
    func everyToken_parsesToItsOwnColour(_ name: String) throws {
        let token = try #require(ColorTokenTable.token(named: name))
        let parsed = try ColorParser.parse(name)
        #expect(parsed == token.color, "\(name) parses to a different colour than the table resolves")
    }

    @Test("every alias parses to its token's colour")
    func everyAlias_parsesToItsTokenColour() throws {
        for token in ColorTokenTable.all {
            for alias in token.aliases {
                let parsed = try ColorParser.parse(alias)
                #expect(parsed == token.color, "alias '\(alias)' parses to a different colour than \(token.name)")
            }
        }
    }

    @Test("parseWithOpacity resolves a token the same way parse does")
    func parseWithOpacity_agreesWithParse() throws {
        for token in ColorTokenTable.all {
            #expect(try ColorParser.parseWithOpacity(token.name) == token.color, "\(token.name) disagrees")
        }
    }

    // MARK: - The appex-native subset

    /// The exact list the appex `Info.plist` accepts, established empirically on
    /// 2026-08-02 (§1.1 of the colour-resolution plan). This is a *closed*
    /// set defined by Apple's pipeline, not by Mica, so it is spelled out here
    /// rather than derived — that is the whole point of the assertion.
    private static let appexAcceptedTokens: Set<String> = [
        "black", "blue", "brown", "cyan", "gray", "green", "indigo", "mint",
        "orange", "pink", "purple", "red", "teal", "white", "yellow",
    ]

    @Test("the appex-native subset is exactly the 15 the pipeline accepts")
    func appexNative_isExactlyApplesFifteen() {
        let flagged = Set(ColorTokenTable.appexNative.map(\.name))
        #expect(flagged == Self.appexAcceptedTokens)
        #expect(ColorTokenTable.appexNative.count == 15)
    }

    @Test("AppexNamedColor is exactly the appex-native subset")
    func appexNamedColor_derivesFromTheTable() {
        #expect(AppexNamedColor.allCases.map(\.rawValue) == ColorTokenTable.appexNative.map(\.name))
    }

    @Test("mint is reachable from System mode")
    func mint_isAppexNative() throws {
        // The gap this table was built to close: the pipeline accepts `mint` and
        // the hand-written enum had no case for it until 2026-08-02, so a mint
        // System-mode icon silently resolved to components instead of Apple's
        // curated tile.
        let mint = try #require(AppexNamedColor(rawValue: "mint"))
        #expect(AppexColor.named(mint).plistValue == "mint")
        #expect(try AppexColor.plistValue(fromCLIString: "mint") == "mint")
        #expect(try AppexColor.parsing(cliString: "mint") == .named(mint))
    }

    @Test("every appex-native token survives the CLI resolver as a token")
    func appexNative_resolvesAsTokensFromTheCLI() throws {
        // Branch 1 of `plistValue(fromCLIString:)` — anything that falls through to
        // components has lost Apple's curated rendering without saying so.
        for token in ColorTokenTable.appexNative {
            #expect(try AppexColor.plistValue(fromCLIString: token.name) == token.name)
            #expect(try AppexColor.plistValue(fromCLIString: token.name.uppercased()) == token.name)
        }
    }

    @Test("no appex-native token needs a spelling the plist would reject")
    func appexNative_spellingsAreValid() {
        // The plist grammar is a bare lowercase word — no dots, no spaces.
        for token in ColorTokenTable.appexNative {
            #expect(!token.name.contains("."), "\(token.name) has a dot")
            #expect(!token.name.contains(" "), "\(token.name) has a space")
            let allLetters = token.name.allSatisfy { $0.isLetter }
            #expect(allLetters, "\(token.name) is not all letters")
        }
    }

    // MARK: - The consumers cannot drift

    /// `ColorPickerWithDropdown.presets` defaults to `.presentable`, so this is the
    /// GUI's swatch list itself rather than a copy of it. It went through
    /// `OptionsCatalog.colorOptions` until 2026-08-16, when that type was deleted
    /// along with the pre-rendered background picker it was written for.
    @Test("every presentable token gives the picker a display name and a colour")
    func presentableTokens_areUsableAsPresets() {
        for token in ColorTokenTable.presentable {
            #expect(!token.displayName.isEmpty, "\(token.name) has no display name")
        }
    }

    @Test("every GUI preset is a name the parser accepts")
    func presentableTokenNamesParse() throws {
        for token in ColorTokenTable.presentable {
            let parsed = try ColorParser.parse(token.displayName)
            #expect(parsed == token.color,
                    "the preset '\(token.displayName)' parses to a different colour")
        }
    }

    @Test("every token round-trips through the value type as itself")
    func micaColorValue_keepsEveryToken() throws {
        // The writer emits `stringValue`; reading it back must give the same
        // token, or a configuration would drift a little on every save.
        for token in ColorTokenTable.all {
            let value = MicaColorValue.token(token.name)
            #expect(value.stringValue == token.name)
            #expect(try MicaColorValue(parsing: value.stringValue) == value)
        }
    }

    // MARK: - Display names

    @Test("display names are derived, not stored")
    func displayName_isDerivedFromTheName() {
        #expect(ColorTokenTable.token(named: "blue")?.displayName == "Blue")
        #expect(ColorTokenTable.token(named: "primary")?.displayName == "Primary")
        // No token carries a dot since the `system.*` spellings went, but the
        // derivation still has to handle one — a name is the only input a display
        // string may have, and a hand-written second list is what this prevents.
        #expect(ColorToken("secondary.label") { .clear }.displayName == "Secondary Label")
    }

    @Test("presets are listed alphabetically by display name")
    func presentable_isAlphabetical() {
        let names = ColorTokenTable.presentable.map(\.displayName)
        #expect(names == names.sorted())
    }

    // MARK: - The oracle: tokens resolve to what Apple says they mean

    @Test("every appex-native token resolves to Apple's published value in both appearances")
    func tokens_matchApplesPublishedValues() throws {
        for token in ColorTokenTable.appexNative {
            for (appearance, isDark) in [(NSAppearance.Name.aqua, false), (.darkAqua, true)] {
                let expected = try #require(
                    AppleColorTokenOracle.expected(for: token.name, dark: isDark),
                    "\(token.name) is appex-native but absent from the \(AppleColorTokenOracle.osVersion) oracle"
                )
                let actual = inAppearance(appearance) { srgbBytes(token.color) }
                #expect(
                    actual == expected,
                    """
                    \(token.name) in \(appearance.rawValue) resolved to \
                    \(actual.r),\(actual.g),\(actual.b) but \(AppleColorTokenOracle.osVersion) \
                    says \(expected.r),\(expected.g),\(expected.b). If the OS moved a token, \
                    record it — do not loosen this test.
                    """
                )
            }
        }
    }

    @Test("the oracle covers exactly the appex-native tokens")
    func oracle_coversTheSubset() {
        #expect(Set(AppleColorTokenOracle.standard.keys) == Set(ColorTokenTable.appexNative.map(\.name)))
    }

    @Test("the recorded deviations are still deviations")
    func oracle_deviationsAreStillReal() {
        // If Apple's table and AppKit ever agree again, the deviation entry has
        // become a lie that would mask a real move. Fail rather than pass quietly.
        for (name, pair) in AppleColorTokenOracle.deviations {
            for (published, isDark) in [(pair.light, false), (pair.dark, true)] {
                guard let deviation = published else { continue }
                let table = AppleColorTokenOracle.standard[name]
                let applesValue = isDark ? table?.dark : table?.light
                #expect(
                    applesValue != deviation,
                    "\(name) (\(isDark ? "dark" : "light")) no longer deviates — delete the entry"
                )
            }
        }
    }

    // MARK: - The vocabulary is SwiftUI's, and the AppKit spellings are gone

    @Test("the retired AppKit spellings are not tokens", arguments: retiredAppKitNames)
    func retiredNames_areNotTokens(_ name: String) {
        #expect(ColorTokenTable.token(named: name) == nil, "\(name) is still a token")
    }

    @Test("the retired AppKit spellings are not parseable either", arguments: retiredAppKitNames)
    func retiredNames_doNotParse(_ name: String) {
        // Removal, not aliasing — so this is a *contract* change and belongs in a
        // test rather than in a changelog. `ColorGrammarTests` pins the same thing
        // at the CLI's other two entry points.
        #expect(throws: (any Error).self) { try ColorParser.parse(name) }
    }

    @Test("primary and secondary are exactly what the label ladder resolved to")
    func semanticTokens_keepTheirValues() throws {
        // The rename is value-preserving: `Color.primary` and `Color.secondary`
        // measure byte-identical to `labelColor`/`secondaryLabelColor` in both
        // appearances, which is what lets `primary:0.5` still render at ~42% and
        // keeps `ColorProvenanceTests`' opacity case meaning what it did.
        let pairs: [(String, NSColor)] = [
            ("primary", .labelColor),
            ("secondary", .secondaryLabelColor),
        ]
        for (name, appKit) in pairs {
            let token = try #require(ColorTokenTable.token(named: name))
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                // All four components: both of these are black or white, so an
                // RGB-only comparison would pass while the *alpha* — the whole
                // point of a semantic colour, and what `:opacity` multiplies —
                // moved underneath it.
                //
                // At `MicaColorValue.precision`, because the two bridges carry
                // that alpha at different float widths: 0.84705883 through
                // SwiftUI against 0.8470588235 through AppKit, a difference three
                // decimal places past anything a written configuration keeps.
                func components(_ color: Color) -> ColorParser.ExtendedComponents {
                    inAppearance(appearance) {
                        ColorParser.ExtendedComponents.resolving(color)
                            .rounded(to: MicaColorValue.precision)
                    }
                }
                let a = components(token.color)
                let b = components(Color(appKit))
                #expect(a == b, "\(name) diverged from its AppKit original in \(appearance.rawValue)")
            }
        }
    }

    @Test("no token resolves through AppKit's palette")
    func noToken_duplicatesAnAppKitSystemColour() {
        // The `system.*` group was thirteen byte-identical duplicates of the plain
        // palette, so a colour had two names and the JSON writer had to prefer
        // one. Adding another AppKit spelling back would restore that ambiguity.
        for token in ColorTokenTable.all {
            #expect(!token.name.hasPrefix("system."), "\(token.name) is an AppKit spelling")
        }
    }
}
