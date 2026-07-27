// BadgeShadowExtentTests.swift
// Pixel-level proof that the badge's shadow allowance tracks the badge.
//
// `BadgeGeometry.extents` budgets room for the badge's drop shadow so the clamp
// can keep it on the canvas. These tests render a badge slammed into a corner
// and measure where its pixels actually land, which catches the two ways that
// budget can be wrong:
//
//   too small — the shadow is clipped flat against the canvas edge
//   too large — the badge floats short of the edge for a shadow that isn't there
//
// Both were live bugs when the allowance was a fixed fraction of the enclosure
// while the shadow scaled with the badge diameter.

import Testing
import AppKit
@testable import Mica

@Suite(.tags(.rendering))
@MainActor
struct BadgeShadowExtentTests {

    /// Alpha bounding box at an arbitrary threshold. `IconRenderingAssertions`
    /// hardcodes 0.5, which a 0.23-opacity shadow never reaches.
    static func bbox(of image: NSImage, alphaAbove threshold: CGFloat) -> CGRect? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        let w = rep.pixelsWide, h = rep.pixelsHigh
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                guard let c = rep.colorAt(x: x, y: y) else { continue }
                if c.alphaComponent > threshold {
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// A badge alone on the canvas, shoved as far into the bottom-right as the
    /// clamp allows.
    static func cornerBadge(scale: CGFloat, size: CGFloat = 512) -> IconSettings {
        var s = IconSettings()
        s.exportSize = size
        s.exportRetinaSize = false
        s.iconBackgroundHidden = true
        s.iconForegroundHidden = true
        s.showBadge = true
        s.badgePosition = .bottomRight
        s.badgeSymbolName = "gearshape.fill"
        s.badgeScale = scale
        // Far past any legal offset, so the clamp is what positions the badge.
        s.badgeManualOffsetX = 1.0
        s.badgeManualOffsetY = 1.0
        return s
    }

    nonisolated static let scales: [CGFloat] = [0.3, 0.5, 1.0, 1.5, 2.0]

    /// Strongest alpha found anywhere in the canvas's outermost row/column.
    static func maxEdgeAlpha(of image: NSImage) -> CGFloat {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return 0 }
        let w = rep.pixelsWide, h = rep.pixelsHigh
        var peak: CGFloat = 0
        for y in 0..<h {
            if let c = rep.colorAt(x: 0, y: y) { peak = max(peak, c.alphaComponent) }
            if let c = rep.colorAt(x: w - 1, y: y) { peak = max(peak, c.alphaComponent) }
        }
        for x in 0..<w {
            if let c = rep.colorAt(x: x, y: 0) { peak = max(peak, c.alphaComponent) }
            if let c = rep.colorAt(x: x, y: h - 1) { peak = max(peak, c.alphaComponent) }
        }
        return peak
    }

