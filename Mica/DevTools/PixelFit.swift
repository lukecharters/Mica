// PixelFit.swift - Fits a symbol's calibration to Apple's own rendering of it
//
// Compares the glyph alone: Mica's exact alpha against a coverage estimate read out of
// the appex reference, scored by soft IoU, and coordinate-descends multiplier and
// offsets at each offered weight. Measured in experiments/vision-calibration: fits
// recover known values to ~0.0001 in multiplier and ~0.3 px in offset, and Apple's
// renders in different colours agree to ~0.001.

import Accelerate
import AppKit
import SwiftUI

/// The calibration view's geometry, shared by `DimIconView` and the fit so the two
/// cannot drift: a 256-unit base with a 25-unit enclosure inset and 53-unit corners,
/// `fontSize = enclosure × multiplier`, offsets as fractions of the enclosure.
enum CalibrationIconGeometry {
    static let baseSize: CGFloat = 256
    static let baseInset: CGFloat = 25
    static let baseCornerRadius: CGFloat = 53

    static func enclosure(forDisplaySize size: CGFloat) -> CGFloat {
        size - 2 * baseInset * size / baseSize
    }
}

// MARK: - Coverage

/// Per-pixel glyph coverage in 0...1, `size`×`size`, row 0 at the top.
struct GlyphCoverage: Sendable {
    let size: Int
    var values: [Float]

    /// Σmin / Σmax: 1 for identical coverage, 0 for disjoint.
    func softIoU(_ other: GlyphCoverage) -> Double {
        let sums = softIoUSums(other)
        return sums.high == 0 ? 0 : sums.low / sums.high
    }

    func softIoUSums(_ other: GlyphCoverage) -> (low: Double, high: Double) {
        precondition(size == other.size && values.count == other.values.count)
        var low = [Float](repeating: 0, count: size), high = low
        var lowSum = 0.0, highSum = 0.0
        values.withUnsafeBufferPointer { a in
            other.values.withUnsafeBufferPointer { b in
                // Row sums in Float, the total in Double: a million-term Float sum drifts
                // by more than the descent's smallest steps change the score.
                for row in 0..<size {
                    let offset = row * size
                    vDSP_vmin(a.baseAddress! + offset, 1, b.baseAddress! + offset, 1, &low, 1, vDSP_Length(size))
                    vDSP_vmax(a.baseAddress! + offset, 1, b.baseAddress! + offset, 1, &high, 1, vDSP_Length(size))
                    var l: Float = 0, h: Float = 0
                    vDSP_sve(low, 1, &l, vDSP_Length(size))
                    vDSP_sve(high, 1, &h, vDSP_Length(size))
                    lowSum += Double(l); highSum += Double(h)
                }
            }
        }
        return (lowSum, highSum)
    }

    /// Bounding box of the pixels at least half covered.
    var box: (minX: Int, maxX: Int, minY: Int, maxY: Int)? {
        var columnMax = [Float](repeating: 0, count: size)
        var minY = -1, maxY = -1
        values.withUnsafeBufferPointer { v in
            for row in 0..<size {
                let p = v.baseAddress! + row * size
                var rowMax: Float = 0
                vDSP_maxv(p, 1, &rowMax, vDSP_Length(size))
                if rowMax >= 0.5 {
                    if minY < 0 { minY = row }
                    maxY = row
                }
                vDSP_vmax(columnMax, 1, p, 1, &columnMax, 1, vDSP_Length(size))
            }
        }
        guard let minX = columnMax.firstIndex(where: { $0 >= 0.5 }),
              let maxX = columnMax.lastIndex(where: { $0 >= 0.5 }), minY >= 0 else { return nil }
        return (minX, maxX, minY, maxY)
    }

    var enclosurePixels: Double { Double(CalibrationIconGeometry.enclosure(forDisplaySize: CGFloat(size))) }
}

enum PixelBuffers {
    static func rgba(_ image: CGImage, size: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        return bytes
    }

    /// Channel `channel` of an RGBA buffer as Float 0...255.
    static func channel(_ rgba: [UInt8], _ channel: Int, count: Int) -> [Float] {
        var out = [Float](repeating: 0, count: count)
        rgba.withUnsafeBufferPointer { p in
            vDSP_vfltu8(p.baseAddress! + channel, 4, &out, 1, vDSP_Length(count))
        }
        return out
    }

