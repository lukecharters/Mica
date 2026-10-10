// ImportedImageFixtures.swift
// Shared ImportedImage fixtures. Several suites need an ImportedImage whose data
// actually decodes to an NSImage, because the render paths (and PreviewHitTester)
// gate on `nsImage != nil` rather than on the ImportedImage being present.

import AppKit
@testable import Mica

extension ImportedImage {
    /// A tiny solid-colour PNG wrapped in an ImportedImage. Keeps tests free of
    /// bundled asset dependencies.
    static func testFixture(
        width: Int = 4,
        height: Int = 4,
        fill: NSColor = .systemRed,
        sourceName: String = "fixture.png",
        isFileIcon: Bool = false
    ) throws -> ImportedImage {
        ImportedImage(
            id: UUID(),
            imageData: try pngData(width: width, height: height, fill: fill),
            sourceName: sourceName,
            isFileIcon: isFileIcon
        )
    }

    /// An app-icon-shaped image: a transparent canvas with an opaque square inset
    /// by `inset` of each side, the way the macOS icon grid places a chiclet.
    static func iconFixture(size: Int = 64, inset: Double = 0.1,
                            fill: NSColor = .systemBlue) throws -> ImportedImage {
        ImportedImage(
            id: UUID(),
            imageData: try pngData(width: size, height: size, fill: fill, inset: inset),
            sourceName: "icon-fixture.png",
            isFileIcon: false
        )
    }

    /// Solid-colour PNG bytes, filling the whole canvas or, with `inset`, a centred
    /// square that leaves that fraction of each side transparent.
    static func pngData(width: Int = 4, height: Int = 4, fill: NSColor = .systemRed,
                        inset: Double = 0) throws -> Data {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ) else {
            throw FixtureError.bitmapCreationFailed
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        fill.setFill()
        NSRect(x: 0, y: 0, width: width, height: height)
            .insetBy(dx: Double(width) * inset, dy: Double(height) * inset)
            .fill()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw FixtureError.pngEncodingFailed
        }
        return data
    }

    enum FixtureError: Error {
        case bitmapCreationFailed
        case pngEncodingFailed
    }
}