    /// Nothing *visible* may be cut off at the canvas boundary.
    ///
    /// Asserted on alpha rather than position, because the clamp deliberately
    /// lands the shadow's computed extent exactly on the edge — so the faintest
    /// tail pixel (1/255) touching the boundary is correct, not a defect. A
    /// genuine cut leaves a much stronger edge: the enclosure-relative allowance
    /// this replaced severed the scale-2.0 shadow ~21pt early, at roughly 9/255.
    ///
    /// 3/255 sits clear of both.
    @Test("A corner badge is never visibly clipped", arguments: scales)
    func cornerBadge_isNeverVisiblyClipped(_ scale: CGFloat) throws {
        let settings = Self.cornerBadge(scale: scale)
        let image = IconRenderer.renderIconSafely(settings: settings)

        _ = try #require(Self.bbox(of: image, alphaAbove: 0),
                         "Precondition: the badge must actually draw")
        let edge = Self.maxEdgeAlpha(of: image)
        #expect(edge <= 3.0 / 255.0,
                "Canvas edge carries \(edge * 255)/255 alpha at scale \(scale) — the shadow is being cut, not clamped")
    }

    /// …and it must not stop short either. Pushed into the corner, the badge's
    /// outermost pixel should sit within a few pixels of the edge at every size.
    ///
    /// This is the regression that matters: the old fixed allowance left a gap
    /// that grew, in relative terms, as the badge shrank — 3pt of dead space
    /// around a badge only 24pt across.
    @Test("A corner badge sits flush against the edge at every size", arguments: scales)
    func cornerBadge_leavesNoGap(_ scale: CGFloat) throws {
        let settings = Self.cornerBadge(scale: scale)
        let side = settings.finalExportSize
        let image = IconRenderer.renderIconSafely(settings: settings)

        let box = try #require(Self.bbox(of: image, alphaAbove: 0))
        let rightGap = side - box.maxX
        let bottomGap = side - box.maxY

        // 4px covers the rounding in shadowBlurExtentFactor (2.1 vs the measured
        // 2.083) plus pixel quantisation, and is far tighter than the ~15px the
        // enclosure-relative allowance left at scale 0.3.
        #expect(rightGap <= 4,
                "\(rightGap)px of dead space on the right at scale \(scale) — the allowance isn't tracking the badge")
        #expect(bottomGap <= 4,
                "\(bottomGap)px of dead space at the bottom at scale \(scale) — the allowance isn't tracking the badge")
    }

    /// The measured reach of a SwiftUI shadow, as a multiple of its blur radius,
    /// at each opacity. Taken from the largest radius tested (14.4pt), where
    /// pixel quantisation matters least.
    ///
    /// `shadowBlurExtent` must cover every one of these, or retuning
    /// `ShadowStyle.badgeBackground.opacity` would start clipping the badge —
    /// the exact coupling the formula exists to remove.
    nonisolated static let measuredReach: [(opacity: CGFloat, reachOverRadius: CGFloat)] = [
        (0.10, 1.875),
        (0.23, 2.083),
        (0.40, 2.222),
        (0.60, 2.292),
        (1.00, 2.500)   // small radii reached 2.5 at full opacity
    ]

    @Test("The blur allowance covers the measured reach at every opacity",
          arguments: measuredReach)
    func shadowBlurExtent_coversMeasuredReach(_ point: (opacity: CGFloat, reachOverRadius: CGFloat)) {
        for radius in [CGFloat(2.4), 4.8, 14.4] {
            let allowed = BadgeGeometry.shadowBlurExtent(radius: radius, opacity: point.opacity)
            let needed = radius * point.reachOverRadius
            #expect(allowed >= needed,
                    "At opacity \(point.opacity), radius \(radius): allowing \(allowed)pt but the shadow reaches \(needed)pt")
            // …and not wildly more, or the badge floats off the edge again.
            #expect(allowed <= needed * 1.35,
                    "At opacity \(point.opacity): allowing \(allowed)pt for a \(needed)pt shadow — over-reserving")
        }
    }

    /// A shadow too faint to render at all needs no allowance.
    @Test("A sub-visible shadow gets no allowance")
    func shadowBlurExtent_zeroBelowTheAlphaFloor() {
        #expect(BadgeGeometry.shadowBlurExtent(radius: 10, opacity: 0) == 0)
        #expect(BadgeGeometry.shadowBlurExtent(radius: 10, opacity: 0.001) == 0)
        #expect(BadgeGeometry.shadowBlurExtent(radius: 0, opacity: 0.5) == 0)
    }

    /// With the shadow switched off there is nothing past the badge's own edge,
    /// so it should sit flush — its circle tangent to the canvas boundary. The
    /// old constant buffer applied regardless, holding the badge off the edge for
    /// a shadow that wasn't being drawn.
    @Test("A shadowless badge sits flush against the edge")
    func shadowlessBadge_hasNoAllowance() throws {
        var settings = Self.cornerBadge(scale: 1.0)
        settings.badgeEnableBackgroundShadow = false
        settings.badgeEnableSymbolShadow = false
        let side = settings.finalExportSize

        let image = IconRenderer.renderIconSafely(settings: settings)
        let box = try #require(Self.bbox(of: image, alphaAbove: 0))

        // Tangent, so the gap is zero — deliberately not an alpha check: here the
        // hard shape reaches the boundary by design, unlike the shadow cases.
        #expect(side - box.maxX <= 2,
                "A shadowless badge left \(side - box.maxX)px on the right; it should be flush")
        #expect(side - box.maxY <= 2,
                "A shadowless badge left \(side - box.maxY)px at the bottom; it should be flush")
    }

    /// An imported background draws unclipped into a frame that import scale and
    /// padding compensation push past the nominal diameter (1.5 x 1.2427 here).
    /// The clamp has to budget for the frame actually drawn, not the diameter.
    @Test("An oversized imported badge background is not clipped")
    func importedBackground_respectsItsEffectiveScale() throws {
        var settings = Self.cornerBadge(scale: 1.0)
        settings.badgeUseImportedBackground = true
        settings.badgeImportedBackground = try ImportedImage.testFixture(
            width: 64, height: 64, fill: .systemGreen)
        settings.badgeImportedBackgroundScale = 1.5
        settings.badgeImportedBackgroundPaddingCompensation = true

        let enclosure = PreviewHitTester.enclosureSize(displaySize: settings.finalExportSize)
        let half = BadgeGeometry.diameter(enclosureSize: enclosure, badgeScale: 1.0) / 2
        let ext = BadgeGeometry.extents(for: settings, enclosureSize: enclosure)
        #expect(ext.horizontal > half * 1.8,
                "Precondition: the effective scale must push the footprint well past the diameter")

        let image = IconRenderer.renderIconSafely(settings: settings)
        _ = try #require(Self.bbox(of: image, alphaAbove: 0))

        // The fixture is a solid square, so a clip would leave a hard edge —
        // far above the shadow tail's 1/255.
        let edge = Self.maxEdgeAlpha(of: image)
        #expect(edge <= 3.0 / 255.0,
                "Canvas edge carries \(edge * 255)/255 alpha — the imported background is being clipped")
    }
}
