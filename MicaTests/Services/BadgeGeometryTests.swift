// BadgeGeometryTests.swift
// Unit tests for BadgeGeometry, the single source of truth for badge
// anchor/diameter math shared by the render pipeline and both previews,
// plus the clamp that keeps an oversized badge inside a fixed-size canvas.

import Testing
import AppKit
@testable import Mica

@Suite(.tags(.unit))
struct BadgeGeometryTests {

    private static func settings(
        position: BadgePosition,
        manualOffset: (x: Double, y: Double) = (0, 0),
        badgeScale: CGFloat = 1.0
    ) -> IconSettings {
        var s = IconSettings()
        s.showBadge = true
        s.badgePosition = position
        s.badgeManualOffsetX = manualOffset.x
        s.badgeManualOffsetY = manualOffset.y
        s.badgeScale = badgeScale
        return s
    }

    // MARK: - Offset

    /// Expected offset signs per position in SwiftUI top-origin coords
    /// (y grows downward: "top" positions have negative height).
    nonisolated static let positionSigns: [(position: BadgePosition, xSign: CGFloat, ySign: CGFloat)] = [
        (.topRight,    +1, -1),
        (.topLeft,     -1, -1),
        (.bottomRight, +1, +1),
        (.bottomLeft,  -1, +1)
    ]

    @Test("Offset anchors are ±76/208 of the enclosure on both axes", arguments: positionSigns)
    func offset_matchesAnchorRatios(_ arg: (position: BadgePosition, xSign: CGFloat, ySign: CGFloat)) {
        let enclosure: CGFloat = 208 // makes the expected value exactly 76
        let offset = BadgeGeometry.offset(for: Self.settings(position: arg.position), enclosureSize: enclosure)
        #expect(offset.width == arg.xSign * 76)
        // The Y anchor was 80/208 until the badge anchor was made symmetric in
        // 1b1a985 ("removed default badge offset").
        #expect(offset.height == arg.ySign * 76)
    }

    /// Inward offsets, which have plenty of room before the canvas clamp bites.
    /// The outward direction is deliberately tight — see `clamp_…` below.
    @Test("Manual offset adds linearly in enclosure fractions")
    func offset_appliesManualOffset() {
        let enclosure: CGFloat = 208
        let base = BadgeGeometry.offset(
            for: Self.settings(position: .bottomRight),
            enclosureSize: enclosure
        )
        let shifted = BadgeGeometry.offset(
            for: Self.settings(position: .bottomRight, manualOffset: (-0.25, -0.5)),
            enclosureSize: enclosure
        )
        #expect(shifted.width - base.width == -0.25 * enclosure)
        #expect(shifted.height - base.height == -0.5 * enclosure)
    }

    /// Holds even in the clamped regime: the clamp limit is itself proportional
    /// to the enclosure, so `offset` is homogeneous of degree 1 throughout.
    @Test("Offset scales linearly with enclosure size", arguments: [CGFloat(1.0), 2.0])
    func offset_scalesWithEnclosure(_ badgeScale: CGFloat) {
        let s = Self.settings(position: .topLeft, manualOffset: (0.1, 0.2), badgeScale: badgeScale)
        let small = BadgeGeometry.offset(for: s, enclosureSize: 104)
        let large = BadgeGeometry.offset(for: s, enclosureSize: 208)
        #expect(abs(large.width - small.width * 2) < 0.0001)
        #expect(abs(large.height - small.height * 2) < 0.0001)
    }

    // MARK: - Diameter

    @Test("Diameter is 80/208 of the enclosure, scaled by badgeScale")
    func diameter_matchesRatio() {
        #expect(BadgeGeometry.diameter(enclosureSize: 208, badgeScale: 1.0) == 80)
        #expect(BadgeGeometry.diameter(enclosureSize: 208, badgeScale: 1.5) == 120)
        #expect(BadgeGeometry.diameter(enclosureSize: 104, badgeScale: 1.0) == 40)
    }

