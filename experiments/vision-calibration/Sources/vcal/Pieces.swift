import AppKit
import Foundation

/// Second pass for a symbol whose parts are not where Apple draws them (`allergens`: its dots sit at
/// another angle). A thicker weight wins the first pass by smearing over the misplaced parts, so every
/// weight is refit with those parts scored after moving Mica's onto Apple's centre.
///
/// A part is misplaced when the matching part of Mica's fit has its centre displaced by more than
/// `threshold` of the part's own radius. Weight grows a stroke symmetrically and leaves its centre
/// where it was; a misplaced part moves. The refit stands only if the part is still displaced at the
/// weight it chooses.
@MainActor
enum Pieces {
    struct Piece {
        var pixels: [Int]
        var cx: Double
        var cy: Double
        var area: Int { pixels.count }
        var radius: Double { (Double(area) / .pi).squareRoot() }
    }

    struct FittedEntry: Decodable {
        var multiplier: Double
        var xOffset: Double
        var yOffset: Double
        var weight: String
        var status: String
        var fitScore: Double?
    }

    private struct FittedFile: Decodable { var symbols: [String: FittedEntry] }

    static let minimumArea = 40

    /// 8-connected pieces of the pixels at least half covered.
    static func label(_ c: Coverage) -> (pieces: [Piece], labels: [Int]) {
        let n = c.size
        var labels = [Int](repeating: -1, count: n * n)
        var pieces: [Piece] = []
        var stack: [Int] = []
        for start in 0..<(n * n) where c.values[start] >= 0.5 && labels[start] == -1 {
            let id = pieces.count
            var pixels: [Int] = []
            labels[start] = id
            stack.append(start)
            while let i = stack.popLast() {
                pixels.append(i)
                let x = i % n, y = i / n
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, ny >= 0, nx < n, ny < n else { continue }
                        let j = ny * n + nx
                        if labels[j] == -1 && c.values[j] >= 0.5 { labels[j] = id; stack.append(j) }
                    }
                }
            }
            var sx = 0.0, sy = 0.0
            for i in pixels { sx += Double(i % n); sy += Double(i / n) }
            pieces.append(Piece(pixels: pixels, cx: sx / Double(pixels.count), cy: sy / Double(pixels.count)))
        }
        // Specks keep their label (so a match can land on one) but are never judged themselves.
        return (pieces, labels)
    }

    struct Match {
        var displacement: Double
        var micaPiece: Int?
    }

    /// For each reference piece, Mica's piece that overlaps it most, and how far
    /// apart their centres are as a fraction of the reference piece's radius.
    static func match(_ reference: [Piece], mica: (pieces: [Piece], labels: [Int])) -> [Match] {
        reference.map { r in
            var counts: [Int: Int] = [:]
            for i in r.pixels where mica.labels[i] >= 0 { counts[mica.labels[i], default: 0] += 1 }
            // No overlap means Mica draws nothing there (a translucent layer under the cut): missing, not misplaced.
            guard let m = counts.max(by: { $0.value < $1.value })?.key else { return Match(displacement: 0, micaPiece: nil) }
            let p = mica.pieces[m]
            return Match(displacement: hypot(p.cx - r.cx, p.cy - r.cy) / r.radius, micaPiece: m)
        }
    }

    /// Soft IoU outside `mask`, plus each misplaced part scored against Mica's matching part moved
    /// onto its centre: the part's size and stroke still count, its position does not.
    static func recentredScorer(target: Coverage, maskedTarget: Coverage, mask: [Bool], parts: [Piece], size n: Int) -> (Coverage) -> Double {
        struct Local {
            var x0: Int, y0: Int, w: Int, h: Int
            var reference: [Float]
            var cx: Double, cy: Double
            var region: [Bool]
        }
        let locals: [Local] = parts.map { part in
            var own = [Bool](repeating: false, count: n * n)
            for i in part.pixels { own[i] = true }
            let reach = dilate(own, size: n, radius: 3)
            let margin = Int(part.radius) + 6
            let xs = part.pixels.map { $0 % n }, ys = part.pixels.map { $0 / n }
            let x0 = max(xs.min()! - margin, 0), y0 = max(ys.min()! - margin, 0)
            let x1 = min(xs.max()! + margin, n - 1), y1 = min(ys.max()! + margin, n - 1)
            let w = x1 - x0 + 1, h = y1 - y0 + 1
            var reference = [Float](repeating: 0, count: w * h)
            var sx = 0.0, sy = 0.0, sv = 0.0
            for y in 0..<h { for x in 0..<w {
                let i = (y0 + y) * n + x0 + x
                guard reach[i] else { continue }
                let v = target.values[i]
                reference[y * w + x] = v
                sx += Double(v) * Double(x0 + x); sy += Double(v) * Double(y0 + y); sv += Double(v)
            } }
            var region = [Bool](repeating: false, count: n * n)
            for i in 0..<(n * n) where reach[i] || mask[i] { region[i] = true }
            return Local(x0: x0, y0: y0, w: w, h: h, reference: reference, cx: sx / sv, cy: sy / sv, region: mask)
        }
        return { mica in
            var low = 0.0, high = 0.0
            for i in 0..<(n * n) where !mask[i] {
                let a = maskedTarget.values[i], b = mica.values[i]
                low += Double(min(a, b)); high += Double(max(a, b))
            }
            let labelled = label(mica)
            for part in locals {
                // Mica's part: the piece overlapping the reference part most, else the nearest inside the mask.
                var counts: [Int: Int] = [:]
                for y in 0..<part.h { for x in 0..<part.w where part.reference[y * part.w + x] >= 0.5 {
                    let l = labelled.labels[(part.y0 + y) * n + part.x0 + x]
                    if l >= 0 { counts[l, default: 0] += 1 }
                } }
                let chosen = counts.max { $0.value < $1.value }?.key ?? labelled.pieces.indices
                    .filter { labelled.pieces[$0].pixels.contains { part.region[$0] } }
                    .min { hypot(labelled.pieces[$0].cx - part.cx, labelled.pieces[$0].cy - part.cy) < hypot(labelled.pieces[$1].cx - part.cx, labelled.pieces[$1].cy - part.cy) }
                var refSum = 0.0
                for v in part.reference { refSum += Double(v) }
                guard let p = chosen else { high += refSum; continue }
                var own = [Bool](repeating: false, count: n * n)
                for i in labelled.pieces[p].pixels { own[i] = true }
                let reach = dilate(own, size: n, radius: 3)
                var sx = 0.0, sy = 0.0, sv = 0.0
                for i in 0..<(n * n) where reach[i] {
                    let v = Double(mica.values[i]); sx += v * Double(i % n); sy += v * Double(i / n); sv += v
                }
                guard sv > 0 else { high += refSum; continue }
                let dx = part.cx - sx / sv, dy = part.cy - sy / sv
                func sample(_ x: Double, _ y: Double) -> Double {
                    let fx = floor(x), fy = floor(y), tx = x - fx, ty = y - fy
                    var out = 0.0
                    for (ox, oy, wgt) in [(0, 0, (1 - tx) * (1 - ty)), (1, 0, tx * (1 - ty)), (0, 1, (1 - tx) * ty), (1, 1, tx * ty)] {
                        let xi = Int(fx) + ox, yi = Int(fy) + oy
                        guard xi >= 0, yi >= 0, xi < n, yi < n, reach[yi * n + xi] else { continue }
                        out += wgt * Double(mica.values[yi * n + xi])
                    }
                    return out
                }
                var micaSum = 0.0, localLow = 0.0, localHigh = 0.0
                for y in 0..<part.h { for x in 0..<part.w {
                    let a = Double(part.reference[y * part.w + x])
                    let b = sample(Double(part.x0 + x) - dx, Double(part.y0 + y) - dy)
                    micaSum += b; localLow += min(a, b); localHigh += max(a, b)
                } }
                // Whatever of Mica's part fell outside the window still counts against it.
                low += localLow; high += localHigh + max(sv - micaSum, 0)
            }
            return high == 0 ? 0 : low / high
        }
    }

    static func dilate(_ mask: [Bool], size n: Int, radius: Int) -> [Bool] {
        var horizontal = [Bool](repeating: false, count: mask.count)
        for y in 0..<n {
            var last = -Int.max / 2
            for x in 0..<n { if mask[y * n + x] { last = x }; if x - last <= radius { horizontal[y * n + x] = true } }
            last = Int.max / 2
            for x in stride(from: n - 1, through: 0, by: -1) { if mask[y * n + x] { last = x }; if last - x <= radius { horizontal[y * n + x] = true } }
        }
        var out = [Bool](repeating: false, count: mask.count)
        for x in 0..<n {
            var last = -Int.max / 2
            for y in 0..<n { if horizontal[y * n + x] { last = y }; if y - last <= radius { out[y * n + x] = true } }
            last = Int.max / 2
            for y in stride(from: n - 1, through: 0, by: -1) { if horizontal[y * n + x] { last = y }; if last - y <= radius { out[y * n + x] = true } }
        }
        return out
    }

    struct Row: Codable {
        var symbol: String
        var stored: String
        var storedScore: Double?
        var firstScores: [Double]
        var firstWeight: String
        var maxDisplacement: [Double]
        var pieces: Int
        var misplaced: Int
        var maskedFraction: Double
        var maskedScores: [Double]?
        var maskedWeight: String?
        var maskedParams: String?
    }

    static func run(fittedFile: URL, only: [String], low: Bool, sample: Int, seed: UInt64, threshold: Double,
                    cacheDirectory: URL, outputDirectory: URL) throws -> String {
        let file = try JSONDecoder().decode(FittedFile.self, from: Data(contentsOf: fittedFile))
        let drawable = file.symbols.keys.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }.sorted()
        var names = only
        if low { names += drawable.filter { (file.symbols[$0]?.fitScore ?? 1) < 0.85 } }
        if sample > 0 {
            var rng = SplitMix64(seed: seed)
            names += drawable.shuffled(using: &rng).prefix(sample)
        }
        var seen = Set<String>()
        names = names.filter { seen.insert($0).inserted && file.symbols[$0] != nil }

        let size = 1024
        var rows: [Row] = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for (index, name) in names.enumerated() {
            let entry = file.symbols[name]!
            let start = IconParams(multiplier: entry.multiplier, xOffset: entry.xOffset, yOffset: entry.yOffset, weight: entry.weight)
            let reference = try AppexReference.render(name, cacheDirectory: cacheDirectory)
            let target = ReferenceCoverage.normalised(reference, size: size)
            let perWeight = IconParams.weightTokens.indices.map {
                CoverageFit.descend(name, target: target, start: start, size: size, weights: [$0], binary: false)
            }
            let first = perWeight.max { $0.iou < $1.iou }!

            let ref = label(target)
            let judged = ref.pieces.indices.filter { ref.pieces[$0].area >= minimumArea }
            var worst = [Double](repeating: 0, count: perWeight.count)
            var misplaced = Set<Int>()
            var micaLabelled: [(pieces: [Piece], labels: [Int])] = []
            var matches: [[Match]] = []
            for (w, result) in perWeight.enumerated() {
                guard let mica = GlyphCoverage.mica(name, result.params, size: size) else { continue }
                let labelled = label(mica)
                let m = match(judged.map { ref.pieces[$0] }, mica: labelled)
                micaLabelled.append(labelled)
                matches.append(m)
                worst[w] = m.map(\.displacement).max() ?? 0
                if ProcessInfo.processInfo.environment["VCAL_PIECES_DEBUG"] != nil {
                    for (k, mk) in m.enumerated() {
                        let r = ref.pieces[judged[k]]
                        let mp = mk.micaPiece.map { labelled.pieces[$0] }
                        print(String(format: "  w%d ref#%d area %d at (%.0f,%.0f)  mica area %d at (%.0f,%.0f)  disp %.2f",
                                     w, k, r.area, r.cx, r.cy, mp?.area ?? 0, mp?.cx ?? 0, mp?.cy ?? 0, mk.displacement))
                    }
                }
                // Beyond 1.5 radii the overlap is a different part (strokes merging at a heavier weight), not this one moved.
                for (k, mk) in m.enumerated() where mk.displacement > threshold && mk.displacement < 1.5 {
                    guard let p = mk.micaPiece else { continue }
                    let ratio = Double(labelled.pieces[p].area) / Double(ref.pieces[judged[k]].area)
                    if ratio > 0.5 && ratio < 2 { misplaced.insert(k) }
                }
            }

            var row = Row(symbol: name, stored: entry.weight, storedScore: entry.fitScore,
                          firstScores: perWeight.map(\.iou), firstWeight: first.params.weight,
                          maxDisplacement: worst, pieces: judged.count, misplaced: misplaced.count, maskedFraction: 0)

            if !misplaced.isEmpty {
                var mask = [Bool](repeating: false, count: size * size)
                for k in misplaced { for i in ref.pieces[judged[k]].pixels { mask[i] = true } }
                for (w, m) in matches.enumerated() {
                    for k in misplaced { if let p = m[k].micaPiece { for i in micaLabelled[w].pieces[p].pixels { mask[i] = true } } }
                }
                mask = dilate(mask, size: size, radius: size / 128)
                var maskedTarget = target
                var removed = 0.0, total = 0.0
                for i in 0..<mask.count {
                    total += Double(target.values[i])
                    if mask[i] { removed += Double(target.values[i]); maskedTarget.values[i] = 0 }
                }
                row.maskedFraction = total == 0 ? 0 : removed / total
                let scorer = recentredScorer(target: target, maskedTarget: maskedTarget, mask: mask,
                                             parts: misplaced.sorted().map { ref.pieces[judged[$0]] }, size: size)
                let refit = perWeight.enumerated().map { w, r in
                    CoverageFit.descend(name, target: target, start: r.params, size: size, weights: [w], binary: false, scorer: scorer)
                }
                let best = refit.max { $0.iou < $1.iou }!
                let chosenWeight = best.params.weightIndex
                // A part displaced only at weights the refit rejects was never misplaced: keep the first pass.
                guard misplaced.contains(where: { matches[chosenWeight][$0].displacement > threshold }) else {
                    rows.append(row)
                    print("[\(index + 1)/\(names.count)] \(name)  flagged \(misplaced.count)/\(judged.count), not displaced at \(best.params.weight): first pass kept")
                    try encoder.encode(rows).write(to: outputDirectory.appendingPathComponent("results.json"))
                    continue
                }
                row.maskedScores = refit.map(\.iou)
                row.maskedWeight = best.params.weight
                row.maskedParams = best.params.short
                try PNG.write(sheet(name, target: target, mask: mask, first: first, masked: best),
                              to: outputDirectory.appendingPathComponent("\(name).png"))
            }
            rows.append(row)
            let change = row.maskedWeight.map { $0 == first.params.weight ? "  masked: same" : "  masked: \(first.params.weight) → \($0)" } ?? ""
            print("[\(index + 1)/\(names.count)] \(name)  first \(first.params.weight) " +
                  row.firstScores.map(f3).joined(separator: "/") +
                  "  displacement " + worst.map { String(format: "%.2f", $0) }.joined(separator: "/") +
                  "  misplaced \(misplaced.count)/\(judged.count)" + change)
            try encoder.encode(rows).write(to: outputDirectory.appendingPathComponent("results.json"))
        }
        return summary(rows, threshold: threshold)
    }

    private static func sheet(_ name: String, target: Coverage, mask: [Bool], first: CoverageFit.Result, masked: CoverageFit.Result) -> CGImage {
        let n = target.size
        var maskImage = [UInt8](repeating: 255, count: n * n * 4)
        for i in 0..<(n * n) {
            let v = UInt8(255 * (1 - target.values[i]))
            maskImage[i * 4] = mask[i] ? 255 : v
            maskImage[i * 4 + 1] = mask[i] ? v / 2 + 100 : v
            maskImage[i * 4 + 2] = mask[i] ? v / 2 + 100 : v
        }
        let panels = [Pixels.image(maskImage, size: n), Review.overlay(target, name, first.params), Review.overlay(target, name, masked.params)].compactMap { $0 }
        let panel = 400, gap = 12, header = 40
        let width = panels.count * panel + (panels.count + 1) * gap, height = panel + header + 2 * gap
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 0.93, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let titles = ["masked parts (pink)", "first pass: \(first.params.weight) \(f3(first.iou))", "masked refit: \(masked.params.weight) \(f3(masked.iou))"]
        for (i, image) in panels.enumerated() {
            let x = gap + i * (panel + gap)
            context.draw(image, in: CGRect(x: x, y: gap, width: panel, height: panel))
            NSAttributedString(string: titles[i], attributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor.black])
                .draw(at: CGPoint(x: x, y: height - header + 10))
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }

    static func summary(_ rows: [Row], threshold: Double) -> String {
        let flagged = rows.filter { $0.misplaced > 0 }
        let changed = flagged.filter { $0.maskedWeight != $0.firstWeight }
        var out = "# pieces\n\nthreshold \(threshold) of a part's radius; \(rows.count) symbols, \(flagged.count) with a misplaced part, \(changed.count) change weight.\n\n"
        out += "| symbol | first pass | displacement r/m/s/b | misplaced | masked share | masked refit |\n|---|---|---|---|---|---|\n"
        for r in rows.sorted(by: { ($0.maxDisplacement.max() ?? 0) > ($1.maxDisplacement.max() ?? 0) }) {
            out += "| \(r.symbol) | \(r.firstWeight) \(f3(r.firstScores.max() ?? 0)) | \(r.maxDisplacement.map { String(format: "%.2f", $0) }.joined(separator: " / ")) | \(r.misplaced)/\(r.pieces) | \(r.misplaced > 0 ? String(format: "%.0f%%", 100 * r.maskedFraction) : "") | \(r.maskedWeight.map { "\($0) \(f3(r.maskedScores!.max()!))" } ?? "") |\n"
        }
        return out
    }
}
