// App/IconViewModel+Configuration.swift
//
// Where the view model meets the JSON configuration format: the four System-mode
// colours as one value, which is what makes them observable as a unit.
//
// Import lands here too (Phase 8). It is deliberately not a per-property copy — an
// import is one thing the user did, so it registers one undo step, which is why
// `isInstallingImportedConfiguration` exists on the view model.

import SwiftUI

extension IconViewModel {
    /// The four System-mode colours as one value. They sit on this object rather than
    /// in `IconSettings` — the renderer takes them separately, and the CLI carries them
    /// on `GenerationContext` for the same reason.
    ///
    /// Grouping them matters for undo: `ContentView` observes *this*, so the four
    /// `@Published` properties produce one change to compare rather than four
    /// independent ones, and `MicaAppexColors: Equatable` is what tells a real edit from
    /// a no-op write.
    var micaAppexColors: MicaAppexColors {
        get {
            MicaAppexColors(
                iconEnclosure: appexEnclosureColor,
                iconSymbol: appexSymbolColor,
                badgeEnclosure: badgeAppexEnclosureColor,
                badgeSymbol: badgeAppexSymbolColor
            )
        }
        set {
            appexEnclosureColor = newValue.iconEnclosure
            appexSymbolColor = newValue.iconSymbol
            badgeAppexEnclosureColor = newValue.badgeEnclosure
            badgeAppexSymbolColor = newValue.badgeSymbol
        }
    }

    // MARK: - Export

    /// Prepare the configuration export and open the save panel.
    ///
    /// Preparing before presenting is what lets the exporter know which *shape* it is
    /// writing: a configuration with no imported images is a single `.json` file, one
    /// with them is a `.folder`, and `fileExporter` needs that content type up front.
    /// It also means the JSON is encoded once per export rather than once per view
    /// update.
    func beginConfigurationExport() {
        do {
            configExportDocument = try ConfigurationExportDocument(
                settings: iconSettings,
                appexColors: micaAppexColors,
                baseName: iconSettings.exportBaseName
            )
            showConfigExportDialog = true
        } catch {
            configExportDocument = nil
            report(.configurationExportFailed(error))
        }
    }

    // MARK: - Import

    /// Read the configuration at `url` and install it as one undoable step.
    ///
    /// `url` comes from a `fileImporter`, so it carries a security scope that has to be
    /// opened around every read — the JSON *and* the sidecar images the codec resolves
    /// from it, which is why the scope stays open for the whole decode rather than just
    /// the `Data(contentsOf:)`.
    func importConfiguration(from url: URL, undoManager: UndoManager?) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let source = try ConfigurationImportSource(url: url)
            let contents = try MicaConfigCodec.decode(
                json: try Data(contentsOf: source.jsonURL),
                configDirectory: source.directory
            )
            importConfiguration(
                settings: contents.settings,
                appexColors: contents.appexColors,
                warnings: source.warningsAdvising(contents.warnings),
                undoManager: undoManager
            )
        } catch {
            // Nothing is installed on a failure: a configuration that cannot be read
            // must not leave the app half-changed.
            report(.configurationImportFailed(error))
        }
    }

    /// Install a decoded configuration as a single undo step.
    ///
    /// ## Why the suppression flags rather than `isInstallingImportedConfiguration`
    ///
    /// `ContentView`'s observers do not run during this function. SwiftUI's `onChange`
    /// runs on the *next* view update, by which time this has long returned — so a flag
    /// set and cleared around the writes below would already be false when the observer
    /// finally looked at it, and the observer would register a second, per-property undo
    /// step on top of this one. That is the same ordering that produced the toggling
    /// undo described in `IconViewModel+Undo.swift`.
    ///
    /// So this uses `undoState.isApplyingSettings` / `isApplyingAppexColors`, which the
    /// observer *consumes* whenever it eventually fires — exactly how undo and redo
    /// already suppress their own writes.
    ///
    /// **Setting both mechanisms would be a bug, not belt and braces.**
    /// `settingsDidChange` checks `isInstallingImportedConfiguration` *before* it
    /// consumes `isApplyingSettings`, so an observer that saw both set would return on
    /// the first and leave the second standing — and a leaked flag silently swallows the
    /// next real edit the user makes.
    ///
    /// Each flag is set only when its value actually changes, for the same reason: a
    /// write of an equal value produces no `onChange`, so there would be no observation
    /// to consume the flag.
    func importConfiguration(
        settings: IconSettings,
        appexColors: MicaAppexColors,
        warnings: [MicaConfigWarning],
        undoManager: UndoManager?,
        actionName: String = "Import Configuration"
    ) {
        // An import is not part of whatever gesture or burst preceded it.
        endContinuousEdit()
        // Reported before the early return below: a configuration whose settings match
        // what is already on screen still has to account for what it dropped on the way,
        // and "nothing changed" is the case where an unread warning matters most.
        report(.configurationImportWarnings(warnings))

        let previousSettings = iconSettings
        let previousColors = micaAppexColors
        let changesSettings = settings != previousSettings
        let changesColors = appexColors != previousColors

        // Importing a configuration identical to the current state changed nothing, so
        // it earns no undo step.
        guard changesSettings || changesColors else { return }

        if let undoManager {
            registerConfigurationUndo(
                restoringSettings: previousSettings,
                appexColors: previousColors,
                undoManager: undoManager,
                actionName: actionName
            )
        }

        if changesSettings {
            undoState.isApplyingSettings = true
            iconSettings = settings
        }
        if changesColors {
            undoState.isApplyingAppexColors = true
            micaAppexColors = appexColors
        }
    }

    /// One undo entry restoring both pieces of state, re-registering its inverse so redo
    /// works — the same shape as `registerSettingsUndo`, but covering the pair, because
    /// an import is one thing the user did.
    func registerConfigurationUndo(
        restoringSettings previousSettings: IconSettings,
        appexColors previousColors: MicaAppexColors,
        undoManager: UndoManager,
        actionName: String = "Import Configuration"
    ) {
        undoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                let currentSettings = target.iconSettings
                let currentColors = target.micaAppexColors
                guard currentSettings != previousSettings || currentColors != previousColors
                else { return }

                if currentSettings != previousSettings {
                    target.undoState.isApplyingSettings = true
                    target.iconSettings = previousSettings
                }
                if currentColors != previousColors {
                    target.undoState.isApplyingAppexColors = true
                    target.micaAppexColors = previousColors
                }
                target.registerConfigurationUndo(
                    restoringSettings: currentSettings,
                    appexColors: currentColors,
                    undoManager: undoManager,
                    actionName: actionName
                )
            }
        }
        undoManager.setActionName(actionName.localizedFromCatalog)
    }
}
