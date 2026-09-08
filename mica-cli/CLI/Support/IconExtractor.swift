import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IconExtractor {
    /// Wider than `ExportSpec`'s 16–1024 because an extracted icon is a copy of
    /// something macOS already drew at up to 1024pt and the 2x scale doubles it.
    /// Bounded at all because the pixel size feeds a bitmap allocation and a row
    /// stride, and neither survives an arbitrary value.
    static let sizeRange = 16...2048

    static func saveIcon(
        forBundleAt bundlePath: String,
        size: Int,
        scaleFactor: Int,
        colorSpace: ExportColorSpace,
        destination: URL
    ) throws {
        guard sizeRange.contains(size) else {
            throw CLIError.invalidArgument("Size must be between \(sizeRange.lowerBound) and \(sizeRange.upperBound) (received \(size))")
        }

        guard scaleFactor == 1 || scaleFactor == 2 else {
            throw CLIError.invalidArgument("--scale must be 1x or 2x (received \(scaleFactor))")
        }

        let pixelSize = size * scaleFactor
        let cgImage = try renderCGImage(
            bundlePath: bundlePath,
            pixelSize: pixelSize,
            scaleFactor: scaleFactor,
            colorSpace: colorSpace
        )
        let pngData = try makePNGData(from: cgImage, scaleFactor: scaleFactor, bundlePath: bundlePath)

        do {
            let directoryURL = destination.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            try pngData.write(to: destination, options: Data.WritingOptions.atomic)
        } catch {
            throw CLIError.fileSystem("Failed to write icon to \(destination.path): \(error.localizedDescription)")
        }
    }

    private static func renderCGImage(
        bundlePath: String,
        pixelSize: Int,
        scaleFactor: Int,
        colorSpace: ExportColorSpace
    ) throws -> CGImage {
        let pointsPerSide = CGFloat(pixelSize) / CGFloat(scaleFactor)
        let drawingSize = CGSize(width: pointsPerSide, height: pointsPerSide)
        let nsDrawingRect = NSRect(origin: .zero, size: NSSize(width: drawingSize.width, height: drawingSize.height))

        guard let iconImage = NSWorkspace.shared.icon(forFile: bundlePath).copy() as? NSImage else {
            throw CLIError.renderingError("Failed to render icon for \(bundlePath)")
        }

        let cgColorSpace = colorSpace.cgColorSpace

        let bytesPerRow = pixelSize * 4
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))

        guard let cgContext = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: cgColorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw CLIError.renderingError("Failed to render icon for \(bundlePath)")
        }

        cgContext.interpolationQuality = CGInterpolationQuality.high
        cgContext.setFillColorSpace(cgColorSpace)
        cgContext.setStrokeColorSpace(cgColorSpace)
        cgContext.clear(CGRect(origin: .zero, size: CGSize(width: CGFloat(pixelSize), height: CGFloat(pixelSize))))
        let scale = CGFloat(scaleFactor)
        cgContext.scaleBy(x: scale, y: scale)

        NSGraphicsContext.saveGraphicsState()
        let graphicsContext = NSGraphicsContext(cgContext: cgContext, flipped: false)
        NSGraphicsContext.current = graphicsContext
        iconImage.size = nsDrawingRect.size
        iconImage.draw(in: nsDrawingRect, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = cgContext.makeImage() else {
            throw CLIError.renderingError("Failed to render icon for \(bundlePath)")
        }

        return cgImage
    }

    private static func makePNGData(from cgImage: CGImage, scaleFactor: Int, bundlePath: String) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw CLIError.renderingError("Failed to render icon for \(bundlePath)")
        }

        let dpi = CGFloat(scaleFactor == 2 ? 144 : 72)
        let pixelsPerMeter = dpi / 0.0254
        let pngProperties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyPNGXPixelsPerMeter: pixelsPerMeter,
                kCGImagePropertyPNGYPixelsPerMeter: pixelsPerMeter
            ]
        ]
        CGImageDestinationAddImage(destination, cgImage, pngProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CLIError.renderingError("Failed to render icon for \(bundlePath)")
        }

        return data as Data
    }
}
