// App/IconViewModel+Undo.swift
//
// Undo for the app's two pieces of editable state.
//
// ## Why this is central rather than at the bindings
//
// Every setting is written by a `@Binding` somewhere in the inspector — hundreds of
// them, across four background sections, four foreground sections, the layout sections
// and the simple pane. Registering undo at each write would mean every new control
// remembering to do it, and a forgotten one is invisible: the setting simply is not
// undoable, and nothing fails.
//
// So `ContentView` observes the two pieces of state (`iconSettings` and
// `micaAppexColors`) and forwards each change here instead. That is one place rather
// than hundreds, and it cannot fall out of step with the bindings because there is
// nothing at the bindings to keep in step. The appex colours need their own path
// because they are not part of `IconSettings`.
//
// The window's own `UndoManager` does the recording — `@Environment(\.undoManager)` in a
// plain `WindowGroup` is non-nil and *is* the window's manager, verified in the running
// app. There is no document and no dirty state: the app keeps nothing between launches
// by design, and Export Configuration is how work is kept.
//
// ## The observer fires *after* the undo, which is the whole difficulty
//
// An earlier version registered undo from that observer and had the undo's own closure
// re-register its inverse, so redo would work. In the running app that produced an undo
// that **toggled**: change one setting, undo once, and the value went back correctly —
// but Undo stayed enabled and Redo never became available, so pressing Undo again
// *redid* the change, forever.
//
// The reason is that SwiftUI's `onChange` does not run during the mutation. It runs on
// the next view update, by which time the undo operation has finished and
// `UndoManager.isUndoing` is false again. So the closure's re-registration landed on
// the redo stack correctly, and then the observer fired and registered a *second* entry
// — this time on the undo stack, which discards the redo stack as a side effect.
// Verified in the running app, not deduced: Undo/Redo enablement was read out of the
// Edit menu after each step.
//
// Hence `UndoState.isApplying`: the closure sets it immediately before installing its
// value, and the observer consumes it and registers nothing. It is a flag rather than a
// check of `undoManager.isUndoing` precisely because by then `isUndoing` is false.
//
// **The unit tests could not see this**, because they called the register functions
// directly and never simulated the observer firing afterwards. The tests now drive
// `settingsDidChange(from:)` in the order SwiftUI does — mutate, then observe — which
// is why they are worth reading before changing anything here.
//
// ## One gesture, one undo
//
// A slider drag or a badge drag changes the settings on every frame, and each frame is
// an observation. Without coalescing, undo steps back through a drag frame by frame.
// Two mechanisms, because SwiftUI reports boundaries for some controls and not others:
//
// - **Declared boundaries.** Sliders (`onEditingChanged`) and the badge drag
//   (`DragGesture`) say when they start and stop, through
//   `EnvironmentValues.continuousEdit`. Exact: the group is the gesture.
// - **A same-key time window.** Everything else — in practice the colour panel, whose
//   drag has no boundary callback at all — coalesces consecutive changes to the *same*
//   setting that arrive within `burstWindow`. Inexact by nature, so it is the fallback
//   and not the primary: a bulk change never uses it (see `SettingsChange.isBulk`), and
//   a declared gesture overrides it.
//
// Either way only the *first* change of the run registers, and it restores the value
// from before the run — so one undo returns to where the gesture started.

import SwiftUI

/// Undo bookkeeping. Lives as one stored property on `IconViewModel` because Swift
/// extensions cannot add stored properties, and as a struct so it is one property
/// rather than five loose flags.
struct UndoState {
    /// Set by an undo or redo just before it installs its value, and consumed by the
    /// observer that sees that write. See the file header — this cannot be replaced by
    /// checking `UndoManager.isUndoing`, which is already false by then.
    var isApplyingSettings = false

    /// The same, for the appex colours, which have their own observer. Separate flags
    /// rather than one shared: a settings undo does not change the colours, so a shared
    /// flag would be left set and would swallow the next real colour edit.
    var isApplyingAppexColors = false

    /// Non-nil while a control has declared a gesture in progress.
    var gesture: Gesture?

    /// The setting the current run of changes is about, and when it was last touched.
    /// Together these are the same-key time window.
    var burstKey: String?
    var lastChangeAt: Date?

    struct Gesture {
        /// Overrides the action name for the whole gesture; `nil` lets the change name
        /// itself.
        let name: String?
        /// Whether this gesture's undo has been registered yet. Only the first change
        /// registers.
        var hasRegistered = false
    }
}

@MainActor
extension IconViewModel {

    /// How long after a change another change to the *same* setting still counts as the
    /// same continuous edit. Only the undeclared path uses this — a slider or the badge
    /// drag declares its own boundaries and is unaffected by the value.
    ///
    /// Long enough to bridge the gaps in a colour-panel drag, short enough that two
    /// deliberate edits do not merge. If two do merge the cost is small: the coalesced
    /// undo restores the value from before the first of them.
    static var burstWindow: TimeInterval { 0.5 }

    // MARK: - What ContentView's observers call

