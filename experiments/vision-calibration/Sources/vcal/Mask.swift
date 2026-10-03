import CoreGraphics
import Foundation

/// The white glyph pixels of an icon render, at `size`×`size`, row 0 at the top.
struct GlyphMask {
    static let size = 512

    let bits: [Bool]
    let count: Int
    let minX: Int, maxX: Int, minY: Int, maxY: Int
    let centroidX: Double, centroidY: Double

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
    var boxCentreX: Double { Double(minX + maxX) / 2 }
    var boxCentreY: Double { Double(minY + maxY) / 2 }

    /// Pixels per unit of the calibration offsets, which are fractions of the enclosure.
    static var enclosurePixels: Double {
        Double(IconGeometry.enclosure(forDisplaySize: CGFloat(size)))
    }

    init?(_ image: CGImage) {
        let n = Self.size
        guard let context = CGContext(
            data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: n, height: n))
        guard let data = context.data else { return nil }
        let pixels = data.assumingMemoryBound(to: UInt8.self)

        var bits = [Bool](repeating: false, count: n * n)
        var count = 0, minX = n, maxX = -1, minY = n, maxY = -1
        var sumX = 0.0, sumY = 0.0
        for y in 0..<n {
            for x in 0..<n {
                let i = (y * n + x) * 4
                let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
                // White glyph on a saturated blue enclosure: the red channel separates them.
                guard a > 200, min(r, g, b) > 175 else { continue }
                bits[y * n + x] = true
                count += 1
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                sumX += Double(x); sumY += Double(y)
            }
        }
        guard count > 0 else { return nil }
        self.bits = bits
        self.count = count
        self.minX = minX; self.maxX = maxX; self.minY = minY; self.maxY = maxY
        self.centroidX = sumX / Double(count)
        self.centroidY = sumY / Double(count)
    }

    func iou(_ other: GlyphMask) -> Double {
        var intersection = 0, union = 0
        for i in 0..<bits.count {
            let a = bits[i], b = other.bits[i]
            if a && b { intersection += 1 }
            if a || b { union += 1 }
        }
        return union == 0 ? 0 : Double(intersection) / Double(union)
    }
}

/// The pictures the model is shown.
enum Composite {
    enum View: String, CaseIterable {
        /// Reference glyph red, candidate cyan, overlap white, on black.
        case overlay
        /// The two icons side by side: reference left, candidate right.
        case pair
        /// Both of the above, as two attachments.
        case both
    }

    static func overlay(reference: GlyphMask, candidate: GlyphMask) -> CGImage {
        let n = GlyphMask.size
        var rgba = [UInt8](repeating: 0, count: n * n * 4)
        let inset = Int(Double(n) * IconGeometry.baseInset / IconGeometry.baseSize)
        for y in 0..<n {
            for x in 0..<n {
                let i = y * n + x
                let a = reference.bits[i], b = candidate.bits[i]
                var c: (UInt8, UInt8, UInt8)
                switch (a, b) {
                case (true, true): c = (255, 255, 255)
                case (true, false): c = (235, 40, 40)
                case (false, true): c = (0, 200, 255)
                default:
                    let onGuide = x == n / 2 || y == n / 2
                        || ((x == inset || x == n - inset) && (inset...(n - inset)).contains(y))
                        || ((y == inset || y == n - inset) && (inset...(n - inset)).contains(x))
                    c = onGuide ? (70, 70, 70) : (0, 0, 0)
                }
                rgba[i * 4] = c.0; rgba[i * 4 + 1] = c.1; rgba[i * 4 + 2] = c.2; rgba[i * 4 + 3] = 255
            }
        }
        return image(fromRGBA: rgba, width: n, height: n)
    }

    static func pair(reference: CGImage, candidate: CGImage) -> CGImage {
        let panel = GlyphMask.size, gap = 24
        let width = panel * 2 + gap
        let context = CGContext(
            data: nil, width: width, height: panel, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: 0.12, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: panel))
        context.interpolationQuality = .high
        for (index, image) in [reference, candidate].enumerated() {
            let originX = index * (panel + gap)
            context.draw(image, in: CGRect(x: originX, y: 0, width: panel, height: panel))
            context.setStrokeColor(CGColor(gray: 0, alpha: 0.35))
            context.setLineWidth(1)
            context.stroke(CGRect(x: originX + panel / 2, y: 0, width: 0, height: panel))
            context.stroke(CGRect(x: originX, y: panel / 2, width: panel, height: 0))
        }
        return context.makeImage()!
    }

    private static func image(fromRGBA rgba: [UInt8], width: Int, height: Int) -> CGImage {
        let provider = CGDataProvider(data: Data(rgba) as CFData)!
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }
}
