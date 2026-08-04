// MicaTests/Models/IconLayerGroupTests.swift
// `IconLayerGroup.label` is the only name the user ever sees for a group: the
// sidebar row, the toolbar mode menus' tooltips, and `InspectorGroupHeader`.
// These pin what that header needs to do its job.

import Testing
@testable import Mica

@Suite("Icon layer groups", .tags(.unit))
struct IconLayerGroupTests {

    @Test("Every group has a name to show", arguments: IconLayerGroup.allCases)
    func everyGroupIsNamed(group: IconLayerGroup) {
        #expect(!group.label.isEmpty)
    }

    /// The header exists to say *which* group is being edited, so two groups sharing
    /// a label would make it decorative. Guards a third group added with a copied name.
    @Test("No two groups share a label")
    func labelsAreDistinct() {
        let labels = IconLayerGroup.allCases.map(\.label)
        #expect(Set(labels).count == labels.count)
    }

    /// Raw values are the enum's identity for `List` selection tags and the
    /// `InspectorControls` scroll-reset `.id`, so they are not free to rename.
    @Test("Raw values are stable")
    func rawValuesAreStable() {
        #expect(IconLayerGroup.icon.rawValue == "icon")
        #expect(IconLayerGroup.badge.rawValue == "badge")
        #expect(IconLayerGroup.allCases == [.icon, .badge])
    }
}
