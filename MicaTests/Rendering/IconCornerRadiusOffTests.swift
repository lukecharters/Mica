// IconCornerRadiusOffTests.swift
// `IconCornerRadiusStyle.off`, on both background sources.
//
// Strategy: sample a small patch inside one *corner* of the chiclet, rather
// than comparing whole-image areas. Area is the wrong instrument here — an
// imported icon background clipped at the macOS 26 radius still covers ≈0.94 of
// its square frame, so an area threshold barely separates clipped from
// unclipped. (The badge's equivalent test can use area because its clip was a
// full circle at ≈0.785.) The corner patch states the actual claim: with `.off`
// the corners survive.
//
// Each test asserts *both* styles, so a fixture or geometry mistake that made
// the patch permanently empty could not read as a pass.
//
// Testing trap, per the visibility-and-imported-backgrounds plan
// §2: the artwork must fill its own bounds. A Mica-rendered PNG already has
// transparent corners, so clipping it at any radius changes nothing and the
// setting reads as inert.

import Testing
import AppKit
@testable import Mica

@Suite("Icon corner radius off", .tags(.rendering))
@MainActor
struct IconCornerRadiusOffTests {

    /// A patch just inside the chiclet's top-left corner — outside the rounded
    /// shape at the macOS 26 radius, inside the square one at `.off`.
    ///
    /// At 512px the chiclet is inset 50px and its corner arc has radius 108, so
    /// the arc centre sits at (158, 158): the patch's far corner is ≈130 from it,
    /// comfortably outside the 108 radius.
    private func cornerPatch(canvas: CGFloat) -> CGRect {
        let inset = (canvas - PreviewHitTester.enclosureSize(displaySize: canvas)) / 2
        let side = canvas * (12.0 / 512.0)
        let offset = canvas * (4.0 / 512.0)
        return CGRect(x: inset + offset, y: inset + offset, width: side, height: side)
    }

    private func baseSettings() -> IconSettings {
        var settings = IconSettings()
        settings.export.size = 512
        settings.export.isRetina = false
        // No shadow: it would paint into the corner patch and blur the question
        // from "does the artwork reach here" into "does anything reach here".
        settings.icon.background.shadowStyle = .off
        settings.icon.foreground.isHidden = true
        return settings
    }

    @Test("`.off` leaves an imported icon background unclipped")
    func off_leavesImportedIconBackgroundUnclipped() throws {
        var settings = baseSettings()
        settings.icon.background.source = .image
        settings.icon.background.image = try ImportedImage.testFixture(
            width: 64, height: 64, fill: .systemGreen)
        // The fixture fills its own bounds, so it needs no padding compensation —
        // its frame is then exactly the enclosure, and its corners land on the
        // chiclet's corners.
        settings.icon.background.compensatesForPadding = false

        let canvas = settings.export.pixelSize
        let patch = cornerPatch(canvas: canvas)

        settings.icon.background.cornerRadiusStyle = .macOS26
        let clipped = IconRenderingAssertions.clearPixelFraction(
            in: IconRenderer.renderIconSafely(settings: settings), rect: patch)

        settings.icon.background.cornerRadiusStyle = .off
        let unclipped = IconRenderingAssertions.clearPixelFraction(
            in: IconRenderer.renderIconSafely(settings: settings), rect: patch)

        #expect(clipped > 0.98,
                "At the macOS 26 radius the chiclet corner should be empty, but \(1 - clipped) of the patch is drawn — the patch may be in the wrong place, which would make the `.off` assertion below vacuous")
        #expect(unclipped < 0.02,
                "`.off` should leave the artwork's corner intact, but \(unclipped) of the corner patch is clear — the import is still being clipped")
    }

    @Test("`.off` gives a square chiclet on a colour background")
    func off_givesASquareChicletOnAColourBackground() throws {
        var settings = baseSettings()
        settings.icon.background.source = .color

        let canvas = settings.export.pixelSize
        let patch = cornerPatch(canvas: canvas)

        settings.icon.background.cornerRadiusStyle = .macOS26
        let rounded = IconRenderingAssertions.clearPixelFraction(
            in: IconRenderer.renderIconSafely(settings: settings), rect: patch)

        settings.icon.background.cornerRadiusStyle = .off
        let square = IconRenderingAssertions.clearPixelFraction(
            in: IconRenderer.renderIconSafely(settings: settings), rect: patch)

        #expect(rounded > 0.98,
                "The macOS 26 chiclet should not fill its corner, but \(1 - rounded) of the patch is drawn")
        #expect(square < 0.02,
                "`.off` should fill the corner (a square chiclet is the accepted consequence of the option), but \(square) of the patch is clear")
    }
}
