// PaneWidthPreferencesTests.swift
//
// The side panes' widths — the inspector's, which Mica persists, and the
// sidebar's, which it deliberately does not. C5 of
// the Mac-conventions plan.
//
// The write-back itself is a `GeometryReader` inside a split-view column and no
// test can reach it — which is exactly why the *decisions* are a pure type. Same
// shape as `BadgeNudgeTests` and `SymbolPickerKeyTests`: pin what a width report
// means, and leave the wiring to the on-screen pass.
//
// The store-touching tests use their own `UserDefaults` suite rather than
// `.standard`, so a test run cannot resize the developer's own window.
import Foundation
import Testing
@testable import Mica

@Suite("Pane width preferences")
struct PaneWidthPreferencesTests {

    // MARK: - What a width report means

    @Test("A real resize is persisted, clamped into the pane's range")
    func aResizeIsPersisted() {
        let range: ClosedRange<Double> = 220...360
        #expect(PaneWidthPreferences.widthToPersist(observed: 300, stored: 280, range: range) == 300)
        #expect(PaneWidthPreferences.widthToPersist(observed: 500, stored: 280, range: range) == 360)
        #expect(PaneWidthPreferences.widthToPersist(observed: 100, stored: 280, range: range) == 220)
    }

    /// The infamous failure of naive width persistence: hide the pane, quit, and it
    /// comes back zero-wide forever. A pane reports zero while it is torn down and
    /// on the first frame of a hide animation, so this is a report that arrives in
    /// normal use rather than a defensive nicety.
    @Test("A zero or non-finite width is never persisted")
    func aVanishedPaneIsNotPersisted() {
        let range: ClosedRange<Double> = 220...360
        #expect(PaneWidthPreferences.widthToPersist(observed: 0, stored: 280, range: range) == nil)
        #expect(PaneWidthPreferences.widthToPersist(observed: -40, stored: 280, range: range) == nil)
        #expect(PaneWidthPreferences.widthToPersist(observed: .nan, stored: 280, range: range) == nil)
        #expect(PaneWidthPreferences.widthToPersist(observed: .infinity, stored: 280, range: range) == nil)
    }

    @Test("A width that has not moved is not persisted")
    func anUnchangedWidthIsNotPersisted() {
        let range: ClosedRange<Double> = 220...360
        #expect(PaneWidthPreferences.widthToPersist(observed: 280, stored: 280, range: range) == nil)
        #expect(PaneWidthPreferences.widthToPersist(observed: 280.2, stored: 280, range: range) == nil)
        #expect(PaneWidthPreferences.widthToPersist(observed: 280.6, stored: 280, range: range) == 280.6)
    }

    /// A clamped observation still counts as unchanged when it lands on the value
    /// already stored — otherwise a pane pinned at its maximum would write the same
    /// number on every layout pass for as long as the user held the divider there.
    @Test("A clamped width equal to the stored one is not rewritten")
    func aClampedWidthAtTheStoredValueIsNotRewritten() {
        let range: ClosedRange<Double> = 220...360
        #expect(PaneWidthPreferences.widthToPersist(observed: 500, stored: 360, range: range) == nil)
    }

    // MARK: - What a pane opens at

    @Test("An absent preference opens at the pane's default")
    func anAbsentPreferenceUsesTheDefault() {
        // `UserDefaults.double(forKey:)` returns 0 for a key never written, so 0 is
        // what "absent" actually looks like at this boundary — not nil.
        #expect(PaneWidthPreferences.launchWidth(stored: 0, range: 220...360, fallback: 280) == 280)
        #expect(PaneWidthPreferences.launchWidth(stored: .nan, range: 220...360, fallback: 280) == 280)
    }

    /// Narrowing a pane's bounds in a later build must not strand a window outside
    /// them: a stored 400 opens at 360 rather than at a width the divider can never
    /// return to.
    @Test("A stored width outside the range opens clamped, not ignored")
    func anOutOfRangeStoredWidthIsClamped() {
        #expect(PaneWidthPreferences.launchWidth(stored: 400, range: 220...360, fallback: 280) == 360)
        #expect(PaneWidthPreferences.launchWidth(stored: 90, range: 220...360, fallback: 280) == 220)
    }

    @Test("A stored width inside the range opens at it")
    func anInRangeStoredWidthIsHonoured() {
        #expect(PaneWidthPreferences.launchWidth(stored: 305, range: 220...360, fallback: 280) == 305)
    }

    // MARK: - The two panes

    /// The inspector's key is the one that was already in the preference file, dead,
    /// before C5 wired it up — so an existing install keeps whatever width it never
    /// got to use rather than being handed a fresh default.
    @Test("The inspector's key is the one that was already there")
    func theInspectorKeyIsUnchanged() {
        #expect(PaneWidthPreferences.Pane.inspector.preferenceKey == "layout.inspectorWidth")
    }

