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

    var errorDescription: String? {
        switch self {
        case .failedToLoadImage(let url): return "Failed to load image from \(url.lastPathComponent)"
        case .failedToExtractIcon(let name): return "Failed to extract icon from \(name)"
        case .failedToNormalize: return "Failed to normalize image to PNG"
        }
    }
}

enum ImageImportService {

    // MARK: - Supported types

    /// What the canvas declares to `.onDrop`, and therefore the only thing the
    /// importer is ever offered. `ScaledIconPreview` reads this rather than
    /// spelling a list of its own.
    ///
    /// It was `[.fileURL]` alone until 2026-08-05, and that — not format support
    /// — was where the limit sat: `importFromURL` reads anything `NSImage`
    /// handles and falls back to the Finder icon for everything else, so *any
    /// file at all* already imported as something. What never arrived was a drag
    /// carrying no file: image **data** or a file **promise**, which is what
    /// Safari, Photos, Preview and most export panels put on the pasteboard.
    /// Nothing reached the view, so the importer never ran. See B4 of
    /// `docs/plans/mac-conventions.md`.
    ///
    /// `.image` is the abstract supertype, so `public.png`, `public.tiff`,
    /// `public.jpeg`, HEIC and the rest are matched by conformance — listing
    /// them individually would be a second list to keep in step.
    ///
    /// **Deliberately not `.url`.** A Safari image drag also carries a *network*
    /// URL, and fetching one is a sandboxed network request with its own failure
    /// and progress story: a different feature from importing, not a wider type
    /// list.
    static let allDropTypes: [UTType] = [.fileURL, .image]

    /// Pixel budget for normalized imports (longest side of the stored PNG).
    static let normalizedMaxPixel = 1024

    // MARK: - Public API

    /// Import from any URL. Raster images decode through ImageIO's bounded
    /// thumbnail path; other drawable files (PDF, EPS) fall back to NSImage;
    /// everything else imports its Finder icon via NSWorkspace.
    static func importFromURL(_ url: URL) throws -> ImportedImage {
        // Bounded ImageIO decode: downsamples to ≤normalizedMaxPixel on the
        // longest side without materializing the full-resolution bitmap (a
        // 20,000px drop no longer allocates gigabytes), applies the EXIF
        // orientation tag, and never upscales small sources (upscale blur
        // would be baked permanently into the stored PNG).
        if let cgImage = boundedCGImage(at: url, maxPixel: normalizedMaxPixel) {
            let data = try renderToData(cgImage)
            return ImportedImage(id: UUID(), imageData: data, sourceName: url.lastPathComponent, isFileIcon: false)
        }
        // AppKit fallback for non-ImageIO formats NSImage can still draw
        // (PDF, EPS — vector-backed, so the full target size is safe).
        if let image = NSImage(contentsOf: url) {
            let data = try renderToData(image, targetSize: normalizedMaxPixel)
            return ImportedImage(id: UUID(), imageData: data, sourceName: url.lastPathComponent, isFileIcon: false)
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
            let data = try renderToData(image, targetSize: normalizedMaxPixel)
            return ImportedImage(id: UUID(), imageData: data, sourceName: "Pasted Image", isFileIcon: false)
        }

        return nil
    }

    /// Extract the Finder icon for any file via NSWorkspace. Everything that
    /// comes through here — app bundle or plain file — is a file *icon*, not
    /// the file's own image content, and is flagged as such.
    static func extractFileIcon(from url: URL) throws -> ImportedImage {
        let iconImage = NSWorkspace.shared.icon(forFile: url.path)
        let data = try renderToData(iconImage, targetSize: normalizedMaxPixel)
        return ImportedImage(id: UUID(), imageData: data, sourceName: url.lastPathComponent, isFileIcon: true)
    }

    // MARK: - Bounded decode

    /// Decode the image at `url` via ImageIO, bounded to `maxPixel` on its
    /// longest side, with the EXIF orientation applied. Never upscales.
    /// Returns nil when the file is not an ImageIO-readable raster image.
    private static func boundedCGImage(at url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // apply EXIF orientation
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Draw an already-bounded CGImage 1:1 onto a square transparent canvas
    /// (its longest side) and encode as PNG — no resampling of any kind.
    private static func renderToData(_ cgImage: CGImage) throws -> Data {
        let canvasSize = max(cgImage.width, cgImage.height)
        let cgColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )

        guard canvasSize > 0, let cgContext = CGContext(
            data: nil,
            width: canvasSize,
            height: canvasSize,
            bitsPerComponent: 8,
            bytesPerRow: canvasSize * 4,
            space: cgColorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw ImageImportError.failedToNormalize
        }

        cgContext.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
        let drawRect = CGRect(
            x: CGFloat(canvasSize - cgImage.width) / 2,
            y: CGFloat(canvasSize - cgImage.height) / 2,
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        )
        cgContext.draw(cgImage, in: drawRect)

        guard let normalized = cgContext.makeImage() else {
            throw ImageImportError.failedToNormalize
        }
        return try makePNGData(from: normalized)
    }

    /// Renders an NSImage into a CGContext at the target pixel size, returns PNG Data.
    /// Adapted from swiftIconTools/IconExtractor.renderCGImage + makePNGData.
    private static func renderToData(_ image: NSImage, targetSize: Int) throws -> Data {
        // Never upscale raster sources — the blur would be baked into the
        // stored PNG. Vector-backed images (PDF/EPS reps report 0 pixels)
        // keep the full target size.
        let nativeMax = image.representations
            .map { max($0.pixelsWide, $0.pixelsHigh) }
            .max() ?? 0
        let pixelSize = nativeMax > 0 ? min(targetSize, nativeMax) : targetSize
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
        let canvasSizeCG = CGFloat(pixelSize)
        let scale: CGFloat
        if imageSize.width > 0 && imageSize.height > 0 {
            scale = min(canvasSizeCG / imageSize.width, canvasSizeCG / imageSize.height)
        } else {
            scale = 1.0
        }
        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale
        let drawX = (canvasSizeCG - drawWidth) / 2
        let drawY = (canvasSizeCG - drawHeight) / 2
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
