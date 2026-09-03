// MicaTests/Models/PresetSearchTests.swift
// The Presets window shows one scope at a time, narrowed by its search field. The
// filter is pure so the rule can be pinned here without a window: scope first, then a
// case-insensitive match on the name, and an empty query is everything.

import Foundation
import Testing
@testable import Mica

@Suite("Preset search", .tags(.unit))
struct PresetSearchTests {

    private func preset(_ name: String, scope: PresetScope = .icon) -> MicaPreset {
        MicaPreset(name: name, scope: scope, keys: ["\(scope.rawValue)-bg-color": .string("red")])
    }

    private var rows: [ResolvedPreset] {
        ResolvedPreset.resolve([
            preset("Sunrise"),
            preset("Deep Ocean"),
            preset("Ocean Badge", scope: .badge),
        ])
    }

    @Test("An empty query matches everything in the scope")
    func emptyQueryMatchesAll() {
        let matched = PresetSearch.filter(rows, scope: .icon, query: "")
        #expect(matched.map(\.displayName) == ["Sunrise", "Deep Ocean"])
    }

    @Test("Whitespace alone is an empty query")
    func whitespaceQueryMatchesAll() {
        let matched = PresetSearch.filter(rows, scope: .icon, query: "   ")
        #expect(matched.count == 2)
    }

    @Test("The other scope is never in the result, even when its name matches")
    func otherScopeExcluded() {
        let matched = PresetSearch.filter(rows, scope: .icon, query: "ocean")
        #expect(matched.map(\.displayName) == ["Deep Ocean"])
    }

    @Test("Matching is case-insensitive and on any part of the name")
    func caseInsensitiveSubstring() {
        #expect(PresetSearch.matches("Deep Ocean", query: "OCEAN"))
        #expect(PresetSearch.matches("Deep Ocean", query: "ep oc"))
        #expect(!PresetSearch.matches("Deep Ocean", query: "lake"))
    }

    @Test("Surrounding whitespace in the query is ignored")
    func queryIsTrimmed() {
        #expect(PresetSearch.matches("Sunrise", query: "  sun "))
    }

    @Test("Order is preserved")
    func orderPreserved() {
        let matched = PresetSearch.filter(rows, scope: .icon, query: "e")
        #expect(matched.map(\.displayName) == ["Sunrise", "Deep Ocean"])
    }
}
