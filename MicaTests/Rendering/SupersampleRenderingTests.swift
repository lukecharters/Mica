// SupersampleRenderingTests.swift
// Exports below 1024px render at an integer multiple ≥1024 and are downsampled
// (IconRenderer.supersampleFactor). This keeps the mismatch between shape-frame
// pixel snapping and Core Text glyph-origin rounding sub-pixel in the output
// (visible as an off-centre badge symbol at small 1x sizes). These tests pin
// the factor rule and verify supersampling never changes the delivered pixel
// dimensions or logical (DPI) size.

import Testing
import AppKit
@testable import Mica

@Suite(.tags(.rendering))
struct SupersampleRenderingTests {

    // MARK: - Factor rule

    @Test("Factor is the smallest integer multiple reaching 1024")
    func factorRule() {
        #expect(IconRenderer.supersampleFactor(forPixelSize: 1024) == 1)
        #expect(IconRenderer.supersampleFactor(forPixelSize: 2048) == 1)
        #expect(IconRenderer.supersampleFactor(forPixelSize: 1023) == 2)
        #expect(IconRenderer.supersampleFactor(forPixelSize: 512) == 2)
        #expect(IconRenderer.supersampleFactor(forPixelSize: 400) == 3)
        #expect(IconRenderer.supersampleFactor(forPixelSize: 300) == 4)
        #expect(IconRenderer.supersampleFactor(forPixelSize: 256) == 4)
        #expect(IconRenderer.supersampleFactor(forPixelSize: 128) == 8)
        #expect(IconRenderer.supersampleFactor(forPixelSize: 100) == 11)
    }

    @Test("Degenerate pixel sizes fall back to no supersampling")
    func degenerateSizes() {
        #expect(IconRenderer.supersampleFactor(forPixelSize: 0) == 1)
        #expect(IconRenderer.supersampleFactor(forPixelSize: -256) == 1)
    }

    // MARK: - Output dimensions are unchanged by supersampling

    @Test("Badged export pixel dimensions equal the requested size",
          arguments: [128.0, 256.0, 300.0, 512.0])
    @MainActor
    func badgedExportDimensions(size: Double) throws {
        var settings = IconSettings()
        settings.exportSize = size
        settings.exportRetinaSize = false
        settings.showBadge = true

        let image = IconRenderer.renderIcon(settings: settings)
        let rep = try #require(image.representations.first as? NSBitmapImageRep)
        #expect(rep.pixelsWide == Int(size),
                "Pixel width must equal requested size \(Int(size)), got \(rep.pixelsWide)")
        #expect(rep.pixelsHigh == Int(size),
                "Pixel height must equal requested size \(Int(size)), got \(rep.pixelsHigh)")
    }

    @Test("Retina badged export keeps 2x raster and 1x logical size")
    @MainActor
    func retinaBadgedExport() throws {
        var settings = IconSettings()
        settings.exportSize = 256
        settings.exportRetinaSize = true
        settings.showBadge = true

        let image = IconRenderer.renderIcon(settings: settings)
        let rep = try #require(image.representations.first as? NSBitmapImageRep)
        #expect(rep.pixelsWide == 512)
        #expect(rep.pixelsHigh == 512)
        #expect(rep.size.width == 256)
        #expect(rep.size.height == 256)
    }

    @Test("Appex composite with badge keeps requested pixel dimensions")
    @MainActor
    func appexCompositeDimensions() throws {
        var settings = IconSettings()
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.showBadge = true

        let appexImage = AppexRenderingStructuralTests.solidColorImage(.red, size: 256)
        let image = IconRenderer.renderAppexWithBadge(appexImage: appexImage, settings: settings)
        let rep = try #require(image.representations.first as? NSBitmapImageRep)
        let expectedCanvas = settings.finalExportSize
        // ±1px: the supersampled raster is reduced by its integer factor and
        // rounded.
        #expect(abs(Double(rep.pixelsWide) - Double(expectedCanvas)) <= 1)
        #expect(abs(Double(rep.pixelsHigh) - Double(expectedCanvas)) <= 1)
    }
}
