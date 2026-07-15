// PNGExporterTests.swift
// The shared GUI/CLI PNG serializer must stamp DPI metadata matching the
// scale factor and preserve pixel dimensions exactly.

import Testing
import AppKit
import ImageIO
@testable import Mica

@Suite(.tags(.unit))
struct PNGExporterTests {

    private func makeImage(pixels: Int) throws -> NSImage {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.addRepresentation(rep)
        return image
    }

    private func pngProperties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    @Test("2x exports carry 144 DPI; 1x carry 72", arguments: [(1, 72.0), (2, 144.0)])
    func dpiMetadataMatchesScaleFactor(_ arg: (scaleFactor: Int, dpi: Double)) throws {
        let data = try PNGExporter.pngData(from: try makeImage(pixels: 64), scaleFactor: arg.scaleFactor)
        let properties = try pngProperties(of: data)

        let dpiWidth = try #require(properties[kCGImagePropertyDPIWidth] as? Double)
        let dpiHeight = try #require(properties[kCGImagePropertyDPIHeight] as? Double)
        #expect(abs(dpiWidth - arg.dpi) < 0.5, "DPI width \(dpiWidth) != \(arg.dpi) at \(arg.scaleFactor)x")
        #expect(abs(dpiHeight - arg.dpi) < 0.5, "DPI height \(dpiHeight) != \(arg.dpi) at \(arg.scaleFactor)x")
    }

    @Test("Pixel dimensions are preserved exactly")
    func pixelDimensionsPreserved() throws {
        let data = try PNGExporter.pngData(from: try makeImage(pixels: 577), scaleFactor: 2)
        let properties = try pngProperties(of: data)

        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 577)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 577)
    }
}
