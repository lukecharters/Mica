// PixelFitParts.swift - The pixel fit's second pass, for parts Apple draws somewhere else
//
// Some appex renders place a separate part of the glyph where no size or offset can put
// Mica's: `allergens` draws its dots at another angle. Plain IoU then rewards a heavier
// weight for smearing over them. Weight grows a stroke about its centre and leaves the
// centre put, so a part whose centre moves is misplaced, and the refit scores it after
// moving Mica's part onto Apple's centre: its size and stroke count, its position does not.
// Measured in experiments/vision-calibration (`vcal pieces`).

import Accelerate
import Foundation

/// A rectangle of the image with a per-pixel membership flag, for working on one part.
struct PixelRegion {
    let x0: Int, y0: Int, width: Int, height: Int
    var member: [Bool]

    func contains(_ x: Int, _ y: Int) -> Bool {
        let lx = x - x0, ly = y - y0
        return lx >= 0 && ly >= 0 && lx < width && ly < height && member[ly * width + lx]
    }

    /// `pixels` grown by `radius` in every direction, clipped to the image.
    static func halo(of pixels: [Int], size n: Int, radius: Int) -> PixelRegion {
        let xs = pixels.map { $0 % n }, ys = pixels.map { $0 / n }
        let x0 = max(xs.min()! - radius, 0), y0 = max(ys.min()! - radius, 0)
        let x1 = min(xs.max()! + radius, n - 1), y1 = min(ys.max()! + radius, n - 1)
        let w = x1 - x0 + 1, h = y1 - y0 + 1
        var own = [Bool](repeating: false, count: w * h)
        for i in pixels { own[(i / n - y0) * w + i % n - x0] = true }
        var rows = [Bool](repeating: false, count: w * h)
        for y in 0..<h {
            var last = -radius - 1
            for x in 0..<w { if own[y * w + x] { last = x }; if x - last <= radius { rows[y * w + x] = true } }
            last = w + radius
            for x in stride(from: w - 1, through: 0, by: -1) { if own[y * w + x] { last = x }; if last - x <= radius { rows[y * w + x] = true } }
        }
        var member = [Bool](repeating: false, count: w * h)
        for x in 0..<w {
            var last = -radius - 1
            for y in 0..<h { if rows[y * w + x] { last = y }; if y - last <= radius { member[y * w + x] = true } }
            last = h + radius
            for y in stride(from: h - 1, through: 0, by: -1) { if rows[y * w + x] { last = y }; if last - y <= radius { member[y * w + x] = true } }
        }
        return PixelRegion(x0: x0, y0: y0, width: w, height: h, member: member)
    }
}

/// The 8-connected pieces of a coverage's pixels that are at least half covered.
struct GlyphPieces {
    struct Piece {
        var pixels: [Int]
        var cx: Double
        var cy: Double
        var area: Int { pixels.count }
        var radius: Double { (Double(area) / .pi).squareRoot() }
    }

    let pieces: [Piece]
    /// Each pixel's index into `pieces`, or -1.
    let labels: [Int32]

    init(_ coverage: GlyphCoverage) {
        let n = coverage.size
        var labels = [Int32](repeating: -1, count: n * n)
        var pieces: [Piece] = []
        var stack: [Int] = []
        coverage.values.withUnsafeBufferPointer { v in
            for seed in 0..<(n * n) where v[seed] >= 0.5 && labels[seed] == -1 {
                let id = Int32(pieces.count)
                var pixels: [Int] = []
                var sx = 0.0, sy = 0.0
                labels[seed] = id
                stack.append(seed)
                while let i = stack.popLast() {
                    pixels.append(i)
                    let x = i % n, y = i / n
                    sx += Double(x); sy += Double(y)
                    for ny in max(y - 1, 0)...min(y + 1, n - 1) {
                        for nx in max(x - 1, 0)...min(x + 1, n - 1) {
                            let j = ny * n + nx
                            if labels[j] == -1 && v[j] >= 0.5 { labels[j] = id; stack.append(j) }
                        }
                    }
                }
                pieces.append(Piece(pixels: pixels, cx: sx / Double(pixels.count), cy: sy / Double(pixels.count)))
            }
        }
        self.pieces = pieces
        self.labels = labels
    }

    /// The piece overlapping `pixels` most, if any does.
    func mostOverlapping(_ pixels: [Int]) -> Int? {
        var counts: [Int32: Int] = [:]
        for i in pixels where labels[i] >= 0 { counts[labels[i], default: 0] += 1 }
        return counts.max { $0.value < $1.value }.map { Int($0.key) }
    }
}

/// Parts of Apple's glyph that no size or offset aligns, and the score that ignores where they sit.
@MainActor
struct MisplacedParts {
    /// Centre distance, as a fraction of the part's radius, past which a part is misplaced.
    nonisolated static let threshold = 0.5
    /// Past this, the overlapping piece is another part (strokes merged at a heavier weight).
    nonisolated static let maximumDisplacement = 1.5
    nonisolated static let minimumArea = 40
    nonisolated static let edgeHalo = 3

    struct Part {
        let pixels: [Int]
        let window: PixelRegion
        /// Apple's coverage over `window`, kept only within the part's halo.
        let reference: [Float]
        let cx: Double
        let cy: Double
        /// Per weight, how far Mica's matching piece sat from this part, in part radii.
        let displacement: [String: Double]
    }

    let parts: [Part]
    let size: Int
    /// 1 outside the misplaced parts and everything matched to them, 0 inside.
    let outside: [Float]
    let outsideTarget: GlyphCoverage

