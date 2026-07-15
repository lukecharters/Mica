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
@testable import Mica

@Suite(.tags(.rendering))
@MainActor
struct BadgeRenderingStructuralTests {

    // MARK: - Helpers

    /// Render a 256pt non-retina icon at the default settings, optionally with
    /// a badge at the given position. Inherits `@MainActor` from the enclosing
    /// struct — required by `IconRenderer.renderIconSafely` / SwiftUI `ImageRenderer`.
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

    // MARK: - Export integrity

    @Test("Pending System-mode badge draws nothing — no placeholder can reach exports")
    func pendingAppexBadge_drawsNothing() throws {
        var settings = IconSettings()
        settings.symbolName = "folder.fill"
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.baseColor = .blue
        settings.showBadge = true
        settings.badgeIconSource = .appleReference
        settings.badgePosition = .bottomRight
        // Badge is System mode but its appex image hasn't rendered yet.
        let pendingBadge = IconRenderer.renderIconSafely(settings: settings, badgeAppexImage: nil)

        settings.showBadge = false
        let noBadge = IconRenderer.renderIconSafely(settings: settings)

        // The canvases may differ (badge overflow buffer), but the drawn content
        // must be identical in extent: any placeholder circle at the badge anchor
        // would extend the alpha bounding box beyond the chiclet.
        let pendingBox = try #require(
            IconRenderingAssertions.alphaBoundingBox(of: pendingBadge),
            "Pending-badge render must still contain the chiclet"
        )
        let baseBox = try #require(
            IconRenderingAssertions.alphaBoundingBox(of: noBadge),
            "Baseline render must contain the chiclet"
        )
        #expect(abs(pendingBox.width - baseBox.width) <= 1,
                "Pending System badge must not draw anything (Δwidth \(pendingBox.width - baseBox.width))")
        #expect(abs(pendingBox.height - baseBox.height) <= 1,
                "Pending System badge must not draw anything (Δheight \(pendingBox.height - baseBox.height))")
    }

    @Test("Imported-background flag with no image still renders a visible badge")
    func importedBackgroundFlag_withoutImage_stillRendersBadge() throws {
        // The Type picker can set badgeUseImportedBackground before an image is
        // chosen; the badge must fall back to its color background + symbol
        // rather than rendering nothing.
        var settings = IconSettings()
        settings.symbolName = "folder.fill"
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.baseColor = .blue
        settings.badgeSymbolName = "gearshape.fill"
        settings.badgeBaseColor = .red
        settings.showBadge = true
        settings.badgePosition = .bottomRight
        settings.badgeUseImportedBackground = true
        settings.badgeImportedBackground = nil
        let withBadge = IconRenderer.renderIconSafely(settings: settings)

        settings.showBadge = false
        let baseline = IconRenderer.renderIconSafely(settings: settings)

        let badgedCentroid = try #require(IconRenderingAssertions.centroidOfNonClearPixels(in: withBadge))
        let baseCentroid = try #require(IconRenderingAssertions.centroidOfNonClearPixels(in: baseline))

        // Same sign-of-shift assertion as the position tests: a visible badge at
        // bottomRight must pull the centroid (+x, -y) in bottom-origin coords.
        #expect(badgedCentroid.x - baseCentroid.x > 1.0,
                "Badge must be visible: expected Δx > 1, got \(badgedCentroid.x - baseCentroid.x)")
        #expect(badgedCentroid.y - baseCentroid.y < -1.0,
                "Badge must be visible: expected Δy < -1, got \(badgedCentroid.y - baseCentroid.y)")
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

    // MARK: - Badged canvas expansion

    nonisolated static let badgedDimsMatrix: [(size: CGFloat, retina: Bool)] = [
        (256, false),
        (256, true),
        (512, false)
    ]

    /// A badge overflowing the chiclet expands the canvas beyond
    /// finalExportSize; the rendered pixel dimensions must match
    /// totalCanvasSize, not finalExportSize. The default anchor stays
    /// inside the canvas, so a manual offset pushes the badge out.
    /// (No-badge renders pin dims == finalExportSize in
    /// IconRenderingStructuralTests.)
    @Test("Badged render pixel dimensions equal totalCanvasSize, not finalExportSize",
          arguments: badgedDimsMatrix)
    func badgedCanvas_pixelDimensionsMatchTotalCanvasSize(_ arg: (size: CGFloat, retina: Bool)) throws {
        var settings = IconSettings()
        settings.symbolName = "folder.fill"
        settings.exportSize = arg.size
        settings.exportRetinaSize = arg.retina
        settings.baseColor = .blue
        settings.showBadge = true
        settings.badgePosition = .bottomRight
        settings.badgeSymbolName = "gearshape.fill"
        settings.badgeManualOffsetX = 0.3
        settings.badgeManualOffsetY = 0.3

        let expectedCanvas = IconContentView.totalCanvasSize(
            for: settings, displaySize: settings.finalExportSize)
        #expect(expectedCanvas > settings.finalExportSize,
                "Precondition: a default bottom-right badge must overflow the canvas")

        let image = IconRenderer.renderIconSafely(settings: settings)
        let data = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: data))

        // ±1px: totalCanvasSize can be fractional; ImageRenderer rounds.
        #expect(abs(Double(rep.pixelsWide) - Double(expectedCanvas)) <= 1,
                "Pixel width \(rep.pixelsWide) must equal totalCanvasSize \(expectedCanvas) for (size=\(Int(arg.size)),retina=\(arg.retina))")
        #expect(abs(Double(rep.pixelsHigh) - Double(expectedCanvas)) <= 1,
                "Pixel height \(rep.pixelsHigh) must equal totalCanvasSize \(expectedCanvas) for (size=\(Int(arg.size)),retina=\(arg.retina))")
    }
}
