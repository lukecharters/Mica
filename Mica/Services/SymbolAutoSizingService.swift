// SymbolAutoSizingService.swift - Automated SF Symbol sizing via tight-bounds box-fit
//
// Implements the empirically recovered default sizing rule used by Apple's
// appex icon pipeline for symbols without a hand-tuned container recipe:
//
//     multiplier = clamp(min(0.77 / th, 0.79 / tw), 0.43, 0.65)
//
// where tw/th are the symbol's tight (alpha-scanned) content extents rendered
// at the 100pt reference size, as fractions of that reference. Validated
// against symbol-calibration.json ground truth at 0.38% median relative error
// (73% exact to ±0.01) on the 4,432 calibrated symbols outside
// container_recipes.plist. See research/automated-sizing-and-system-resources-2026-07.md.
//
// Badge composites (`x.badge.y`) are calibrated systematically smaller than
// the general rule predicts; they use factors refit on the 527 calibrated
// badge variants (0.75/0.74, same clamps), halving their prediction error
// (MAE 0.030 -> 0.020).

import AppKit

// MARK: - Tight Bounds

/// Tight content bounds of a symbol rendered at the reference point size.
/// All values are in points at `SymbolTightBounds.referencePointSize`.
struct SymbolTightBounds: Codable, Equatable, Sendable {
    /// Tight content width/height (first to last opaque pixel).
    var tightWidth: Double
    var tightHeight: Double
    /// Content-center offset from the typographic frame center.
    /// Positive x = content sits right of center; positive y = below center.
    var centerXOffset: Double
    var centerYOffset: Double
    /// Typographic frame (NSImage.size).
    var frameWidth: Double
    var frameHeight: Double

    static let referencePointSize: Double = 100
}

// MARK: - Service

enum SymbolAutoSizingService {
    // Box-fit rule constants (fitted against symbol-calibration ground truth, on bounds measured at regular weight).
    static let heightFactor = 0.77
    static let widthFactor = 0.79
    // Badge-composite refit (see header note).
    static let badgeHeightFactor = 0.75
    static let badgeWidthFactor = 0.74
    static let minMultiplier = 0.43
    static let maxMultiplier = 0.65

    /// True for badge composites — a `badge` component after the base name
    /// (`folder.badge.plus` yes, `badge.plus.radiowaves.forward` no).
    static func isBadgeVariant(_ name: String) -> Bool {
        name.split(separator: ".").dropFirst().contains("badge")
    }

    /// Applies the box-fit rule to measured tight bounds.
    static func multiplier(for bounds: SymbolTightBounds, isBadge: Bool = false) -> Double {
        let ref = SymbolTightBounds.referencePointSize
        let th = bounds.tightHeight / ref
        let tw = bounds.tightWidth / ref
        guard th > 0, tw > 0 else { return maxMultiplier }
        let raw = rawFit(th: th, tw: tw, isBadge: isBadge)
        return min(max(raw, minMultiplier), maxMultiplier)
    }

    private static func rawFit(th: Double, tw: Double, isBadge: Bool) -> Double {
        min((isBadge ? badgeHeightFactor : heightFactor) / th,
            (isBadge ? badgeWidthFactor : widthFactor) / tw)
    }

    // MARK: - Tight-Bounds Measurement

    /// Renders the symbol at the reference size and alpha-scans for tight
    /// content bounds. Returns nil for unknown symbols or empty renders.
    ///
    /// Note: symbol images silently render nothing into an alpha-only
    /// CGContext — an RGBA context with alpha-channel scanning is required.
    static func measureTightBounds(symbol name: String, weight: NSFont.Weight = SymbolCalibrationEntry.defaultMeasurementWeight) -> SymbolTightBounds? {
        let config = NSImage.SymbolConfiguration(
            pointSize: SymbolTightBounds.referencePointSize, weight: weight)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }

        let size = image.size
        let pw = Int(ceil(size.width)), ph = Int(ceil(size.height))
        guard pw > 0, ph > 0,
              let ctx = CGContext(
                  data: nil, width: pw, height: ph,
                  bitsPerComponent: 8, bytesPerRow: pw * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        let gctx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gctx
        image.draw(in: CGRect(x: 0, y: 0, width: CGFloat(pw), height: CGFloat(ph)))
        NSGraphicsContext.restoreGraphicsState()

        guard let data = ctx.data else { return nil }
        let buf = data.bindMemory(to: UInt8.self, capacity: pw * ph * 4)
        var minX = pw, maxX = -1, minY = ph, maxY = -1
        for y in 0..<ph {
            let row = y * pw * 4
            for x in 0..<pw where buf[row + x * 4 + 3] > 8 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= 0 else { return nil }

        // Bitmap buffer row 0 is the visual top, so a positive centerYOffset
        // means the content sits visually below the frame center.
        return SymbolTightBounds(
            tightWidth: Double(maxX - minX + 1),
            tightHeight: Double(maxY - minY + 1),
            centerXOffset: Double(minX + maxX + 1) / 2 - Double(pw) / 2,
            centerYOffset: Double(minY + maxY + 1) / 2 - Double(ph) / 2,
            frameWidth: Double(size.width),
            frameHeight: Double(size.height)
        )
    }
}
