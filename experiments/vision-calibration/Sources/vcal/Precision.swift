import CoreGraphics
import Foundation
import SwiftUI

/// Per-pixel glyph coverage in 0...1, `size`×`size`, row 0 at the top.
struct Coverage {
    let size: Int
    var values: [Float]

    func softIoU(_ other: Coverage) -> Double {
        var low = 0.0, high = 0.0
        for i in 0..<values.count {
            let a = values[i], b = other.values[i]
            low += Double(min(a, b))
            high += Double(max(a, b))
        }
        return high == 0 ? 0 : low / high
    }

    /// Bounding box of pixels at least half covered.
    var box: (minX: Int, maxX: Int, minY: Int, maxY: Int)? {
        var minX = size, maxX = -1, minY = size, maxY = -1
        for y in 0..<size {
            for x in 0..<size where values[y * size + x] >= 0.5 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        return maxX < 0 ? nil : (minX, maxX, minY, maxY)
    }

    var enclosurePixels: Double { Double(IconGeometry.enclosure(forDisplaySize: CGFloat(size))) }
}

enum Pixels {
    static func rgba(_ image: CGImage, size: Int) -> [UInt8] {
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        return Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: size * size * 4))
    }

    static func image(_ rgba: [UInt8], size: Int) -> CGImage {
        CGImage(
            width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(rgba) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }

    /// Whether (x, y) lies inside the enclosure's rounded square, shrunk by `margin` pixels.
    static func insideEnclosure(_ x: Int, _ y: Int, size: Int, margin: Double) -> Bool {
        let scale = Double(size) / Double(IconGeometry.baseSize)
        let lo = Double(IconGeometry.baseInset) * scale + margin
        let hi = Double(size) - lo
        let r = max(Double(IconGeometry.baseCornerRadius) * scale - margin, 0)
        let px = Double(x) + 0.5, py = Double(y) + 0.5
        guard px >= lo, px <= hi, py >= lo, py <= hi else { return false }
        let cx = min(max(px, lo + r), hi - r), cy = min(max(py, lo + r), hi - r)
        return (px - cx) * (px - cx) + (py - cy) * (py - cy) <= r * r
    }
}

// MARK: - Mica's side: exact coverage

private struct GlyphOnlyView: View {
    let symbolName: String
    let params: IconParams

    var body: some View {
        let enclosure = IconGeometry.enclosure(forDisplaySize: IconGeometry.pointSize)
        Image(systemName: symbolName)
            .font(.system(size: enclosure * params.multiplier, weight: params.fontWeight))
            .foregroundStyle(.white)
            .offset(x: enclosure * params.xOffset, y: enclosure * params.yOffset)
            .frame(width: IconGeometry.pointSize, height: IconGeometry.pointSize)
    }
}

@MainActor
enum GlyphCoverage {
    /// The glyph's alpha, which is its coverage exactly.
    static func mica(_ symbol: String, _ params: IconParams, size: Int) -> Coverage? {
        let renderer = ImageRenderer(content: GlyphOnlyView(symbolName: symbol, params: params))
        renderer.scale = IconGeometry.scale
        guard let image = renderer.cgImage else { return nil }
        let rgba = Pixels.rgba(image, size: size)
        var values = [Float](repeating: 0, count: size * size)
        for i in 0..<values.count { values[i] = Float(rgba[i * 4 + 3]) / 255 }
        return Coverage(size: size, values: values)
    }
}

// MARK: - The reference's side: estimated coverage

enum ReferenceCoverage {
    /// One channel of the reference, flipped if need be so the glyph is the bright side.
    private struct Prepared {
        let size: Int
        var values: [Float]
        let inside: [Bool]
        let background: Float
        let glyph: Float
    }

