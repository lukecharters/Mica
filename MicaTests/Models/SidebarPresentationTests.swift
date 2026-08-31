// MicaTests/Models/SidebarPresentationTests.swift
// The sidebar column shows either the layer list or the preset library, and
// `SidebarPresentation` is that mode plus whether the column is on screen at all.
//
// What is worth testing here is not the enum — it is the ⌃⌘P rule, which reads and
// writes *two* pieces of state and is deliberately asymmetric: showing the presets
// reveals the column, hiding them does not hide it. Both halves fail silently in a
// view. Setting a mode on a hidden column reports success while nothing appears; and
// hiding the whole sidebar from "Hide Presets" throws away the layer list as a side
// effect of a command that never mentions it. Neither is a value a view test can read
// back, which is why the rule is a pure function — the same reason
// `LayerSidebarRow.selected` is one.
//
// The interaction itself is new: while the preset library was a pane in the detail
// column, ⌃⌘P and ⌃⌘S were independent of each other.

import Testing
@testable import Mica

@Suite("Sidebar presentation", .tags(.unit))
struct SidebarPresentationTests {

    // MARK: - Reading

    /// Presets mode alone is not enough — the column has to be on screen.
    ///
    /// This is the assertion that stops ⌃⌘P reporting success against a hidden
    /// sidebar, which is exactly what reading `mode` on its own would do.
    @Test("Presets show only when the column is visible too")
    func showsPresetsNeedsBothHalves() {
        #expect(SidebarPresentation(mode: .presets, isColumnVisible: true).showsPresets)
        #expect(!SidebarPresentation(mode: .presets, isColumnVisible: false).showsPresets)
        #expect(!SidebarPresentation(mode: .layers, isColumnVisible: true).showsPresets)
        #expect(!SidebarPresentation(mode: .layers, isColumnVisible: false).showsPresets)
    }

    // MARK: - Writing

    /// Showing reveals the column, whatever it was doing before.
    @Test(
        "Showing presets reveals the column",
        arguments: SidebarMode.allCases, [true, false]
    )
    func showingRevealsTheColumn(mode: SidebarMode, visible: Bool) {
        let next = SidebarPresentation(mode: mode, isColumnVisible: visible)
            .settingPresets(true)

        #expect(next.mode == .presets)
        #expect(next.isColumnVisible)
        #expect(next.showsPresets)
    }

    /// Hiding goes back to Layers and leaves ⌃⌘S's state exactly as it was.
    ///
    /// **The `isColumnVisible` half is the point.** "Hide Presets" hiding the whole
    /// sidebar would be a command changing something it does not name, and it would
    /// read as working — the presets do stop showing.
    @Test(
        "Hiding presets returns to layers without touching the column",
        arguments: SidebarMode.allCases, [true, false]
    )
    func hidingLeavesTheColumnAlone(mode: SidebarMode, visible: Bool) {
        let before = SidebarPresentation(mode: mode, isColumnVisible: visible)
        let next = before.settingPresets(false)

        #expect(next.mode == .layers)
        #expect(next.isColumnVisible == before.isColumnVisible)
        #expect(!next.showsPresets)
    }

    /// Setting the same value twice is the same as setting it once.
    ///
    /// The toolbar control is a `Toggle` and the menu item flips the same binding, so
    /// a repeat is reachable by ordinary use rather than only by a test.
    @Test("Setting the same value twice is idempotent", arguments: [true, false])
    func settingIsIdempotent(showing: Bool) {
        let once = SidebarPresentation(mode: .layers, isColumnVisible: true)
            .settingPresets(showing)

        #expect(once.settingPresets(showing) == once)
    }

    /// ⌃⌘P twice from a hidden sidebar leaves the sidebar **shown**, on Layers.
    ///
    /// **This is the assertion that was wrong when it was first written**, and the
    /// wrongness was a belief about the feature rather than a typo: it claimed the
    /// round trip restored the column. It does not, and it should not. The first press
    /// reveals the column — that is the whole point of the reveal — and the second
    /// press is documented as leaving the column alone, so what comes back is a
    /// *visible* sidebar showing the layer list. ⌃⌘P is not a sidebar toggle, and
    /// making the second press re-hide the column is what would turn it into one.
    ///
    /// So the round trip is idempotent in the mode and monotonic in the column.
    @Test("⌃⌘P twice leaves the column shown, on layers", arguments: [true, false])
    func roundTripLandsOnAVisibleLayerList(startVisible: Bool) {
        let after = SidebarPresentation(mode: .presets, isColumnVisible: startVisible)
            .settingPresets(true)
            .settingPresets(false)

        #expect(after.mode == .layers)
        #expect(after.isColumnVisible)
        #expect(!after.showsPresets)
    }

    // MARK: - The mode itself

    /// Two modes, each with a segment title. A blank one would render an unlabelled
    /// segment in the selector bar rather than fail anything.
    @Test("Every mode has a non-empty label", arguments: SidebarMode.allCases)
    func everyModeIsLabelled(mode: SidebarMode) {
        #expect(!mode.label.isEmpty)
    }
}
