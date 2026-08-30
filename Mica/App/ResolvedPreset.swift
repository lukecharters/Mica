// App/ResolvedPreset.swift
//
// A preset with everything the pane needs to draw it, computed once.
//
// **This exists because decoding a preset is not free and `body` is not a cache.**
// `PresetApplication.previewSettings` runs `JSONSerialization` over the preset's keys
// and then the whole configuration decoder. Reading it from a computed property
// inside a view means paying for that on **every** body evaluation — and three
// properties did: the icon thumbnail's settings, the badge thumbnail's settings (twice
// over, since `cropAlignment` asked again), and the tile's advanced-controls
// indicator. Ten tiles came to roughly thirty codec round trips per repaint, and the
// pane repaints on every frame of its own slide-in animation and on every edit to the
// icon, because `PresetPane` reads `iconSettings`.
//
// Nothing about that is visible in a profile of the tests, and nothing about it fails:
// it is simply slow, in a view whose whole selling point is being cheap enough to draw
// live. Resolving once, where the list is built, removes it entirely.
//
// **App-target only.** `needsAdvancedControls` reads `resetToSimpleControls()`, which
// `mica-cli` does not compile.

import SwiftUI

/// A preset, its thumbnail's settings, and whether it needs the advanced controls.
///
/// Built by `resolve(_:)` when the preset list is loaded — on the pane appearing, and
/// after a save or a delete — and treated as a plain value from then on.
struct ResolvedPreset: Identifiable, Equatable {
    let preset: MicaPreset

    /// What the thumbnail draws: the preset over defaults, with the per-scope
    /// staging already applied. See `thumbnailSettings(for:)`.
    let thumbnailSettings: IconSettings

    /// Whether applying this preset turns on Show Advanced Controls.
    let needsAdvancedControls: Bool

    var id: String { preset.id }
    var scope: PresetScope { preset.scope }

    /// The display name, already through the string catalog for a built-in.
    ///
    /// A built-in's name is a literal in `PresetCatalog`, so it has an entry to find;
    /// a user's is whatever they typed and is shown as it was typed. Resolved here so
    /// the view has a plain `String` and the choice between the two `Text` overloads
    /// is made once, in a place where getting it wrong is visible.
    var displayName: String {
        preset.isBuiltIn ? preset.name.localizedFromCatalog : preset.name
    }

    init(_ preset: MicaPreset) {
        self.preset = preset
        self.thumbnailSettings = Self.thumbnailSettings(for: preset)
        self.needsAdvancedControls = preset.needsAdvancedControls
    }

    /// Resolve a list, in order.
    static func resolve(_ presets: [MicaPreset]) -> [ResolvedPreset] {
        presets.map(ResolvedPreset.init)
    }

    // MARK: - Staging

    /// The preset over defaults, staged for its thumbnail.
    ///
    /// An icon preset draws itself with the badge suppressed. A badge preset draws
    /// over a **ghost icon**: `secondary` is the adaptive ~50%-of-label token, so the
    /// placeholder reads correctly in both appearances without pinning a grey that
    /// would be wrong in one of them, and it is flat and shadowless because a gradient
    /// or a drop shadow on a stand-in competes with the badge — the only thing in that
    /// thumbnail the user is being asked to look at.
    private static func thumbnailSettings(for preset: MicaPreset) -> IconSettings {
        var settings = PresetApplication.previewSettings(for: preset)

        switch preset.scope {
        case .icon:
            // Already hidden in `IconSettings()`; belt and braces against a future
            // default, and it costs one line.
            settings.badge.isHidden = true
        case .badge:
            settings.icon.foreground.isHidden = true
            settings.icon.background.source = .color
            settings.icon.background.color = .token("secondary")
            settings.icon.background.usesGradient = false
            settings.icon.background.usesCustomGradient = false
            settings.icon.background.shadowStyle = .off
        }
        return settings
    }
}