    private static func prepare(_ image: CGImage, size: Int) -> Prepared {
        let rgba = Pixels.rgba(image, size: size)
        let margin = Double(size) / 64
        var inside = [Bool](repeating: false, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                inside[y * size + x] = Pixels.insideEnclosure(x, y, size: size, margin: margin) && rgba[(y * size + x) * 4 + 3] > 250
            }
        }
        func percentiles(_ c: Int) -> (p02: Float, median: Float, p98: Float) {
            var v: [UInt8] = []
            for i in stride(from: 0, to: size * size, by: 3) where inside[i] { v.append(rgba[i * 4 + c]) }
            v.sort()
            return (Float(v[v.count / 50]), Float(v[v.count / 2]), Float(v[v.count * 49 / 50]))
        }
        // The enclosure is the majority of the interior, so its median is the background.
        var best = (channel: 0, contrast: Float(-1), bright: true)
        for c in 0..<3 {
            let p = percentiles(c)
            let up = p.p98 - p.median, down = p.median - p.p02
            if max(up, down) > best.contrast { best = (c, max(up, down), up >= down) }
        }
        var values = [Float](repeating: 0, count: size * size)
        for i in 0..<values.count {
            let v = Float(rgba[i * 4 + best.channel])
            values[i] = best.bright ? v : 255 - v
        }
        let p = percentiles(best.channel)
        let background = best.bright ? p.median : 255 - p.median
        return Prepared(size: size, values: values, inside: inside, background: background, glyph: background + best.contrast)
    }

    /// One global cut halfway between the background and the glyph level: 0 or 1.
    static func threshold(_ image: CGImage, size: Int) -> Coverage {
        let p = prepare(image, size: size)
        let cut = (p.background + p.glyph) / 2
        var values = [Float](repeating: 0, count: size * size)
        for i in 0..<values.count where p.inside[i] { values[i] = p.values[i] > cut ? 1 : 0 }
        return Coverage(size: size, values: values)
    }

    /// Unmixes each pixel between the darkest and brightest values within a stroke's reach, so
    /// a gradient across the glyph, or a different level per layer, cancels instead of moving
    /// the edge.
    static func normalised(_ image: CGImage, size: Int) -> Coverage {
        let p = prepare(image, size: size)
        let radius = max(size / 96, 3)
        let low = slidingExtreme(p.values, inside: p.inside, size: size, radius: radius, max: false)
        let high = slidingExtreme(p.values, inside: p.inside, size: size, radius: radius, max: true)
        let minimumSpan = (p.glyph - p.background) * 0.4
        var values = [Float](repeating: 0, count: size * size)
        for i in 0..<values.count where p.inside[i] {
            let span = high[i] - low[i]
            // No edge within reach: the pixel is wholly glyph or wholly background.
            guard span >= minimumSpan else {
                values[i] = p.values[i] > (p.background + p.glyph) / 2 ? 1 : 0
                continue
            }
            values[i] = min(max((p.values[i] - low[i]) / span, 0), 1)
        }
        return Coverage(size: size, values: values)
    }

    /// A square max or min filter that ignores pixels outside the enclosure.
    private static func slidingExtreme(_ v: [Float], inside: [Bool], size: Int, radius: Int, max useMax: Bool) -> [Float] {
        let empty: Float = useMax ? -.infinity : .infinity
        func pick(_ a: Float, _ b: Float) -> Float { useMax ? Swift.max(a, b) : Swift.min(a, b) }
        var source = [Float](repeating: empty, count: v.count)
        for i in 0..<v.count where inside[i] { source[i] = v[i] }
        var horizontal = [Float](repeating: empty, count: v.count)
        for y in 0..<size {
            for x in 0..<size {
                var e = empty
                for k in Swift.max(0, x - radius)...Swift.min(size - 1, x + radius) { e = pick(e, source[y * size + k]) }
                horizontal[y * size + x] = e
            }
        }
        var out = [Float](repeating: empty, count: v.count)
        for y in 0..<size {
            for x in 0..<size {
                var e = empty
                for k in Swift.max(0, y - radius)...Swift.min(size - 1, y + radius) { e = pick(e, horizontal[k * size + x]) }
                out[y * size + x] = e
            }
        }
        return out
    }
}

// MARK: - Synthetic references

@MainActor
enum Synthetic {
    /// Mica's glyph at `params`, composited onto a blue gradient with the glyph itself shaded
    /// from `top` to `bottom` brightness over its height, optionally blurred by `blur` pixels.
    static func reference(_ symbol: String, _ params: IconParams, top: Double, bottom: Double, blur: Int, size: Int = 1024) -> CGImage? {
        guard var coverage = GlyphCoverage.mica(symbol, params, size: size), let box = coverage.box else { return nil }
        if blur > 0 { coverage.values = boxBlur(coverage.values, size: size, radius: blur, passes: 3) }
        var rgba = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0..<size {
            let t = min(max(Double(y - box.minY) / Double(max(box.maxY - box.minY, 1)), 0), 1)
            let glyph = top + (bottom - top) * t
            let g = Double(y) / Double(size)
            let bg = (r: 0.0, g: 150 - 40 * g, b: 255.0)
            for x in 0..<size where Pixels.insideEnclosure(x, y, size: size, margin: 0) {
                let a = Double(coverage.values[y * size + x])
                let i = (y * size + x) * 4
                rgba[i] = UInt8(bg.r * (1 - a) + glyph * a)
                rgba[i + 1] = UInt8(bg.g * (1 - a) + glyph * a)
                rgba[i + 2] = UInt8(bg.b * (1 - a) + min(glyph + 20, 255) * a)
                rgba[i + 3] = 255
            }
        }
        return Pixels.image(rgba, size: size)
    }

