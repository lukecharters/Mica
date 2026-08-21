// DeveloperToolsPreferenceTests.swift
//
// The switch behind the Developer menu, and behind `SymbolSizingService`'s
// Application Support override. What is worth pinning here is not the boolean —
// it is that **off is what an absent key means**, because off is what every user
// who never opts in gets, and a default of true would hand them a mutable
// calibration file they never asked for.

import Foundation
import Testing
@testable import Mica

@Suite("Developer tools preference")
struct DeveloperToolsPreferenceTests {

    /// A defaults domain of its own, so nothing here can see — or leave behind —
    /// the real preference on this machine.
    private func scratchDefaults() -> UserDefaults {
        let suite = "DeveloperToolsPreferenceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("An unset key is off")
    func absentKeyIsOff() {
        #expect(DeveloperToolsPreference.isEnabled(scratchDefaults()) == false)
    }

    @Test("Set true, and it reads true")
    func setTrue() {
        let defaults = scratchDefaults()
        defaults.set(true, forKey: DeveloperToolsPreference.enabledKey)
        #expect(DeveloperToolsPreference.isEnabled(defaults))
    }

    @Test("Set false, and it reads false")
    func setFalse() {
        let defaults = scratchDefaults()
        defaults.set(false, forKey: DeveloperToolsPreference.enabledKey)
        #expect(DeveloperToolsPreference.isEnabled(defaults) == false)
    }

    /// The key is a shipped name: renaming it silently turns the tools off for
    /// anyone who had turned them on, and — worse — leaves the calibration
    /// override reading a key nothing writes.
    @Test("The key string is the one that shipped")
    func keyIsStable() {
        #expect(DeveloperToolsPreference.enabledKey == "developer.toolsEnabled")
    }
}
