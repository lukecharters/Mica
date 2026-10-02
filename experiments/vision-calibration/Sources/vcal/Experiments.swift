import CoreGraphics
import Foundation

enum ReferenceSource: String {
    /// Apple's appex render: the real calibration task.
    case apple
    /// Mica's own render at the hand-calibrated values: perception with no rendering mismatch.
    case mica
}

/// Sign and rough size of a judgement: -1/0/+1, and 0.5/1/2 for slight/plain/far.
struct Judged: Codable {
    var size: Int, x: Int, y: Int, weight: Int
    var sizeMagnitude: Double, xMagnitude: Double, yMagnitude: Double, weightMagnitude: Double

    init(_ c: Comparison) {
        func s(_ v: SizeComparison) -> (Int, Double) {
            switch v {
            case .muchSmaller: (-1, 2); case .smaller: (-1, 1); case .slightlySmaller: (-1, 0.5)
            case .same: (0, 0)
            case .slightlyLarger: (1, 0.5); case .larger: (1, 1); case .muchLarger: (1, 2)
            }
        }
        func h(_ v: HorizontalComparison) -> (Int, Double) {
            switch v {
            case .farLeft: (-1, 2); case .left: (-1, 1); case .slightlyLeft: (-1, 0.5)
            case .aligned: (0, 0)
            case .slightlyRight: (1, 0.5); case .right: (1, 1); case .farRight: (1, 2)
            }
        }
        func v(_ v: VerticalComparison) -> (Int, Double) {
            switch v {
            case .farHigher: (-1, 2); case .higher: (-1, 1); case .slightlyHigher: (-1, 0.5)
            case .aligned: (0, 0)
            case .slightlyLower: (1, 0.5); case .lower: (1, 1); case .farLower: (1, 2)
            }
        }
        func w(_ v: WeightComparison) -> (Int, Double) {
            switch v {
            case .muchThinner: (-1, 2); case .thinner: (-1, 1)
            case .same: (0, 0)
            case .thicker: (1, 1); case .muchThicker: (1, 2)
            }
        }
        (size, sizeMagnitude) = s(c.size)
        (x, xMagnitude) = h(c.horizontal)
        (y, yMagnitude) = v(c.vertical)
        (weight, weightMagnitude) = w(c.weight)
    }

    var isMatch: Bool { size == 0 && x == 0 && y == 0 && weight == 0 }
}

@MainActor
final class Harness {
    let runner: ModelRunner
    let view: Composite.View
    let referenceSource: ReferenceSource
    let think: Bool
    let cacheDirectory: URL
    let outputDirectory: URL
    var callCount = 0

    init(runner: ModelRunner, view: Composite.View, referenceSource: ReferenceSource, think: Bool,
         cacheDirectory: URL, outputDirectory: URL) {
        self.runner = runner
        self.view = view
        self.referenceSource = referenceSource
        self.think = think
        self.cacheDirectory = cacheDirectory
        self.outputDirectory = outputDirectory
    }

    func reference(for sample: Sample) throws -> (CGImage, GlyphMask) {
        let image: CGImage
        switch referenceSource {
        case .apple: image = try AppexReference.render(sample.symbol, cacheDirectory: cacheDirectory)
        case .mica:
            guard let rendered = MicaRenderer.render(sample.symbol, sample.truth) else { throw HarnessError("render failed") }
            image = rendered
        }
        guard let mask = GlyphMask(image) else { throw HarnessError("no glyph pixels in the reference for \(sample.symbol)") }
        return (image, mask)
    }

    func candidate(_ symbol: String, _ params: IconParams) -> (CGImage, GlyphMask)? {
        guard let image = MicaRenderer.render(symbol, params), let mask = GlyphMask(image) else { return nil }
        return (image, mask)
    }

    func modelImages(reference: (CGImage, GlyphMask), candidate: (CGImage, GlyphMask)) -> [CGImage] {
        Prompts.images(view, reference: reference.0, candidate: candidate.0,
                       referenceMask: reference.1, candidateMask: candidate.1)
    }

