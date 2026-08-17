// LayerTabTests.swift
// Tests for LayerTab: which layers each group offers in Mica vs System mode, the
// per-group default, which rows the sidebar draws from that, and raw-value
// stability (raw values are the enum's identity for `List` selection tags).

import AppKit
import Testing
@testable import Mica

@Suite(.tags(.unit))
struct LayerTabTests {

    // MARK: - availableTabs

    @Test("Icon offers Foreground + Background in Mica mode")
    func availableTabs_iconMica() {
        #expect(LayerTab.availableTabs(for: .icon, isSystem: false) == [.foreground, .background])
    }

    @Test("Badge offers Layout + Foreground + Background in Mica mode")
    func availableTabs_badgeMica() {
        #expect(LayerTab.availableTabs(for: .badge, isSystem: false) == [.layout, .foreground, .background])
    }

    @Test("System mode offers no tabs for either group", arguments: IconLayerGroup.allCases)
    func availableTabs_systemIsEmpty(group: IconLayerGroup) {
        #expect(LayerTab.availableTabs(for: group, isSystem: true).isEmpty)
    }

    @Test("Layout is badge-only")
    func availableTabs_layoutIsBadgeOnly() {
        #expect(LayerTab.availableTabs(for: .icon, isSystem: false).contains(.layout) == false)
        #expect(LayerTab.availableTabs(for: .badge, isSystem: false).contains(.layout) == true)
    }

    // MARK: - defaultTab

    @Test("Default tabs are Foreground for the icon and Layout for the badge")
    func defaultTab_perGroup() {
        #expect(LayerTab.defaultTab(for: .icon) == .foreground)
        #expect(LayerTab.defaultTab(for: .badge) == .layout)
    }

    @Test("Each group's default tab is one of its available tabs", arguments: IconLayerGroup.allCases)
    func defaultTab_isAvailable(group: IconLayerGroup) {
        let tabs = LayerTab.availableTabs(for: group, isSystem: false)
        #expect(tabs.contains(LayerTab.defaultTab(for: group)))
    }

    // MARK: - sidebarRows

    /// The gate that matters: with the advanced controls off the inspector edits a
    /// group as one un-tabbed thing, so child rows would offer a selection the
    /// panel cannot honour.
    @Test(
        "No child rows with the advanced controls off",
        arguments: IconLayerGroup.allCases, [false, true]
    )
    func sidebarRows_needAdvancedControls(group: IconLayerGroup, isSystem: Bool) {
        #expect(LayerTab.sidebarRows(
            for: group,
            isSystem: isSystem,
            advancedControlsEnabled: false
        ).isEmpty)
    }

    @Test("No child rows in System mode", arguments: IconLayerGroup.allCases)
    func sidebarRows_noneInSystemMode(group: IconLayerGroup) {
        #expect(LayerTab.sidebarRows(
            for: group,
            isSystem: true,
            advancedControlsEnabled: true
        ).isEmpty)
    }

    /// Where rows do appear they are exactly the available layers, in order — the
    /// sidebar must not invent a fourth row or reorder Layout above the group.
    @Test("Child rows are the group's available layers", arguments: IconLayerGroup.allCases)
    func sidebarRows_matchAvailableTabs(group: IconLayerGroup) {
        #expect(
            LayerTab.sidebarRows(for: group, isSystem: false, advancedControlsEnabled: true)
                == LayerTab.availableTabs(for: group, isSystem: false)
        )
    }

    /// Pins the shape a reader of the sidebar sees: two rows under Icon, three
    /// under Badge, Layout first.
    @Test("The badge has one more row than the icon, and it is Layout")
    func sidebarRows_badgeShape() {
        let icon = LayerTab.sidebarRows(for: .icon, isSystem: false, advancedControlsEnabled: true)
        let badge = LayerTab.sidebarRows(for: .badge, isSystem: false, advancedControlsEnabled: true)
        #expect(icon == [.foreground, .background])
        #expect(badge == [.layout, .foreground, .background])
    }

    // MARK: - Row presentation

    /// A misspelled SF Symbol name draws *nothing* — no error, no placeholder — so
    /// the row would silently lose its glyph and only a screenshot would catch it.
    /// `NSImage` returning nil is the one check that can.
    @Test("Every layer's glyph is a real SF Symbol", arguments: LayerTab.allCases)
    func systemImage_resolves(tab: LayerTab) {
        #expect(NSImage(systemSymbolName: tab.systemImage, accessibilityDescription: nil) != nil)
    }

    /// Three rows sitting on top of each other with one picture between them would
    /// make the glyph decorative.
    @Test("No two layers share a glyph")
    func systemImage_areDistinct() {
        let names = LayerTab.allCases.map(\.systemImage)
        #expect(Set(names).count == names.count)
    }

    /// Layout is the badge's position and size, not a layer, so it carries no eye —
    /// and `LayerSidebar` hands it a nil visibility binding on the strength of this.
    @Test("Layout is the one row that cannot be hidden")
    func isHideable_excludesLayout() {
        #expect(LayerTab.layout.isHideable == false)
        #expect(LayerTab.foreground.isHideable)
        #expect(LayerTab.background.isHideable)
    }

    // MARK: - Identity

    @Test("Raw values and ids are stable")
    func rawValuesAreStable() {
        #expect(LayerTab.layout.rawValue == "layout")
        #expect(LayerTab.foreground.rawValue == "foreground")
        #expect(LayerTab.background.rawValue == "background")
        #expect(LayerTab.allCases.map(\.id) == ["layout", "foreground", "background"])
    }

    @Test("Labels are title-cased for display")
    func labels() {
        #expect(LayerTab.layout.label == "Layout")
        #expect(LayerTab.foreground.label == "Foreground")
        #expect(LayerTab.background.label == "Background")
    }
}
