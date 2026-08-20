// MicaTests/Models/EnglishVariantLocalizationTests.swift
//
// `Localizable.xcstrings` carries `en` plus seven English variants, and the only
// three words that differ across them are *color/colour*, *gray/grey* and
// *recenter/recentre*.
//
// **The failure this suite exists for is a silently missing resource.** Every
// lookup falls back to its own key, and every key *is* the US spelling — so a
// catalog dropped from the target, a locale missing from `knownRegions`, or a
// `.lproj` that never got copied all present as an app that simply says "Color"
// everywhere. Nothing throws, nothing logs, and no assertion on a rendered icon
// can see it. The same shape as the CLI's missing `Assets.car`.
//
// Note on failure messages: Swift Testing's `Comment` is `ExpressibleByStringLiteral`
// but **not** by string interpolation, so a message naming the variant has to be
// built with `Comment(rawValue:)` rather than written as an interpolated literal.

import Testing
import Foundation
@testable import Mica

@Suite("English variant localisation")
struct EnglishVariantLocalizationTests {

    /// The variants shipped beside the `en` source, matching `knownRegions` in
    /// `project.pbxproj`. All seven take identical values: no word in Mica's UI
    /// splits Canadian from British English (the `-ize`/`-ise` divide would, but
    /// no UI string contains such a word).
    static let variants = ["en-AU", "en-CA", "en-GB", "en-IE", "en-IN", "en-NZ", "en-ZA"]

    /// A value that cannot be a translation, so a missing key is distinguishable
    /// from a key that translates to itself.
    private static let missing = "\u{0}<missing>"

    private static func bundle(for localization: String) throws -> Bundle {
        let path = try #require(
            Bundle.main.path(forResource: localization, ofType: "lproj"),
            Comment(rawValue: "\(localization).lproj is not in Mica.app — the catalog was "
                    + "dropped from the target, or \(localization) is missing from knownRegions")
        )
        let loaded = Bundle(path: path)
        return try #require(loaded, "the .lproj is not a loadable bundle")
    }

    private static func lookup(_ key: String, in localization: String) throws -> String {
        try bundle(for: localization).localizedString(forKey: key, value: missing, table: nil)
    }

    // MARK: - The resource is there at all

    @Test("Every declared variant ships a compiled catalog", arguments: variants)
    func everyVariantShipsACatalog(_ variant: String) throws {
        let value = try Self.lookup("Color", in: variant)
        #expect(value != Self.missing,
                Comment(rawValue: "\(variant) has no entry for \"Color\""))
    }

    @Test("Bundle.main offers every variant as a localization")
    func bundleAdvertisesEveryVariant() {
        let advertised = Set(Bundle.main.localizations)
        for variant in Self.variants {
            #expect(advertised.contains(variant),
                    Comment(rawValue: "Bundle.main does not list \(variant)"))
        }
        #expect(advertised.contains("en"), "the source localization is missing")
    }

    // MARK: - The three words that actually differ

    @Test("color becomes colour in every variant", arguments: variants)
    func colorIsBritishInEveryVariant(_ variant: String) throws {
        #expect(try Self.lookup("Color", in: variant) == "Colour")
        #expect(try Self.lookup("Symbol Color", in: variant) == "Symbol Colour")
        #expect(try Self.lookup("Multicolor", in: variant) == "Multicolour")
        // Interpolated at run time from SettingsChange's Icon/Badge subject.
        #expect(try Self.lookup("Change Icon Symbol Color", in: variant)
                == "Change Icon Symbol Colour")
        // Lowercase, mid-sentence, from IconAccessibilityDescription.
        #expect(try Self.lookup("a custom color", in: variant) == "a custom colour")
    }

    @Test("gray becomes grey in every variant", arguments: variants)
    func grayIsBritishInEveryVariant(_ variant: String) throws {
        // Keyed on `ColorToken.displayName`, which is derived from the token name
        // rather than written down — so this is the derived string, not the `gray`
        // token, which is a CLI contract and never moves. "System Gray" was a key
        // here too until the `system.*` spellings went on 2026-08-17; a catalog
        // entry for a display name no token produces is a string that can never be
        // looked up, which is why it went with them.
        #expect(try Self.lookup("Gray", in: variant) == "Grey")
    }

    @Test("recenter becomes recentre in every variant", arguments: variants)
    func centerIsBritishInEveryVariant(_ variant: String) throws {
        // The `-re` ending, which Canadian English takes with the British group —
        // unlike `-ize`/`-ise`, the one axis that would split it. So all seven
        // variants stay identical, and the note on `variants` still holds.
        #expect(try Self.lookup("Recenter", in: variant) == "Recentre")
    }

    @Test("The source localization keeps the American spelling")
    func sourceIsAmerican() throws {
        #expect(try Self.lookup("Color", in: "en") == "Color")
        #expect(try Self.lookup("Gray", in: "en") == "Gray")
        #expect(try Self.lookup("Recenter", in: "en") == "Recenter")
    }

    // MARK: - Nothing in the catalog is dead weight

    /// Only strings that genuinely differ belong in the catalog. An entry equal to
    /// its own key is a string somebody added that needed no translation — it
    /// costs a lookup and, more to the point, suggests the catalog is meant to
    /// hold every string in the app, which it deliberately is not.
    @Test("Every variant entry differs from its key", arguments: variants)
    func noEntryIsANoOp(_ variant: String) throws {
        let url = try #require(
            Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                            subdirectory: nil, localization: variant)
        )
        let entries = try #require(NSDictionary(contentsOf: url) as? [String: String])
        #expect(!entries.isEmpty)
        for (key, value) in entries where value == key {
            Issue.record(Comment(rawValue: "\(variant) translates \"\(key)\" to itself"))
        }
    }

    // MARK: - The fallback the whole design rests on

    /// `localizedFromCatalog` is called on strings that mostly have no entry —
    /// 66 undo action names, of which 19 say "Color", and every colour token's
    /// display name. Falling back to the key is what makes that safe.
    @Test("An absent key falls back to itself")
    func absentKeyFallsBackToItself() {
        let key = "Change Icon Corner Style"
        #expect(key.localizedFromCatalog == key)
    }
}
