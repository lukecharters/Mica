// PresetApplicationTests.swift
// Tests for the scoped apply: scope-completeness, the untouched other half, badge
// activation, and mode switching in both directions.
//
// **Scope-completeness is the load-bearing one.** Without it, clicking preset A then
// B gives a different icon than clicking B alone, and the residue accumulates
// invisibly — nothing errors, nothing looks wrong, and the icon is simply not what
// the thumbnail showed. The two tests that pin it apply a preset over deliberately
// dirty settings and check that keys the preset never mentions came back to their
// *defaults* rather than keeping what was there.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct PresetApplicationTests {

    // MARK: - Helpers

    /// Settings with something non-default in every corner, so residue is visible.
    private func dirtySettings() -> IconSettings {
        var settings = IconSettings()
        settings.export.size = 1024
        settings.export.isRetina = true
        settings.export.colorSpace = .displayP3

        settings.icon.foreground.symbolName = "trash.fill"
        settings.icon.foreground.symbolScale = 1.7
        settings.icon.foreground.symbolWeight = .black
        settings.icon.foreground.renderingStyle = .palette
        settings.icon.foreground.offsetX = 0.3
        settings.icon.background.color = .red
        settings.icon.background.cornerRadiusStyle = .macOS15
        settings.icon.background.shadowStyle = .off

        settings.badge.foreground.symbolName = "bell.fill"
        settings.badge.foreground.isHidden = false
        settings.badge.background.isHidden = false
        settings.badge.position = .topLeft
        settings.badge.scale = 1.4
        settings.badge.offsetX = 0.2
        return settings
    }

    private func apply(_ preset: MicaPreset, to settings: IconSettings) throws -> IconSettings {
        var applied = settings
        var colors = MicaAppexColors()
        try PresetApplication.apply(preset, to: &applied, appexColors: &colors)
        return applied
    }

    // MARK: - Scope-completeness

    @Test("An icon preset resets icon keys it does not mention to their defaults")
    func iconPresetIsScopeComplete() throws {
        // The preset names a background colour and a symbol and nothing else, so
        // everything else about the icon must come back to `IconSpec()` — not stay at
        // whatever the user had.
        let preset = MicaPreset(
            name: "Minimal",
            scope: .icon,
            keys: ["icon-bg-color": .string("green"), "icon-fg": .string("symbol:star.fill")]
        )
        let applied = try apply(preset, to: dirtySettings())
        let defaults = IconSpec()

        #expect(applied.icon.foreground.symbolName == "star.fill")
        #expect(applied.icon.foreground.symbolScale == defaults.foreground.symbolScale)
        #expect(applied.icon.foreground.symbolWeight == defaults.foreground.symbolWeight)
        #expect(applied.icon.foreground.renderingStyle == defaults.foreground.renderingStyle)
        #expect(applied.icon.foreground.offsetX == defaults.foreground.offsetX)
        #expect(applied.icon.background.cornerRadiusStyle == defaults.background.cornerRadiusStyle)
        #expect(applied.icon.background.shadowStyle == defaults.background.shadowStyle)
    }

    @Test("A badge preset resets badge layout it does not mention to its defaults")
    func badgePresetIsScopeComplete() throws {
        // Layout is the sharpest case: `badge-position`, `badge-scale` and the two
        // offsets are in scope precisely so the thumbnail's corner arrow is truthful,
        // and the accepted cost is that a badge preset overwrites an arrow-key nudge.
        // That cost is this test.
        let preset = MicaPreset(
            name: "Plain",
            scope: .badge,
            keys: ["badge-fg": .string("symbol:plus"), "badge-bg-color": .string("blue")]
        )
        let applied = try apply(preset, to: dirtySettings())
        let defaults = BadgeSpec()

        #expect(applied.badge.position == defaults.position)
        #expect(applied.badge.scale == defaults.scale)
        #expect(applied.badge.offsetX == defaults.offsetX)
        #expect(applied.badge.offsetY == defaults.offsetY)
    }

    @Test("Applying A then B equals applying B alone")
    func applyingTwoPresetsLeavesNoResidue() throws {
        // The property scope-completeness exists for, stated directly. If this fails,
        // presets accumulate — and the symptom is an icon that is subtly not what its
        // thumbnail showed, with nothing to say so.
        for scope in PresetScope.allCases {
            let presets = PresetCatalog.builtIn(scope)
            let first = presets[0]
            let second = presets[1]

            let sequential = try apply(second, to: apply(first, to: dirtySettings()))
            let direct = try apply(second, to: dirtySettings())

            switch scope {
            case .icon:  #expect(sequential.icon == direct.icon, "icon residue after \(first.name) → \(second.name)")
            case .badge: #expect(sequential.badge == direct.badge, "badge residue after \(first.name) → \(second.name)")
            }
        }
    }

    // MARK: - The other half, untouched

    @Test("An icon preset leaves the badge and the export settings alone")
    func iconPresetTouchesNothingElse() throws {
        let before = dirtySettings()
        let applied = try apply(PresetCatalog.builtInIcon[0], to: before)

        #expect(applied.badge == before.badge)
        #expect(applied.export == before.export)
    }

    @Test("A badge preset leaves the icon and the export settings alone")
    func badgePresetTouchesNothingElse() throws {
        let before = dirtySettings()
        let applied = try apply(PresetCatalog.builtInBadge[0], to: before)

        #expect(applied.icon == before.icon)
        #expect(applied.export == before.export)
    }

    @Test("No preset changes the export size, scale or colour space")
    func noPresetTouchesExport() throws {
        // A consequence of the key namespace rather than a rule anyone enforces —
        // which is why it is worth a test: nothing in the apply path would stop an
        // `icon-*` key from being added that wrote to `export`.
        let before = dirtySettings()
        for preset in PresetCatalog.builtIn {
            let applied = try apply(preset, to: before)
            #expect(applied.export == before.export, "\(preset.name) changed the export settings")
        }
    }

    // MARK: - Badge activation

    @Test("Every badge preset turns the badge on")
    func badgePresetsActivateTheBadge() throws {
        // The codec's existing rule working, not a new one: a badge is switched on by
        // the *presence* of `badge-fg`, and every badge preset carries its symbol. It
        // is also the reason style-only presets were declined — an omitted `badge-fg`
        // could not mean both "reset to the default" and "keep mine", and for the
        // badge it would mean "do not turn the badge on at all".
        var off = IconSettings()
        off.badge.isHidden = true
        #expect(!off.badge.isVisible)

        for preset in PresetCatalog.builtInBadge {
            let applied = try apply(preset, to: off)
            #expect(applied.badge.isVisible, "\(preset.name) did not turn the badge on")
        }
    }

    @Test("Every badge preset carries a symbol")
    func badgePresetsCarryTheirSymbol() {
        for preset in PresetCatalog.builtInBadge {
            #expect(preset.keys[MicaConfigKey.badgeFG.rawValue] != nil,
                    "\(preset.name) has no badge-fg, so applying it would activate nothing")
        }
    }

    @Test("Every icon preset carries a symbol")
    func iconPresetsCarryTheirSymbol() {
        for preset in PresetCatalog.builtInIcon {
            #expect(preset.keys[MicaConfigKey.iconFG.rawValue] != nil,
                    "\(preset.name) has no icon-fg, so its thumbnail would draw the default glyph")
        }
    }

    // MARK: - Generation mode

    @Test("A Mica preset switches a System-mode group back to Mica")
    func presetSwitchesSystemToMica() throws {
        // `icon-generation-mode` and `badge-generation-mode` are in scope, so the mode
        // is *carried* rather than special-cased. Exercised by every preset in the set.
        var system = IconSettings()
        system.icon.mode = .system
        system.badge.foreground.isHidden = false
        system.badge.background.isHidden = false
        system.badge.mode = .system

        let iconApplied = try apply(PresetCatalog.builtInIcon[0], to: system)
        #expect(iconApplied.icon.mode == .mica)

        let badgeApplied = try apply(PresetCatalog.builtInBadge[0], to: system)
        #expect(badgeApplied.badge.mode == .mica)
    }

    @Test("A System-mode preset switches a Mica group into System mode")
    func presetSwitchesMicaToSystem() throws {
        // **The one direction the built-in set does not cover.** A Security (icon) and
        // a System Badge preset were drafted and cut, because their thumbnails could
        // not use the cheap synchronous `IconContentView` path. The behaviour lives in
        // the keys rather than in the catalogue, so it is tested here rather than by
        // reinstating a preset — which is what keeps the pane free of a loading state
        // and a thumbnail cache.
        let iconPreset = MicaPreset(
            name: "System Icon",
            scope: .icon,
            keys: [
                "icon-generation-mode": .string("system"),
                "icon-fg": .string("symbol:lock.fill"),
                "icon-bg-color": .string("blue"),
            ]
        )
        let applied = try apply(iconPreset, to: IconSettings())
        #expect(applied.icon.mode == .system)

        let badgePreset = MicaPreset(
            name: "System Badge",
            scope: .badge,
            keys: [
                "badge-generation-mode": .string("system"),
                "badge-fg": .string("symbol:lock.fill"),
                "badge-bg-color": .string("blue"),
            ]
        )
        let badgeApplied = try apply(badgePreset, to: IconSettings())
        #expect(badgeApplied.badge.mode == .system)
        #expect(badgeApplied.badge.isVisible)
    }

    // MARK: - Decoding over defaults

    @Test("Decoding never reads the current settings")
    func decodeIsOverDefaults() throws {
        // The step that turns "this key is absent" into "this key is at its default"
        // rather than "leave whatever is there". Decoding over the current settings
        // instead is the single change that would break scope-completeness, and it
        // would look like nothing until two presets were clicked in a row.
        let preset = MicaPreset(name: "Bare", scope: .icon, keys: ["icon-bg-color": .string("green")])
        let decoded = try PresetApplication.decode(preset)
        #expect(decoded.settings.icon.foreground.symbolName == IconSettings().icon.foreground.symbolName)
        #expect(decoded.settings.badge == IconSettings().badge)
    }

    @Test("previewSettings draws the preset over defaults and nothing else")
    func previewSettingsIsIsolated() {
        // What a thumbnail draws: a catalogue entry, not a preview of the current
        // document. This is what keeps the pane stable while the icon is edited.
        let preset = PresetCatalog.builtInIcon[0]
        let first = PresetApplication.previewSettings(for: preset)
        let second = PresetApplication.previewSettings(for: preset)
        #expect(first == second)
        #expect(first.badge == IconSettings().badge)
    }

    @Test("A badge preview leaves the icon at its defaults for the staging to hide")
    func previewSettingsForBadgeLeavesIconDefault() {
        let preview = PresetApplication.previewSettings(for: PresetCatalog.builtInBadge[0])
        #expect(preview.icon == IconSettings().icon)
    }

    // MARK: - Warnings

    @Test("A value the codec cannot read warns rather than failing the apply")
    func unreadableValueWarns() throws {
        // A hand-edited user preset is the realistic source. The apply still happens
        // and the bad key falls back to its default; the warning is what stops that
        // being silent.
        let preset = MicaPreset(
            name: "Broken",
            scope: .icon,
            keys: ["icon-fg": .string("symbol:star"), "icon-bg-color": .string("not-a-colour")]
        )
        var settings = IconSettings()
        var colors = MicaAppexColors()
        let warnings = try PresetApplication.apply(preset, to: &settings, appexColors: &colors)

        #expect(warnings.contains { $0.key == "icon-bg-color" })
        #expect(settings.icon.foreground.symbolName == "star")
    }
}
