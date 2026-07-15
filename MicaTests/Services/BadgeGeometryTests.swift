// BadgeGeometryTests.swift
// Unit tests for BadgeGeometry, the single source of truth for badge
// anchor/diameter math shared by the render pipeline and both previews,
// plus a static-vs-instance totalCanvasSize consistency check.

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

    @Test("Offset anchors are ±76/208 and ±80/208 of the enclosure", arguments: positionSigns)
    func offset_matchesAnchorRatios(_ arg: (position: BadgePosition, xSign: CGFloat, ySign: CGFloat)) {
        let enclosure: CGFloat = 208 // makes expected values exactly 76 and 80
        let offset = BadgeGeometry.offset(for: Self.settings(position: arg.position), enclosureSize: enclosure)
        #expect(offset.width == arg.xSign * 76)
        #expect(offset.height == arg.ySign * 80)
    }

    @Test("Manual offset adds linearly in enclosure fractions")
    func offset_appliesManualOffset() {
        let enclosure: CGFloat = 208
        let base = BadgeGeometry.offset(
            for: Self.settings(position: .bottomRight),
            enclosureSize: enclosure
        )
        let shifted = BadgeGeometry.offset(
            for: Self.settings(position: .bottomRight, manualOffset: (0.25, -0.5)),
            enclosureSize: enclosure
        )
        #expect(shifted.width - base.width == 0.25 * enclosure)
        #expect(shifted.height - base.height == -0.5 * enclosure)
    }

    @Test("Offset scales linearly with enclosure size")
    func offset_scalesWithEnclosure() {
        let s = Self.settings(position: .topLeft, manualOffset: (0.1, 0.2))
        let small = BadgeGeometry.offset(for: s, enclosureSize: 104)
        let large = BadgeGeometry.offset(for: s, enclosureSize: 208)
        #expect(large.width == small.width * 2)
        #expect(large.height == small.height * 2)
    }

    // MARK: - Diameter

    @Test("Diameter is 80/208 of the enclosure, scaled by badgeScale")
    func diameter_matchesRatio() {
        #expect(BadgeGeometry.diameter(enclosureSize: 208, badgeScale: 1.0) == 80)
        #expect(BadgeGeometry.diameter(enclosureSize: 208, badgeScale: 1.5) == 120)
        #expect(BadgeGeometry.diameter(enclosureSize: 104, badgeScale: 1.0) == 40)
    }

    // MARK: - totalCanvasSize static/instance sync

    @Test("Static totalCanvasSize matches the instance computation",
          arguments: [
              (BadgePosition.bottomRight, 0.0, 0.0, CGFloat(1.0)),
              (BadgePosition.topLeft, 0.0, 0.0, CGFloat(1.0)),
              (BadgePosition.bottomRight, 0.4, 0.4, CGFloat(1.0)),
              (BadgePosition.topRight, -0.3, 0.6, CGFloat(1.8)),
              (BadgePosition.bottomLeft, 0.9, -0.9, CGFloat(2.0))
          ])
    @MainActor
    func totalCanvasSize_staticMatchesInstance(
        _ arg: (position: BadgePosition, mx: Double, my: Double, scale: CGFloat)
    ) {
        let s = Self.settings(
            position: arg.position,
            manualOffset: (arg.mx, arg.my),
            badgeScale: arg.scale
        )
        for displaySize: CGFloat in [256, 512, 1024] {
            let staticSize = IconContentView.totalCanvasSize(for: s, displaySize: displaySize)
            let instanceSize = IconContentView(settings: s, displaySize: displaySize).totalCanvasSize
            #expect(abs(staticSize - instanceSize) < 0.0001,
                    "static \(staticSize) vs instance \(instanceSize) at \(displaySize)pt, \(arg)")
            #expect(staticSize >= displaySize)
        }
    }

    @Test("totalCanvasSize is the display size when the badge is hidden")
    @MainActor
    func totalCanvasSize_noBadge() {
        var s = IconSettings()
        s.showBadge = false
        #expect(IconContentView.totalCanvasSize(for: s, displaySize: 256) == 256)
    }
}
