// ImportedIconPaddingCompensationTests.swift
// Regression tests for the "Icon Padding" compensation factor applied to
// imported macOS file icons (ImportedImageGeometry.paddingCompensationFactor).
//
// A native macOS icon's chiclet occupies 824 of its 1024-pixel canvas. When a
// Finder/app icon is imported as a background with padding compensation on,
// the render must scale it by exactly 1024/824 so the icon fills the canvas
// and the export matches `mica-cli extract` pixel-for-pixel. The original bug:
// an eyeballed 1.22 factor shrank imported icons by ~1.8% (≈7 px at 512pt)
// relative to extraction tools.
//
// The tests use a synthetic "app icon" — a transparent 1024px canvas with an
// opaque centered 824px square chiclet — so expected alpha bounds are exact.

import Testing
import AppKit
import CoreGraphics
@testable import Mica

@Suite(.tags(.rendering))
@MainActor
struct ImportedIconPaddingCompensationTests {

    // MARK: - Helpers

    /// Fake macOS app icon: transparent canvas with an opaque, centered,
    /// axis-aligned square chiclet at the native icon-grid ratio (824/1024).
    static func syntheticAppIconPNG(canvas: Int = 1024, chiclet: Int = 824) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: canvas,
            pixelsHigh: canvas,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: canvas * 4,
            bitsPerPixel: 32
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()
        NSColor.systemGreen.setFill()
        let inset = CGFloat(canvas - chiclet) / 2
        NSRect(x: inset, y: inset, width: CGFloat(chiclet), height: CGFloat(chiclet)).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    static func makeImportedFileIcon() throws -> ImportedImage {
        let data = try #require(Self.syntheticAppIconPNG(),
                                "Failed to synthesize app-icon PNG fixture")
        return ImportedImage(id: UUID(), imageData: data,
                             sourceName: "Fake.app", isFileIcon: true)
    }

    /// The macOS icon-grid chiclet fraction the synthetic icon is built with.
    static let chicletFraction: CGFloat = 824.0 / 1024.0

    /// Antialiasing/interpolation spill allowance on each measured dimension.
    static let tolerance: CGFloat = 3

    // MARK: - Constant

    @Test("Padding compensation factor is exactly the inverse of the icon-grid chiclet fraction")
    func compensationFactor_isInverseOfChicletFraction() {
        #expect(abs(ImportedImageGeometry.paddingCompensationFactor * Self.chicletFraction - 1.0) < 0.0001,
                "Factor (\(ImportedImageGeometry.paddingCompensationFactor)) must be 1024/824 so a native icon's chiclet fills the target frame")
    }

    // MARK: - Icon background path (drag an app into Mica)

    /// The original bug report: a 512pt @2x export of a dropped app icon came
    /// out ~7 px smaller than `mica-cli extract`. With compensation on, the
    /// imported icon must fill the full canvas, so its chiclet must occupy the
    /// same fraction of the export as it does of its own source canvas.
    @Test("Imported file icon fills the full canvas, matching extract",
          arguments: [(size: CGFloat(512), retina: true), (size: CGFloat(1024), retina: false)])
    func importedIconBackground_fillsCanvas(_ arg: (size: CGFloat, retina: Bool)) throws {
        var settings = IconSettings()
        settings.applyImportedIconBackground(try Self.makeImportedFileIcon())
        settings.showBadge = false
        settings.exportSize = arg.size
        settings.exportRetinaSize = arg.retina

        let image = IconRenderer.renderIconSafely(settings: settings)

        // alphaBoundingBox measures in logical points (image.size), which equals
        // exportSize regardless of retina.
        let bbox = try #require(IconRenderingAssertions.alphaBoundingBox(of: image),
                                "Imported background must render non-empty content")

        let expected = arg.size * Self.chicletFraction
        #expect(abs(bbox.width - expected) <= Self.tolerance,
                "Chiclet width must be \(expected) (source fraction preserved → full-canvas fill); got \(bbox.width). The pre-fix 1.22 factor produced ≈\(expected * 1.22 / (1024.0 / 824.0)).")
        #expect(abs(bbox.height - expected) <= Self.tolerance,
                "Chiclet height must be \(expected); got \(bbox.height)")

        // Extract parity also requires the content to stay centered.
        #expect(abs(bbox.midX - image.size.width / 2) <= Self.tolerance,
                "Chiclet must be horizontally centered; midX \(bbox.midX) vs \(image.size.width / 2)")
        #expect(abs(bbox.midY - image.size.height / 2) <= Self.tolerance,
                "Chiclet must be vertically centered; midY \(bbox.midY) vs \(image.size.height / 2)")
    }

    // MARK: - Badge background path (imported icon as badge)

    /// Same factor on the badge layer: with compensation on, the imported
    /// icon's chiclet must exactly fill the badge frame (badgeSize).
    @Test("Imported badge background chiclet fills the badge frame")
    func importedBadgeBackground_chicletFillsBadgeFrame() throws {
        var settings = IconSettings()
        settings.applyImportedBadgeBackground(try Self.makeImportedFileIcon())
        settings.showBadge = true
        settings.iconBackgroundHidden = true
        settings.iconForegroundHidden = true
        settings.exportSize = 1024
        settings.exportRetinaSize = false

        let image = IconRenderer.renderIconSafely(settings: settings)

        let bbox = try #require(IconRenderingAssertions.alphaBoundingBox(of: image),
                                "Badge imported background must render non-empty content")

        // At exportSize 1024: enclosure = 1024 − 2·100 = 824,
        // badgeSize = 824 · (80/208) · badgeScale.
        let enclosureSize: CGFloat = 1024 - 2 * (25 * 1024 / 256)
        let badgeSize = BadgeGeometry.diameter(enclosureSize: enclosureSize,
                                               badgeScale: settings.badgeScale)
        #expect(abs(bbox.width - badgeSize) <= Self.tolerance,
                "Badge chiclet width must equal badgeSize (\(badgeSize)); got \(bbox.width)")
        #expect(abs(bbox.height - badgeSize) <= Self.tolerance,
                "Badge chiclet height must equal badgeSize (\(badgeSize)); got \(bbox.height)")
    }
}