    func compare(reference: (CGImage, GlyphMask), candidate: (CGImage, GlyphMask)) async -> ModelCall<Comparison> {
        callCount += 1
        let images = modelImages(reference: reference, candidate: candidate)
        let prompt = Prompts.describe(view) + "\nHow does the candidate glyph differ from the reference glyph?"
        if think {
            let call = await runner.ask(ComparisonWithNote.self, instructions: Prompts.instructions, prompt: prompt, images: images)
            return ModelCall(value: call.value?.comparison, error: call.error, seconds: call.seconds)
        }
        return await runner.ask(Comparison.self, instructions: Prompts.instructions, prompt: prompt, images: images)
    }

    func save(_ images: [CGImage], _ name: String) {
        for (i, image) in images.enumerated() {
            try? PNG.write(image, to: outputDirectory.appendingPathComponent("images/\(name)\(images.count > 1 ? "-\(i)" : "").png"))
        }
    }
}

// MARK: - Perception

struct PerceptionTrial: Codable {
    var symbol: String
    var axis: String
    var delta: Double
    var expected: Int
    var answer: Judged?
    var error: String?
    var seconds: Double

    var observed: Int? {
        guard let a = answer else { return nil }
        switch axis {
        case "size": return a.size
        case "x": return a.x
        case "y": return a.y
        case "weight": return a.weight
        default: return 0
        }
    }

    func falseAlarms(on other: String) -> Int? {
        guard let a = answer, other != axis else { return nil }
        switch other {
        case "size": return a.size != 0 ? 1 : 0
        case "x": return a.x != 0 ? 1 : 0
        case "y": return a.y != 0 ? 1 : 0
        case "weight": return a.weight != 0 ? 1 : 0
        default: return nil
        }
    }
}

enum Perception {
    static let deltas: [String: [Double]] = [
        "size": [-0.20, -0.10, -0.05, -0.02, 0.02, 0.05, 0.10, 0.20],
        "x": [-0.06, -0.03, -0.01, 0.01, 0.03, 0.06],
        "y": [-0.06, -0.03, -0.01, 0.01, 0.03, 0.06],
        "weight": [-2, -1, 1, 2],
        "none": [0],
    ]

    static func perturb(_ p: IconParams, axis: String, delta: Double) -> IconParams? {
        var q = p
        switch axis {
        case "size": q.multiplier *= 1 + delta
        case "x": q.xOffset += delta
        case "y": q.yOffset += delta
        case "weight":
            let index = p.weightIndex + Int(delta)
            guard IconParams.weightTokens.indices.contains(index) else { return nil }
            q = p.withWeight(index: index)
        default: break
        }
        return q
    }

    @MainActor
    static func run(_ harness: Harness, samples: [Sample], axes: [String]) async throws -> [PerceptionTrial] {
        var trials: [PerceptionTrial] = []
        for (sampleIndex, sample) in samples.enumerated() {
            let reference = try harness.reference(for: sample)
            for axis in axes + ["none"] {
                for delta in deltas[axis] ?? [] {
                    guard let params = perturb(sample.truth, axis: axis, delta: delta),
                          let candidate = harness.candidate(sample.symbol, params) else { continue }
                    if sampleIndex < 2 {
                        harness.save(harness.modelImages(reference: reference, candidate: candidate),
                                     "perceive-\(sample.symbol)-\(axis)\(String(format: "%+.2f", delta))")
                    }
                    let call = await harness.compare(reference: reference, candidate: candidate)
                    let trial = PerceptionTrial(
                        symbol: sample.symbol, axis: axis, delta: delta,
                        expected: delta > 0 ? 1 : (delta < 0 ? -1 : 0),
                        answer: call.value.map(Judged.init), error: call.error, seconds: call.seconds)
                    trials.append(trial)
                    let verdict = trial.observed.map { $0 == trial.expected ? "ok " : "MISS" } ?? "ERR "
                    print("  \(verdict) \(sample.symbol) \(axis) \(String(format: "%+.2f", delta)) -> \(call.value.map { "\($0.size.rawValue)/\($0.horizontal.rawValue)/\($0.vertical.rawValue)/\($0.weight.rawValue)" } ?? (call.error ?? "")) \(String(format: "%.1fs", call.seconds))")
                }
            }
        }
        return trials
    }

