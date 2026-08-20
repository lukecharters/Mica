// ForegroundOffsetTests.swift
//
// The foreground nudge, measured in pixels. `ForegroundSpec.offsetX`/`offsetY` are
// fractions of the layer's own frame — the icon enclosure for an icon foreground,
// the badge diameter for a badge one — and the only proof that the render agrees
// with that definition is where the ink lands.
//
// Strategy: draw *only* the layer under test (every other layer hidden), take the
// centroid of the non-transparent pixels, and require it to move by the predicted
// number of points. A centroid is the right measure here because the nudge is a
// pure translation: it says nothing about the glyph's shape, so the assertion holds
// whatever symbol calibration does. `IconRenderingAssertions.centroidOfNonClearPixels`
// works in NSImage coordinates (y grows *upward*), so a positive `offsetY` — down,
// in SwiftUI's coordinates — must *lower* the centroid's y. Getting that backwards
// is the mistake these tests exist to catch.

import Testing
import AppKit
@testable import Mica

@Suite("Foreground offsets", .tags(.rendering))
@MainActor
struct ForegroundOffsetTests {

    /// A canvas holding nothing but the icon's symbol.
    private func iconGlyphOnly(size: CGFloat = 512) -> IconSettings {
        var settings = IconSettings()
        settings.export.size = size
        settings.export.isRetina = false
        settings.icon.foreground.symbolName = "star.fill"
        settings.icon.foreground.drawsShadow = false
        settings.icon.background.isHidden = true
        return settings
    }

    /// A canvas holding nothing but the badge's glyph.
    private func badgeGlyphOnly(size: CGFloat = 512) -> IconSettings {
        var settings = IconSettings()
        settings.export.size = size
        settings.export.isRetina = false
        settings.icon.foreground.isHidden = true
        settings.icon.background.isHidden = true
        settings.badge.foreground.isHidden = false
        settings.badge.foreground.drawsShadow = false
        settings.badge.background.isHidden = true
        return settings
    }

    private func centroid(_ settings: IconSettings) throws -> CGPoint {
        let image = IconRenderer.renderIconSafely(settings: settings)
        return try #require(IconRenderingAssertions.centroidOfNonClearPixels(in: image),
                            "nothing was drawn, so there is no centroid to compare")
    }

    private func enclosure(_ settings: IconSettings) -> CGFloat {
        PreviewHitTester.enclosureSize(displaySize: settings.export.pixelSize)
    }

    // MARK: - Icon foreground

    @Test("The icon foreground moves by the offset times the enclosure")
    func iconOffset_movesTheGlyphByEnclosureFractions() throws {
        var settings = iconGlyphOnly()
        let before = try centroid(settings)

        settings.icon.foreground.offsetX = 0.2
        settings.icon.foreground.offsetY = 0.1
        let after = try centroid(settings)

        let enclosure = enclosure(settings)
        // 2pt of slack: the glyph is antialiased and clipped to whole pixels, so a
        // translation lands the centroid within a pixel or so of the prediction.
        #expect(abs((after.x - before.x) - enclosure * 0.2) < 2)
        // Down in SwiftUI is down the image, which is *negative* here.
        #expect(abs((after.y - before.y) + enclosure * 0.1) < 2)
    }

    @Test("The offset is a fraction, so it survives a change of export size")
    func iconOffset_isScaleInvariant() throws {
        func travel(size: CGFloat) throws -> CGFloat {
            var settings = iconGlyphOnly(size: size)
            let before = try centroid(settings)
            settings.icon.foreground.offsetX = 0.25
            let after = try centroid(settings)
            return (after.x - before.x) / size
        }

        let small = try travel(size: 256)
        let large = try travel(size: 512)
        #expect(abs(small - large) < 0.01,
                "the nudge moved \(small) of the canvas at 256pt and \(large) at 512pt")
    }

    @Test("Zero is centred, and is what a fresh spec holds")
    func iconOffset_defaultsToCentred() throws {
        let settings = iconGlyphOnly()
        #expect(settings.icon.foreground.offsetX == 0)
        #expect(settings.icon.foreground.offsetY == 0)

        var nudgedBackToZero = settings
        nudgedBackToZero.icon.foreground.offsetX = 0.3
        nudgedBackToZero.icon.foreground.offsetX = 0
        let restored = try centroid(nudgedBackToZero)
        let centred = try centroid(settings)
        #expect(restored == centred)
    }

    // MARK: - Badge foreground

    @Test("The badge glyph moves by the offset times the badge diameter")
    func badgeOffset_movesTheGlyphByBadgeDiameters() throws {
        var settings = badgeGlyphOnly()
        let before = try centroid(settings)

        settings.badge.foreground.offsetX = -0.3
        let after = try centroid(settings)

        let diameter = BadgeGeometry.diameter(enclosureSize: enclosure(settings),
                                              badgeScale: settings.badge.scale)
        #expect(abs((after.x - before.x) + diameter * 0.3) < 2,
                "the glyph moved \(after.x - before.x)pt where the badge is \(diameter)pt across")
    }

    @Test("The badge glyph's nudge keeps its place when the badge is resized")
    func badgeOffset_scalesWithTheBadge() throws {
        func travel(badgeScale: Double) throws -> CGFloat {
            var settings = badgeGlyphOnly()
            settings.badge.scale = badgeScale
            let before = try centroid(settings)
            settings.badge.foreground.offsetX = 0.25
            let after = try centroid(settings)
            let diameter = BadgeGeometry.diameter(enclosureSize: enclosure(settings),
                                                  badgeScale: badgeScale)
            return (after.x - before.x) / diameter
        }

        // Measured in badge diameters, the travel is the same — which is what makes
        // the glyph stay put relative to the badge rather than drifting out of it.
        #expect(abs(try travel(badgeScale: 0.7) - 0.25) < 0.06)
        #expect(abs(try travel(badgeScale: 1.4) - 0.25) < 0.06)
    }

    @Test("Nudging the badge glyph does not move the badge")
    func badgeOffset_leavesTheBadgeWhereItIs() throws {
        // The badge's background only, so the centroid measures the badge itself.
        var settings = IconSettings()
        settings.export.size = 512
        settings.export.isRetina = false
        settings.icon.foreground.isHidden = true
        settings.icon.background.isHidden = true
        settings.badge.background.isHidden = false
        settings.badge.foreground.isHidden = true

        let before = try centroid(settings)
        settings.badge.foreground.offsetX = 0.5
        settings.badge.foreground.offsetY = -0.5
        let after = try centroid(settings)

        #expect(before == after,
                "the badge moved to \(after) from \(before) because its hidden glyph was nudged")
    }
}