    /// Whether each pixel lies inside the enclosure's rounded square, shrunk by `margin`.
    static func enclosureMask(size: Int, margin: Double) -> [Bool] {
        let scale = Double(size) / Double(CalibrationIconGeometry.baseSize)
        let lo = Double(CalibrationIconGeometry.baseInset) * scale + margin
        let hi = Double(size) - lo
        let r = max(Double(CalibrationIconGeometry.baseCornerRadius) * scale - margin, 0)
        var mask = [Bool](repeating: false, count: size * size)
        for y in 0..<size {
            let py = Double(y) + 0.5
            guard py >= lo, py <= hi else { continue }
            for x in 0..<size {
                let px = Double(x) + 0.5
                guard px >= lo, px <= hi else { continue }
                let cx = min(max(px, lo + r), hi - r), cy = min(max(py, lo + r), hi - r)
                mask[y * size + x] = (px - cx) * (px - cx) + (py - cy) * (py - cy) <= r * r
            }
        }
        return mask
    }

    /// A square sliding maximum of `radius`, separable, through `vDSP_vswmax`.
    static func slidingMax(_ values: [Float], size: Int, radius: Int) -> [Float] {
        func horizontal(_ source: [Float]) -> [Float] {
            let window = 2 * radius + 1
            var padded = [Float](repeating: -.greatestFiniteMagnitude, count: size + 2 * radius)
            var out = [Float](repeating: 0, count: source.count)
            source.withUnsafeBufferPointer { src in
                out.withUnsafeMutableBufferPointer { dst in
                    padded.withUnsafeMutableBufferPointer { row in
                        for y in 0..<size {
                            (row.baseAddress! + radius).update(from: src.baseAddress! + y * size, count: size)
                            vDSP_vswmax(row.baseAddress!, 1, dst.baseAddress! + y * size, 1, vDSP_Length(size), vDSP_Length(window))
                        }
                    }
                }
            }
            return out
        }
        func transposed(_ m: [Float]) -> [Float] {
            var out = [Float](repeating: 0, count: m.count)
            vDSP_mtrans(m, 1, &out, 1, vDSP_Length(size), vDSP_Length(size))
            return out
        }
        return transposed(horizontal(transposed(horizontal(values))))
    }
}

// MARK: - Apple's side

enum ReferenceGlyphCoverage {
    /// Unmixes each pixel between the darkest and brightest values within a stroke's reach,
    /// in whichever channel separates glyph from enclosure most, so the glyph's gradient
    /// and any per-layer shading cancel instead of moving the edge. Where no edge is in
    /// reach the pixel is wholly glyph or wholly background, and a midpoint cut decides it.
    static func estimate(from image: CGImage, size: Int) -> GlyphCoverage {
        let count = size * size
        let rgba = PixelBuffers.rgba(image, size: size)
        let alpha = PixelBuffers.channel(rgba, 3, count: count)
        let enclosure = PixelBuffers.enclosureMask(size: size, margin: Double(size) / 64)
        var inside = [Bool](repeating: false, count: count)
        for i in 0..<count { inside[i] = enclosure[i] && alpha[i] > 250 }

        let channels = (0..<3).map { PixelBuffers.channel(rgba, $0, count: count) }
        func percentiles(_ v: [Float]) -> (p02: Float, median: Float, p98: Float) {
            var sample: [Float] = []
            sample.reserveCapacity(count / 3)
            for i in stride(from: 0, to: count, by: 3) where inside[i] { sample.append(v[i]) }
            guard !sample.isEmpty else { return (0, 0, 0) }
            sample.sort()
            return (sample[sample.count / 50], sample[sample.count / 2], sample[sample.count * 49 / 50])
        }
        // The enclosure is most of the interior, so the median is the background.
        var best = (channel: 0, contrast: Float(-1), bright: true, background: Float(0))
        for c in 0..<3 {
            let p = percentiles(channels[c])
            let up = p.p98 - p.median, down = p.median - p.p02
            if max(up, down) > best.contrast {
                best = (c, max(up, down), up >= down, up >= down ? p.median : 255 - p.median)
            }
        }
        var values = channels[best.channel]
        if !best.bright {
            var minusOne: Float = -1, full: Float = 255
            vDSP_vsmsa(values, 1, &minusOne, &full, &values, 1, vDSP_Length(count))
        }
        let glyphLevel = best.background + best.contrast
        let cut = (best.background + glyphLevel) / 2

        let radius = max(size / 96, 3)
        let big = Float.greatestFiniteMagnitude / 4
        var forMax = values, forMin = values
        for i in 0..<count where !inside[i] { forMax[i] = -big; forMin[i] = -big }
        for i in 0..<count where inside[i] { forMin[i] = -values[i] }
        let high = PixelBuffers.slidingMax(forMax, size: size, radius: radius)
        let negatedLow = PixelBuffers.slidingMax(forMin, size: size, radius: radius)

        let minimumSpan = best.contrast * 0.4
        var coverage = [Float](repeating: 0, count: count)
        for i in 0..<count where inside[i] {
            let low = -negatedLow[i]
            let span = high[i] - low
            if span < minimumSpan {
                coverage[i] = values[i] > cut ? 1 : 0
            } else {
                coverage[i] = min(max((values[i] - low) / span, 0), 1)
            }
        }
        return GlyphCoverage(size: size, values: coverage)
    }
}

