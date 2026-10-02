import Foundation

private let usage = """
    vcal — can Apple's vision models calibrate SF Symbol sizing?

      vcal probe                         model availability and capabilities
      vcal render <symbol> [m x y w]     write Apple's reference, Mica's render and the model's views
      vcal perceive [options]            can the model tell which way a known error runs?
      vcal calibrate [options]           one-shot, iterative and pixel-matching runs against hand values

    options:
      --model ondevice|pcc        (ondevice)
      --reasoning light|moderate|deep
      --view overlay|pair|both    (overlay)
      --reference apple|mica      (apple)  mica = Mica's render at the hand values, no render mismatch
      --count N                   symbols to sample (perceive 6, calibrate 12)
      --seed N                    (1)
      --symbols a,b,c             use these instead of sampling
      --axes size,x,y,weight      perceive only
      --methods oneshot,iterate,pixel   calibrate only
      --start perturbed|default   calibrate only (perturbed)
      --steps N                   iterate's step limit (8)
      --think                     ask for a one-sentence observation before the verdict
      --max-tokens N              (256)
    """

private let packageDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
private let calibrationFile = packageDirectory
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Mica/Resources/symbol-calibration.json")

@main
struct VCal {
    @MainActor
    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else { print(usage); return }
        args.removeFirst()

        var options: [String: String] = [:]
        var flags: Set<String> = []
        var positional: [String] = []
        var i = 0
        while i < args.count {
            let a = args[i]
            if a == "--think" { flags.insert("think"); i += 1; continue }
            if a.hasPrefix("--"), i + 1 < args.count { options[String(a.dropFirst(2))] = args[i + 1]; i += 2; continue }
            positional.append(a); i += 1
        }

        do {
            switch command {
            case "probe":
                print(await ModelRunner.availabilityReport())
                print(await ModelRunner.textCheck())
            case "render":
                try render(positional)
            case "perceive", "calibrate":
                try await experiment(command, options: options, flags: flags)
            default:
                print(usage)
            }
        } catch {
            print("error: \(error)")
            exit(1)
        }
    }

    @MainActor
    static func render(_ positional: [String]) throws {
        guard let symbol = positional.first else { throw HarnessError("render needs a symbol name") }
        let params = positional.count >= 5
            ? IconParams(multiplier: Double(positional[1]) ?? 0.65, xOffset: Double(positional[2]) ?? 0, yOffset: Double(positional[3]) ?? 0, weight: positional[4])
            : IconParams(multiplier: 0.65, xOffset: 0, yOffset: 0, weight: "regular")
        let out = packageDirectory.appendingPathComponent("runs/render-\(symbol)")
        let reference = try AppexReference.render(symbol, cacheDirectory: packageDirectory.appendingPathComponent(".cache/refs"))
        guard let candidate = MicaRenderer.render(symbol, params) else { throw HarnessError("render failed") }
        guard let rm = GlyphMask(reference), let cm = GlyphMask(candidate) else { throw HarnessError("no glyph pixels") }
        try PNG.write(reference, to: out.appendingPathComponent("apple.png"))
        try PNG.write(candidate, to: out.appendingPathComponent("mica.png"))
        try PNG.write(Composite.overlay(reference: rm, candidate: cm), to: out.appendingPathComponent("overlay.png"))
        try PNG.write(Composite.pair(reference: reference, candidate: candidate), to: out.appendingPathComponent("pair.png"))
        print("\(params.short)  IoU \(f3(rm.iou(cm)))  reference box \(rm.width)×\(rm.height) at (\(rm.boxCentreX), \(rm.boxCentreY))  mica box \(cm.width)×\(cm.height) at (\(cm.boxCentreX), \(cm.boxCentreY))")
        print(out.path)
    }

    @MainActor
    static func experiment(_ command: String, options: [String: String], flags: Set<String>) async throws {
        guard let model = ModelChoice(rawValue: options["model"] ?? "ondevice") else { throw HarnessError("unknown --model") }
        guard let view = Composite.View(rawValue: options["view"] ?? "overlay") else { throw HarnessError("unknown --view") }
        guard let referenceSource = ReferenceSource(rawValue: options["reference"] ?? "apple") else { throw HarnessError("unknown --reference") }
        let reasoningName = options["reasoning"] ?? "none"
        let runner = ModelRunner(choice: model, reasoning: ModelRunner.reasoningLevel(named: reasoningName),
                                 maximumResponseTokens: Int(options["max-tokens"] ?? "") ?? 256)
        let samples = try GroundTruth.sample(
            from: calibrationFile,
            count: Int(options["count"] ?? "") ?? (command == "perceive" ? 6 : 12),
            seed: UInt64(options["seed"] ?? "") ?? 1,
            only: options["symbols"]?.split(separator: ",").map(String.init) ?? [])

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let name = "\(command)-\(model.rawValue)-\(view.rawValue)-\(referenceSource.rawValue)\(reasoningName == "none" ? "" : "-" + reasoningName)\(flags.contains("think") ? "-think" : "")-\(stamp)"
        let out = packageDirectory.appendingPathComponent("runs/\(name)")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let harness = Harness(runner: runner, view: view, referenceSource: referenceSource, think: flags.contains("think"),
                              cacheDirectory: packageDirectory.appendingPathComponent(".cache/refs"), outputDirectory: out)

        print(await ModelRunner.availabilityReport())
        print("\(command): \(samples.count) symbols → \(out.path)\n")
        let began = Date()
        var report = "# \(command)\n\nmodel \(model.rawValue), reasoning \(reasoningName), view \(view.rawValue), reference \(referenceSource.rawValue), think \(flags.contains("think"))\n"
        report += "symbols: \(samples.map(\.symbol).joined(separator: ", "))\n\n"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if command == "perceive" {
            let axes = options["axes"]?.split(separator: ",").map(String.init) ?? ["size", "x", "y", "weight"]
            let trials = try await Perception.run(harness, samples: samples, axes: axes)
            try encoder.encode(trials).write(to: out.appendingPathComponent("results.json"))
            report += Perception.summary(trials, axes: axes)
        } else {
            let methods = options["methods"]?.split(separator: ",").map(String.init) ?? ["oneshot", "iterate", "pixel"]
            let results = try await Calibration.run(harness, samples: samples, methods: methods,
                                                    startMode: options["start"] ?? "perturbed",
                                                    maxSteps: Int(options["steps"] ?? "") ?? 8, saveImagesFor: 3)
            try encoder.encode(results).write(to: out.appendingPathComponent("results.json"))
            report += Calibration.summary(results)
        }
        report += "\nWall time \(String(format: "%.0f", Date().timeIntervalSince(began)))s, \(harness.callCount) model calls.\n"
        try report.write(to: out.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
        print("\n" + report)
    }
}
