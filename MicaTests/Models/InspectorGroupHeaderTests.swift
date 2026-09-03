// MicaTests/Models/InspectorGroupHeaderTests.swift
// `InspectorGroupHeader.sublayer(for:in:isSystem:advancedControlsEnabled:)` decides
// whether the header names the layer being edited beside the group. It has to
// agree with the sidebar's child rows, which is the invariant pinned here.

import Testing
@testable import Mica

@Suite("Inspector group header", .tags(.unit))
struct InspectorGroupHeaderTests {

    /// The rule the header exists for: with the advanced controls on, the pane is
    /// the active layer's, and the header says which one.
    @Test("Advanced Mica mode names the active layer", arguments: IconLayerGroup.allCases)
    func advancedMicaNamesTheLayer(group: IconLayerGroup) {
        for tab in LayerTab.availableTabs(for: group, isSystem: false) {
            #expect(InspectorGroupHeader.sublayer(
                for: tab, in: group, isSystem: false, advancedControlsEnabled: true
            ) == tab)
        }
    }

    /// The simple pane edits the group as one thing, so a layer name over it would
    /// describe a selection the panel is not honouring.
    @Test("Advanced controls off names no layer", arguments: IconLayerGroup.allCases, LayerTab.allCases)
    func simplePaneNamesNoLayer(group: IconLayerGroup, tab: LayerTab) {
        #expect(InspectorGroupHeader.sublayer(
            for: tab, in: group, isSystem: false, advancedControlsEnabled: false
        ) == nil)
    }

    /// System mode has no layers at all; the still-stored tab must not leak into the title.
    @Test("System mode names no layer", arguments: IconLayerGroup.allCases, LayerTab.allCases)
    func systemModeNamesNoLayer(group: IconLayerGroup, tab: LayerTab) {
        #expect(InspectorGroupHeader.sublayer(
            for: tab, in: group, isSystem: true, advancedControlsEnabled: true
        ) == nil)
    }

    /// The icon has no Layout layer, so a stray `.layout` must never be named over it.
    @Test("A layer the group does not offer is never named")
    func unofferedLayerIsNeverNamed() {
        #expect(InspectorGroupHeader.sublayer(
            for: .layout, in: .icon, isSystem: false, advancedControlsEnabled: true
        ) == nil)
    }

    /// The whole contract in one line: the header names a layer exactly when the
    /// sidebar draws a row for it, across every combination of inputs.
    @Test("The header names a layer exactly when the sidebar has a row for it",
          arguments: IconLayerGroup.allCases, LayerTab.allCases)
    func mirrorsSidebarRows(group: IconLayerGroup, tab: LayerTab) {
        for isSystem in [false, true] {
            for advanced in [false, true] {
                let rows = LayerTab.sidebarRows(
                    for: group, isSystem: isSystem, advancedControlsEnabled: advanced
                )
                let named = InspectorGroupHeader.sublayer(
                    for: tab, in: group, isSystem: isSystem, advancedControlsEnabled: advanced
                )
                #expect((named != nil) == rows.contains(tab))
            }
        }
    }
}