    private static func boxBlur(_ v: [Float], size: Int, radius: Int, passes: Int) -> [Float] {
        var a = v, b = v
        let w = Float(2 * radius + 1)
        for _ in 0..<passes {
            for y in 0..<size {
                for x in 0..<size {
                    var s: Float = 0
                    for k in -radius...radius { s += a[y * size + min(max(x + k, 0), size - 1)] }
                    b[y * size + x] = s / w
                }
            }
            for y in 0..<size {
                for x in 0..<size {
                    var s: Float = 0
                    for k in -radius...radius { s += b[min(max(y + k, 0), size - 1) * size + x] }
                    a[y * size + x] = s / w
                }
            }
        }
        return a
    }
}

// MARK: - Fitting

enum FitMethod: String, CaseIterable {
    /// One global cut on the reference, Mica's alpha cut at 0.5, binary IoU.
    case threshold
    /// Reference unmixed against its local extremes, Mica's exact alpha, soft IoU.
    case normalised
}

@MainActor
enum CoverageFit {
    struct Result {
        var params: IconParams
        var iou: Double
        var renders: Int
    }

    static func fit(_ symbol: String, reference: CGImage, method: FitMethod, start: IconParams, size: Int, weights: [Int]? = nil) -> Result {
        switch method {
        case .threshold:
            return descend(symbol, target: ReferenceCoverage.threshold(reference, size: size), start: start, size: size, weights: weights, binary: true)
        case .normalised:
            return descend(symbol, target: ReferenceCoverage.normalised(reference, size: size), start: start, size: size, weights: weights, binary: false)
        }
    }

    /// `mask` marks pixels left out of the score on both sides; the target must already be zero there.
    static func descend(_ symbol: String, target: Coverage, start: IconParams, size: Int, weights: [Int]?, binary: Bool,
                        mask: [Bool]? = nil, scorer: ((Coverage) -> Double)? = nil) -> Result {
        var renders = 0
        func render(_ p: IconParams) -> Coverage? {
            renders += 1
            guard var c = GlyphCoverage.mica(symbol, p, size: size) else { return nil }
            if binary { c.values = c.values.map { $0 >= 0.5 ? 1 : 0 } }
            if let mask { for i in 0..<c.values.count where mask[i] { c.values[i] = 0 } }
            return c
        }
        func score(_ p: IconParams) -> Double {
            guard let c = render(p) else { return 0 }
            return scorer?(c) ?? c.softIoU(target)
        }
        guard let targetBox = target.box else { return Result(params: start, iou: 0, renders: 0) }
        var best = Result(params: start, iou: -1, renders: 0)
        for weightIndex in weights ?? Array(IconParams.weightTokens.indices) {
            let unaligned = start.withWeight(index: weightIndex)
            var p = unaligned
            if let b = render(p)?.box {
                let ratioH = Double(targetBox.maxY - targetBox.minY + 1) / Double(b.maxY - b.minY + 1)
                let ratioW = Double(targetBox.maxX - targetBox.minX + 1) / Double(b.maxX - b.minX + 1)
                p.multiplier *= (ratioH + ratioW) / 2
            }
            if let b = render(p)?.box {
                p.xOffset += (Double(targetBox.minX + targetBox.maxX) - Double(b.minX + b.maxX)) / 2 / target.enclosurePixels
                p.yOffset += (Double(targetBox.minY + targetBox.maxY) - Double(b.minY + b.maxY)) / 2 / target.enclosurePixels
            }
            var current = score(p)
            // Box alignment misleads on a translucent layer, which sits either side of the 0.5 cut.
            let unalignedScore = score(unaligned)
            if unalignedScore > current { p = unaligned; current = unalignedScore }
            var steps = [0.01, 0.005, 0.005]
            while steps.max()! > 0.00025 {
                var improved = false
                for axis in 0..<3 {
                    for sign in [-1.0, 1.0] {
                        var q = p
                        switch axis {
                        case 0: q.multiplier += sign * steps[0]
                        case 1: q.xOffset += sign * steps[1]
                        default: q.yOffset += sign * steps[2]
                        }
                        let s = score(q)
                        if s > current { p = q; current = s; improved = true }
                    }
                }
                if !improved { steps = steps.map { $0 / 2 } }
            }
            if current > best.iou { best = Result(params: p, iou: current, renders: 0) }
        }
        best.renders = renders
        return best
    }
}

