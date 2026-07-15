// ColorSpaceConversionTests.swift
// Pixel-fidelity regression tests for IconRenderer.convertToColorSpace.

import Testing
import AppKit
@testable import Mica

@Suite(.tags(.rendering))
struct ColorSpaceConversionTests {

    /// Regression: badge overflow can yield fractional logical canvas sizes
    /// (e.g. 552.7pt for a 553px bitmap). Conversion must size its context from
    /// the bitmap's pixel dimensions — truncating the point size resampled the
    /// whole image into a context 1px smaller on every export.
    @Test("Fractional logical size keeps exact pixel dimensions",
          arguments: [ExportColorSpace.sRGB, .displayP3])
    func fractionalSize_keepsPixelDimensions(_ colorSpace: ExportColorSpace) throws {
        let pixelDim = 553
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelDim,
            pixelsHigh: pixelDim,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let image = NSImage(size: NSSize(width: 552.7, height: 552.7))
        image.addRepresentation(rep)

        let converted = IconRenderer.convertToColorSpace(image: image, colorSpace: colorSpace)
        let cgImage = try #require(converted.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(cgImage.width == pixelDim,
                "Conversion must preserve pixel width (got \(cgImage.width), want \(pixelDim))")
        #expect(cgImage.height == pixelDim,
                "Conversion must preserve pixel height (got \(cgImage.height), want \(pixelDim))")
    }
}
