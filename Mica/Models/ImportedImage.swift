// Models/ImportedImage.swift — imported image data
//
// `ForegroundSource`, which used to live here as `IconSource`, moved to
// IconSettings.swift with the other configuration enums (2026-07-28).

import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Holds a PNG-normalized imported image with metadata about its origin.
struct ImportedImage: Equatable {
    let id: UUID
    let imageData: Data
    let sourceName: String
    /// True when the image is a Finder icon extracted via NSWorkspace (an app
    /// bundle or any other non-image file), false when the source file's own
    /// pixels were imported. Drives the "Icon"/"Image" label in the UI.
    let isFileIcon: Bool
    /// True when every edge of the image is transparent — the margin the macOS
    /// icon grid leaves around an app icon's chiclet. Decides the background
    /// import defaults: an app icon gets padding compensation with its shadow and
    /// corners off, artwork that reaches its edges keeps both. Data that does not
    /// decode reads as an app icon.
    let hasIconMargin: Bool

    init(id: UUID, imageData: Data, sourceName: String, isFileIcon: Bool) {
        self.id = id
        self.imageData = imageData
        self.sourceName = sourceName
        self.isFileIcon = isFileIcon
        self.hasIconMargin = Self.detectsIconMargin(in: imageData)
    }

    var nsImage: NSImage? { NSImage(data: imageData) }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Icon margin

    /// The band checked on each side, as a fraction of that side. Native icons
    /// put the chiclet 9.8% in and their baked-in shadow reaches 6.5% in.
    static let iconMarginBand: CGFloat = 0.04

    /// The highest alpha, out of 255, a margin pixel may carry.
    static let iconMarginAlphaTolerance: UInt8 = 4

    static func detectsIconMargin(in data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0, image.height > 0 else { return true }
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return true }

        let bandX = max(1, Int(CGFloat(width) * iconMarginBand))
        let bandY = max(1, Int(CGFloat(height) * iconMarginBand))
        for y in 0..<height {
            let inRowBand = y < bandY || y >= height - bandY
            for x in 0..<width where inRowBand || x < bandX || x >= width - bandX {
                if pixels[y * bytesPerRow + x * 4 + 3] > iconMarginAlphaTolerance {
                    return false
                }
            }
        }
        return true
    }
}