    /// Nil when every part of `target` is where Mica's fit at some weight puts it.
    /// `fits` is Mica's coverage at each weight's first-pass values.
    static func find(in target: GlyphCoverage, fits: [(weight: String, coverage: GlyphCoverage)]) -> MisplacedParts? {
        let n = target.size
        let reference = GlyphPieces(target)
        let judged = reference.pieces.filter { $0.area >= minimumArea }
        let labelled = fits.map { GlyphPieces($0.coverage) }

        var misplaced: [Int] = []
        var displacements = [[String: Double]](repeating: [:], count: judged.count)
        var matched = [[Int]](repeating: [], count: judged.count)
        for (k, part) in judged.enumerated() {
            var isMisplaced = false
            for (fit, mica) in zip(fits, labelled) {
                // No overlap means Mica draws nothing there (a translucent layer under the cut): missing, not misplaced.
                guard let m = mica.mostOverlapping(part.pixels) else { continue }
                let piece = mica.pieces[m]
                let d = hypot(piece.cx - part.cx, piece.cy - part.cy) / part.radius
                let ratio = Double(piece.area) / Double(part.area)
                displacements[k][fit.weight] = d
                matched[k] += piece.pixels
                if d > threshold && d < maximumDisplacement && ratio > 0.5 && ratio < 2 { isMisplaced = true }
            }
            if isMisplaced { misplaced.append(k) }
        }
        guard !misplaced.isEmpty else { return nil }

        var covered = [Float](repeating: 0, count: n * n)
        for k in misplaced {
            for i in judged[k].pixels { covered[i] = 1 }
            for i in matched[k] { covered[i] = 1 }
        }
        covered = PixelBuffers.slidingMax(covered, size: n, radius: n / 128)
        var outside = [Float](repeating: 1, count: n * n)
        vDSP_vsub(covered, 1, outside, 1, &outside, 1, vDSP_Length(n * n))
        var outsideTarget = target
        vDSP_vmul(target.values, 1, outside, 1, &outsideTarget.values, 1, vDSP_Length(n * n))

        let parts = misplaced.map { k -> Part in
            let piece = judged[k]
            let halo = PixelRegion.halo(of: piece.pixels, size: n, radius: edgeHalo)
            let window = PixelRegion.halo(of: piece.pixels, size: n, radius: Int(piece.radius) + 6)
            var values = [Float](repeating: 0, count: window.width * window.height)
            var sx = 0.0, sy = 0.0, sv = 0.0
            for ly in 0..<window.height {
                for lx in 0..<window.width {
                    let x = window.x0 + lx, y = window.y0 + ly
                    guard halo.contains(x, y) else { continue }
                    let v = target.values[y * n + x]
                    values[ly * window.width + lx] = v
                    sx += Double(v) * Double(x); sy += Double(v) * Double(y); sv += Double(v)
                }
            }
            return Part(pixels: piece.pixels, window: window, reference: values,
                        cx: sx / sv, cy: sy / sv, displacement: displacements[k])
        }
        return MisplacedParts(parts: parts, size: n, outside: outside, outsideTarget: outsideTarget)
    }

    /// Whether any misplaced part is still displaced at `weight`. When none is, they were only
    /// displaced at weights the refit rejects, and the first pass stands.
    func isDisplaced(atWeight weight: String) -> Bool {
        parts.contains { ($0.displacement[weight] ?? 0) > Self.threshold }
    }

    /// Soft IoU outside the misplaced parts, plus each part against Mica's matching piece moved onto its centre.
    func score(_ mica: GlyphCoverage) -> Double {
        let n = size
        var masked = mica
        vDSP_vmul(mica.values, 1, outside, 1, &masked.values, 1, vDSP_Length(n * n))
        var (low, high) = masked.softIoUSums(outsideTarget)
        let labelled = GlyphPieces(mica)
        for part in parts {
            let referenceSum = part.reference.reduce(0.0) { $0 + Double($1) }
            guard let m = labelled.mostOverlapping(part.pixels) else { high += referenceSum; continue }
            let halo = PixelRegion.halo(of: labelled.pieces[m].pixels, size: n, radius: Self.edgeHalo)
            var sx = 0.0, sy = 0.0, micaSum = 0.0
            for ly in 0..<halo.height {
                for lx in 0..<halo.width where halo.member[ly * halo.width + lx] {
                    let x = halo.x0 + lx, y = halo.y0 + ly
                    let v = Double(mica.values[y * n + x])
                    sx += v * Double(x); sy += v * Double(y); micaSum += v
                }
            }
            guard micaSum > 0 else { high += referenceSum; continue }
            let dx = part.cx - sx / micaSum, dy = part.cy - sy / micaSum
            func sample(_ x: Double, _ y: Double) -> Double {
                let fx = x.rounded(.down), fy = y.rounded(.down), tx = x - fx, ty = y - fy
                var out = 0.0
                for (ox, oy, w) in [(0, 0, (1 - tx) * (1 - ty)), (1, 0, tx * (1 - ty)), (0, 1, (1 - tx) * ty), (1, 1, tx * ty)] {
                    let xi = Int(fx) + ox, yi = Int(fy) + oy
                    guard halo.contains(xi, yi) else { continue }
                    out += w * Double(mica.values[yi * n + xi])
                }
                return out
            }
            var inWindow = 0.0
            let window = part.window
            for ly in 0..<window.height {
                for lx in 0..<window.width {
                    let a = Double(part.reference[ly * window.width + lx])
                    let b = sample(Double(window.x0 + lx) - dx, Double(window.y0 + ly) - dy)
                    inWindow += b; low += min(a, b); high += max(a, b)
                }
            }
            // Whatever of Mica's piece the window missed still counts against it.
            high += max(micaSum - inWindow, 0)
        }
        return high == 0 ? 0 : low / high
    }
}
