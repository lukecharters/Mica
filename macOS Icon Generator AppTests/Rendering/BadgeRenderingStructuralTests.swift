// BadgeRenderingStructuralTests.swift
// Structural assertions for badge placement in IconRenderer.renderIcon.
// Strategy: compare the alpha-weighted centroid of a rendered icon with
// and without the badge. For each BadgePosition, the shift must have the
// expected sign in both x and y. Sign-of-shift is robust to the exact
// pixel-count contribution of the badge vs the chiclet and tolerates
// antialiasing + minor symbol-metric drift.
//
// Coordinate note: IconRenderingAssertions.centroidOfNonClearPixels
// returns points in AppKit bottom-origin (y grows upward). Expected
// badge-center offsets (from the render pipeline) in bottom-origin:
//   topRight:    (+x, +y)
//   topLeft:     (-x, +y)
//   bottomRight: (+x, -y)
//   bottomLeft:  (-x, -y)
// Delta centroid signs must match these.

import Testing
import AppKit
import SwiftUI
import CoreGraphics
@testable import macOS_Icon_Generator_App

@Suite(.tags(.rendering))
@MainActor
struct BadgeRenderingStructuralTests {

    // MARK: - Helpers

    /// Render a 256pt non-retina icon at the default settings, optionally with
    /// a badge at the given position.
    static func renderIcon(withBadgeAt position: BadgePosition?,
                           manualOffset: (x: Double, y: Double) = (0, 0),
                           exportSize: CGFloat = 256) -> NSImage {
        var settings = IconSettings()
        settings.symbolName = "folder.fill"
        settings.exportSize = exportSize
        settings.exportRetinaSize = false
        settings.baseColor = .blue
        settings.badgeSymbolName = "gearshape.fill"
        settings.badgeBaseColor = .red // visually distinct from chiclet blue
        if let position {
            settings.showBadge = true
            settings.badgePosition = position
            settings.badgeManualOffsetX = manualOffset.x
            settings.badgeManualOffsetY = manualOffset.y
        } else {
            settings.showBadge = false
        }
        return IconRenderer.renderIconSafely(settings: settings)
    }

    // MARK: - Sign-of-shift per BadgePosition

    /// (position, expected sign of Δx, expected sign of Δy) in
    /// AppKit bottom-origin (y grows upward).
    nonisolated static let positionShiftSigns: [(position: BadgePosition, dxSign: Int, dySign: Int)] = [
        (.topRight,    +1, +1),
        (.topLeft,     -1, +1),
        (.bottomRight, +1, -1),
        (.bottomLeft,  -1, -1)
    ]

    @Test("Adding a badge shifts the centroid in the expected direction",
          arguments: positionShiftSigns)
    func badge_shiftsCentroidInExpectedDirection(
        _ arg: (position: BadgePosition, dxSign: Int, dySign: Int)
    ) throws {
        let baseline = Self.renderIcon(withBadgeAt: nil)
        let withBadge = Self.renderIcon(withBadgeAt: arg.position)

        let baseCentroid = try #require(
            IconRenderingAssertions.centroidOfNonClearPixels(in: baseline),
            "Baseline (no badge) render must have a measurable centroid"
        )
        let badgedCentroid = try #require(
            IconRenderingAssertions.centroidOfNonClearPixels(in: withBadge),
            "Badged render must have a measurable centroid"
        )

        let dx = badgedCentroid.x - baseCentroid.x
        let dy = badgedCentroid.y - baseCentroid.y
        // Require a non-trivial shift in both axes — at least 1 pixel.
        let minMagnitude: CGFloat = 1.0

        switch arg.dxSign {
        case  1: #expect(dx > minMagnitude,
                         "Position \(arg.position): expected Δx > \(minMagnitude), got \(dx)")
        case -1: #expect(dx < -minMagnitude,
                         "Position \(arg.position): expected Δx < -\(minMagnitude), got \(dx)")
        default: Issue.record("Unreachable dxSign for \(arg.position)")
        }

        switch arg.dySign {
        case  1: #expect(dy > minMagnitude,
                         "Position \(arg.position): expected Δy > \(minMagnitude), got \(dy)")
        case -1: #expect(dy < -minMagnitude,
                         "Position \(arg.position): expected Δy < -\(minMagnitude), got \(dy)")
        default: Issue.record("Unreachable dySign for \(arg.position)")
        }
    }

    // MARK: - Manual offset normalization scales with canvas size

    @Test("Manual offset (normalized fraction) produces proportional centroid shift across sizes")
    func manualOffset_scalesWithCanvasSize() throws {
        // At each canvas size, measure the extra centroid shift from
        // badgeManualOffsetX = 0.2 compared to badgeManualOffsetX = 0.0
        // (both at bottomRight). The two shifts, normalised by their
        // respective canvas widths, should be approximately equal —
        // proving the stored offset is a normalized fraction of
        // enclosure size and scales with the canvas.

        func centroidShiftDelta(exportSize: CGFloat) throws -> CGFloat {
            let zeroOffset = Self.renderIcon(
                withBadgeAt: .bottomRight,
                manualOffset: (0, 0),
                exportSize: exportSize
            )
            let positiveOffset = Self.renderIcon(
                withBadgeAt: .bottomRight,
                manualOffset: (0.2, 0),
                exportSize: exportSize
            )
            let c0 = try #require(IconRenderingAssertions.centroidOfNonClearPixels(in: zeroOffset))
            let cP = try #require(IconRenderingAssertions.centroidOfNonClearPixels(in: positiveOffset))
            return cP.x - c0.x
        }

        let dx256 = try centroidShiftDelta(exportSize: 256)
        let dx512 = try centroidShiftDelta(exportSize: 512)

        // Normalized shifts (as a fraction of canvas width) must be close.
        let ratio256 = dx256 / 256
        let ratio512 = dx512 / 512

        // Both shifts must be positive (positive manualOffsetX shifts
        // the centroid in the +x direction).
        #expect(dx256 > 0,
                "At size 256, positive manualOffsetX must shift centroid +x (got \(dx256))")
        #expect(dx512 > 0,
                "At size 512, positive manualOffsetX must shift centroid +x (got \(dx512))")

        // Allow ±25% tolerance on the normalized shift — badge pixel
        // contribution vs chiclet pixel contribution is not exactly
        // scale-invariant due to antialiasing at small sizes.
        let tolerance = 0.25 * max(abs(ratio256), abs(ratio512))
        #expect(abs(ratio256 - ratio512) <= tolerance,
                "Normalized centroid shifts must be proportional across sizes. ratio256=\(ratio256), ratio512=\(ratio512), tolerance=\(tolerance)")
    }
}
