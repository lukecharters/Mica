// AppexRenderingStructuralTests.swift
// Structural assertions for the appex rendering path.
//
// Fast path (no NSWorkspace): IconRenderer.renderAppexWithBadge(...) takes
// an appex image as input and composites it with an optional badge. We
// synthesize the appex image in-test (a solid red NSImage), then verify:
//   - Output dimensions match finalExportSize (the canvas never grows)
//   - Red dominates every quadrant (the synthesized appex fills the canvas)
//   - Adding a green badge at bottomRight shifts the green signal there
//
// Slow path (.slow tag): AppexReferenceService.renderForExport(...) is
// invoked against a real SF Symbol via the private /System/Library/
// ExtensionKit/Extensions/Storage.appex bundle. Verifies the pipeline
// returns a non-empty image at the requested dimensions. NSWorkspace +
// LaunchServices + file-I/O cost makes this a >100ms test per spec guidance.

import Testing
import AppKit
@testable import Mica

@Suite(.tags(.rendering))
@MainActor
struct AppexRenderingStructuralTests {

    // MARK: - Helpers

    /// Build a solid-colour NSImage for use as a stubbed appex render input.
    static func solidColorImage(_ color: NSColor, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        image.unlockFocus()
        return image
    }

    // MARK: - Fast path: renderAppexWithBadge with stubbed appex image

