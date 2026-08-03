// Tests for the shared rendering assertion helpers in IconRenderingAssertions.swift.
// These helpers are used by every structural render test, so correctness matters.

import Testing
import AppKit
@testable import Mica

@Suite("IconRenderingAssertions", .tags(.unit))
@MainActor
struct IconRenderingAssertionsTests {

    // MARK: - Helpers to build synthetic NSImages

    /// Returns a 100x100 image, fully transparent except for an opaque red
    /// rectangle at the given origin with the given size.
    static func makeImage(with rect: NSRect) -> NSImage {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        defer { image.unlockFocus() }
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        NSColor.red.setFill()
        rect.fill()
        return image
    }

    /// Returns a fully opaque solid-color image with the given per-quadrant colors.
    /// Quadrants laid out like a 2x2 grid: topLeft, topRight, bottomLeft, bottomRight.
    static func makeQuadrantImage(
        topLeft: NSColor,
        topRight: NSColor,
        bottomLeft: NSColor,
        bottomRight: NSColor,
        size: CGFloat = 100
    ) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }
        let half = size / 2
        topLeft.setFill();     NSRect(x: 0,    y: half, width: half, height: half).fill()
        topRight.setFill();    NSRect(x: half, y: half, width: half, height: half).fill()
        bottomLeft.setFill();  NSRect(x: 0,    y: 0,    width: half, height: half).fill()
        bottomRight.setFill(); NSRect(x: half, y: 0,    width: half, height: half).fill()
        return image
    }

    // MARK: - alphaBoundingBox

    @Test("alphaBoundingBox finds tight box around opaque pixels")
    func alphaBoundingBox_tight() throws {
        let image = Self.makeImage(with: NSRect(x: 20, y: 30, width: 40, height: 25))
        let box = try #require(IconRenderingAssertions.alphaBoundingBox(of: image))
        #expect(box.origin.x == 20)
        #expect(box.size.width == 40)
        #expect(box.size.height == 25)
        // Y origin varies by coordinate system convention; assert within 1px.
        #expect(abs(box.origin.y - 30) <= 1 || abs(box.origin.y - (100 - 30 - 25)) <= 1)
    }

    @Test("alphaBoundingBox returns nil for fully transparent image")
    func alphaBoundingBox_emptyWhenTransparent() throws {
        let image = NSImage(size: NSSize(width: 50, height: 50))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 50, height: 50).fill()
        image.unlockFocus()
        #expect(IconRenderingAssertions.alphaBoundingBox(of: image) == nil)
    }

    // MARK: - quadrantAverageColors

    @Test("quadrantAverageColors returns distinct per-quadrant colors for solid quads")
    func quadrantAverages_solidQuads() throws {
        let image = Self.makeQuadrantImage(
            topLeft: .red,
            topRight: .green,
            bottomLeft: .blue,
            bottomRight: .yellow
        )
        let avgs = try #require(IconRenderingAssertions.quadrantAverageColors(of: image))
        // Assert the dominant channel of each quadrant to avoid colorspace drift.
        #expect(avgs.topLeft.redComponent > 0.8 && avgs.topLeft.greenComponent < 0.2)
        #expect(avgs.topRight.greenComponent > 0.4 && avgs.topRight.redComponent < 0.4)
        #expect(avgs.bottomLeft.blueComponent > 0.8)
        #expect(avgs.bottomRight.redComponent > 0.8 && avgs.bottomRight.greenComponent > 0.8)
    }

    // MARK: - centroidOfNonClearPixels

    @Test("centroidOfNonClearPixels is near geometric center of a centered opaque rect")
    func centroid_centeredRect() throws {
        let image = Self.makeImage(with: NSRect(x: 40, y: 40, width: 20, height: 20))
        let centroid = try #require(IconRenderingAssertions.centroidOfNonClearPixels(in: image))
        // Geometric centroid of the opaque region is (50, 50).
        #expect(abs(centroid.x - 50) < 2)
        #expect(abs(centroid.y - 50) < 2)
    }

    @Test("centroidOfNonClearPixels offsets for off-center opaque rect")
    func centroid_offCenter() throws {
        // Opaque rect covers the right half: centroid should sit well right of 50.
        let image = Self.makeImage(with: NSRect(x: 50, y: 0, width: 50, height: 100))
        let centroid = try #require(IconRenderingAssertions.centroidOfNonClearPixels(in: image))
        #expect(centroid.x > 70)
        // Y-centroid should be near 50 (full vertical span).
        #expect(abs(centroid.y - 50) < 2)
    }

    // MARK: - cgColorSpaceName(of:)

    @Test("cgColorSpaceName returns the CGColorSpace name for an sRGB NSImage")
    func cgColorSpaceName_sRGB() throws {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = try #require(CGContext(
            data: nil, width: 8, height: 8,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let cg = try #require(ctx.makeImage())
        let image = NSImage(cgImage: cg, size: NSSize(width: 8, height: 8))

        let name = IconRenderingAssertions.cgColorSpaceName(of: image)
        let value = try #require(name)
        #expect(value == (CGColorSpace.sRGB as String),
                "sRGB CGImage must report its color-space name as kCGColorSpaceSRGB")
    }

    @Test("cgColorSpaceName returns the CGColorSpace name for a Display P3 NSImage")
    func cgColorSpaceName_displayP3() throws {
        let cs = CGColorSpace(name: CGColorSpace.displayP3)!
        let ctx = try #require(CGContext(
            data: nil, width: 8, height: 8,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let cg = try #require(ctx.makeImage())
        let image = NSImage(cgImage: cg, size: NSSize(width: 8, height: 8))

        let name = IconRenderingAssertions.cgColorSpaceName(of: image)
        let value = try #require(name)
        #expect(value == (CGColorSpace.displayP3 as String),
                "Display P3 CGImage must report its color-space name as kCGColorSpaceDisplayP3")
    }

    // MARK: - clearPixelFraction(in:rect:)

    @Test("clearPixelFraction returns 1.0 for a fully transparent image")
    func clearPixelFraction_fullyTransparent() {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        // NSImage with no drawing ops is fully transparent.
        let fraction = IconRenderingAssertions.clearPixelFraction(
            in: image,
            rect: CGRect(x: 0, y: 0, width: 16, height: 16)
        )
        #expect(fraction == 1.0,
                "Untouched 16x16 NSImage is fully transparent — every pixel must count as clear")
    }

    @Test("clearPixelFraction returns 0.0 for a fully opaque image")
    func clearPixelFraction_fullyOpaque() {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 16, height: 16).fill()
        image.unlockFocus()

        let fraction = IconRenderingAssertions.clearPixelFraction(
            in: image,
            rect: CGRect(x: 0, y: 0, width: 16, height: 16)
        )
        #expect(fraction == 0.0,
                "Solid red NSImage has no clear pixels — fraction must be 0.0")
    }

    @Test("clearPixelFraction restricts to the provided rect")
    func clearPixelFraction_honoursRect() {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.red.setFill()
        // Fill only the left half — right half stays transparent.
        NSRect(x: 0, y: 0, width: 8, height: 16).fill()
        image.unlockFocus()

        let leftFraction = IconRenderingAssertions.clearPixelFraction(
            in: image, rect: CGRect(x: 0, y: 0, width: 8, height: 16)
        )
        let rightFraction = IconRenderingAssertions.clearPixelFraction(
            in: image, rect: CGRect(x: 8, y: 0, width: 8, height: 16)
        )
        #expect(leftFraction == 0.0, "Left half is solid red")
        #expect(rightFraction == 1.0, "Right half is untouched")
    }

    // MARK: - fractionDiffering(in:rect:from:)

    @Test("fractionDiffering returns 0.0 for an image of exactly that colour")
    func fractionDiffering_matchingFill() {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 16, height: 16).fill()
        image.unlockFocus()

        #expect(IconRenderingAssertions.fractionDiffering(
            in: image, rect: CGRect(x: 0, y: 0, width: 16, height: 16), from: .white) == 0.0,
                "A solid white image must not differ from white anywhere")
    }

    // The fixtures below are 64pt rather than 16pt on purpose. `lockFocus` draws
    // into a Retina backing store, so `normalizedBitmapRep` downsamples 2:1 and
    // leaves a one-pixel blended seam along each internal edge — genuinely
    // "differing" from the reference, and correctly counted. At 16pt that seam was
    // 16 of 256 pixels and moved a quarter-area fill to 0.3125; at 64pt it is under
    // 2%, so a tolerance can be tight enough to mean something.

    @Test("fractionDiffering measures the part drawn over the reference colour")
    func fractionDiffering_measuresWhatWasDrawnOnTop() {
        let side: CGFloat = 64
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        NSColor.black.setFill()
        // A quarter of the area, drawn on top.
        NSRect(x: 0, y: 0, width: side / 2, height: side / 2).fill()
        image.unlockFocus()

        let fraction = IconRenderingAssertions.fractionDiffering(
            in: image, rect: CGRect(x: 0, y: 0, width: side, height: side), from: .white)
        #expect(abs(fraction - 0.25) < 0.03,
                "A quarter drawn in black over white should read as ≈0.25, got \(fraction)")
    }

    @Test("fractionDiffering counts transparency as differing from an opaque colour")
    func fractionDiffering_countsTransparency() {
        // The case that makes this usable on a rendered icon: the area outside the
        // artwork is clear, and clear is not white.
        let side: CGFloat = 64
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: side / 2, height: side).fill()
        image.unlockFocus()

        let fraction = IconRenderingAssertions.fractionDiffering(
            in: image, rect: CGRect(x: 0, y: 0, width: side, height: side), from: .white)
        #expect(abs(fraction - 0.5) < 0.03,
                "Half white, half transparent should read as ≈0.5, got \(fraction)")
    }

    @Test("fractionDiffering reports .nan rather than 0.0 when it cannot measure")
    func fractionDiffering_failsLoudly() {
        // A zero-sized rect cannot be measured. 0.0 would read as "no differences
        // found" — a silent pass — so the helper returns .nan, which fails any
        // comparison an assertion makes.
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()

        let fraction = IconRenderingAssertions.fractionDiffering(
            in: image, rect: .zero, from: .white)
        #expect(fraction.isNaN, "An unmeasurable rect must not read as 0.0, got \(fraction)")
    }
}
