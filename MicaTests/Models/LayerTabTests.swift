// LayerTabTests.swift
// Tests for LayerTab: which tabs each group offers in Mica vs System mode, the
// per-group default tab, and raw-value stability (raw values are the enum's
// identity for Picker tags).

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
