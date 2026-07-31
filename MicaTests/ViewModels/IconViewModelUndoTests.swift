// MicaTests/ViewModels/IconViewModelUndoTests.swift
//
// Undo for the app's two pieces of editable state.
//
// ## Every test here drives the observer, never `registerSettingsUndo` directly
//
// That is the entire point of the suite. An earlier version's tests called the register
// functions straight and all passed while, in the running app, undo *toggled*: one change,
// undo once and the value came back, but Undo stayed enabled and Redo never appeared, so
// pressing Undo again redid the change, forever. The bug was in the ordering — SwiftUI's
// `onChange` runs on the update *after* the mutation, so it also fired after an undo had
// finished and registered a second entry on the wrong stack — and a test that skips the
// observer cannot see ordering at all. So `edit` and `undo` reproduce that ordering:
// mutate, then observe. Keep it that way; a test here that calls a register function
// directly is testing nothing.
//
// ## Why the assertions are about values rather than about `canUndo`
//
// `UndoManager` groups registrations by event loop iteration, and nothing turns the run
// loop in a test, so it never closes its own group: left alone, every edit in a test lands
// in one group and a single undo jumps past all of them. Neither `run(until:)` (with a
// past *or* a future date) nor `endUndoGrouping()` fixes it — the latter does not
// decrement `groupingLevel` for a group the manager opened itself, so looping on that
// hangs the test run. All three were tried.
//
// So the harness sets `groupsByEvent = false` and groups each edit itself. The cost is
// that a *coalesced* frame — one that deliberately registers nothing — still opens and
// closes a group, and an explicitly opened empty group is **not** discarded: it becomes an
// undo step that does nothing, and it makes `canUndo` true. That is an artefact of the
// harness and never happens in the app, where groups form lazily on registration (both
// measured).
//
// `undoTrace` is the answer: it undoes to exhaustion and returns only the values that
// actually *changed* — the sequence a user sees pressing ⌘Z. Empty groups vanish from it,
// and a toggling undo shows up as a trace that oscillates instead of terminating.

