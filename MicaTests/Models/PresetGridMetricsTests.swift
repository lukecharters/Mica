// MicaTests/Models/PresetGridMetricsTests.swift
// The popover's width is computed from its column count rather than typed in, so the
// grid and the popover cannot disagree about how much room three tiles need.

import CoreGraphics
import Testing
@testable import Mica

@Suite("Preset grid metrics", .tags(.unit))
struct PresetGridMetricsTests {

    @Test("Fixed columns come out as asked", arguments: [1, 2, 3, 4])
    func fixedColumnCount(count: Int) {
        #expect(PresetGridMetrics.fixedColumns(count).count == count)
    }

    @Test("Width for N columns is N tiles, N−1 gaps and the padding either side", arguments: [1, 2, 3])
    func widthForColumns(count: Int) {
        let tile = PresetGridMetrics.thumbnailSize
        let gap = PresetGridMetrics.columnSpacing
        let padding = PresetGridMetrics.horizontalPadding
        let expected: CGFloat = CGFloat(count) * tile + CGFloat(count - 1) * gap + 2 * padding
        let actual = PresetGridMetrics.width(forColumns: count)
        #expect(actual == expected, "\(actual.bitPattern) vs \(expected.bitPattern)")
    }

    @Test("The padded width is the grid width plus the padding either side", arguments: [1, 3])
    func paddedWidthWrapsGridWidth(count: Int) {
        let expected: CGFloat = PresetGridMetrics.gridWidth(forColumns: count) + 2 * PresetGridMetrics.horizontalPadding
        let actual = PresetGridMetrics.width(forColumns: count)
        #expect(actual == expected)
    }

    @Test("One more column adds exactly a tile and a gap")
    func widthGrowsByTileAndGap() {
        let tile = PresetGridMetrics.thumbnailSize
        let gap = PresetGridMetrics.columnSpacing
        #expect(PresetGridMetrics.width(forColumns: 3) - PresetGridMetrics.width(forColumns: 2) == tile + gap)
    }
}