// MARK: - Mica's side

private struct PixelFitGlyphView: View {
    let symbolName: String
    let multiplier: Double
    let xOffset: Double
    let yOffset: Double
    let weight: Font.Weight

    var body: some View {
        let enclosure = CalibrationIconGeometry.enclosure(forDisplaySize: PixelFitter.pointSize)
        Image(systemName: symbolName)
            .font(.system(size: enclosure * multiplier, weight: weight))
            .foregroundStyle(.white)
            .offset(x: enclosure * xOffset, y: enclosure * yOffset)
            .frame(width: PixelFitter.pointSize, height: PixelFitter.pointSize)
    }
}

// MARK: - The fit

@MainActor
enum PixelFitter {
    nonisolated static let pointSize: CGFloat = 512
    nonisolated static let size = 1024
    nonisolated static let source = "pixel-fit"

    struct Values: Equatable, Sendable {
        var multiplier: Double
        var xOffset: Double
        var yOffset: Double
        var weight: String
    }

    struct Result: Sendable {
        var values: Values
        var score: Double
    }

    /// The glyph's alpha, which is its coverage exactly.
    static func micaCoverage(_ symbol: String, _ v: Values) -> GlyphCoverage? {
        let renderer = ImageRenderer(content: PixelFitGlyphView(
            symbolName: symbol, multiplier: v.multiplier, xOffset: v.xOffset, yOffset: v.yOffset,
            weight: SymbolCalibrationEntry.fontWeight(fromToken: v.weight)))
        renderer.scale = CGFloat(size) / pointSize
        guard let image = renderer.cgImage else { return nil }
        var alpha = PixelBuffers.channel(PixelBuffers.rgba(image, size: size), 3, count: size * size)
        var scale: Float = 255
        vDSP_vsdiv(alpha, 1, &scale, &alpha, 1, vDSP_Length(alpha.count))
        return GlyphCoverage(size: size, values: alpha)
    }

    /// Fits `symbol` to `target`, starting from `start`: a coarse fit at each of `weights`,
    /// then a fine one for the best and for any runner-up within 0.01 of it. When some part
    /// of Apple's glyph sits where no size or offset can put Mica's, every weight is refit
    /// scoring that part where it is (`MisplacedParts`). Nil when cancelled or when nothing
    /// renders. Yields between renders so the window stays live.
    static func fit(_ symbol: String, target: GlyphCoverage, start: Values,
                    weights: [String] = SymbolCalibrationEntry.weightTokens.map(\.token)) async -> Result? {
        guard let targetBox = target.box else { return nil }
        let starts = weights.map { weight in
            var values = start
            values.weight = weight
            return values
        }
        guard let first = await fitWeights(symbol, target: target, targetBox: targetBox, starts: starts,
                                           scoring: { $0.softIoU(target) })
        else { return nil }
        var result = first.best
        let fits = first.coarse.compactMap { coarse in
            micaCoverage(symbol, coarse.values).map { (weight: coarse.values.weight, coverage: $0) }
        }
        if let parts = MisplacedParts.find(in: target, fits: fits) {
            guard let second = await fitWeights(symbol, target: target, targetBox: targetBox,
                                                starts: first.coarse.map(\.values), scoring: parts.score)
            else { return nil }
            if parts.isDisplaced(atWeight: second.best.values.weight) { result = second.best }
        }
        result.values.multiplier = rounded(result.values.multiplier)
        result.values.xOffset = rounded(result.values.xOffset)
        result.values.yOffset = rounded(result.values.yOffset)
        return result
    }

