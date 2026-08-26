// MDMPortalSizePresetTests.swift
// The preview-size menu's MDM portal presets, and the vendor sections they are
// drawn in.
//
// `grouped` is a *view* of `all` rather than a second list, so what these tests
// watch is the arrangement holding: a vendor mistyped in one row would show up as
// a second heading spelled almost the same, which reads on screen as a section
// that has lost most of its rows rather than as an error.

import Testing
import Foundation
@testable import Mica

@Suite("MDM portal size presets")
struct MDMPortalSizePresetTests {

    @Test("Every preset lands in exactly one group, and no preset is lost")
    func groupingIsAPartition() {
        let grouped = MDMPortalSizePreset.grouped
        let regrouped = grouped.flatMap(\.presets)

        #expect(regrouped.count == MDMPortalSizePreset.all.count)
        #expect(regrouped.map(\.id) == MDMPortalSizePreset.all.map(\.id))
    }

    @Test("A vendor gets one section, not one per run of rows")
    func vendorsAreUnique() {
        let vendors = MDMPortalSizePreset.grouped.map(\.vendor)
        #expect(Set(vendors).count == vendors.count)
    }

    @Test("Vendors keep the order they first appear in `all`")
    func vendorOrderFollowsTheList() {
        var expected: [String] = []
        for preset in MDMPortalSizePreset.all where !expected.contains(preset.vendor) {
            expected.append(preset.vendor)
        }

        #expect(MDMPortalSizePreset.grouped.map(\.vendor) == expected)
    }

    /// The section header carries the vendor, so a row repeating it would read as
    /// "Fleet ▸ Fleet Desktop — Software View".
    @Test("No row repeats its own section's heading")
    func rowsDoNotRepeatTheVendor() {
        for group in MDMPortalSizePreset.grouped {
            for preset in group.presets {
                #expect(
                    !preset.name.hasPrefix(group.vendor),
                    Comment(rawValue: "\(group.vendor) ▸ \(preset.name)")
                )
            }
        }
    }

    /// Ids are what `ForEach` diffs on, and the names alone are not unique — Jamf
    /// and Fleet both ship an "… - Software View" style row.
    @Test("Preset ids are unique")
    func idsAreUnique() {
        let ids = MDMPortalSizePreset.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every preset names a positive point size")
    func pointSizesArePositive() {
        for preset in MDMPortalSizePreset.all {
            #expect(preset.pointSize > 0, Comment(rawValue: preset.id))
        }
    }
}
