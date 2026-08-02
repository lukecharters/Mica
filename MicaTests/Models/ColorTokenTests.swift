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
    /// 2026-08-02 (§1.1 of `docs/plans/colour-resolution.md`). This is a *closed*
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

    @Test("OptionsCatalog is the presentable subset, and nothing else")
    func optionsCatalog_derivesFromTheTable() {
        let presentable = ColorTokenTable.presentable
        #expect(OptionsCatalog.colorOptions.count == presentable.count)
        for (option, token) in zip(OptionsCatalog.colorOptions, presentable) {
            #expect(option.name == token.displayName)
            #expect(option.color == token.color)
        }
    }

    @Test("every GUI preset is a name the parser accepts")
    func optionsCatalog_namesParse() throws {
        for option in OptionsCatalog.colorOptions {
            let parsed = try ColorParser.parse(option.name)
            #expect(parsed == option.color, "the preset '\(option.name)' parses to a different colour")
        }
    }

    @Test("every GUI preset has a pre-rendered background asset")
    func optionsCatalog_hasPreRenderedAssets() {
        // `BackgroundSpec.preRenderedAssetName` is "background-<lowercased>-solid",
        // so adding a presentable token without the artwork would silently offer a
        // background that draws nothing.
        for option in OptionsCatalog.colorOptions {
            for variant in ["solid", "gradient"] {
                let asset = "background-\(option.name.lowercased())-\(variant)"
                #expect(NSImage(named: asset) != nil, "missing asset \(asset)")
            }
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
        #expect(ColorTokenTable.token(named: "system.blue")?.displayName == "System Blue")
        #expect(ColorTokenTable.token(named: "quaternary.label")?.displayName == "Quaternary Label")
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

    @Test("SwiftUI's palette and AppKit's system palette agree on macOS 26")
    func plainAndSystemTokens_resolveIdentically() {
        // Not a requirement, but the reason `MicaColor` prefers the short name: if
        // these ever diverge, `blue` and `system.blue` stop being interchangeable
        // and the writer's ordering starts changing which colour gets recorded.
        for plain in ColorTokenTable.appexNative {
            guard let system = ColorTokenTable.token(named: "system.\(plain.name)") else { continue }
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                let a = inAppearance(appearance) { srgbBytes(plain.color) }
                let b = inAppearance(appearance) { srgbBytes(system.color) }
                #expect(a == b, "\(plain.name) and system.\(plain.name) differ in \(appearance.rawValue)")
            }
        }
    }
}