    @Test("Appex composite without badge matches finalExportSize and is red-dominant")
    func appexComposite_noBadge_dimensionsAndDominance() throws {
        var settings = IconSettings()
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.showBadge = false

        let expectedCanvas = settings.finalExportSize
        let appex = Self.solidColorImage(.red, size: settings.finalExportSize)

        let output = IconRenderer.renderAppexWithBadge(
            appexImage: appex,
            settings: settings,
            badgeAppexImage: nil
        )

        // Logical size tracks the exportSize via setImageDPI.
        #expect(Int(output.size.width) == Int(settings.exportSize))
        #expect(Int(output.size.height) == Int(settings.exportSize))

        // The returned NSImage after setImageDPI reports logical = exportSize,
        // pixels = finalExportSize. Validate at the pixel level.
        let data = try #require(output.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: data))
        #expect(rep.pixelsWide == Int(expectedCanvas))
        #expect(rep.pixelsHigh == Int(expectedCanvas))

        let quadrants = try #require(IconRenderingAssertions.quadrantAverageColors(of: output))
        for (name, color) in [
            ("topLeft",     quadrants.topLeft),
            ("topRight",    quadrants.topRight),
            ("bottomLeft",  quadrants.bottomLeft),
            ("bottomRight", quadrants.bottomRight)
        ] {
            #expect(color.redComponent > 0.5,
                    "Solid-red stub appex must produce red-dominant quadrants. Quadrant \(name): R=\(color.redComponent)")
            #expect(color.redComponent > color.greenComponent,
                    "Quadrant \(name): red must exceed green (R=\(color.redComponent), G=\(color.greenComponent))")
            #expect(color.redComponent > color.blueComponent,
                    "Quadrant \(name): red must exceed blue (R=\(color.redComponent), B=\(color.blueComponent))")
        }
    }

    @Test("Appex composite with an appleReference badge adds green in the badge quadrant")
    func appexComposite_withAppleReferenceBadge_addsGreenInBadgeQuadrant() throws {
        var settings = IconSettings()
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.showBadge = true
        settings.badgePosition = .bottomRight
        settings.badgeIconSource = .system // BadgeView uses badgeAppexImage for this mode

        let appex = Self.solidColorImage(.red, size: settings.finalExportSize)
        // Badge appex is typically provided at 512pt @2x = 1024px per
        // AppexReferenceService.referenceIcon defaults; a smaller stub is
        // fine here — renderAppexWithBadge will scale it to badgeSize.
        let badgeAppex = Self.solidColorImage(.green, size: 1024)

        let output = IconRenderer.renderAppexWithBadge(
            appexImage: appex,
            settings: settings,
            badgeAppexImage: badgeAppex
        )

        let quadrants = try #require(IconRenderingAssertions.quadrantAverageColors(of: output))

        // The bottomRight quadrant should have appreciably more green than
        // the topLeft (diagonally opposite) one. We don't assert an absolute
        // green fraction — the badge covers a small portion of the quadrant,
        // and green vs red average depends on the exact badge size.
        #expect(
            quadrants.bottomRight.greenComponent > quadrants.topLeft.greenComponent,
            "bottomRight badge must lift green component in bottomRight quadrant relative to the diagonally opposite topLeft. BR.G=\(quadrants.bottomRight.greenComponent), TL.G=\(quadrants.topLeft.greenComponent)"
        )
    }

    // MARK: - Icon group visibility

    @Test("Hiding the icon group drops the appex raster from the composite")
    func appexComposite_iconHidden_isTransparent() throws {
        var settings = IconSettings()
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.showBadge = false
        settings.iconHidden = true

        let appex = Self.solidColorImage(.red, size: settings.finalExportSize)
        let output = IconRenderer.renderAppexWithBadge(
            appexImage: appex,
            settings: settings,
            badgeAppexImage: nil
        )

        // Nothing is drawn, so no opaque pixels survive anywhere.
        let quadrants = try #require(IconRenderingAssertions.quadrantAverageColors(of: output))
        for (name, color) in [
            ("topLeft",     quadrants.topLeft),
            ("topRight",    quadrants.topRight),
            ("bottomLeft",  quadrants.bottomLeft),
            ("bottomRight", quadrants.bottomRight)
        ] {
            #expect(color.alphaComponent < 0.05,
                    "Hidden icon group must leave quadrant \(name) transparent. A=\(color.alphaComponent)")
        }
    }

    @Test("Hiding the icon group keeps the badge, leaving a badge-only render")
    func appexComposite_iconHiddenWithBadge_keepsBadge() throws {
        var settings = IconSettings()
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.showBadge = true
        settings.badgePosition = .bottomRight
        settings.badgeIconSource = .system
        settings.iconHidden = true

        let appex = Self.solidColorImage(.red, size: settings.finalExportSize)
        let badgeAppex = Self.solidColorImage(.green, size: 1024)

        let output = IconRenderer.renderAppexWithBadge(
            appexImage: appex,
            settings: settings,
            badgeAppexImage: badgeAppex
        )

        let quadrants = try #require(IconRenderingAssertions.quadrantAverageColors(of: output))
        // The badge still lands bottom-right; the icon's red is gone everywhere.
        #expect(quadrants.bottomRight.alphaComponent > quadrants.topLeft.alphaComponent,
                "Badge must still draw with the icon hidden. BR.A=\(quadrants.bottomRight.alphaComponent), TL.A=\(quadrants.topLeft.alphaComponent)")
        #expect(quadrants.topLeft.alphaComponent < 0.05,
                "Hidden icon group must leave the badge-free topLeft quadrant transparent. A=\(quadrants.topLeft.alphaComponent)")
    }

    // MARK: - Slow path: AppexReferenceService.renderForExport

    @Test("AppexReferenceService.renderForExport returns a sized non-empty image for star.fill",
          .tags(.slow),
          .enabled(if: TestFilters.runSlowTests, "Slow test — run via Full.xctestplan (RUN_SLOW_TESTS=1)"))
    func appexReferenceService_renderForExport_starFill() throws {
        try #require(
            FileManager.default.fileExists(atPath: "/System/Library/ExtensionKit/Extensions/Storage.appex"),
            "Storage.appex must exist at its canonical macOS path for the appex pipeline to work"
        )

        let pointSize: CGFloat = 256
        let scaleFactor = 2
        let image = try AppexReferenceService.renderForExport(
            symbolName: "star.fill",
            enclosureColor: "blue",
            symbolColor: "white",
            pointSize: pointSize,
            scaleFactor: scaleFactor,
            colorSpace: .displayP3
        )

        #expect(image.size.width == pointSize)
        #expect(image.size.height == pointSize)

        // Output must have pixel dimensions pointSize * scaleFactor.
        let data = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: data))
        #expect(rep.pixelsWide == Int(pointSize) * scaleFactor)
        #expect(rep.pixelsHigh == Int(pointSize) * scaleFactor)

        // The returned image must be mostly opaque — a real appex render is
        // a filled chiclet with a glyph. If clearPixelFraction > 0.5 the
        // private pipeline returned a mostly-transparent placeholder icon,
        // which indicates a LaunchServices cache or Info.plist configuration
        // failure rather than a genuine render.
        let clear = IconRenderingAssertions.clearPixelFraction(
            in: image,
            rect: CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh)
        )
        #expect(clear < 0.5,
                "A real appex render of star.fill must be mostly opaque (clear fraction \(clear))")
    }
}
