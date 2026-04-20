// AppexEnclosureColorTests.swift
// AppexEnclosureColor raw values are the exact strings Apple's
// IconServices pipeline expects for ISEnclosureColor, so round-tripping
// the rawValue is a real contract — not ceremony.

import Testing
import SwiftUI
@testable import macOS_Icon_Generator_App

@Suite(.tags(.unit))
@MainActor
struct AppexEnclosureColorTests {

    @Test("All 14 Apple-named enclosure colors are present")
    func allCases_countIsFourteen() {
        #expect(AppexEnclosureColor.allCases.count == 14)
    }

    @Test("Raw values are the lowercase color names Apple accepts")
    func rawValues_areLowercase() {
        for c in AppexEnclosureColor.allCases {
            #expect(c.rawValue == c.rawValue.lowercased(), "\(c) rawValue should be lowercase")
        }
    }

    @Test("rawValue round-trips through init", arguments: AppexEnclosureColor.allCases)
    func rawValue_roundTrips(_ color: AppexEnclosureColor) throws {
        let rt = try #require(AppexEnclosureColor(rawValue: color.rawValue))
        #expect(rt == color)
        #expect(rt.id == color.rawValue)
    }

    @Test("displayName is the capitalized rawValue", arguments: AppexEnclosureColor.allCases)
    func displayName_isCapitalized(_ color: AppexEnclosureColor) {
        #expect(color.displayName == color.rawValue.capitalized)
    }

    @Test("Specific raw-value strings match Apple's spec")
    func specificRawValues() {
        #expect(AppexEnclosureColor.blue.rawValue == "blue")
        #expect(AppexEnclosureColor.gray.rawValue == "gray")
        #expect(AppexEnclosureColor.indigo.rawValue == "indigo")
        #expect(AppexEnclosureColor.yellow.rawValue == "yellow")
    }

    @Test("init?(rawValue:) returns nil for unknown strings")
    func initRawValue_nilForUnknown() {
        #expect(AppexEnclosureColor(rawValue: "Black") == nil) // case-sensitive
        #expect(AppexEnclosureColor(rawValue: "") == nil)
        #expect(AppexEnclosureColor(rawValue: "not-a-color") == nil)
    }
}
