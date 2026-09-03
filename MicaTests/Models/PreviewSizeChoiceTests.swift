// MicaTests/Models/PreviewSizeChoiceTests.swift
//
// The rule that turns the preview's one stored point size back into a picker row.
// Several rows share a size, so which one is checked is a decision, and this is
// where it is pinned. Nothing here names a portal or a size from the curated list:
// the list is data, and the tests read it rather than restate it.

import CoreGraphics
import Testing
@testable import Mica

@Suite("Preview size picker rows")
struct PreviewSizeChoiceTests {

    @Test("Nil is Match Export Size, and Match Export Size stores nil")
    func nilIsMatchExport() {
        #expect(PreviewSizeChoice(pointSize: nil) == .matchExport)
        #expect(PreviewSizeChoice.matchExport.pointSize == nil)
    }

    @Test("Every standard size maps to its own row and back")
    func standardSizesRoundTrip() {
        for size in PreviewSizeChoice.standardSizes {
            let choice = PreviewSizeChoice(pointSize: CGFloat(size))
            #expect(choice == .standard(size))
            #expect(choice.pointSize == CGFloat(size))
        }
    }

    @Test("Every portal row stores its own size")
    func portalRowsStoreTheirSize() {
        for preset in MDMPortalSizePreset.all {
            #expect(PreviewSizeChoice.portal(preset.id).pointSize == CGFloat(preset.pointSize))
        }
    }

    @Test("A size shared by a standard row and a portal checks the standard row")
    func sharedSizePrefersTheStandardRow() {
        let shared = MDMPortalSizePreset.all.filter {
            PreviewSizeChoice.standardSizes.contains($0.pointSize)
        }
        // If the curated list ever stops overlapping the standard sizes there is
        // nothing to decide; say so rather than pass on an empty loop.
        guard !shared.isEmpty else {
            Issue.record("no portal shares a standard size, so the preference cannot be exercised")
            return
        }
        for preset in shared {
            #expect(PreviewSizeChoice(pointSize: CGFloat(preset.pointSize)) == .standard(preset.pointSize))
        }
    }

    @Test("A size only portals name checks the first portal that names it")
    func portalOnlySizeChecksTheFirstPortal() {
        let portalOnly = MDMPortalSizePreset.all.filter {
            !PreviewSizeChoice.standardSizes.contains($0.pointSize)
        }
        guard !portalOnly.isEmpty else {
            Issue.record("every portal size is also a standard size, so the rule cannot be exercised")
            return
        }
        for preset in portalOnly {
            let first = MDMPortalSizePreset.all.first { $0.pointSize == preset.pointSize }
            let choice = PreviewSizeChoice(pointSize: CGFloat(preset.pointSize))
            #expect(choice == first.map { .portal($0.id) })
            #expect(choice.pointSize == CGFloat(preset.pointSize))
        }
    }

    @Test("An unknown portal id stores nothing rather than a guess")
    func unknownPortalStoresNil() {
        #expect(PreviewSizeChoice.portal("no such portal").pointSize == nil)
    }
}
