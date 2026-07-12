// SymbolAutoSizingService.swift - Automated SF Symbol sizing via tight-bounds box-fit
//
// Implements the empirically recovered default sizing rule used by Apple's
// appex icon pipeline for symbols without a hand-tuned container recipe:
//
//     multiplier = clamp(min(0.77 / th, 0.79 / tw), 0.43, 0.65)
//
// where tw/th are the symbol's tight (alpha-scanned) content extents rendered
// at the 100pt reference size, as fractions of that reference. Validated
// against family-calibration.json ground truth at 0.38% median relative error
// (73% exact to ±0.01) on the 4,432 calibrated symbols outside
// container_recipes.plist. See research/automated-sizing-and-system-resources-2026-07.md.

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

// MARK: - Prediction

struct AutoSizingPrediction: Sendable {
    var multiplier: Double
    /// Content-centering hint for the Y offset (normalized enclosure fraction,
    /// same units as FamilyCalEntry.yOffset). Advisory only — offsets are
    /// partly optical and shouldn't be applied blindly.
    var suggestedYOffset: Double
    var bounds: SymbolTightBounds
    /// True when the multiplier hit the clamp, meaning the rule had less
    /// confidence for this shape (very wide/tall or very compact symbols).
    var isClamped: Bool
}

// MARK: - Service

enum SymbolAutoSizingService {
    // Box-fit rule constants (fitted against family-calibration ground truth).
    static let heightFactor = 0.77
    static let widthFactor = 0.79
    static let minMultiplier = 0.43
    static let maxMultiplier = 0.65
    /// Global linear coefficient relating measured content-center offset to
    /// calibrated yOffset (fitted; r = -0.61).
    static let yOffsetCoefficient = -0.78

    /// Applies the box-fit rule to measured tight bounds.
    static func multiplier(for bounds: SymbolTightBounds) -> Double {
        let ref = SymbolTightBounds.referencePointSize
        let th = bounds.tightHeight / ref
        let tw = bounds.tightWidth / ref
        guard th > 0, tw > 0 else { return maxMultiplier }
        let raw = min(heightFactor / th, widthFactor / tw)
        return min(max(raw, minMultiplier), maxMultiplier)
    }

    static func prediction(for bounds: SymbolTightBounds) -> AutoSizingPrediction {
        let mul = multiplier(for: bounds)
        let ref = SymbolTightBounds.referencePointSize
        let raw = bounds.tightHeight > 0 && bounds.tightWidth > 0
            ? min(heightFactor / (bounds.tightHeight / ref), widthFactor / (bounds.tightWidth / ref))
            : maxMultiplier
        return AutoSizingPrediction(
            multiplier: mul,
            suggestedYOffset: yOffsetCoefficient * bounds.centerYOffset / ref,
            bounds: bounds,
            isClamped: raw < minMultiplier || raw > maxMultiplier
        )
    }

    /// Measures a symbol's tight content bounds and returns the full prediction.
    static func prediction(forSymbol name: String, weight: NSFont.Weight = .regular) -> AutoSizingPrediction? {
        guard let bounds = measureTightBounds(symbol: name, weight: weight) else { return nil }
        return prediction(for: bounds)
    }

    // MARK: - Tight-Bounds Measurement

    /// Renders the symbol at the reference size and alpha-scans for tight
    /// content bounds. Returns nil for unknown symbols or empty renders.
    ///
    /// Note: symbol images silently render nothing into an alpha-only
    /// CGContext — an RGBA context with alpha-channel scanning is required.
    static func measureTightBounds(symbol name: String, weight: NSFont.Weight = .regular) -> SymbolTightBounds? {
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
        // means the content sits visually below the frame center — the same
        // convention `yOffsetCoefficient` was fitted with.
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

// MARK: - Container Recipe Catalog

/// Reads Apple's hand-tuned symbol list from the live system
/// container_recipes.plist. Membership marks symbols whose appex sizing is
/// individually curated by Apple — i.e. symbols the box-fit rule is NOT
/// expected to match and which deserve manual calibration.
///
/// The file is read from the system path at runtime and never bundled
/// (Apple-derived data). Returns an empty set when unavailable.
enum ContainerRecipeCatalog {
    static let systemPath =
        "/System/Library/PrivateFrameworks/SFSymbols.framework/Versions/A/Resources/CoreGlyphsPrivate.bundle/Contents/Resources/container_recipes.plist"

    static func loadSymbolNames(from path: String = systemPath) -> Set<String> {
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let root = plist as? [String: Any],
              let symbols = root["symbols"] as? [String: Any]
        else { return [] }
        return Set(symbols.keys)
    }
}