    static func summary(_ trials: [PerceptionTrial], axes: [String]) -> String {
        var out = "## Direction accuracy by axis and error size\n\n"
        out += "A trial is correct when the model names the right direction on the perturbed axis. Chance is about 33%.\n\n"
        out += "| axis | delta | n | correct | said same | correct when + | correct when − |\n|---|---|---|---|---|---|---|\n"
        for axis in axes {
            let magnitudes = Set((deltas[axis] ?? []).map { abs($0) }).sorted()
            for m in magnitudes {
                let group = trials.filter { $0.axis == axis && abs(abs($0.delta) - m) < 1e-9 && $0.answer != nil }
                guard !group.isEmpty else { continue }
                let correct = group.filter { $0.observed == $0.expected }.count
                let same = group.filter { $0.observed == 0 }.count
                let plus = group.filter { $0.delta > 0 }, minus = group.filter { $0.delta < 0 }
                let label = axis == "size" ? String(format: "%.0f%%", m * 100)
                    : axis == "weight" ? String(format: "%.0f step", m) : String(format: "%.2f enc", m)
                out += "| \(axis) | \(label) | \(group.count) | \(pct(correct, group.count)) | \(pct(same, group.count)) | \(pct(plus.filter { $0.observed == 1 }.count, plus.count)) | \(pct(minus.filter { $0.observed == -1 }.count, minus.count)) |\n"
            }
        }
        out += "\n## False alarms\n\nHow often the model reported a difference on an axis that was not perturbed.\n\n| axis | n | reported a difference |\n|---|---|---|\n"
        for axis in axes {
            let values = trials.compactMap { $0.falseAlarms(on: axis) }
            out += "| \(axis) | \(values.count) | \(pct(values.reduce(0, +), values.count)) |\n"
        }
        let control = trials.filter { $0.axis == "none" && $0.answer != nil }
        out += "\nUnperturbed controls answered as a full match: \(pct(control.filter { $0.answer!.isMatch }.count, control.count)) of \(control.count).\n"
        let errors = trials.filter { $0.error != nil }
        out += "\nErrors: \(errors.count) of \(trials.count)."
        if let first = errors.first?.error { out += " First: `\(first.prefix(200))`" }
        out += "\n\nMedian seconds per call: \(String(format: "%.2f", median(trials.map(\.seconds))))\n"
        return out
    }
}

// MARK: - Calibration

struct CalibrationResult: Codable {
    var symbol: String
    var stratum: String
    var method: String
    var truth: IconParams
    var start: IconParams
    var final: IconParams
    var iou: Double
    var truthIoU: Double
    var calls: Int
    var renders: Int
    var seconds: Double
    var stopped: String
    var trace: [String]

    var dm: Double { abs(final.multiplier - truth.multiplier) }
    var dx: Double { abs(final.xOffset - truth.xOffset) }
    var dy: Double { abs(final.yOffset - truth.yOffset) }
    var weightMatch: Bool { final.weight == truth.weight }
    var withinTolerance: Bool { dm <= 0.01 && dx <= 0.01 && dy <= 0.01 && weightMatch }
}

enum Calibration {
    static func perturbedStart(_ truth: IconParams, seed: UInt64) -> IconParams {
        var rng = SplitMix64(seed: seed)
        func signed(_ range: ClosedRange<Double>) -> Double {
            Double.random(in: range, using: &rng) * (Bool.random(using: &rng) ? 1 : -1)
        }
        var p = truth
        p.multiplier = truth.multiplier * (1 + signed(0.08...0.20))
        p.xOffset = truth.xOffset + signed(0.02...0.06)
        p.yOffset = truth.yOffset + signed(0.02...0.06)
        if Bool.random(using: &rng) {
            let shifted = truth.weightIndex + (Bool.random(using: &rng) ? 1 : -1)
            p = p.withWeight(index: IconParams.weightTokens.indices.contains(shifted) ? shifted : truth.weightIndex - (shifted - truth.weightIndex))
        }
        return p
    }

    static let defaultStart = IconParams(multiplier: 0.60, xOffset: 0, yOffset: 0, weight: "regular")

    // MARK: One shot

