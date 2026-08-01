// MicaTests/ViewModels/IconViewModelConfigImportTests.swift
//
// Importing a configuration as ONE undo step.
//
// Same harness discipline as IconViewModelUndoTests, and for the same reason: these
// tests drive the observers in the order SwiftUI actually runs them — mutate, then
// observe on the next update — because that ordering is the entire difficulty. An
// import writes the same two properties a user edit writes, so without suppression the
// observer would add a second, per-property undo step on top of the import's own, and
// ⌘Z would take two presses to undo one action.
//
// The suppression cannot be a flag held across the call. `onChange` runs long after
// `importConfiguration` returns, so a flag set and cleared around the writes would
// already be false by the time the observer read it. It is `undoState.isApplying*`,
// which the observer *consumes* whenever it fires — which is why several tests here
// assert on those flags being false afterwards rather than only on the undo stack: a
// flag left standing is invisible until it silently swallows the user's next edit.
//
// A test here that calls `registerConfigurationUndo` directly tests nothing.

import Testing
import SwiftUI
import Foundation
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct IconViewModelConfigImportTests {

    // MARK: - Harness

    private func manager() -> UndoManager {
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        return undoManager
    }

    /// Both observers, as ContentView forwards them after an update. Deliberately
    /// outside any group — see IconViewModelUndoTests' note on why wrapping an
    /// observation in a group destroys the redo stack.
    private func observe(
        _ model: IconViewModel,
        _ undoManager: UndoManager,
        settings: IconSettings,
        colors: MicaAppexColors
    ) {
        model.settingsDidChange(from: settings, undoManager: undoManager)
        model.appexColorsDidChange(from: colors, undoManager: undoManager)
    }

    /// An import, as the app performs it: the call registers its own step inside a
    /// group, and the observers fire afterwards.
    private func performImport(
        _ model: IconViewModel,
        _ undoManager: UndoManager,
        settings: IconSettings,
        colors: MicaAppexColors = MicaAppexColors(),
        warnings: [MicaConfigWarning] = []
    ) {
        let previousSettings = model.iconSettings
        let previousColors = model.micaAppexColors
        undoManager.beginUndoGrouping()
        model.importConfiguration(
            settings: settings, appexColors: colors,
            warnings: warnings, undoManager: undoManager
        )
        undoManager.endUndoGrouping()
        observe(model, undoManager, settings: previousSettings, colors: previousColors)
    }

    private func undo(_ model: IconViewModel, _ undoManager: UndoManager) {
        let settings = model.iconSettings
        let colors = model.micaAppexColors
        undoManager.undo()
        observe(model, undoManager, settings: settings, colors: colors)
    }

    private func redo(_ model: IconViewModel, _ undoManager: UndoManager) {
        let settings = model.iconSettings
        let colors = model.micaAppexColors
        undoManager.redo()
        observe(model, undoManager, settings: settings, colors: colors)
    }

    /// A configuration differing from the defaults in both pieces of state.
    private func importedConfiguration() -> (IconSettings, MicaAppexColors) {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "bolt.fill"
        settings.export.size = 512
        let colors = MicaAppexColors(iconEnclosure: .green, iconSymbol: .black)
        return (settings, colors)
    }

    // MARK: - One step

    @Test("An import is a single undo step that restores both settings and colours")
    func import_isOneUndoStep() {
        let model = IconViewModel()
        let undoManager = manager()
        let (settings, colors) = importedConfiguration()

        performImport(model, undoManager, settings: settings, colors: colors)
        #expect(model.iconSettings.icon.foreground.symbolName == "bolt.fill")
        #expect(model.micaAppexColors.iconEnclosure == .green)

        undo(model, undoManager)

        #expect(model.iconSettings == IconSettings())
        #expect(model.micaAppexColors == MicaAppexColors())
        #expect(!undoManager.canUndo, "one import must not leave a second step behind it")
    }

    @Test("Redo puts the imported configuration back")
    func import_redoRestoresIt() {
        let model = IconViewModel()
        let undoManager = manager()
        let (settings, colors) = importedConfiguration()

        performImport(model, undoManager, settings: settings, colors: colors)
        undo(model, undoManager)
        #expect(undoManager.canRedo, "the toggle bug shows up here first")

        redo(model, undoManager)

        #expect(model.iconSettings.icon.foreground.symbolName == "bolt.fill")
        #expect(model.iconSettings.export.size == 512)
        #expect(model.micaAppexColors.iconEnclosure == .green)
        #expect(model.micaAppexColors.iconSymbol == .black)
    }

    @Test("The import's action name is what the Edit menu shows")
    func import_actionName() {
        let model = IconViewModel()
        let undoManager = manager()
        let (settings, colors) = importedConfiguration()

        performImport(model, undoManager, settings: settings, colors: colors)

        #expect(undoManager.undoActionName == "Import Configuration")
    }

    // MARK: - Flag hygiene

    @Test("Both suppression flags are consumed by the observers that follow an import")
    func import_consumesBothFlags() {
        let model = IconViewModel()
        let undoManager = manager()
        let (settings, colors) = importedConfiguration()

        performImport(model, undoManager, settings: settings, colors: colors)

        #expect(!model.undoState.isApplyingSettings)
        #expect(!model.undoState.isApplyingAppexColors)
    }

    @Test("An import that changes only the settings never sets the colour flag")
    func import_settingsOnly_leavesNoColourFlag() {
        let model = IconViewModel()
        let undoManager = manager()
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "bolt.fill"

        // Colours identical to the current state, so no colour write happens and no
        // observation would arrive to consume a flag set for one.
        performImport(model, undoManager, settings: settings, colors: model.micaAppexColors)

        #expect(!model.undoState.isApplyingAppexColors)

        // The proof that it did not leak: the next real colour edit still registers.
        let previousColors = model.micaAppexColors
        undoManager.beginUndoGrouping()
        model.appexEnclosureColor = .red
        model.appexColorsDidChange(from: previousColors, undoManager: undoManager)
        undoManager.endUndoGrouping()

        undo(model, undoManager)
        #expect(model.micaAppexColors.iconEnclosure == previousColors.iconEnclosure,
                "a leaked flag would have swallowed this edit")
    }

    @Test("An import that changes only the colours never sets the settings flag")
    func import_coloursOnly_leavesNoSettingsFlag() {
        let model = IconViewModel()
        let undoManager = manager()
        let colors = MicaAppexColors(iconEnclosure: .green)

        performImport(model, undoManager, settings: model.iconSettings, colors: colors)

        #expect(!model.undoState.isApplyingSettings)

        let previousSettings = model.iconSettings
        undoManager.beginUndoGrouping()
        model.iconSettings.icon.foreground.symbolName = "bolt.fill"
        model.settingsDidChange(from: previousSettings, undoManager: undoManager)
        undoManager.endUndoGrouping()

        undo(model, undoManager)
        #expect(model.iconSettings.icon.foreground.symbolName
                    == previousSettings.icon.foreground.symbolName,
                "a leaked flag would have swallowed this edit")
    }

    // MARK: - Nothing to do

    /// Asserted by undoing and finding nothing moved, **not** by `canUndo`.
    ///
    /// The harness opens a group around every import so each is its own step. A group
    /// that gets no registration is still kept by `UndoManager`, and an empty group
    /// makes `canUndo` true — so `canUndo` cannot distinguish "registered nothing" from
    /// "registered something" here. That is a harness artifact and never happens in the
    /// app, where groups form lazily on registration. The undo suite's header documents
    /// the same trap; do not rewrite these as `#expect(!canUndo)`.
    @Test("Importing the configuration already loaded registers no undo step")
    func import_noOp_registersNothing() {
        let model = IconViewModel()
        let undoManager = manager()

        performImport(
            model, undoManager,
            settings: model.iconSettings, colors: model.micaAppexColors
        )

        let settings = model.iconSettings
        let colors = model.micaAppexColors
        undo(model, undoManager)

        #expect(model.iconSettings == settings, "an undo step was registered for a no-op")
        #expect(model.micaAppexColors == colors)
    }

    @Test("An import ends any gesture or burst window in progress")
    func import_endsContinuousEdit() {
        let model = IconViewModel()
        let undoManager = manager()
        model.beginContinuousEdit(named: "Drag Something")

        performImport(model, undoManager, settings: importedConfiguration().0)

        #expect(model.undoState.gesture == nil)
        #expect(model.undoState.burstKey == nil)
    }

    // MARK: - Warnings

    @Test("Warnings from the decode reach the view model for the alert to show")
    func import_carriesWarnings() {
        let model = IconViewModel()
        let undoManager = manager()
        let warnings = [
            MicaConfigWarning(key: "icon-fg", message: "image could not be loaded"),
            MicaConfigWarning(key: "images", message: "import the folder instead"),
        ]

        performImport(
            model, undoManager,
            settings: importedConfiguration().0, warnings: warnings
        )

        #expect(model.configImportWarnings == warnings)
    }

    @Test("A no-op import still reports its warnings")
    func import_noOp_stillWarns() {
        let model = IconViewModel()
        let undoManager = manager()
        let warnings = [MicaConfigWarning(key: "icon-fg", message: "image could not be loaded")]

        // Nothing to install, but the user still needs telling why their images are
        // missing — the early return for a no-op must come after the warnings land.
        performImport(
            model, undoManager,
            settings: model.iconSettings, colors: model.micaAppexColors,
            warnings: warnings
        )

        #expect(model.configImportWarnings == warnings)

        // Still nothing to undo — see import_noOp_registersNothing on why this is
        // checked by undoing rather than by canUndo.
        let settings = model.iconSettings
        undo(model, undoManager)
        #expect(model.iconSettings == settings)
    }
}