// MARK: - The experiment

@MainActor
enum PrecisionExperiment {
    struct Row: Codable {
        var symbol: String
        var test: String
        var method: String
        var truth: IconParams?
        var fitted: IconParams
        var iou: Double
        var seconds: Double
    }

    static func run(samples: [Sample], combos: [(String, String)], methods: [FitMethod], size: Int,
                    cacheDirectory: URL, outputDirectory: URL) throws -> String {
        var rows: [Row] = []
        let synthetic: [(name: String, top: Double, bottom: Double, blur: Int)] = [
            ("flat", 255, 255, 0), ("gradient", 255, 205, 0), ("steep gradient", 255, 140, 0), ("gradient+blur", 255, 205, 1),
        ]
        for (index, sample) in samples.enumerated() {
            print("[\(index + 1)/\(samples.count)] \(sample.symbol)")
            let start = Calibration.perturbedStart(sample.truth, seed: UInt64(index + 1) &* 7919).withWeight(index: sample.truth.weightIndex)
            for variant in synthetic {
                guard let reference = Synthetic.reference(sample.symbol, sample.truth, top: variant.top, bottom: variant.bottom, blur: variant.blur) else { continue }
                if index == 0 { try? PNG.write(reference, to: outputDirectory.appendingPathComponent("images/synthetic-\(sample.symbol)-\(variant.name).png")) }
                for method in methods {
                    let began = Date()
                    let r = CoverageFit.fit(sample.symbol, reference: reference, method: method, start: start, size: size)
                    rows.append(Row(symbol: sample.symbol, test: "synthetic:\(variant.name)", method: method.rawValue, truth: sample.truth, fitted: r.params, iou: r.iou, seconds: Date().timeIntervalSince(began)))
                    print("    synthetic \(variant.name.padding(toLength: 14, withPad: " ", startingAt: 0)) \(method.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) \(r.params.short)  IoU \(f3(r.iou))  Δm \(String(format: "%+.4f", r.params.multiplier - sample.truth.multiplier)) Δx \(String(format: "%+.4f", r.params.xOffset - sample.truth.xOffset)) Δy \(String(format: "%+.4f", r.params.yOffset - sample.truth.yOffset))")
                }
            }
            for (enclosure, symbolColour) in combos {
                let reference = try AppexReference.render(sample.symbol, enclosure: enclosure, symbolColour: symbolColour, cacheDirectory: cacheDirectory)
                if index == 0 {
                    let coverage = ReferenceCoverage.normalised(reference, size: size)
                    var rgba = [UInt8](repeating: 255, count: size * size * 4)
                    for i in 0..<coverage.values.count { let v = UInt8(coverage.values[i] * 255); rgba[i * 4] = v; rgba[i * 4 + 1] = v; rgba[i * 4 + 2] = v }
                    try? PNG.write(Pixels.image(rgba, size: size), to: outputDirectory.appendingPathComponent("images/coverage-\(sample.symbol)-\(enclosure)+\(symbolColour).png"))
                }
                for method in methods {
                    let began = Date()
                    let r = CoverageFit.fit(sample.symbol, reference: reference, method: method, start: sample.truth, size: size)
                    rows.append(Row(symbol: sample.symbol, test: "apple:\(enclosure)+\(symbolColour)", method: method.rawValue, truth: nil, fitted: r.params, iou: r.iou, seconds: Date().timeIntervalSince(began)))
                    print("    apple \(enclosure)+\(symbolColour) \(method.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) \(r.params.short)  IoU \(f3(r.iou))  \(String(format: "%.1fs", Date().timeIntervalSince(began)))")
                }
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rows).write(to: outputDirectory.appendingPathComponent("results.json"))
        return summary(rows, combos: combos, methods: methods, size: size)
    }

    static func summary(_ rows: [Row], combos: [(String, String)], methods: [FitMethod], size: Int) -> String {
        let pxPerUnit = Double(IconGeometry.enclosure(forDisplaySize: 1024))
        var out = "## Synthetic references: error against known values\n\n"
        out += "Offsets in enclosure units; 0.001 is \(String(format: "%.2f", pxPerUnit * 0.001)) px on a 1024 px icon. Size error is the multiplier difference.\n\n"
        out += "| reference | method | median abs Δm | max abs Δm | median abs Δx | median abs Δy | max abs Δy | mean signed Δy | weight right |\n|---|---|---|---|---|---|---|---|---|\n"
        var tests: [String] = []
        for r in rows where !tests.contains(r.test) { tests.append(r.test) }
        for test in tests where test.hasPrefix("synthetic") {
            for method in methods {
                let g = rows.filter { $0.test == test && $0.method == method.rawValue }
                guard !g.isEmpty else { continue }
                let dm = g.map { abs($0.fitted.multiplier - $0.truth!.multiplier) }
                let dx = g.map { abs($0.fitted.xOffset - $0.truth!.xOffset) }
                let dy = g.map { abs($0.fitted.yOffset - $0.truth!.yOffset) }
                let sy = g.map { $0.fitted.yOffset - $0.truth!.yOffset }
                out += "| \(test.dropFirst(10)) | \(method.rawValue) | \(f4(median(dm))) | \(f4(dm.max()!)) | \(f4(median(dx))) | \(f4(median(dy))) | \(f4(dy.max()!)) | \(String(format: "%+.4f", mean(sy))) | \(pct(g.filter { $0.fitted.weight == $0.truth!.weight }.count, g.count)) |\n"
            }
        }
        out += "\n## Apple's renders: does the fit depend on the colours?\n\nApple's glyph geometry should not change with colour, so the spread between colour combinations is error the method adds.\n\n"
        out += "| method | mean IoU per combination | median spread m | max spread m | median spread x | median spread y | max spread y | same weight in every combination |\n|---|---|---|---|---|---|---|---|\n"
        let symbols = Array(Set(rows.map(\.symbol))).sorted()
        for method in methods {
            let iouByCombo = combos.map { c -> String in
                let g = rows.filter { $0.test == "apple:\(c.0)+\(c.1)" && $0.method == method.rawValue }
                return "\(c.0)+\(c.1) \(f3(mean(g.map(\.iou))))"
            }.joined(separator: ", ")
            var sm: [Double] = [], sx: [Double] = [], sy: [Double] = [], sameWeight = 0
            for s in symbols {
                let g = rows.filter { $0.symbol == s && $0.method == method.rawValue && $0.test.hasPrefix("apple") }
                guard g.count > 1 else { continue }
                func spread(_ k: KeyPath<IconParams, Double>) -> Double { g.map { $0.fitted[keyPath: k] }.max()! - g.map { $0.fitted[keyPath: k] }.min()! }
                sm.append(spread(\.multiplier)); sx.append(spread(\.xOffset)); sy.append(spread(\.yOffset))
                if Set(g.map(\.fitted.weight)).count == 1 { sameWeight += 1 }
            }
            out += "| \(method.rawValue) | \(iouByCombo) | \(f4(median(sm))) | \(f4(sm.max() ?? 0)) | \(f4(median(sx))) | \(f4(median(sy))) | \(f4(sy.max() ?? 0)) | \(pct(sameWeight, sm.count)) |\n"
        }
        if methods.count == 2 {
            out += "\n## Apple's renders: how far apart the two methods land\n\n| combination | mean signed Δm | mean signed Δy | median abs Δx | weight agrees |\n|---|---|---|---|---|\n"
            for c in combos {
                let key = "apple:\(c.0)+\(c.1)"
                let pairs = symbols.compactMap { s -> (Row, Row)? in
                    guard let a = rows.first(where: { $0.symbol == s && $0.test == key && $0.method == methods[0].rawValue }),
                          let b = rows.first(where: { $0.symbol == s && $0.test == key && $0.method == methods[1].rawValue }) else { return nil }
                    return (a, b)
                }
                out += "| \(c.0)+\(c.1) | \(String(format: "%+.4f", mean(pairs.map { $0.1.fitted.multiplier - $0.0.fitted.multiplier }))) | \(String(format: "%+.4f", mean(pairs.map { $0.1.fitted.yOffset - $0.0.fitted.yOffset }))) | \(f4(median(pairs.map { abs($0.1.fitted.xOffset - $0.0.fitted.xOffset) }))) | \(pct(pairs.filter { $0.0.fitted.weight == $0.1.fitted.weight }.count, pairs.count)) |\n"
            }
            out += "\nSigned differences are \(methods[1].rawValue) minus \(methods[0].rawValue).\n"
        }
        out += "\nMedian seconds per fit: " + methods.map { m in "\(m.rawValue) \(String(format: "%.1f", median(rows.filter { $0.method == m.rawValue }.map(\.seconds))))" }.joined(separator: ", ") + "\n"
        return out
    }
}

func f4(_ v: Double) -> String { String(format: "%.4f", v) }