    @MainActor
    static func oneShot(_ h: Harness, _ sample: Sample, reference: (CGImage, GlyphMask), start: IconParams, save: Bool) async -> (IconParams, Int, Double, String, [String]) {
        guard let candidate = h.candidate(sample.symbol, start) else { return (start, 0, 0, "render failed", []) }
        let images = h.modelImages(reference: reference, candidate: candidate)
        if save { h.save(images, "oneshot-\(sample.symbol)") }
        h.callCount += 1
        let prompt = Prompts.describe(h.view) + "\nEstimate the corrections that would make the candidate glyph match the reference glyph exactly."
        let call = await h.runner.ask(Estimate.self, instructions: Prompts.instructions, prompt: prompt, images: images)
        guard let e = call.value else { return (start, 1, call.seconds, "error: \(call.error ?? "")", []) }
        let imageToEnclosure = Double(GlyphMask.size) / GlyphMask.enclosurePixels
        var p = start
        p.multiplier *= e.referenceSizePercent / 100
        p.xOffset += e.moveRightPercent / 100 * imageToEnclosure
        p.yOffset += e.moveDownPercent / 100 * imageToEnclosure
        let weightStep: Int = switch e.weight {
        case .muchThinner: 2; case .thinner: 1; case .same: 0; case .thicker: -1; case .muchThicker: -2
        }
        p = p.withWeight(index: p.weightIndex + weightStep)
        let note = String(format: "size %.0f%% right %+.1f%% down %+.1f%% weight %@", e.referenceSizePercent, e.moveRightPercent, e.moveDownPercent, e.weight.rawValue)
        return (p, 1, call.seconds, "answered", [note])
    }

    // MARK: Iterative

    /// Model-only feedback loop: the model names a direction and rough size per axis; each axis
    /// keeps its own step, halved whenever the model reverses direction on it.
    @MainActor
    static func iterate(_ h: Harness, _ sample: Sample, reference: (CGImage, GlyphMask), start: IconParams, maxSteps: Int, save: Bool) async -> (IconParams, Int, Double, String, [String]) {
        var p = start
        var stepSize = 0.08, stepX = 0.03, stepY = 0.03
        var lastSize = 0, lastX = 0, lastY = 0, lastWeight = 0
        var weightFrozen = false
        var calls = 0, seconds = 0.0
        var trace: [String] = []
        for step in 0..<maxSteps {
            guard let candidate = h.candidate(sample.symbol, p) else { return (p, calls, seconds, "render failed", trace) }
            if save { h.save(h.modelImages(reference: reference, candidate: candidate), "iterate-\(sample.symbol)-step\(step)") }
            let call = await h.compare(reference: reference, candidate: candidate)
            calls += 1; seconds += call.seconds
            guard let c = call.value else { return (p, calls, seconds, "error: \(call.error ?? "")", trace) }
            let j = Judged(c)
            trace.append("\(p.short) -> \(c.size.rawValue)/\(c.horizontal.rawValue)/\(c.vertical.rawValue)/\(c.weight.rawValue)")
            if j.isMatch || (j.size == 0 && j.x == 0 && j.y == 0 && weightFrozen) { return (p, calls, seconds, "model says match", trace) }

            // The judgement describes the candidate, so each correction runs the other way.
            if j.size != 0 {
                if lastSize != 0 && j.size != lastSize { stepSize = max(stepSize / 2, 0.004) }
                p.multiplier *= 1 - Double(j.size) * j.sizeMagnitude * stepSize
                lastSize = j.size
            }
            if j.x != 0 {
                if lastX != 0 && j.x != lastX { stepX = max(stepX / 2, 0.003) }
                p.xOffset -= Double(j.x) * j.xMagnitude * stepX
                lastX = j.x
            }
            if j.y != 0 {
                if lastY != 0 && j.y != lastY { stepY = max(stepY / 2, 0.003) }
                p.yOffset -= Double(j.y) * j.yMagnitude * stepY
                lastY = j.y
            }
            if j.weight != 0 && !weightFrozen {
                let move = j.weight > 0 ? -1 : 1
                if lastWeight != 0 && move != lastWeight { weightFrozen = true } else {
                    p = p.withWeight(index: p.weightIndex + move)
                    lastWeight = move
                }
            }
        }
        return (p, calls, seconds, "step limit", trace)
    }

    // MARK: Pixel baseline