    /// **The sidebar deliberately has no key**, because AppKit's `NSSplitView`
    /// autosave already persists that divider and restores it *ahead of* `ideal:` —
    /// measured on screen 2026-08-07, and written up in `PaneWidthPreferences`. A
    /// Mica key here would be a second mechanism that loses every argument with the
    /// first, and it would look like it worked right up until the user dragged the
    /// divider, which is the only moment it would matter.
    ///
    /// This is the test that stops the "missing" key being helpfully added back.
    @Test("The sidebar has no preference of its own — AppKit owns it")
    func theSidebarIsNotMicasToPersist() {
        #expect(PaneWidthPreferences.Pane.sidebar.preferenceKey == nil)
    }

    /// A keyless pane cannot be written, whatever it reports, and opens at its
    /// default every time. Both follow from `preferenceKey` alone, so neither can
    /// be half-true.
    @Test("A pane with no key is never written and always opens at its default")
    func aKeylessPaneIsInert() throws {
        let suite = "PaneWidthPreferencesTests.keyless"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.removePersistentDomain(forName: suite)

        #expect(PaneWidthPreferences.persist(observed: 340, for: .sidebar, defaults: defaults) == nil)
        #expect(PaneWidthPreferences.launchWidth(.sidebar, defaults: defaults) == 280)
        // Not even under the old key, which an existing install may still carry.
        #expect(defaults.object(forKey: "layout.sidebarWidth") == nil)
    }

    /// Hazard 2 of `PaneWidthPreferences`, as an invariant rather than a comment: a
    /// pane whose default sits outside its own range would be moved by the clamp at
    /// the first launch, and the "default" would be a width no window ever opened at.
    @Test("Every pane's default is inside its own range", arguments: PaneWidthPreferences.Pane.allCases)
    func everyDefaultIsInsideItsRange(pane: PaneWidthPreferences.Pane) {
        #expect(pane.range.contains(pane.defaultWidth))
        #expect(PaneWidthPreferences.launchWidth(
            stored: pane.defaultWidth,
            range: pane.range,
            fallback: pane.defaultWidth
        ) == pane.defaultWidth)
    }

    // MARK: - Against a store

    @Test("A pane with no preference opens at its default, then remembers a drag")
    func aDragSurvivesTheStore() throws {
        let defaults = try #require(UserDefaults(suiteName: "PaneWidthPreferencesTests.drag"))
        defer { defaults.removePersistentDomain(forName: "PaneWidthPreferencesTests.drag") }
        defaults.removePersistentDomain(forName: "PaneWidthPreferencesTests.drag")

        #expect(PaneWidthPreferences.launchWidth(.inspector, defaults: defaults) == 380)
        #expect(PaneWidthPreferences.persist(observed: 422, for: .inspector, defaults: defaults) == 422)
        #expect(PaneWidthPreferences.launchWidth(.inspector, defaults: defaults) == 422)
    }

    /// The feedback loop the whole design exists to prevent, run as arithmetic: what
    /// is written is what comes back as the column's `ideal:`, so re-persisting that
    /// same number must be a no-op. If the two ever disagreed by a constant inset,
    /// this is the test that would walk the pane down to its minimum.
    @Test("Persisting a width, then reporting it back, writes nothing")
    func theRoundTripIsStable() throws {
        let suite = "PaneWidthPreferencesTests.roundTrip"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.removePersistentDomain(forName: suite)

        for pane in PaneWidthPreferences.Pane.allCases where pane.preferenceKey != nil {
            let dragged = pane.range.lowerBound + 20
            #expect(PaneWidthPreferences.persist(observed: dragged, for: pane, defaults: defaults) == dragged)
            let reopened = PaneWidthPreferences.launchWidth(pane, defaults: defaults)
            #expect(reopened == dragged)
            #expect(PaneWidthPreferences.persist(observed: reopened, for: pane, defaults: defaults) == nil)
            #expect(PaneWidthPreferences.launchWidth(pane, defaults: defaults) == dragged)
        }
    }

    @Test("A vanished pane leaves the stored width alone")
    func aVanishedPaneLeavesTheStoreAlone() throws {
        let suite = "PaneWidthPreferencesTests.vanished"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.removePersistentDomain(forName: suite)

        PaneWidthPreferences.persist(observed: 440, for: .inspector, defaults: defaults)
        #expect(PaneWidthPreferences.persist(observed: 0, for: .inspector, defaults: defaults) == nil)
        #expect(PaneWidthPreferences.launchWidth(.inspector, defaults: defaults) == 440)
    }

    /// Resizing the sidebar must not move the inspector's stored width — which it
    /// could only do by sharing a key, and is worth pinning now that only one pane
    /// has one.
    @Test("Resizing the unpersisted pane leaves the persisted one alone")
    func thePanesAreIndependent() throws {
        let suite = "PaneWidthPreferencesTests.independent"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.removePersistentDomain(forName: suite)

        PaneWidthPreferences.persist(observed: 400, for: .inspector, defaults: defaults)
        PaneWidthPreferences.persist(observed: 350, for: .sidebar, defaults: defaults)
        #expect(PaneWidthPreferences.launchWidth(.inspector, defaults: defaults) == 400)
    }
}
