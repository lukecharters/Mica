// Services/PresetApplication.swift
//
// Applying a preset: decode its keys through the configuration codec, then copy
// across the half of the result its scope owns.
//
// **Two steps, and the split is the whole design.** The decode is the existing
// codec doing exactly what it does for a `--config` file, which is what makes a
// preset able to say precisely what a configuration can say. The copy is what makes
// it *scoped* and *scope-complete* at the same time: because the decode ran against
// a fresh `IconSettings`, every key the preset did not mention is already at its
// default, so copying the whole subtree installs those defaults rather than leaving
// the user's residue behind.
//
// The badge activation rule needs no code here and that is not an accident. A badge
// is switched on by the *presence* of `badge-fg`, and a badge preset always carries
// its symbol, so decoding one always produces a visible badge. That is the codec's
// existing rule working, not a new one — which is also why applying a badge preset
// to an icon with no badge turns the badge on.
//
// Shared with `mica-cli`, so this is one of the paths named in both
// `membershipExceptions` lists.

import Foundation

enum PresetApplication {

    /// What decoding a preset produced, before anything is copied anywhere.
    struct Decoded: Equatable {
        /// The settings a preset's keys decode to, over defaults.
        var settings: IconSettings
        /// The System-mode colours beside them.
        var appexColors: MicaAppexColors
        /// Anything the preset said that this build could not honour. Never fatal;
        /// a built-in producing one is a bug, which `PresetCatalogTests` pins.
        var warnings: [MicaConfigWarning]
    }

    /// Decode a preset's keys over a fresh `IconSettings`.
    ///
    /// **Never over the current settings.** Decoding onto defaults is what makes a
    /// preset scope-complete: it is the step that turns "this key is absent" into
    /// "this key is at its default" rather than "leave whatever is there".
    ///
    /// Only unreadable JSON throws, and a preset's keys are built in memory rather
    /// than parsed from text, so in practice this cannot — a preset whose values
    /// are wrong produces warnings and defaults instead. The `throws` is kept
    /// because it is the codec's, not because a caller has a useful recovery.
    static func decode(_ preset: MicaPreset) throws -> Decoded {
        let json = try JSONSerialization.data(withJSONObject: preset.jsonObject)
        // No `configDirectory`: a preset carries no imported images. There is
        // nothing structural stopping one — `icon-bg` takes a path — but a preset
        // that referenced a file on the author's disk would break the moment it was
        // shared, and the pane's thumbnails would have to load it asynchronously.
        // A relative path in a preset therefore resolves against nothing and warns,
        // which is the honest failure.
        let contents = try MicaConfigCodec.decode(json: json, configDirectory: nil)
        return Decoded(
            settings: contents.settings,
            appexColors: contents.appexColors,
            warnings: contents.warnings
        )
    }

    /// Apply a preset in place, replacing the half of `settings` its scope owns.
    ///
    /// The System-mode colours travel with their scope: `appexColors` splits
    /// icon/badge exactly as `IconSettings` does, so an icon preset writes the two
    /// icon colours and leaves the badge's alone. Returns the codec's warnings so a
    /// caller can surface them; a built-in produces none.
    @discardableResult
    static func apply(
        _ preset: MicaPreset,
        to settings: inout IconSettings,
        appexColors: inout MicaAppexColors
    ) throws -> [MicaConfigWarning] {
        let decoded = try decode(preset)
        copy(decoded, scope: preset.scope, to: &settings, appexColors: &appexColors)
        return decoded.warnings
    }

    /// The scoped copy on its own, for callers that already decoded.
    ///
    /// Split out because the advanced-controls indicator decodes once and folds
    /// twice, and because `mica-cli` applies a preset onto a `--config` base where
    /// the decode and the copy happen at different points in the pipeline.
    static func copy(
        _ decoded: Decoded,
        scope: PresetScope,
        to settings: inout IconSettings,
        appexColors: inout MicaAppexColors
    ) {
        switch scope {
        case .icon:
            // The whole `IconSpec`, which is every `icon-*` key including
            // `icon-generation-mode` — so a Mica preset applied to a System-mode
            // icon switches it back to Mica. That is the mode being *carried*
            // rather than special-cased, and it is why the built-in set exercises
            // the switch without needing a System-mode preset of its own.
            settings.icon = decoded.settings.icon
            appexColors.iconEnclosure = decoded.appexColors.iconEnclosure
            appexColors.iconSymbol = decoded.appexColors.iconSymbol
        case .badge:
            // Includes `badge-position`, `badge-scale` and the two offsets, which
            // the pane's ghost-corner thumbnails require: a thumbnail that shows
            // which corner the badge lands in only means anything if the preset
            // sets the corner. The accepted cost is that a badge preset overwrites
            // an arrow-key nudge; one undo puts it back.
            settings.badge = decoded.settings.badge
            appexColors.badgeEnclosure = decoded.appexColors.badgeEnclosure
            appexColors.badgeSymbol = decoded.appexColors.badgeSymbol
        }
    }

    /// The settings a preset produces on its own, over defaults — what a thumbnail
    /// draws, and what the indicator predicate folds.
    ///
    /// Not the same as applying it to the current icon: a thumbnail is a *catalogue*
    /// entry drawn in isolation on neutral ground, so the pane stays stable while
    /// the icon is edited.
    static func previewSettings(for preset: MicaPreset) -> IconSettings {
        guard let decoded = try? decode(preset) else { return IconSettings() }
        var settings = IconSettings()
        var colors = MicaAppexColors()
        copy(decoded, scope: preset.scope, to: &settings, appexColors: &colors)
        return settings
    }
}