import Testing
import SwiftUI
import Foundation
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct IconViewModelUndoTests {

    // MARK: - Harness

    /// Explicit grouping, for the reason in the file header.
    private func manager() -> UndoManager {
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        return undoManager
    }

    /// One user edit, as SwiftUI delivers it: mutate, then let the observer see it on the
    /// next update. Each edit is its own group, except inside a declared gesture, which is
    /// one group for the whole run — which is what the app produces, one event having
    /// registered and the rest having coalesced.
    private func edit(
        _ model: IconViewModel,
        _ undoManager: UndoManager,
        now: Date = Date(),
        _ mutate: (inout IconSettings) -> Void
    ) {
        let inGesture = model.undoState.gesture != nil
        if !inGesture { undoManager.beginUndoGrouping() }
        let before = model.iconSettings
        mutate(&model.iconSettings)
        model.settingsDidChange(from: before, undoManager: undoManager, now: now)
        if !inGesture { undoManager.endUndoGrouping() }
    }

    private func beginGesture(
        _ model: IconViewModel, _ undoManager: UndoManager, named name: String? = nil
    ) {
        undoManager.beginUndoGrouping()
        model.beginContinuousEdit(named: name)
    }

    private func endGesture(_ model: IconViewModel, _ undoManager: UndoManager) {
        model.endContinuousEdit()
        undoManager.endUndoGrouping()
    }

    /// Undo, then the observation that follows it — the half Phase 4 missed, and where the
    /// second registration used to land.
    ///
    /// **The observation is deliberately not wrapped in a group.** Opening a top-level group
    /// outside an undo *clears the redo stack*, so wrapping it destroys the very thing these
    /// tests check; and because an empty group is kept, each one also left `canUndo` true
    /// forever, which made `undoTrace` spin without progress. Correct behaviour registers
    /// nothing here, so no group is needed. If that regresses, `registerUndo` with no open
    /// group raises instead of failing an expectation — loud, if blunt.
    private func undo(_ model: IconViewModel, _ undoManager: UndoManager) {
        let beforeUndo = model.iconSettings
        undoManager.undo()
        model.settingsDidChange(from: beforeUndo, undoManager: undoManager)
    }

    private func redo(_ model: IconViewModel, _ undoManager: UndoManager) {
        let beforeRedo = model.iconSettings
        undoManager.redo()
        model.settingsDidChange(from: beforeRedo, undoManager: undoManager)
    }

    /// Undoes to exhaustion, returning each value that actually changed: the sequence a
    /// user sees pressing ⌘Z. Capped, so a toggling undo terminates the test with a wrong
    /// trace rather than looping.
    private func undoTrace<V: Equatable>(
        _ model: IconViewModel, _ undoManager: UndoManager, _ value: (IconSettings) -> V
    ) -> [V] {
        var trace: [V] = []
        var guardCount = 0
        while undoManager.canUndo && guardCount < 12 {
            let before = value(model.iconSettings)
            undo(model, undoManager)
            let after = value(model.iconSettings)
            if after != before { trace.append(after) }
            guardCount += 1
        }
        return trace
    }

    // MARK: - Registration

    /// The baseline: a plain edit reaches the window's undo manager at all.
    @Test("editing registers an undo")
    func editingRegistersUndo() {
        let model = IconViewModel()
        let undoManager = manager()
        #expect(!undoManager.canUndo)

        edit(model, undoManager) { $0.icon.foreground.symbolName = "star.fill" }

        #expect(undoManager.canUndo, "no undo registered, so the edit could not be taken back")
    }

    /// SwiftUI's `onChange` can fire with an equal value. Registering for that would put a
    /// step on the stack for nothing, so ⌘Z would appear to do nothing at all.
    @Test("an observation with nothing changed registers nothing")
    func unchangedObservationRegistersNothing() {
        let model = IconViewModel()
        let undoManager = manager()

        undoManager.beginUndoGrouping()
        model.settingsDidChange(from: model.iconSettings, undoManager: undoManager)
        undoManager.endUndoGrouping()

        #expect(undoTrace(model, undoManager, \.icon.foreground.symbolName).isEmpty)
    }

    /// An import registers its own single step for the whole configuration, so the
    /// per-change path must add nothing on top of it.
    @Test("importing a configuration does not register a per-change undo")
    func importingRegistersNothing() {
        let model = IconViewModel()
        let undoManager = manager()

        model.isInstallingImportedConfiguration = true
        undoManager.beginUndoGrouping()
        let before = model.iconSettings
        model.iconSettings.icon.foreground.symbolName = "bolt.fill"
        model.settingsDidChange(from: before, undoManager: undoManager)
        undoManager.endUndoGrouping()
        model.isInstallingImportedConfiguration = false

        #expect(undoTrace(model, undoManager, \.icon.foreground.symbolName).isEmpty,
                "an import would leave a stray undo step behind it")
    }

    // MARK: - The toggle bug

    /// The regression test for the bug this phase was really about. On the Phase 4
    /// implementation redo was unavailable after one undo and a second undo was, so undo
    /// behaved as a toggle and the edit could never be recovered.
    @Test("one edit, one undo: redo becomes available")
    func undoLeavesARedo() {
        let model = IconViewModel()
        let undoManager = manager()
        model.iconSettings.icon.foreground.symbolName = "command"

        edit(model, undoManager) { $0.icon.foreground.symbolName = "star.fill" }
        undo(model, undoManager)

        #expect(model.iconSettings.icon.foreground.symbolName == "command")
        #expect(undoManager.canRedo,
                "the observation after the undo registered over the redo stack")
    }

    @Test("undo does not toggle: one edit undoes exactly once")
    func undoIsNotAToggle() {
        let model = IconViewModel()
        let undoManager = manager()
        model.iconSettings.icon.foreground.symbolName = "command"

        edit(model, undoManager) { $0.icon.foreground.symbolName = "star.fill" }

        #expect(undoTrace(model, undoManager, \.icon.foreground.symbolName) == ["command"])
    }

    @Test("undo then redo returns to the edited value")
    func undoRedoRoundTrip() {
        let model = IconViewModel()
        let undoManager = manager()
        model.iconSettings.icon.foreground.symbolName = "command"

        edit(model, undoManager) { $0.icon.foreground.symbolName = "star.fill" }
        undo(model, undoManager)
        redo(model, undoManager)

        #expect(model.iconSettings.icon.foreground.symbolName == "star.fill")
        #expect(undoManager.canUndo, "after a redo the change must be undoable again")
    }

    /// Deliberately spaced past `burstWindow`: three edits to the *same* setting in quick
    /// succession are one continuous edit by design, so the unspaced version of this test
    /// would be asserting that coalescing does not work.
    @Test("a stack of separate edits undoes in reverse order and then stops")
    func undoWalksBackTheWholeStack() {
        let model = IconViewModel()
        let undoManager = manager()
        let start = Date(timeIntervalSince1970: 1_000)
        let apart = IconViewModel.burstWindow + 0.1
        model.iconSettings.icon.foreground.symbolName = "one"

        edit(model, undoManager, now: start) { $0.icon.foreground.symbolName = "two" }
        edit(model, undoManager, now: start.addingTimeInterval(apart)) { $0.icon.foreground.symbolName = "three" }
        edit(model, undoManager, now: start.addingTimeInterval(apart * 2)) { $0.icon.foreground.symbolName = "four" }

        #expect(undoTrace(model, undoManager, \.icon.foreground.symbolName)
                == ["three", "two", "one"])
    }

    // MARK: - Action names

    @Test("the undo action is named for the setting that changed")
    func undoActionIsNamed() {
        let model = IconViewModel()
        let undoManager = manager()

        edit(model, undoManager) { $0.icon.foreground.color = .red }

        #expect(undoManager.undoActionName == "Change Icon Symbol Color")
    }

    @Test("the name survives onto the redo side")
    func redoActionIsNamed() {
        let model = IconViewModel()
        let undoManager = manager()

        edit(model, undoManager) { $0.export.size = 256 }
        undo(model, undoManager)

        #expect(undoManager.redoActionName == "Change Export Size")
    }

    @Test("a visibility flag is named for what it does, not for the property")
    func visibilityIsNamedAsAnAction() {
        let model = IconViewModel()
        let undoManager = manager()

        edit(model, undoManager) { $0.badge.background.isHidden = false }

        #expect(undoManager.undoActionName == "Show Badge Background")
    }

    // MARK: - The appex colours, which are not part of IconSettings

    /// Without their own registration a System-mode colour change would not be undoable at
    /// all, and ⌘Z would silently skip past it to the previous edit.
    @Test("a System-mode colour change registers an undo, and names itself")
    func appexColorChangeRegistersNamedUndo() {
        let model = IconViewModel()
        let undoManager = manager()

        undoManager.beginUndoGrouping()
        let before = model.micaAppexColors
        model.appexEnclosureColor = .named(.teal)
        model.appexColorsDidChange(from: before, undoManager: undoManager)
        undoManager.endUndoGrouping()

        #expect(undoManager.canUndo)
        #expect(undoManager.undoActionName == "Change System Colors")
    }

    /// The appex path has its own observer and its own suppression flag, so it has its own
    /// version of the toggle bug to avoid.
    @Test("undoing a System-mode colour leaves a redo")
    func appexColorUndoLeavesARedo() {
        let model = IconViewModel()
        let undoManager = manager()
        let before = model.micaAppexColors

        undoManager.beginUndoGrouping()
        model.appexEnclosureColor = .named(.teal)
        model.appexColorsDidChange(from: before, undoManager: undoManager)
        undoManager.endUndoGrouping()

        let beforeUndo = model.micaAppexColors
        undoManager.undo()
        model.appexColorsDidChange(from: beforeUndo, undoManager: undoManager)

        #expect(model.micaAppexColors == before)
        #expect(undoManager.canRedo, "the appex path has the toggle bug")
    }

    // MARK: - Coalescing: declared gestures

    /// The complaint Phase 6 exists to fix: a drag writes the settings on every frame, so
    /// undo stepped back through it one frame at a time.
    @Test("a slider drag is one undo step, back to where the drag started")
    func gestureCoalescesToOneStep() {
        let model = IconViewModel()
        let undoManager = manager()
        model.iconSettings.badge.scale = 1.0

        beginGesture(model, undoManager)
        for frame in 1...20 {
            edit(model, undoManager) { $0.badge.scale = 1.0 + Double(frame) * 0.05 }
        }
        endGesture(model, undoManager)

        #expect(model.iconSettings.badge.scale > 1.9)
        #expect(undoTrace(model, undoManager, \.badge.scale) == [1.0], "undo landed mid-drag")
    }

    @Test("a gesture takes its name from the single setting it drives")
    func gestureNamesItselfFromTheChange() {
        let model = IconViewModel()
        let undoManager = manager()

        beginGesture(model, undoManager)
        edit(model, undoManager) { $0.badge.scale = 1.5 }
        endGesture(model, undoManager)

        #expect(undoManager.undoActionName == "Change Badge Size")
    }

    /// The badge drag writes both offsets every frame, so the diff can only report a
    /// generic bulk change — which is why the drag passes a name of its own.
    @Test("a multi-setting gesture uses the name it was given")
    func gestureNameOverridesTheDiff() {
        let model = IconViewModel()
        let undoManager = manager()

        beginGesture(model, undoManager, named: "Move Badge")
        for frame in 1...5 {
            edit(model, undoManager) {
                $0.badge.offsetX = Double(frame) * 0.01
                $0.badge.offsetY = Double(frame) * 0.02
            }
        }
        endGesture(model, undoManager)

        #expect(undoManager.undoActionName == "Move Badge")
        #expect(undoTrace(model, undoManager, \.badge.offsetX) == [0])
    }

    @Test("two gestures are two undo steps")
    func separateGesturesDoNotMerge() {
        let model = IconViewModel()
        let undoManager = manager()
        model.iconSettings.badge.scale = 1.0

        beginGesture(model, undoManager)
        edit(model, undoManager) { $0.badge.scale = 1.5 }
        endGesture(model, undoManager)

        beginGesture(model, undoManager)
        edit(model, undoManager) { $0.badge.scale = 2.0 }
        endGesture(model, undoManager)

        #expect(undoTrace(model, undoManager, \.badge.scale) == [1.5, 1.0],
                "the two drags merged into one")
    }

    /// A `DragGesture.onChanged` fires every frame and calls `begin` every frame rather
    /// than tracking its own "have I started" flag, so a repeat must not restart the
    /// group — that would move the undo target forward to the current frame.
    @Test("beginning a gesture twice does not restart the group")
    func beginIsIdempotent() {
        let model = IconViewModel()
        let undoManager = manager()
        model.iconSettings.badge.scale = 1.0

        beginGesture(model, undoManager)
        edit(model, undoManager) { $0.badge.scale = 1.2 }
        model.beginContinuousEdit(named: nil)   // the next frame calls it again
        edit(model, undoManager) { $0.badge.scale = 1.4 }
        endGesture(model, undoManager)

        #expect(undoTrace(model, undoManager, \.badge.scale) == [1.0])
    }

    // MARK: - Coalescing: the same-key time window

    /// The fallback for continuous controls that report no boundaries — in practice the
    /// colour panel, whose drag SwiftUI gives no callback for at all.
    @Test("rapid changes to one setting coalesce without a declared gesture")
    func sameKeyBurstCoalesces() {
        let model = IconViewModel()
        let undoManager = manager()
        let start = Date(timeIntervalSince1970: 1_000)
        model.iconSettings.icon.background.color = .blue

        edit(model, undoManager, now: start) { $0.icon.background.color = .red }
        edit(model, undoManager, now: start.addingTimeInterval(0.05)) { $0.icon.background.color = .orange }
        edit(model, undoManager, now: start.addingTimeInterval(0.10)) { $0.icon.background.color = .yellow }

        #expect(undoTrace(model, undoManager, \.icon.background.color) == [.blue],
                "the burst registered more than one undo")
    }

    @Test("a gap longer than the window starts a new undo step")
    func aPauseEndsTheBurst() {
        let model = IconViewModel()
        let undoManager = manager()
        let start = Date(timeIntervalSince1970: 1_000)
        model.iconSettings.icon.background.color = .blue

        edit(model, undoManager, now: start) { $0.icon.background.color = .red }
        let afterWindow = start.addingTimeInterval(IconViewModel.burstWindow + 0.1)
        edit(model, undoManager, now: afterWindow) { $0.icon.background.color = .green }

        #expect(undoTrace(model, undoManager, \.icon.background.color) == [.red, .blue])
    }

    @Test("changes to different settings never coalesce, however fast")
    func differentKeysDoNotCoalesce() {
        let model = IconViewModel()
        let undoManager = manager()
        let start = Date(timeIntervalSince1970: 1_000)
        model.iconSettings.badge.scale = 1.0

        edit(model, undoManager, now: start) { $0.icon.background.color = .red }
        edit(model, undoManager, now: start.addingTimeInterval(0.01)) { $0.badge.scale = 1.5 }

        #expect(undoTrace(model, undoManager, \.badge.scale) == [1.0])
    }

    /// A bulk change has no single identity, so two unrelated ones — two imports, or a
    /// reset then an import — would share the key and wrongly collapse into one undo step.
    @Test("bulk changes never coalesce on the time window")
    func bulkChangesDoNotCoalesce() {
        let model = IconViewModel()
        let undoManager = manager()
        let start = Date(timeIntervalSince1970: 1_000)
        model.iconSettings.icon.foreground.symbolName = "start"

        edit(model, undoManager, now: start) {
            $0.icon.foreground.symbolName = "one"
            $0.badge.scale = 1.5
        }
        edit(model, undoManager, now: start.addingTimeInterval(0.01)) {
            $0.icon.foreground.symbolName = "two"
            $0.badge.scale = 2.0
        }

        #expect(undoTrace(model, undoManager, \.icon.foreground.symbolName) == ["one", "start"],
                "the two bulk edits merged")
    }

    /// Ending a gesture has to clear the window too, or a click straight after a drag on
    /// the same setting would be absorbed into the drag's undo step.
    @Test("a change just after a gesture is its own undo step")
    func endingAGestureClearsTheWindow() {
        let model = IconViewModel()
        let undoManager = manager()
        let start = Date(timeIntervalSince1970: 1_000)
        model.iconSettings.badge.scale = 1.0

        beginGesture(model, undoManager)
        edit(model, undoManager, now: start) { $0.badge.scale = 1.5 }
        endGesture(model, undoManager)
        edit(model, undoManager, now: start.addingTimeInterval(0.01)) { $0.badge.scale = 1.6 }

        #expect(undoTrace(model, undoManager, \.badge.scale) == [1.5, 1.0])
    }

    // MARK: - The environment scope

    /// `ContentView` hands this to the inspector sections, which have no view model.
    @Test("the environment scope drives the same coalescing")
    func continuousEditScopeIsWiredToTheModel() {
        let model = IconViewModel()
        let undoManager = manager()
        let scope = model.continuousEditScope
        model.iconSettings.badge.scale = 1.0

        undoManager.beginUndoGrouping()
        scope.sliderEditing(true)
        edit(model, undoManager) { $0.badge.scale = 1.5 }
        edit(model, undoManager) { $0.badge.scale = 2.0 }
        scope.sliderEditing(false)
        undoManager.endUndoGrouping()

        #expect(undoTrace(model, undoManager, \.badge.scale) == [1.0])
    }

    // MARK: - What the observer reports back

    /// `ContentView` ends text editing on a non-nil, non-text-field change, so these
    /// returns decide when the symbol field loses focus. A frame that registers nothing
    /// must report `nil`, or every frame of a slider drag would yank focus repeatedly.
    ///
    /// Driven through the observer like everything else here — the return value is only
    /// meaningful in the same ordering the app produces.
    @Test("a real edit is reported, a coalesced frame is not")
    func onlyRegisteringChangesAreReported() {
        let model = IconViewModel()
        let undoManager = manager()
        let start = Date()

        undoManager.beginUndoGrouping()
        var before = model.iconSettings
        model.iconSettings.badge.scale = 1.5
        let first = model.settingsDidChange(from: before, undoManager: undoManager, now: start)
        #expect(first?.key == "badge.scale")

        // Same setting, inside the burst window: coalesced, so nothing is reported.
        before = model.iconSettings
        model.iconSettings.badge.scale = 1.6
        let coalesced = model.settingsDidChange(
            from: before, undoManager: undoManager, now: start.addingTimeInterval(0.1)
        )
        #expect(coalesced == nil)
        undoManager.endUndoGrouping()
    }

    @Test("a write with no diff is not reported")
    func aNonChangeIsNotReported() {
        let model = IconViewModel()
        let undoManager = manager()
        undoManager.beginUndoGrouping()
        let before = model.iconSettings
        #expect(model.settingsDidChange(from: before, undoManager: undoManager) == nil)
        undoManager.endUndoGrouping()
    }

    /// An undo's own write must not report a change: the user did not touch a control, so
    /// stealing focus out of the symbol field on ⌘Z would be wrong.
    @Test("the write an undo makes is not reported")
    func anUndosOwnWriteIsNotReported() {
        let model = IconViewModel()
        let undoManager = manager()
        edit(model, undoManager) { $0.badge.scale = 1.5 }

        let beforeUndo = model.iconSettings
        undoManager.undo()
        #expect(model.settingsDidChange(from: beforeUndo, undoManager: undoManager) == nil)
    }

    /// Installing an imported configuration rewrites every property; that is not a user edit.
    @Test("installing an imported configuration is not reported")
    func installingAConfigurationIsNotReported() {
        let model = IconViewModel()
        let undoManager = manager()
        model.isInstallingImportedConfiguration = true
        let before = model.iconSettings
        model.iconSettings.badge.scale = 1.5
        #expect(model.settingsDidChange(from: before, undoManager: undoManager) == nil)
        model.isInstallingImportedConfiguration = false
    }
}
