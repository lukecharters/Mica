// App/IconViewModel+Presets.swift
//
// Applying a preset, and saving the current icon as one.
//
// **The apply routes through the configuration-import path** rather than writing
// settings directly, because that path already solves the three problems an apply
// has: it registers exactly one redo-safe undo entry, it guards against a no-op
// apply earning an undo step, and it ends any continuous edit first. Re-implementing
// those here would be a second answer to each, and the undo one in particular is a
// question this codebase has already got wrong once — registering undo from a
// settings observer silently kills redo, and no test on the register function can
// see it.
//
// All it needs on top is a scoped merge and a different action name, both of which
// are parameters rather than branches.
//
// **App-target only.** `mica-cli` applies a preset by composing it into
// `GenerationContext` before the flags land, which is a different mechanism for a
// different reason: the CLI has no undo and no view model, and its precedence rule
// (preset first, flags override) is the whole feature there.

import SwiftUI

extension IconViewModel {

    // MARK: - Applying

    /// Apply a preset to the current icon as one undoable step.
    ///
    /// The merge is scoped, so an icon preset leaves the badge alone and vice versa.
    /// The rest — the undo entry, the no-op guard, ending a continuous edit — is the
    /// import path's, unchanged.
    ///
    /// Warnings come from the codec and are reported the same way an import's are. A
    /// built-in produces none; a hand-edited user preset with an unreadable value
    /// will, and hearing about it is the difference between a preset that half-works
    /// and one that explains itself.
    func applyPreset(_ preset: MicaPreset, undoManager: UndoManager?) {
        var settings = iconSettings
        var appexColors = micaAppexColors

        let warnings: [MicaConfigWarning]
        do {
            warnings = try PresetApplication.apply(preset, to: &settings, appexColors: &appexColors)
        } catch {
            // Only unreadable JSON throws, and a preset's keys are built in memory
            // rather than parsed from text — so this is unreachable in practice.
            // Reported rather than swallowed because a silent no-op click is the
            // worst version of whatever made it reachable.
            report(.presetApplyFailed(preset.name, error))
            return
        }

        importConfiguration(
            settings: settings,
            appexColors: appexColors,
            warnings: warnings,
            undoManager: undoManager,
            actionName: preset.scope.undoActionName
        )
    }

    // MARK: - Saving

    /// Capture the current icon as a user preset and write it.
    ///
    /// The name is uniqued against everything already in the scope, built-ins
    /// included: two identically-labelled rows a click apart in one section is the
    /// confusion that avoids. Returns the preset as saved — with whatever name it
    /// ended up with — so the pane can select it.
    ///
    /// Imported artwork does not survive: a preset has nowhere to put a sidecar PNG,
    /// so those keys are dropped and the user is told which. Saving anyway is the
    /// right call — the rest of the preset is still worth having, and refusing would
    /// leave no way to save a preset from an icon that merely *had* an import in one
    /// layer.
    @discardableResult
    func saveCurrentAsPreset(scope: PresetScope, name: String, existing: [MicaPreset]) -> MicaPreset? {
        let uniqued = UserPresetStore.uniqueName(name, in: scope, existing: existing)
        do {
            let capture = try UserPresetStore.capture(
                iconSettings,
                appexColors: micaAppexColors,
                scope: scope,
                name: uniqued
            )
            try UserPresetStore.save(capture.preset)
            if !capture.droppedImageKeys.isEmpty {
                report(.presetDroppedImages(uniqued, keys: capture.droppedImageKeys))
            }
            return capture.preset
        } catch {
            report(.presetSaveFailed(uniqued, error))
            return nil
        }
    }

    /// Delete a user preset. Built-ins are not files and are refused upstream — the
    /// pane offers no Delete on one.
    func deletePreset(_ preset: MicaPreset) {
        do {
            try UserPresetStore.delete(preset)
        } catch {
            report(.presetDeleteFailed(preset.name, error))
        }
    }
}
