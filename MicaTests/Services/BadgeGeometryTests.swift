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

    /// The invariant the whole change exists for: whatever the position, size or
    /// manual offset, the badge and everything it draws stays inside the canvas.
    /// If this fails, an export would clip the badge (the canvas no longer grows
    /// to rescue it).
    @Test("The badge never leaves the canvas, at any position, size or offset",
          arguments: positionSigns.map(\.position))
    func clamp_badgeStaysInsideTheCanvas(_ position: BadgePosition) {
        for enclosure in Self.enclosures {
            let halfCanvas = enclosure * BadgeGeometry.enclosureToCanvasRatio / 2
            for scale in Self.scales {
                for mx in Self.manualOffsets {
                    for my in Self.manualOffsets {
                        let s = Self.settings(position: position, manualOffset: (mx, my), badgeScale: scale)
                        let offset = BadgeGeometry.offset(for: s, enclosureSize: enclosure)
                        let ext = BadgeGeometry.extents(for: s, enclosureSize: enclosure)
                        let context = "\(position) enclosure=\(enclosure) scale=\(scale) manual=(\(mx),\(my))"

                        #expect(abs(offset.width) + ext.horizontal <= halfCanvas + 0.0001,
                                "Badge escapes horizontally by \(abs(offset.width) + ext.horizontal - halfCanvas)pt — \(context)")
                        // Vertical is checked per direction: the shadow falls
                        // downward, so the two edges have different budgets.
                        #expect(offset.height + ext.down <= halfCanvas + 0.0001,
                                "Badge escapes off the bottom by \(offset.height + ext.down - halfCanvas)pt — \(context)")
                        #expect(-offset.height + ext.up <= halfCanvas + 0.0001,
                                "Badge escapes off the top by \(-offset.height + ext.up - halfCanvas)pt — \(context)")
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
            // 1.05 clears the earliest crossover (≈1.11, on a bottom-anchored
            // badge) with margin, so this can't fail on a floating-point hair.
            for scale in [CGFloat(0.3), 0.5, 1.0, 1.05] {
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

    /// Brackets the crossover without asserting an exact value, which would be
    /// fragile. A bottom-anchored badge hits it first because the shadow falls
    /// that way.
    @Test("A bottom-anchored badge starts moving inward between scale 1.05 and 1.20")
    func clamp_thresholdBracket() {
        let enclosure: CGFloat = 206
        let anchor = enclosure * BadgeGeometry.anchorYRatio

        let below = BadgeGeometry.centreLimits(
            for: Self.settings(position: .bottomRight, badgeScale: 1.05), enclosureSize: enclosure)
        #expect(below.down > anchor, "At 1.05 the default anchor should still fit")

        let above = BadgeGeometry.centreLimits(
            for: Self.settings(position: .bottomRight, badgeScale: 1.20), enclosureSize: enclosure)
        #expect(above.down < anchor, "At 1.20 the badge must be pulled inward")
    }

    // MARK: - Extents track the badge, not the enclosure

    /// The bug this replaced: the shadow buffer was a fixed fraction of the
    /// *enclosure*, while the shadow itself scales with the badge diameter. The
    /// two decouple the moment badgeScale leaves 1.0 — too much room at small
    /// sizes (a visible gap), too little at large ones (a clipped shadow).
    ///
    /// Everything past the badge's own edge must therefore be proportional to the
    /// diameter, i.e. a constant ratio across scales.
    @Test("The shadow allowance is a constant fraction of the badge diameter")
    func extents_scaleWithTheBadgeNotTheEnclosure() {
        let enclosure: CGFloat = 206
        var ratios: [CGFloat] = []

        for scale in Self.scales {
            let s = Self.settings(position: .bottomRight, badgeScale: scale)
            let diameter = BadgeGeometry.diameter(enclosureSize: enclosure, badgeScale: scale)
            let ext = BadgeGeometry.extents(for: s, enclosureSize: enclosure)
            // How far the shadow reaches past the badge's own edge.
            ratios.append((ext.down - diameter / 2) / diameter)
        }

        let first = try! #require(ratios.first)
        for (scale, ratio) in zip(Self.scales, ratios) {
            #expect(abs(ratio - first) < 0.0001,
                    "Shadow allowance is \(ratio) of the diameter at scale \(scale) but \(first) at \(Self.scales[0]) — it isn't tracking the badge")
        }
    }

    /// The vertical asymmetry: the shadow is offset downward, so the bottom needs
    /// more clearance than the top. Treating them the same either clips the
    /// bottom or wastes room at the top.
    @Test("The bottom needs more clearance than the top, by twice the y offset")
    func extents_areAsymmetricByTheShadowOffset() {
        let enclosure: CGFloat = 206
        let s = Self.settings(position: .bottomRight, badgeScale: 1.5)
        let ext = BadgeGeometry.extents(for: s, enclosureSize: enclosure)
        let diameter = BadgeGeometry.diameter(enclosureSize: enclosure, badgeScale: 1.5)
        let dy = diameter * ResolvedShadow.macOS26.badgeBackground.offsetYMultiplier

        #expect(ext.down > ext.up, "The downward shadow must claim more room below than above")
        #expect(abs((ext.down - ext.up) - 2 * dy) < 0.0001,
                "down - up should be exactly twice the shadow's y offset")
        #expect(ext.horizontal > diameter / 2, "The blur still reaches sideways")
    }

    /// With no shadow drawn there is nothing past the badge's edge, so it should
    /// be free to sit flush against the canvas. The old constant buffer applied
    /// regardless, holding the badge off the edge for a shadow that wasn't there.
    @Test("A badge with no shadow gets no allowance",
          arguments: [BadgePosition.bottomRight, .topLeft])
    func extents_noShadowMeansNoAllowance(_ position: BadgePosition) {
        let enclosure: CGFloat = 206
        var s = Self.settings(position: position, badgeScale: 1.0)
        s.badgeEnableBackgroundShadow = false

        let half = BadgeGeometry.diameter(enclosureSize: enclosure, badgeScale: 1.0) / 2
        let ext = BadgeGeometry.extents(for: s, enclosureSize: enclosure)
        #expect(abs(ext.horizontal - half) < 0.0001)
        #expect(abs(ext.up - half) < 0.0001)
        #expect(abs(ext.down - half) < 0.0001)
    }

    /// A System-mode badge is a bare appex raster; Mica draws no shadow behind it.
    @Test("A System-mode badge gets no shadow allowance")
    func extents_systemBadgeHasNoShadow() {
        let enclosure: CGFloat = 206
        var s = Self.settings(position: .bottomRight, badgeScale: 1.0)
        s.badgeIconSource = .system

        let half = BadgeGeometry.diameter(enclosureSize: enclosure, badgeScale: 1.0) / 2
        let ext = BadgeGeometry.extents(for: s, enclosureSize: enclosure)
        #expect(abs(ext.horizontal - half) < 0.0001)
        #expect(abs(ext.down - half) < 0.0001)
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

        for scale in Self.scales {
            let base = Self.settings(position: position, badgeScale: scale)
            let range = BadgeGeometry.manualOffsetRange(for: base, enclosureSize: enclosure)
            let limits = BadgeGeometry.centreLimits(for: base, enclosureSize: enclosure)
            #expect(range.x.lowerBound <= range.x.upperBound)
            #expect(range.y.lowerBound <= range.y.upperBound)

            // A value at either end must land inside the clamp, not on the far
            // side of it.
            for mx in [range.x.lowerBound, range.x.upperBound] {
                for my in [range.y.lowerBound, range.y.upperBound] {
                    let s = Self.settings(position: position, manualOffset: (mx, my), badgeScale: scale)
                    let offset = BadgeGeometry.offset(for: s, enclosureSize: enclosure)
                    #expect(abs(offset.width) <= limits.horizontal + 0.0001,
                            "range endpoint \(mx) exceeded the clamp at scale \(scale), \(position)")
                    #expect(offset.height <= limits.down + 0.0001,
                            "range endpoint \(my) exceeded the bottom clamp at scale \(scale), \(position)")
                    #expect(-offset.height <= limits.up + 0.0001,
                            "range endpoint \(my) exceeded the top clamp at scale \(scale), \(position)")
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
