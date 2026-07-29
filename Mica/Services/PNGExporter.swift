// PNGExporter.swift - Shared PNG serialization for GUI and CLI exports
import AppKit
import UniformTypeIdentifiers
import ImageIO

/// Single source of truth for PNG encoding. Both the GUI (`PNGExportDocument`) and
/// the CLI (`IconGenerationRunner`) serialize through here so DPI metadata cannot
/// drift between the two interfaces.
enum PNGExporter {
    /// Encode `image` as PNG with DPI metadata derived from `scaleFactor`
    /// (72 DPI at 1x, 144 at 2x), including the PNG pHYs pixels-per-meter pair.
    static func pngData(from image: NSImage, scaleFactor: Int) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try pngData(from: cgImage, scaleFactor: scaleFactor)
    }

    static func pngData(from cgImage: CGImage, scaleFactor: Int) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let dpi = CGFloat(scaleFactor == 2 ? 144 : 72)
        let pixelsPerMeter = dpi / 0.0254
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyPNGXPixelsPerMeter: pixelsPerMeter,
                kCGImagePropertyPNGYPixelsPerMeter: pixelsPerMeter
            ]
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data as Data
    }
}
