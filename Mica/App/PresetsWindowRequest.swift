// App/PresetsWindowRequest.swift
//
// Which scope the Presets window should show when something opens it.
//
// `openWindow(id:)` carries no value to a `Window` scene, and a
// `WindowGroup(for: PresetScope.self)` would allow two Presets windows, which is
// wrong. So a popover's footer writes the scope here before it opens the window, and
// the window reads it on appear and whenever a new request lands. ⌃⌘P writes nothing,
// so the window keeps whatever scope it last showed.

import Foundation

@MainActor
@Observable
final class PresetsWindowRequest {
    static let shared = PresetsWindowRequest()

    /// The scope most recently asked for; nil until a popover has asked.
    private(set) var scope: PresetScope?

    /// Counts requests, so that asking for the scope the window already shows is
    /// still an event it can observe — a bare `scope` would not change.
    private(set) var generation = 0

    func open(_ scope: PresetScope) {
        self.scope = scope
        generation += 1
    }
}
