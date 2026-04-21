// ImageImportServiceTests.swift
// ImageImportService exposes three public entry points. This suite
// covers:
//   - importFromURL(_:): image branch via a committed PNG fixture.
//   - importFromURL(_:): NSWorkspace fallback via a synthesized .txt file.
//   - extractFileIcon(from:): direct NSWorkspace call against Finder.app.
// importFromPasteboard() is deferred to Phase 6 UI tests (mutating
// NSPasteboard.general is side-effecting on the user's real clipboard).
// NSWorkspace-backed tests are tagged .slow so Default.xctestplan skips
// them; Full.xctestplan runs everything.

import Testing
import AppKit
import CoreGraphics
import Foundation
@testable import macOS_Icon_Generator_App

@Suite(.tags(.unit))
@MainActor
struct ImageImportServiceTests {

    // MARK: - Bundle + fixture helpers

    /// Marker class used to get a handle on the test bundle via Bundle(for:).
    /// Swift Testing structs can't be passed to Bundle(for:), so a class
    /// sentinel is required.
    private final class BundleMarker {}

    /// Resolve a PNG fixture committed under Support/TestFixtures/.
    /// PBXFileSystemSynchronizedRootGroup copies .png files into the
    /// test bundle's Copy Bundle Resources phase automatically; the exact
    /// subdirectory varies, so we probe both likely locations.
    static func fixtureURL(named name: String) throws -> URL {
        let bundle = Bundle(for: BundleMarker.self)
        let url = bundle.url(forResource: name, withExtension: "png")
            ?? bundle.url(forResource: name, withExtension: "png", subdirectory: "TestFixtures")
            ?? bundle.url(forResource: name, withExtension: "png", subdirectory: "Support/TestFixtures")
        guard let url else {
            throw NSError(
                domain: "ImageImportServiceTests",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Fixture \(name).png not found in test bundle. Confirm the file exists at " +
                        "macOS Icon Generator AppTests/Support/TestFixtures/\(name).png and that " +
                        "PBXFileSystemSynchronizedRootGroup is picking it up as a Copy Bundle Resource."
                ]
            )
        }
        return url
    }

    /// A fresh scratch directory per test with UUID suffix, cleaned up in deinit.
    /// Uses the test bundle's parent directory instead of temporary folders.
    final class TempDir {
        let url: URL

        init() {
            let baseURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
                .appendingPathComponent("macOS Icon Generator App Tests", isDirectory: true)
            try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            url = baseURL.appendingPathComponent(
                "ImageImportServiceTests-\(UUID().uuidString)",
                isDirectory: true
            )
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        deinit { try? FileManager.default.removeItem(at: url) }
    }

    /// The 8-byte PNG signature.
    static let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    static func startsWithPNGMagic(_ data: Data) -> Bool {
        guard data.count >= 8 else { return false }
        return Array(data.prefix(8)) == pngMagic
    }

    static func pixelSize(of image: NSImage) -> CGSize? {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        if let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        }
        return nil
    }

    static func normalizedBitmapData(from image: NSImage, targetSize: Int = 1024) throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let bytesPerRow = targetSize * 4
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
        let context = try #require(
            CGContext(
                data: nil,
                width: targetSize,
                height: targetSize,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            )
        )

        context.interpolationQuality = .high
        context.clear(CGRect(origin: .zero, size: CGSize(width: targetSize, height: targetSize)))

        let imageSize = image.size
        let targetSizeCG = CGFloat(targetSize)
        let scale = imageSize.width > 0 && imageSize.height > 0
            ? min(targetSizeCG / imageSize.width, targetSizeCG / imageSize.height)
            : 1.0
        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale
        let drawingRect = NSRect(
            x: (targetSizeCG - drawWidth) / 2,
            y: (targetSizeCG - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: drawingRect, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let normalized = try #require(context.makeImage())
        let provider = try #require(normalized.dataProvider)
        let providerData = try #require(provider.data)
        return providerData as Data
    }

    // MARK: - Fixture discovery sanity check

    @Test("Bundled fixture PNGs are discoverable via the test bundle")
    func fixtures_discoverable() throws {
        _ = try Self.fixtureURL(named: "test-icon")
        _ = try Self.fixtureURL(named: "test-badge")
    }

    // MARK: - importFromURL — image branch (fast)

    @Test("importFromURL accepts a PNG and flags isAppIcon=false")
    func importFromURL_png_returnsImage() throws {
        let url = try Self.fixtureURL(named: "test-icon")
        let result = try ImageImportService.importFromURL(url)

        #expect(result.isAppIcon == false,
                "NSImage(contentsOf:) succeeds for a PNG — extractFileIcon fallback must NOT run")
        #expect(result.sourceName == "test-icon.png")
        #expect(Self.startsWithPNGMagic(result.imageData),
                "imageData must be PNG-encoded after renderToData normalization")
    }

    @Test("importFromURL normalizes PNG output to 1024×1024")
    func importFromURL_png_normalizedDimensions() throws {
        let url = try Self.fixtureURL(named: "test-icon")
        let originalData = try Data(contentsOf: url)
        let result = try ImageImportService.importFromURL(url)

        let nsImage = try #require(result.nsImage,
                                   "ImportedImage.nsImage must decode the PNG payload")
        let pixelSize = try #require(Self.pixelSize(of: nsImage))
        // ImageImportService.renderToData hard-codes targetSize=1024.
        #expect(pixelSize.width == 1024)
        #expect(pixelSize.height == 1024)
        #expect(result.imageData != originalData,
                "The imported PNG should be re-rendered/normalized, not returned byte-for-byte")
    }

    @Test("importFromURL assigns a unique id to every call")
    func importFromURL_uniqueIDs() throws {
        let url = try Self.fixtureURL(named: "test-icon")
        let first = try ImageImportService.importFromURL(url)
        let second = try ImageImportService.importFromURL(url)
        #expect(first.id != second.id,
                "Each importFromURL invocation must generate a fresh UUID")
    }

    // MARK: - importFromURL — NSWorkspace fallback (slow)

    @Test("importFromURL falls back to extractFileIcon for a non-image file",
          .tags(.slow))
    func importFromURL_nonImage_fallsBackToIcon() throws {
        let temp = TempDir()
        let txtURL = temp.url.appendingPathComponent("hello.txt")
        try #require("hello world".data(using: .utf8)).write(to: txtURL)

        let result = try ImageImportService.importFromURL(txtURL)

        // NSImage(contentsOf:) fails for plain text; extractFileIcon runs.
        #expect(result.isAppIcon == true,
                "Non-image input must come back flagged isAppIcon (NSWorkspace-derived Finder icon)")
        #expect(result.sourceName == "hello.txt")
        #expect(Self.startsWithPNGMagic(result.imageData))

        let nsImage = try #require(result.nsImage)
        let pixelSize = try #require(Self.pixelSize(of: nsImage))
        #expect(pixelSize.width == 1024)
        #expect(pixelSize.height == 1024)

        let expectedBitmap = try Self.normalizedBitmapData(from: NSWorkspace.shared.icon(forFile: txtURL.path))
        let actualBitmap = try Self.normalizedBitmapData(from: nsImage)
        #expect(actualBitmap == expectedBitmap,
                "Fallback import should normalize the exact NSWorkspace file icon")
    }

    // MARK: - extractFileIcon (slow)

    @Test("extractFileIcon returns a PNG-normalized Finder icon",
          .tags(.slow))
    func extractFileIcon_forFinderApp() throws {
        let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder")
            ?? URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        guard FileManager.default.fileExists(atPath: finderURL.path) else {
            throw NSError(
                domain: "ImageImportServiceTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Finder.app must be present at its canonical macOS path"]
            )
        }

        let result = try ImageImportService.extractFileIcon(from: finderURL)

        #expect(result.isAppIcon == true)
        #expect(result.sourceName == "Finder.app")
        #expect(Self.startsWithPNGMagic(result.imageData))

        let nsImage = try #require(result.nsImage)
        let pixelSize = try #require(Self.pixelSize(of: nsImage))
        #expect(pixelSize.width == 1024)
        #expect(pixelSize.height == 1024)

        let expectedBitmap = try Self.normalizedBitmapData(from: NSWorkspace.shared.icon(forFile: finderURL.path))
        let actualBitmap = try Self.normalizedBitmapData(from: nsImage)
        #expect(actualBitmap == expectedBitmap,
                "extractFileIcon should normalize the exact Finder icon from NSWorkspace")
    }
}
