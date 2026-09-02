// App/MicaPreset+AdvancedControls.swift
//
// Whether applying a preset would turn "Show Advanced Controls" on.
//
// **Derived, never authored.** The predicate is exact and already written: a preset
// needs the advanced controls precisely when applying it produces settings that
// `resetToSimpleControls()` would change. So apply to a copy, fold a second copy,
// compare — rather than storing a boolean per preset.
//
// That is worth the indirection for three reasons. It is self-maintaining: if the
// simple pane later grows a gradient control, `resetToSimpleControls()` stops
// folding gradients and presets stop being flagged, with no preset files to edit. It
// covers user-saved presets for free, which a stored flag could only do by asking
// the user a question they cannot answer. And a stored boolean would drift the first
// time the simple pane changes, silently — the pane would promise a restructuring
// that no longer happens, or fail to warn about one that does.
//
// **App-target only.** `resetToSimpleControls()` lives in
// `IconSettings+SimpleInspector.swift`, which `mica-cli` deliberately does not
// compile — the CLI has no inspector and no preference to reveal.

import Foundation

extension MicaPreset {

    /// True when applying this preset produces state the simple inspector cannot
    /// express, so `InspectorControls` will reveal the advanced controls.
    ///
    /// **Measured against defaults, not against the user's current icon.** The
    /// question is a property of the preset — the pane shows the same indicator
    /// whatever is on the canvas — and folding the user's settings would answer a
    /// different question: a badge preset would be flagged because the *icon* already
    /// had a custom gradient, which the badge preset neither caused nor changes.
    ///
    /// Only the scope is compared for the same reason.
    var needsAdvancedControls: Bool {
        let applied = PresetApplication.previewSettings(for: self)
        var folded = applied
        folded.resetToSimpleControls()

        switch scope {
        case .icon:  return folded.icon != applied.icon
        case .badge: return folded.badge != applied.badge
        }
    }
}

extension IconSettings {

    /// True when this preset, applied here, would reveal the advanced controls
    /// *that are not already showing something*.
    ///
    /// Not what the pane's indicator asks — see `needsAdvancedControls`, which is
    /// the property of the preset. This is the apply path's question, and it differs
    /// in one way that matters: an icon whose *other* group already needs the
    /// advanced controls will have them revealed regardless, so the preset is not
    /// what turned them on.
    ///
    /// Not used by the reveal itself, which `IconViewModel.applyPreset` does on
    /// `needsAdvancedControls`. Kept because `PresetCatalogTests` compares the two
    /// predicates, which is what catches the tile's indicator and the apply's reveal
    /// disagreeing.
    func wouldRevealAdvancedControls(applying preset: MicaPreset) -> Bool {
        var applied = self
        var colors = MicaAppexColors()
        _ = try? PresetApplication.apply(preset, to: &applied, appexColors: &colors)

        var folded = applied
        folded.resetToSimpleControls()
        return folded != applied
    }
}