    /// No model: line up the glyph masks' bounding boxes, then coordinate-descend on IoU, once per weight.
    @MainActor
    static func pixelFit(_ h: Harness, _ sample: Sample, reference: GlyphMask, start: IconParams) -> (IconParams, Int) {
        var renders = 0
        func score(_ p: IconParams) -> Double {
            renders += 1
            return h.candidate(sample.symbol, p)?.1.iou(reference) ?? 0
        }
        var best = start, bestScore = -1.0
        for weightIndex in IconParams.weightTokens.indices {
            var p = start.withWeight(index: weightIndex)
            if let m = h.candidate(sample.symbol, p)?.1 {
                renders += 1
                p.multiplier *= (Double(reference.height) / Double(m.height) + Double(reference.width) / Double(m.width)) / 2
            }
            if let m = h.candidate(sample.symbol, p)?.1 {
                renders += 1
                p.xOffset += (reference.boxCentreX - m.boxCentreX) / GlyphMask.enclosurePixels
                p.yOffset += (reference.boxCentreY - m.boxCentreY) / GlyphMask.enclosurePixels
            }
            var current = score(p)
            var steps = [0.02, 0.01, 0.01]
            while steps.max()! > 0.001 {
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
            if current > bestScore { best = p; bestScore = current }
        }
        return (best, renders)
    }

    @MainActor
    static func run(_ h: Harness, samples: [Sample], methods: [String], startMode: String, maxSteps: Int, saveImagesFor: Int) async throws -> [CalibrationResult] {
        var results: [CalibrationResult] = []
        for (index, sample) in samples.enumerated() {
            let reference = try h.reference(for: sample)
            let truthIoU = h.candidate(sample.symbol, sample.truth)?.1.iou(reference.1) ?? 0
            let start = startMode == "default" ? defaultStart : perturbedStart(sample.truth, seed: UInt64(index + 1) &* 7919)
            let startIoU = h.candidate(sample.symbol, start)?.1.iou(reference.1) ?? 0
            print("[\(index + 1)/\(samples.count)] \(sample.symbol) (\(sample.stratum))  truth \(sample.truth.short) IoU \(String(format: "%.3f", truthIoU))")
            print("    start      \(start.short) IoU \(String(format: "%.3f", startIoU))")
            results.append(CalibrationResult(symbol: sample.symbol, stratum: sample.stratum, method: "start", truth: sample.truth, start: start, final: start, iou: startIoU, truthIoU: truthIoU, calls: 0, renders: 0, seconds: 0, stopped: "", trace: []))
            let save = index < saveImagesFor
            for method in methods {
                let began = Date()
                var final = start, calls = 0, renders = 0, modelSeconds = 0.0, stopped = "", trace: [String] = []
                switch method {
                case "oneshot":
                    (final, calls, modelSeconds, stopped, trace) = await oneShot(h, sample, reference: reference, start: start, save: save)
                case "iterate":
                    (final, calls, modelSeconds, stopped, trace) = await iterate(h, sample, reference: reference, start: start, maxSteps: maxSteps, save: save)
                case "pixel":
                    (final, renders) = pixelFit(h, sample, reference: reference.1, start: start)
                    stopped = "converged"
                default:
                    throw HarnessError("unknown method \(method)")
                }
                let iou = h.candidate(sample.symbol, final)?.1.iou(reference.1) ?? 0
                let seconds = method == "pixel" ? Date().timeIntervalSince(began) : modelSeconds
                let result = CalibrationResult(symbol: sample.symbol, stratum: sample.stratum, method: method, truth: sample.truth, start: start, final: final, iou: iou, truthIoU: truthIoU, calls: calls, renders: renders, seconds: seconds, stopped: stopped, trace: trace)
                results.append(result)
                print("    \(method.padding(toLength: 10, withPad: " ", startingAt: 0)) \(final.short) IoU \(String(format: "%.3f", iou))  Δm \(String(format: "%.3f", result.dm)) Δx \(String(format: "%.3f", result.dx)) Δy \(String(format: "%.3f", result.dy)) w \(result.weightMatch ? "✓" : "✗")  \(calls) calls \(String(format: "%.1fs", seconds))  \(stopped)")
            }
        }
        return results
    }

    static func summary(_ results: [CalibrationResult]) -> String {
        var out = "## Error against the hand-calibrated values\n\n"
        out += "Within tolerance means |Δm|, |Δx| and |Δy| all ≤ 0.01 and the weight matches. IoU is glyph overlap with the reference; the truth row is the ceiling the hand values reach.\n\n"
        out += "| method | n | median Δm | median Δx | median Δy | weight ✓ | within tol. | mean IoU | mean calls | median s |\n|---|---|---|---|---|---|---|---|---|---|\n"
        var truthRow = results.filter { $0.method == "start" }
        for i in truthRow.indices { truthRow[i].final = truthRow[i].truth; truthRow[i].iou = truthRow[i].truthIoU; truthRow[i].method = "truth" }
        var methods: [String] = []
        for r in results where !methods.contains(r.method) { methods.append(r.method) }
        for method in methods + ["truth"] {
            let group = method == "truth" ? truthRow : results.filter { $0.method == method }
            guard !group.isEmpty else { continue }
            out += "| \(method) | \(group.count) | \(f3(median(group.map(\.dm)))) | \(f3(median(group.map(\.dx)))) | \(f3(median(group.map(\.dy)))) | \(pct(group.filter(\.weightMatch).count, group.count)) | \(pct(group.filter(\.withinTolerance).count, group.count)) | \(f3(mean(group.map(\.iou)))) | \(String(format: "%.1f", mean(group.map { Double($0.calls) }))) | \(String(format: "%.1f", median(group.map(\.seconds)))) |\n"
        }
        out += "\n## Did the method improve on where it started?\n\n| method | IoU better than start | IoU at or above truth |\n|---|---|---|\n"
        let starts = Dictionary(uniqueKeysWithValues: results.filter { $0.method == "start" }.map { ($0.symbol, $0.iou) })
        for method in methods where method != "start" {
            let group = results.filter { $0.method == method }
            out += "| \(method) | \(pct(group.filter { $0.iou > (starts[$0.symbol] ?? 0) + 0.005 }.count, group.count)) | \(pct(group.filter { $0.iou >= $0.truthIoU - 0.005 }.count, group.count)) |\n"
        }
        let pixel = Dictionary(uniqueKeysWithValues: results.filter { $0.method == "pixel" }.map { ($0.symbol, $0.final) })
        if !pixel.isEmpty {
            out += "\n## Distance from the pixel fit\n\nThe hand values predate macOS 27 for some symbols, so the pixel fit is the better stand-in for where Apple draws the glyph now. Weight is left out: the pixel fit's choice between regular and medium is a few hundredths of IoU either way.\n\n| method | median Δm | median Δx | median Δy | all three ≤ 0.01 |\n|---|---|---|---|---|\n"
            for method in methods where method != "pixel" {
                let group = results.filter { $0.method == method && pixel[$0.symbol] != nil }
                let d = group.map { r -> (Double, Double, Double) in
                    let p = pixel[r.symbol]!
                    return (abs(r.final.multiplier - p.multiplier), abs(r.final.xOffset - p.xOffset), abs(r.final.yOffset - p.yOffset))
                }
                out += "| \(method) | \(f3(median(d.map(\.0)))) | \(f3(median(d.map(\.1)))) | \(f3(median(d.map(\.2)))) | \(pct(d.filter { $0.0 <= 0.01 && $0.1 <= 0.01 && $0.2 <= 0.01 }.count, d.count)) |\n"
            }
            let truth = results.filter { $0.method == "start" }.map { r -> (Double, Double, Double) in
                let p = pixel[r.symbol]!
                return (abs(r.truth.multiplier - p.multiplier), abs(r.truth.xOffset - p.xOffset), abs(r.truth.yOffset - p.yOffset))
            }
            out += "| hand values | \(f3(median(truth.map(\.0)))) | \(f3(median(truth.map(\.1)))) | \(f3(median(truth.map(\.2)))) | \(pct(truth.filter { $0.0 <= 0.01 && $0.1 <= 0.01 && $0.2 <= 0.01 }.count, truth.count)) |\n"
        }
        let stops = Dictionary(grouping: results.filter { $0.method == "iterate" }, by: { $0.stopped.hasPrefix("error") ? "error" : $0.stopped }).mapValues(\.count)
        if !stops.isEmpty { out += "\nIterate stopped by: \(stops.map { "\($0.key) \($0.value)" }.sorted().joined(separator: ", "))\n" }
        return out
    }
}

// MARK: - Helpers

func pct(_ n: Int, _ d: Int) -> String { d == 0 ? "–" : String(format: "%.0f%%", 100 * Double(n) / Double(d)) }
func f3(_ v: Double) -> String { String(format: "%.3f", v) }
func mean(_ v: [Double]) -> Double { v.isEmpty ? 0 : v.reduce(0, +) / Double(v.count) }
func median(_ v: [Double]) -> Double {
    guard !v.isEmpty else { return 0 }
    let s = v.sorted()
    return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
}
