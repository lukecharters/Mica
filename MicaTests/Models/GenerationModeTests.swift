// GenerationModeTests.swift
// The two modes gate which render pipeline runs (SwiftUI ImageRenderer vs
// AppexReferenceService). Raw values are the canonical mica/system vocabulary
// shared with the CLI's --icon/--badge-generation-mode tokens, so they must
// round-trip and stay lowercase.

import Testing
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct GenerationModeTests {

    @Test("Exactly two cases exist")
    func allCases_countIsTwo() {
        #expect(GenerationMode.allCases.count == 2)
        #expect(GenerationMode.allCases.contains(.mica))
        #expect(GenerationMode.allCases.contains(.system))
    }

    @Test("Raw values are the canonical CLI tokens")
    func rawValues() {
        #expect(GenerationMode.mica.rawValue == "mica")
        #expect(GenerationMode.system.rawValue == "system")
    }

    @Test("Cases are not equal to each other")
    func cases_distinct() {
        #expect(GenerationMode.mica != GenerationMode.system)
    }

    @Test("rawValue round-trips", arguments: GenerationMode.allCases)
    func roundTrip(_ mode: GenerationMode) throws {
        let rt = try #require(GenerationMode(rawValue: mode.rawValue))
        #expect(rt == mode)
        #expect(rt.id == mode.rawValue)
    }

    @Test("init?(rawValue:) returns nil for unknown strings")
    func initRawValue_nilForUnknown() {
        #expect(GenerationMode(rawValue: "Mica") == nil) // case-sensitive
        #expect(GenerationMode(rawValue: "custom") == nil) // pre-rename vocabulary
        #expect(GenerationMode(rawValue: "") == nil)
    }
}
