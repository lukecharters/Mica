// MicaTests/Models/LayerSidebarRowTests.swift
// `LayerSidebarRow` is the `List` selection tag for the two shapes of row in the
// LayerSidebar — a group, or one layer within it — plus the rule deciding which
// row is highlighted for a given group + active layer.
//
// That rule is what makes clicking a group row land on a layer, and it is
// deliberately a pure function rather than a computed property inside the view:
// the failure it guards against is a sidebar with *no* row highlighted, or a group
// row highlighted while the inspector shows a layer's controls. Neither is a value
// any view test can read back.

import Testing
@testable import Mica

@Suite("Layer sidebar rows", .tags(.unit))
struct LayerSidebarRowTests {

    /// Every row belongs to a group, whichever shape it is — the group is what the
    /// context menu and the inspector header are about.
    @Test("Both shapes report their group", arguments: IconLayerGroup.allCases)
    func groupAccessor(group: IconLayerGroup) {
        #expect(LayerSidebarRow.group(group).group == group)
        #expect(LayerSidebarRow.layer(group, .foreground).group == group)
    }

    /// The `tab` accessor is how `LayerSidebar`'s setter decides whether a click
    /// moved the layer as well as the group. A group row must report nil, or a
    /// parent click would write a layer the user never picked.
    @Test("Only a layer row reports a layer")
    func tabAccessor() {
        #expect(LayerSidebarRow.group(.icon).tab == nil)
        #expect(LayerSidebarRow.layer(.badge, .layout).tab == .layout)
    }

    /// Two rows in different groups are different rows even when they name the same
    /// layer — `List` selection is by tag, so an `Equatable`/`Hashable` collision
    /// here would highlight the icon's Foreground when the badge's was clicked.
    @Test("Rows are distinct across groups and layers")
    func rowsAreDistinct() {
        var rows: Set<LayerSidebarRow> = []
        for group in IconLayerGroup.allCases {
            rows.insert(.group(group))
            for tab in LayerTab.allCases {
                rows.insert(.layer(group, tab))
            }
        }
        #expect(rows.count == IconLayerGroup.allCases.count * (1 + LayerTab.allCases.count))
    }

    // MARK: - Which row is highlighted

    /// The parent-click behaviour. `LayerSidebar`'s setter writes only the group, so
    /// this is the whole of what sends the highlight down to a layer.
    @Test("A group with layer rows highlights its active layer")
    func selected_resolvesToTheActiveLayer() {
        let rows = LayerTab.sidebarRows(for: .icon, isSystem: false, advancedControlsEnabled: true)
        #expect(
            LayerSidebarRow.selected(group: .icon, activeTab: .background, rows: rows)
                == .layer(.icon, .background)
        )
    }

    /// The group row is the answer exactly where there are no children: System mode,
    /// and Mica mode with the advanced controls off.
    @Test(
        "A group with no layer rows highlights itself",
        arguments: IconLayerGroup.allCases, [(true, true), (false, false), (true, false)]
    )
    func selected_fallsBackToTheGroup(group: IconLayerGroup, modes: (isSystem: Bool, advanced: Bool)) {
        let rows = LayerTab.sidebarRows(
            for: group,
            isSystem: modes.isSystem,
            advancedControlsEnabled: modes.advanced
        )
        #expect(rows.isEmpty)
        #expect(
            LayerSidebarRow.selected(group: group, activeTab: .foreground, rows: rows)
                == .group(group)
        )
    }

    /// The icon has no Layout row, so an active layer of `.layout` — which only the
    /// badge can reach — must not produce a highlight for a row that isn't drawn.
    /// Falling back to the group row keeps exactly one row selected.
    @Test("An active layer with no row falls back to the group")
    func selected_fallsBackWhenTheLayerHasNoRow() {
        let rows = LayerTab.sidebarRows(for: .icon, isSystem: false, advancedControlsEnabled: true)
        #expect(rows.contains(.layout) == false)
        #expect(
            LayerSidebarRow.selected(group: .icon, activeTab: .layout, rows: rows)
                == .group(.icon)
        )
    }

    /// A row is always highlighted, whatever the group, layer and mode — the sidebar
    /// never deselects, and the inspector always has a group to show.
    @Test(
        "Some row is always highlighted",
        arguments: IconLayerGroup.allCases, LayerTab.allCases
    )
    func selected_isTotal(group: IconLayerGroup, activeTab: LayerTab) {
        for isSystem in [false, true] {
            for advanced in [false, true] {
                let rows = LayerTab.sidebarRows(
                    for: group,
                    isSystem: isSystem,
                    advancedControlsEnabled: advanced
                )
                let selected = LayerSidebarRow.selected(group: group, activeTab: activeTab, rows: rows)
                #expect(selected.group == group)
                // Whatever it resolved to has to be a row the sidebar actually draws.
                if let tab = selected.tab {
                    #expect(rows.contains(tab))
                }
            }
        }
    }
}