    // MARK: - Canvas clamp

    /// Enclosures for a 256, 512 and 1024pt canvas.
    nonisolated static let enclosures: [CGFloat] = [206, 412, 824]
    nonisolated static let scales: [CGFloat] = [0.3, 0.5, 1.0, 1.19, 1.5, 2.0]
    nonisolated static let manualOffsets: [Double] = [-1.0, -0.5, 0, 0.5, 1.0]

    /// How far the badge's own edge sits from the icon center, shadow included.
    private static func extent(enclosureSize: CGFloat, badgeScale: CGFloat) -> CGFloat {
        BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: badgeScale) / 2
            + enclosureSize * BadgeGeometry.shadowBufferRatio
    }

    /// The invariant the whole change exists for: whatever the position, size or
    /// manual offset, the badge and its shadow buffer stay inside the canvas. If
    /// this fails, an export would clip the badge (the canvas no longer grows to
    /// rescue it).
    @Test("The badge never leaves the canvas, at any position, size or offset",
          arguments: positionSigns.map(\.position))
    func clamp_badgeStaysInsideTheCanvas(_ position: BadgePosition) {
        for enclosure in Self.enclosures {
            let halfCanvas = enclosure * BadgeGeometry.enclosureToCanvasRatio / 2
            for scale in Self.scales {
                let reach = Self.extent(enclosureSize: enclosure, badgeScale: scale)
                for mx in Self.manualOffsets {
                    for my in Self.manualOffsets {
                        let s = Self.settings(position: position, manualOffset: (mx, my), badgeScale: scale)
                        let offset = BadgeGeometry.offset(for: s, enclosureSize: enclosure)
                        let context = "\(position) enclosure=\(enclosure) scale=\(scale) manual=(\(mx),\(my))"
                        #expect(abs(offset.width) + reach <= halfCanvas + 0.0001,
                                "Badge escapes horizontally by \(abs(offset.width) + reach - halfCanvas)pt — \(context)")
                        #expect(abs(offset.height) + reach <= halfCanvas + 0.0001,
                                "Badge escapes vertically by \(abs(offset.height) + reach - halfCanvas)pt — \(context)")
                    }
                }
            }
        }
    }

    /// The other half of the contract: the clamp must not disturb a badge that
    /// already fits. At the default size the badge stays exactly where native
    /// macOS puts it, so existing icons re-export unchanged.
    @Test("A badge that fits is not moved", arguments: positionSigns)
    func clamp_leavesAFittingBadgeAlone(_ arg: (position: BadgePosition, xSign: CGFloat, ySign: CGFloat)) {
        for enclosure in Self.enclosures {
            // 1.15 sits just under the ≈1.19 threshold with margin to spare, so
            // this can't fail on a floating-point hair.
            for scale in [CGFloat(0.3), 0.5, 1.0, 1.15] {
                let s = Self.settings(position: arg.position, badgeScale: scale)
                let offset = BadgeGeometry.offset(for: s, enclosureSize: enclosure)
                let expectedX = arg.xSign * enclosure * BadgeGeometry.anchorXRatio
                let expectedY = arg.ySign * enclosure * BadgeGeometry.anchorYRatio
                #expect(abs(offset.width - expectedX) < 0.0001,
                        "Anchor moved at scale \(scale), enclosure \(enclosure): \(offset.width) vs \(expectedX)")
                #expect(abs(offset.height - expectedY) < 0.0001,
                        "Anchor moved at scale \(scale), enclosure \(enclosure): \(offset.height) vs \(expectedY)")
            }
        }
    }

    /// Documents the ≈1.19 crossover without asserting on its exact value, which
    /// would be fragile. Below it nothing moves; above it the badge marches in.
    @Test("The badge starts moving inward between badgeScale 1.15 and 1.25")
    func clamp_thresholdIsAroundNineteenPercentOversize() {
        let enclosure: CGFloat = 206
        let anchor = enclosure * BadgeGeometry.anchorXRatio

        let below = BadgeGeometry.maxCenterOffset(enclosureSize: enclosure, badgeScale: 1.15)
        #expect(below > anchor, "At 1.15 the default anchor should still fit")

        let above = BadgeGeometry.maxCenterOffset(enclosureSize: enclosure, badgeScale: 1.25)
        #expect(above < anchor, "At 1.25 the badge must be pulled inward")
    }

    /// A badge wider than the canvas can't be placed legally; it centers rather
    /// than producing a negative limit that would invert the clamp.
    @Test("An absurdly large badge centers instead of inverting the clamp")
    func clamp_degenerateBadgeCenters() {
        let s = Self.settings(position: .bottomRight, badgeScale: 20)
        let offset = BadgeGeometry.offset(for: s, enclosureSize: 206)
        #expect(offset == .zero)
    }

    // MARK: - manualOffsetRange

    /// The inverse must agree with the forward clamp, or the drag gesture would
    /// stop somewhere other than where the badge actually stops.
    @Test("manualOffsetRange endpoints are exactly what offset() still accepts",
          arguments: positionSigns.map(\.position))
    func manualOffsetRange_agreesWithOffset(_ position: BadgePosition) {
        let enclosure: CGFloat = 206
        let limit = { (scale: CGFloat) in
            BadgeGeometry.maxCenterOffset(enclosureSize: enclosure, badgeScale: scale)
        }

        for scale in Self.scales {
            let base = Self.settings(position: position, badgeScale: scale)
            let range = BadgeGeometry.manualOffsetRange(for: base, enclosureSize: enclosure)
            #expect(range.x.lowerBound <= range.x.upperBound)
            #expect(range.y.lowerBound <= range.y.upperBound)

            // A value at either end must land inside the clamp, not on the far
            // side of it.
            for mx in [range.x.lowerBound, range.x.upperBound] {
                for my in [range.y.lowerBound, range.y.upperBound] {
                    let s = Self.settings(position: position, manualOffset: (mx, my), badgeScale: scale)
                    let offset = BadgeGeometry.offset(for: s, enclosureSize: enclosure)
                    #expect(abs(offset.width) <= limit(scale) + 0.0001,
                            "range endpoint \(mx) exceeded the clamp at scale \(scale), \(position)")
                    #expect(abs(offset.height) <= limit(scale) + 0.0001,
                            "range endpoint \(my) exceeded the clamp at scale \(scale), \(position)")
                }
            }
        }
    }

    /// Past the returned upper bound the forward clamp bites — i.e. the range is
    /// the *tightest* one, not merely a safe subset. Only meaningful where the
    /// geometry, not `badgeOffsetRange`, is the binding constraint.
    @Test("manualOffsetRange is tight, not merely safe",
          arguments: positionSigns.map(\.position))
    func manualOffsetRange_isTight(_ position: BadgePosition) {
        let enclosure: CGFloat = 206
        for scale in Self.scales {
            let base = Self.settings(position: position, badgeScale: scale)
            let range = BadgeGeometry.manualOffsetRange(for: base, enclosureSize: enclosure)
            guard range.x.upperBound < IconSettings.badgeOffsetRange.upperBound - 0.001 else { continue }

            let atEdge = Self.settings(
                position: position, manualOffset: (range.x.upperBound, 0), badgeScale: scale)
            let past = Self.settings(
                position: position, manualOffset: (range.x.upperBound + 0.05, 0), badgeScale: scale)
            let atEdgeX = BadgeGeometry.offset(for: atEdge, enclosureSize: enclosure).width
            let pastX = BadgeGeometry.offset(for: past, enclosureSize: enclosure).width

            #expect(abs(pastX - atEdgeX) < 0.0001,
                    "Going past the range's upper bound still moved the badge at scale \(scale), \(position) — the range isn't the real limit")
        }
    }
}
