// AppexNamedColorTests.swift
// AppexNamedColor raw values are the exact strings Apple's
// IconServices pipeline expects for ISEnclosureColor, so round-tripping
// the rawValue is a real contract — not ceremony.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct AppexNamedColorTests {

    /// Fifteen, not fourteen: `mint` was measured as accepted by the pipeline on
    /// 2026-08-02 and the hand-written enum had no case for it. The cases are now
    /// derived from `ColorTokenTable`'s `.appexNative` flag, so this count moves
    /// only when that flag does — see `ColorTokenTests` for the set itself.
    @Test("All 15 Apple-named enclosure colors are present")
    func allCases_countIsFifteen() {
        #expect(AppexNamedColor.allCases.count == 15)
    }

    @Test("every static constant names a real token")
    func staticConstants_areRealTokens() {
        let constants: [AppexNamedColor] = [
            .black, .blue, .brown, .cyan, .gray, .green, .indigo, .mint,
            .orange, .pink, .purple, .red, .teal, .white, .yellow,
        ]
        // The constants use an unchecked initialiser, so a typo would otherwise
        // become a token that resolves to nothing.
        for constant in constants {
            #expect(AppexNamedColor.allCases.contains(constant), "\(constant.rawValue) is not a real token")
        }
        #expect(Set(constants) == Set(AppexNamedColor.allCases))
    }

    @Test("Raw values are the lowercase color names Apple accepts")
    func rawValues_areLowercase() {
        for c in AppexNamedColor.allCases {
            #expect(c.rawValue == c.rawValue.lowercased(), "\(c) rawValue should be lowercase")
        }
    }

    @Test("rawValue round-trips through init", arguments: AppexNamedColor.allCases)
    func rawValue_roundTrips(_ color: AppexNamedColor) throws {
        let rt = try #require(AppexNamedColor(rawValue: color.rawValue))
        #expect(rt == color)
        #expect(rt.id == color.rawValue)
    }

    @Test("displayName is the capitalized rawValue", arguments: AppexNamedColor.allCases)
    func displayName_isCapitalized(_ color: AppexNamedColor) {
        #expect(color.displayName == color.rawValue.capitalized)
    }

    @Test("Specific raw-value strings match Apple's spec")
    func specificRawValues() {
        #expect(AppexNamedColor.blue.rawValue == "blue")
        #expect(AppexNamedColor.gray.rawValue == "gray")
        #expect(AppexNamedColor.indigo.rawValue == "indigo")
        #expect(AppexNamedColor.yellow.rawValue == "yellow")
    }

    @Test("init?(rawValue:) returns nil for unknown strings")
    func initRawValue_nilForUnknown() {
        #expect(AppexNamedColor(rawValue: "Black") == nil) // case-sensitive
        #expect(AppexNamedColor(rawValue: "") == nil)
        #expect(AppexNamedColor(rawValue: "not-a-color") == nil)
    }
}
