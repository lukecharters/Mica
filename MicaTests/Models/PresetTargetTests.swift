// MicaTests/Models/PresetTargetTests.swift
// `PresetTargetRule` decides which icon window the Presets window applies to. It is
// a pure value because the failure it guards against — a click in the Presets
// window landing nowhere, or on the wrong icon — is not something a view test can
// read back, and because the obvious implementation (a focused value) is nil at
// exactly the moment it is needed.

import Foundation
import Testing
@testable import Mica

@Suite("Preset target", .tags(.unit))
struct PresetTargetTests {

    private struct Window: Identifiable, Equatable {
        let id: Int
    }

    @Test("There is no target until an icon window has been key")
    func startsEmpty() {
        let rule = PresetTargetRule<Window>()
        #expect(rule.target == nil)
    }

    @Test("Becoming key makes a window the target")
    func becomingKeyTargets() {
        var rule = PresetTargetRule<Window>()
        rule.windowBecameKey(Window(id: 1))
        #expect(rule.target == Window(id: 1))
    }

    /// The Presets window taking key is exactly when the target is needed, so the
    /// rule has no "lost key" event at all — there is nothing for it to do.
    @Test("A second window becoming key replaces the first")
    func laterKeyReplaces() {
        var rule = PresetTargetRule<Window>()
        rule.windowBecameKey(Window(id: 1))
        rule.windowBecameKey(Window(id: 2))
        #expect(rule.target == Window(id: 2))
    }

    @Test("Closing the target withdraws it, and nothing guesses a replacement")
    func closingTargetWithdraws() {
        var rule = PresetTargetRule<Window>()
        rule.windowBecameKey(Window(id: 1))
        rule.windowBecameKey(Window(id: 2))
        rule.windowClosed(2)
        #expect(rule.target == nil)
    }

    @Test("Closing a window that is not the target changes nothing")
    func closingOtherWindowIsIgnored() {
        var rule = PresetTargetRule<Window>()
        rule.windowBecameKey(Window(id: 1))
        rule.windowBecameKey(Window(id: 2))
        rule.windowClosed(1)
        #expect(rule.target == Window(id: 2))
    }

    @Test("Closing with no target is harmless")
    func closingWithNoTarget() {
        var rule = PresetTargetRule<Window>()
        rule.windowClosed(7)
        #expect(rule.target == nil)
    }
}
