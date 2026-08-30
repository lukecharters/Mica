// MicaPresetTests.swift
// Tests for the preset envelope: which keys each scope owns, the scope-hygiene
// check that catches a hand-edited file, and the JSON value round trip.
//
// The value round trip is the one that would otherwise fail silently.
// `JSONSerialization` surfaces booleans and numbers alike as `NSNumber`, so a `true`
// read back as `1` still *decodes* — the codec's `toggle()` reader then rejects it,
// warns, and the key falls back to its default. A preset that quietly loses its
// `icon-bg-gradient: false` renders with a gradient and looks like a taste
// disagreement rather than a bug.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
struct MicaPresetTests {

    // MARK: - Scope ownership

    @Test("The two scopes partition the key vocabulary, leaving only the export keys")
    func scopesPartitionTheKeys() {
        // The property that makes the whole design cheap: `icon-*` and `badge-*` are
        // disjoint, cover everything but the three export keys, and map onto the two
        // branches of `IconSettings` the scoped copy writes. "Presets never touch
        // export settings" falls out of this rather than being a rule anyone applies.
        var unowned: [String] = []
        for key in MicaConfigKey.allCases {
            let owners = PresetScope.allCases.filter { $0.owns(key) }
            #expect(owners.count <= 1, "'\(key.rawValue)' is owned by two scopes")
            if owners.isEmpty { unowned.append(key.rawValue) }
        }
        #expect(unowned.sorted() == ["color-space", "scale", "size"])
    }

    @Test("Each generation mode belongs to its own scope")
    func generationModesAreScoped() {
        // Not incidental: it is what makes a Mica preset applied to a System-mode
        // group switch that group back to Mica, without a rule anywhere saying so.
        #expect(PresetScope.icon.owns(.iconGenerationMode))
        #expect(PresetScope.badge.owns(.badgeGenerationMode))
        #expect(!PresetScope.icon.owns(.badgeGenerationMode))
    }

    @Test("The badge layout keys are the badge scope's")
    func badgeLayoutIsScoped() {
        // The ghost-corner thumbnail is only truthful if the preset sets the corner.
        for key in [MicaConfigKey.badgePosition, .badgeScale, .badgeOffsetX, .badgeOffsetY] {
            #expect(PresetScope.badge.owns(key), "'\(key.rawValue)' left the badge scope")
        }
    }

    @Test("The two scopes name different undo actions")
    func undoActionNamesDiffer() {
        #expect(PresetScope.icon.undoActionName != PresetScope.badge.undoActionName)
    }

    // MARK: - Scope hygiene

    @Test("A well-formed preset carries no key outside its scope")
    func unscopedKeys_wellFormed() {
        let preset = MicaPreset(
            name: "Test",
            scope: .icon,
            keys: ["icon-bg-color": .string("blue"), "icon-fg": .string("symbol:star")]
        )
        #expect(preset.unscopedKeys.isEmpty)
    }

    @Test("A cross-scope key is reported, not applied")
    func unscopedKeys_crossScope() {
        // The scoped copy would drop this silently. Reporting it is the difference
        // between a hand-edited file that half-works and one that explains itself.
        let preset = MicaPreset(
            name: "Test",
            scope: .badge,
            keys: ["badge-fg": .string("symbol:plus"), "icon-bg-color": .string("blue")]
        )
        #expect(preset.unscopedKeys == ["icon-bg-color"])
    }

    @Test("An export key is unscoped in both scopes")
    func unscopedKeys_exportKey() {
        for scope in PresetScope.allCases {
            let preset = MicaPreset(name: "Test", scope: scope, keys: ["size": .number(1024)])
            #expect(preset.unscopedKeys == ["size"], "\(scope) accepted an export key")
        }
    }

    @Test("A key that is not a configuration key at all is unscoped")
    func unscopedKeys_unknownKey() {
        let preset = MicaPreset(name: "Test", scope: .icon, keys: ["icon-sparkle": .bool(true)])
        #expect(preset.unscopedKeys == ["icon-sparkle"])
    }

    // MARK: - Values

    @Test("Every value kind survives a JSON round trip as its own kind")
    func valueRoundTrip() throws {
        // A `true` that comes back as `1` still decodes — and then the codec's
        // `toggle()` reader rejects it, warns, and the key falls back to its default.
        // So the failure of this test is a preset silently losing a toggle, which
        // looks like nothing at all.
        let values: [MicaPresetValue] = [
            .string("symbol:star.fill"),
            .bool(true),
            .bool(false),
            .number(0.8),
            .number(-0.04),
            .strings(["orange", "pink"]),
        ]
        let object = Dictionary(uniqueKeysWithValues: values.enumerated().map { ("k\($0.offset)", $0.element.jsonObject) })
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        for (index, original) in values.enumerated() {
            let raw = try #require(decoded["k\(index)"])
            #expect(MicaPresetValue(json: raw) == original, "\(original) did not survive")
        }
    }

    @Test("A JSON value the codec could not read either is refused")
    func valueRefusesUnreadable() {
        #expect(MicaPresetValue(json: NSNull()) == nil)
        #expect(MicaPresetValue(json: ["nested": "object"]) == nil)
        #expect(MicaPresetValue(json: [1, "mixed"]) == nil)
    }

    // MARK: - Identity

    @Test("A built-in and a user preset of the same name and scope are distinct")
    func idDistinguishesBuiltInFromUser() {
        // They can coexist only through a bug — `UserPresetStore.uniqueName` compares
        // against built-ins — but `id` is what `ForEach` uses, and two equal ids
        // would drop a row from the pane rather than showing a duplicate.
        let builtIn = MicaPreset(name: "Installer", scope: .icon, keys: [:], isBuiltIn: true)
        let user = MicaPreset(name: "Installer", scope: .icon, keys: [:], isBuiltIn: false)
        #expect(builtIn.id != user.id)
    }

    @Test("The same name in two scopes gives two ids")
    func idDistinguishesScopes() {
        let icon = MicaPreset(name: "Update", scope: .icon, keys: [:])
        let badge = MicaPreset(name: "Update", scope: .badge, keys: [:])
        #expect(icon.id != badge.id)
    }
}
