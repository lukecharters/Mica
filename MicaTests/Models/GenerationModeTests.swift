// GenerationModeTests.swift
// The two modes gate which render pipeline runs (SwiftUI ImageRenderer vs
// AppexReferenceService). Raw values are persisted in settings, so they
// must round-trip.

import Testing
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct GenerationModeTests {

    @Test("Exactly two cases exist")
    func allCases_countIsTwo() {
        #expect(GenerationMode.allCases.count == 2)
        #expect(GenerationMode.allCases.contains(.swiftUI))
        #expect(GenerationMode.allCases.contains(.appleReference))
    }

    @Test("Raw values match user-facing labels")
    func rawValues() {
        #expect(GenerationMode.swiftUI.rawValue == "Custom")
        #expect(GenerationMode.appleReference.rawValue == "Apple")
    }

    @Test("Cases are not equal to each other")
    func cases_distinct() {
        #expect(GenerationMode.swiftUI != GenerationMode.appleReference)
    }

    @Test("rawValue round-trips", arguments: GenerationMode.allCases)
    func roundTrip(_ mode: GenerationMode) throws {
        let rt = try #require(GenerationMode(rawValue: mode.rawValue))
        #expect(rt == mode)
        #expect(rt.id == mode.rawValue)
    }

    @Test("init?(rawValue:) returns nil for unknown strings")
    func initRawValue_nilForUnknown() {
        #expect(GenerationMode(rawValue: "custom") == nil) // case-sensitive
        #expect(GenerationMode(rawValue: "") == nil)
    }
}