    private static func fitWeights(_ symbol: String, target: GlyphCoverage, targetBox: (minX: Int, maxX: Int, minY: Int, maxY: Int),
                                   starts: [Values], scoring: (GlyphCoverage) -> Double) async -> (coarse: [Result], best: Result)? {
        func score(_ v: Values) async -> Double? {
            await Task.yield()
            if Task.isCancelled { return nil }
            return micaCoverage(symbol, v).map(scoring) ?? 0
        }
        func descend(_ from: Result, steps initial: [Double], floor: Double) async -> (Result, [Double])? {
            var p = from.values, current = from.score, steps = initial
            while steps.max()! > floor {
                var improved = false
                for axis in 0..<3 {
                    for sign in [-1.0, 1.0] {
                        var q = p
                        switch axis {
                        case 0: q.multiplier += sign * steps[0]
                        case 1: q.xOffset += sign * steps[1]
                        default: q.yOffset += sign * steps[2]
                        }
                        guard let s = await score(q) else { return nil }
                        if s > current { p = q; current = s; improved = true }
                    }
                }
                if !improved { steps = steps.map { $0 / 2 } }
            }
            return (Result(values: p, score: current), steps)
        }

        var coarse: [(Result, [Double])] = []
        for unaligned in starts {
            var p = unaligned
            if let b = micaCoverage(symbol, p)?.box {
                let ratioH = Double(targetBox.maxY - targetBox.minY + 1) / Double(b.maxY - b.minY + 1)
                let ratioW = Double(targetBox.maxX - targetBox.minX + 1) / Double(b.maxX - b.minX + 1)
                p.multiplier *= (ratioH + ratioW) / 2
            }
            if let b = micaCoverage(symbol, p)?.box {
                p.xOffset += (Double(targetBox.minX + targetBox.maxX) - Double(b.minX + b.maxX)) / 2 / target.enclosurePixels
                p.yOffset += (Double(targetBox.minY + targetBox.maxY) - Double(b.minY + b.maxY)) / 2 / target.enclosurePixels
            }
            guard var current = await score(p), let unalignedScore = await score(unaligned) else { return nil }
            // Box alignment misleads on a translucent layer, which sits either side of the 0.5 cut.
            if unalignedScore > current { p = unaligned; current = unalignedScore }
            guard let fitted = await descend(Result(values: p, score: current), steps: [0.01, 0.005, 0.005], floor: 0.002)
            else { return nil }
            coarse.append(fitted)
        }
        guard let leader = coarse.map(\.0.score).max() else { return nil }
        var best: Result?
        for (result, steps) in coarse where result.score >= leader - 0.01 {
            guard let (fine, _) = await descend(result, steps: steps, floor: 0.00025) else { return nil }
            if fine.score > (best?.score ?? -1) { best = fine }
        }
        guard let best else { return nil }
        return (coarse.map(\.0), best)
    }

    static func rounded(_ value: Double) -> Double { (value * 10_000).rounded() / 10_000 }

    /// Calibrated at or above `threshold`, otherwise flagged for a person to look at.
    static func status(forScore score: Double, threshold: Double) -> String {
        score >= threshold ? "calibrated" : "needs-review"
    }

    /// Every unreviewed `pixel-fit` entry's status set from its score; everything else as it was.
    static func reflagged(_ entries: [String: SymbolCalibrationEntry],
                          threshold: Double) -> [String: SymbolCalibrationEntry] {
        entries.mapValues { entry in
            guard entry.source == source, entry.reviewed != true, let score = entry.fitScore else { return entry }
            var flagged = entry
            flagged.status = status(forScore: score, threshold: threshold)
            return flagged
        }
    }

    /// What marking a symbol writes: a `pixel-fit` entry whose values the edit leaves unchanged
    /// keeps its source and score and is marked reviewed; anything else is a hand edit.
    static func marked(_ edited: SymbolCalibrationEntry, over existing: SymbolCalibrationEntry?) -> SymbolCalibrationEntry {
        guard var kept = existing, kept.source == source, kept.hasSameValues(as: edited) else { return edited }
        kept.status = edited.status
        kept.reviewed = true
        return kept
    }

    static func entry(for result: Result, threshold: Double) -> SymbolCalibrationEntry {
        SymbolCalibrationEntry(
            multiplier: result.values.multiplier, xOffset: result.values.xOffset, yOffset: result.values.yOffset,
            weight: result.values.weight, status: status(forScore: result.score, threshold: threshold),
            source: source, fitScore: PixelFitter.rounded(result.score))
    }
}
