// Pure-function helpers used by the rendering structural test suites
// (Phase 4 adds the suites). Kept dependency-free and synchronous so
// every call site can use them from parameterised tests.

import AppKit
import CoreGraphics

enum IconRenderingAssertions {

    struct QuadrantAverages: Sendable {
        let topLeft: NSColor
        let topRight: NSColor
        let bottomLeft: NSColor
        let bottomRight: NSColor
    }

    /// Smallest axis-aligned rect enclosing every pixel with alpha > 0.
    /// Returns nil when the image is fully transparent.
    static func alphaBoundingBox(of image: NSImage) -> CGRect? {
        guard let rep = normalizedBitmapRep(for: image) else { return nil }
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        var minX = width, minY = height, maxX = -1, maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                if color.alphaComponent > 0.5 {
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX + 1),
            height: CGFloat(maxY - minY + 1)
        )
    }

    /// Averages the RGB(A) channels of each quadrant of the image.
    static func quadrantAverageColors(of image: NSImage) -> QuadrantAverages? {
        guard let rep = normalizedBitmapRep(for: image) else { return nil }
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        let halfW = w / 2
        let halfH = h / 2
        // normalizedBitmapRep uses a top-left-origin CGContext, so row 0 = visual top.
        // NSImage is drawn with bottom-origin into the context (drawingHandler flips).
        // We split at the pixel midpoint to match logical quadrant centres.
        let tl = averageColor(rep: rep, x0: 0,     y0: 0,     x1: halfW, y1: halfH)
        let tr = averageColor(rep: rep, x0: halfW, y0: 0,     x1: w,     y1: halfH)
        let bl = averageColor(rep: rep, x0: 0,     y0: halfH, x1: halfW, y1: h)
        let br = averageColor(rep: rep, x0: halfW, y0: halfH, x1: w,     y1: h)
        guard let tl, let tr, let bl, let br else { return nil }
        return QuadrantAverages(topLeft: tl, topRight: tr, bottomLeft: bl, bottomRight: br)
    }

    /// Intensity-weighted centroid of alpha > 0 pixels, in the image's
    /// NSImage coordinate system (y grows upwards).
    static func centroidOfNonClearPixels(in image: NSImage) -> CGPoint? {
        guard let rep = normalizedBitmapRep(for: image) else { return nil }
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        var sumX: Double = 0, sumY: Double = 0, count: Double = 0
        for y in 0..<h {
            for x in 0..<w {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                if color.alphaComponent > 0.5 {
                    sumX += Double(x)
                    sumY += Double(y)
                    count += 1
                }
            }
        }
        guard count > 0 else { return nil }
        let avgX = sumX / count
        // Flip y to match AppKit bottom-origin convention.
        let avgY = Double(h) - (sumY / count)
        return CGPoint(x: avgX, y: avgY)
    }

    // MARK: - Private

    /// Renders the image at 1:1 (1 point = 1 pixel) into a known-format RGBA8
    /// bitmap. This avoids Retina scale-factor ambiguity when accessing pixels.
    private static func normalizedBitmapRep(for image: NSImage) -> NSBitmapImageRep? {
        let w = Int(image.size.width)
        let h = Int(image.size.height)
        guard w > 0, h > 0 else { return nil }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: w * 4,
            bitsPerPixel: 32
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        // Clear to transparent.
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: w, height: h).fill()
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func averageColor(
        rep: NSBitmapImageRep,
        x0: Int, y0: Int, x1: Int, y1: Int
    ) -> NSColor? {
        var rSum = 0.0, gSum = 0.0, bSum = 0.0, aSum = 0.0, n = 0.0
        for y in y0..<y1 {
            for x in x0..<x1 {
                guard let c = rep.colorAt(x: x, y: y) else { continue }
                rSum += Double(c.redComponent)
                gSum += Double(c.greenComponent)
                bSum += Double(c.blueComponent)
                aSum += Double(c.alphaComponent)
                n += 1
            }
        }
        guard n > 0 else { return nil }
        return NSColor(
            calibratedRed: CGFloat(rSum / n),
            green: CGFloat(gSum / n),
            blue: CGFloat(bSum / n),
            alpha: CGFloat(aSum / n)
        )
    }
}