    /// `iconSettings` changed. Registers undo unless this change was not a user edit.
    ///
    /// Returns the change it registered, or `nil` when it registered nothing — a
    /// configuration being imported, a write that came from an undo, a no-op, or a frame
    /// in the middle of a gesture. **No caller uses the value today**; it is
    /// `@discardableResult` for that reason, and it is kept because it is what the
    /// observer knows and the tests assert on (`IconViewModelUndoTests` checks the
    /// reported change rather than reaching into `UndoState`). It was also the input to
    /// the text-field focus fix that `SettingsChange.isTextFieldEdit` documents and this
    /// app deliberately does not ship.
    ///
    /// `now` is injectable so the time-window behaviour can be tested without sleeping.
    @discardableResult
    func settingsDidChange(
        from previous: IconSettings, undoManager: UndoManager?, now: Date = Date()
    ) -> SettingsChange? {
        // Importing a configuration writes these properties too. It registers its own
        // single undo step for the whole import, so the per-change path must stay out
        // of the way rather than add a second.
        guard !isInstallingImportedConfiguration else { return nil }

        // This write came from an undo or redo, which already registered its inverse on
        // the correct stack. See the file header.
        if undoState.isApplyingSettings {
            undoState.isApplyingSettings = false
            return nil
        }

        guard let change = SettingsChange.between(previous, iconSettings) else { return nil }
        // Still a user edit even with no undo manager to record it, so the caller is
        // told about it.
        guard let undoManager else { return change }

        let continuing = isContinuing(change, at: now)
        undoState.lastChangeAt = now
        undoState.burstKey = change.key
        guard !continuing else { return nil }

        undoState.gesture?.hasRegistered = true
        registerSettingsUndo(
            restoring: previous,
            named: undoState.gesture?.name ?? change.name,
            undoManager: undoManager
        )
        return change
    }

    /// The four System-mode colours changed. They are separate `@Published` properties
    /// rather than part of `IconSettings`, so without this a System-mode colour change
    /// would not be undoable at all — ⌘Z would silently skip past it to the previous
    /// edit, which reads as undo losing a step.
    func appexColorsDidChange(from previous: MicaAppexColors, undoManager: UndoManager?) {
        guard !isInstallingImportedConfiguration else { return }
        if undoState.isApplyingAppexColors {
            undoState.isApplyingAppexColors = false
            return
        }
        guard let undoManager, previous != micaAppexColors else { return }
        registerAppexColorUndo(restoring: previous, undoManager: undoManager)
    }

    /// Whether this change belongs to a run already registered — a declared gesture, or
    /// a rapid repeat of the same setting.
    private func isContinuing(_ change: SettingsChange, at now: Date) -> Bool {
        if let gesture = undoState.gesture { return gesture.hasRegistered }
        guard !change.isBulk,
              undoState.burstKey == change.key,
              let last = undoState.lastChangeAt
        else { return false }
        return now.timeIntervalSince(last) < Self.burstWindow
    }

    // MARK: - Gesture boundaries

    /// The scope to put in the environment for the views below `ContentView`.
    var continuousEditScope: ContinuousEditScope {
        ContinuousEditScope(
            begin: { [weak self] name in self?.beginContinuousEdit(named: name) },
            end: { [weak self] in self?.endContinuousEdit() }
        )
    }

    /// Start one undo group. Ignored if a gesture is already live, so a
    /// `DragGesture.onChanged` can call this on every frame rather than tracking its
    /// own "have I started" flag.
    func beginContinuousEdit(named name: String?) {
        guard undoState.gesture == nil else { return }
        undoState.gesture = UndoState.Gesture(name: name)
    }

    /// End it. Also clears the time window, so the next change to the same setting
    /// starts a fresh undo step instead of being absorbed into the gesture just ended.
    func endContinuousEdit() {
        undoState.gesture = nil
        undoState.burstKey = nil
        undoState.lastChangeAt = nil
    }

    // MARK: - Registration

    /// Register an undo that puts `previous` back, and re-register the inverse when it
    /// runs so redo works too — an undo that registers an undo *is* the redo.
    func registerSettingsUndo(
        restoring previous: IconSettings, named name: String, undoManager: UndoManager
    ) {
        undoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                let current = target.iconSettings
                // Nothing to restore, so nothing to re-register either. Also keeps
                // `isApplyingSettings` from being set for a write that will produce no
                // observation to consume it.
                guard current != previous else { return }
                target.undoState.isApplyingSettings = true
                target.iconSettings = previous
                target.registerSettingsUndo(
                    restoring: current, named: name, undoManager: undoManager
                )
            }
        }
        undoManager.setActionName(name)
    }

    /// The appex colours' equivalent. Unnamed for now: the four colours are edited by
    /// one control each, and "Change System Colors" is as specific as the diff between
    /// two `MicaAppexColors` would get without a second field table for four fields.
    func registerAppexColorUndo(restoring previous: MicaAppexColors, undoManager: UndoManager) {
        undoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                let current = target.micaAppexColors
                guard current != previous else { return }
                target.undoState.isApplyingAppexColors = true
                target.micaAppexColors = previous
                target.registerAppexColorUndo(restoring: current, undoManager: undoManager)
            }
        }
        undoManager.setActionName("Change System Colors")
    }
}
