// Tests for the shared rendering assertion helpers in IconRenderingAssertions.swift.
// These helpers are used by every structural render test, so correctness matters.

import Testing
import AppKit
@testable import macOS_Icon_Generator_App

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
}
