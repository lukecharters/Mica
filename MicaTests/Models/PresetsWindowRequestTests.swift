// MicaTests/Models/PresetsWindowRequestTests.swift
// A popover's footer opens the Presets window on its own scope; ⌃⌘P opens it on
// whatever it last showed. The window observes `generation`, not `scope`, because
// asking for the scope already on show has to register as a request too.

import Foundation
import Testing
@testable import Mica

@Suite("Presets window request", .tags(.unit))
@MainActor
struct PresetsWindowRequestTests {

    @Test("Nothing is requested until a footer asks")
    func startsEmpty() {
        let request = PresetsWindowRequest()
        #expect(request.scope == nil)
        #expect(request.generation == 0)
    }

    @Test("A request carries its scope", arguments: PresetScope.allCases)
    func requestCarriesScope(scope: PresetScope) {
        let request = PresetsWindowRequest()
        request.open(scope)
        #expect(request.scope == scope)
    }

    @Test("A later request replaces the scope")
    func laterRequestReplaces() {
        let request = PresetsWindowRequest()
        request.open(.icon)
        request.open(.badge)
        #expect(request.scope == .badge)
    }

    @Test("Asking for the same scope twice is still two requests")
    func repeatedScopeStillCounts() {
        let request = PresetsWindowRequest()
        request.open(.icon)
        let first = request.generation
        request.open(.icon)
        #expect(request.generation > first)
    }
}
