// Services/ImageImportService.swift — Handles image import and app bundle icon extraction
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageImportError: LocalizedError {
    case failedToLoadImage(URL)
    case failedToExtractIcon(String)
    case failedToNormalize
    case unsupportedFileType(String)

    var errorDescription: String? {
        switch self {
        case .failedToLoadImage(let url): return "Failed to load image from \(url.lastPathComponent)"
        case .failedToExtractIcon(let name): return "Failed to extract icon from \(name)"
        case .failedToNormalize: return "Failed to normalize image to PNG"
        case .unsupportedFileType(let ext): return "Unsupported file type: \(ext)"
        }
    }
}

enum ImageImportService {

    // MARK: - Supported types

    static let allDropTypes: [UTType] = [.fileURL]

    // MARK: - Public API

    /// Import from any URL. If NSImage can load it, imports as an image;
    /// otherwise extracts the file's Finder icon via NSWorkspace.
    static func importFromURL(_ url: URL) throws -> ImportedImage {
        if let image = NSImage(contentsOf: url) {
            let data = try renderToData(image, targetSize: 1024)
            return ImportedImage(id: UUID(), imageData: data, sourceName: url.lastPathComponent, isAppIcon: false)
        }
        return try extractFileIcon(from: url)
    }

    /// Import from pasteboard image data (e.g. Cmd+V).
    /// Returns nil if the pasteboard contains no usable image.
    static func importFromPasteboard() throws -> ImportedImage? {
        let pasteboard = NSPasteboard.general

        // Try file URLs first — supports copied Finder files and app bundles
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], let url = urls.first {
            return try importFromURL(url)
        }

        // Try raw image data from pasteboard
        if let image = NSImage(pasteboard: pasteboard) {
            let data = try renderToData(image, targetSize: 1024)
            return ImportedImage(id: UUID(), imageData: data, sourceName: "Pasted Image", isAppIcon: false)
        }

        return nil
    }

    /// Extract the Finder icon for any file via NSWorkspace.
    static func extractFileIcon(from url: URL) throws -> ImportedImage {
        let iconImage = NSWorkspace.shared.icon(forFile: url.path)
        let data = try renderToData(iconImage, targetSize: 1024)
        return ImportedImage(id: UUID(), imageData: data, sourceName: url.lastPathComponent, isAppIcon: true)
    }

    /// Renders an NSImage into a CGContext at the target pixel size, returns PNG Data.
    /// Adapted from swiftIconTools/IconExtractor.renderCGImage + makePNGData.
    private static func renderToData(_ image: NSImage, targetSize: Int) throws -> Data {
        let pixelSize = targetSize
        let cgColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!

        let bytesPerRow = pixelSize * 4
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )

        guard let cgContext = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: cgColorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw ImageImportError.failedToNormalize
        }

        cgContext.interpolationQuality = .high
        cgContext.clear(CGRect(origin: .zero, size: CGSize(width: pixelSize, height: pixelSize)))

        // Determine drawing rect preserving aspect ratio
        let imageSize = image.size
        let targetSizeCG = CGFloat(targetSize)
        let scale: CGFloat
        if imageSize.width > 0 && imageSize.height > 0 {
            scale = min(targetSizeCG / imageSize.width, targetSizeCG / imageSize.height)
        } else {
            scale = 1.0
        }
        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale
        let drawX = (targetSizeCG - drawWidth) / 2
        let drawY = (targetSizeCG - drawHeight) / 2
        let drawingRect = NSRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: false)
        image.draw(in: drawingRect, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = cgContext.makeImage() else {
            throw ImageImportError.failedToNormalize
        }

        return try makePNGData(from: cgImage)
    }

    /// Converts a CGImage to PNG Data with DPI metadata via ImageIO.
    /// Adapted from swiftIconTools/IconExtractor.makePNGData.
    private static func makePNGData(from cgImage: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw ImageImportError.failedToNormalize
        }

        let dpi: CGFloat = 144
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
            throw ImageImportError.failedToNormalize
        }

        return data as Data
    }

}
