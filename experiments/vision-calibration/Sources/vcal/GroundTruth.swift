import AppKit
import Foundation

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct Sample {
    let symbol: String
    let truth: IconParams
    let stratum: String
}

/// Hand-calibrated entries from `symbol-calibration.json`, drawn evenly from four strata so the
/// sample is not dominated by the 0.65 / 0 / 0 / regular majority.
enum GroundTruth {
    private struct File: Decodable {
        struct Entry: Decodable {
            var multiplier: Double
            var xOffset: Double
            var yOffset: Double
            var weight: String
            var status: String
            var source: String?
        }
        var symbols: [String: Entry]
    }

    static func sample(from url: URL, count: Int, seed: UInt64, only: [String]) throws -> [Sample] {
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        let usable = file.symbols
            .filter { $0.value.status == "calibrated" && $0.value.source == nil }
            .filter { NSImage(systemSymbolName: $0.key, accessibilityDescription: nil) != nil }
            .map { name, e in
                (name, IconParams(multiplier: e.multiplier, xOffset: e.xOffset, yOffset: e.yOffset, weight: e.weight))
            }
            .sorted { $0.0 < $1.0 }

        if !only.isEmpty {
            return only.compactMap { name in
                usable.first { $0.0 == name }.map { Sample(symbol: $0.0, truth: $0.1, stratum: "named") }
            }
        }

        func stratum(_ p: IconParams) -> String {
            if p.xOffset != 0 || p.yOffset != 0 { return "offset" }
            if p.weight != "regular" { return "weight" }
            if p.multiplier < 0.62 { return "small" }
            return "default"
        }
        var rng = SplitMix64(seed: seed)
        var buckets = Dictionary(grouping: usable, by: { stratum($0.1) }).mapValues { $0.shuffled(using: &rng) }
        let order = ["offset", "weight", "small", "default"]
        var result: [Sample] = []
        var index = 0
        while result.count < count, buckets.values.contains(where: { !$0.isEmpty }) {
            let key = order[index % order.count]
            if var bucket = buckets[key], !bucket.isEmpty {
                let (name, params) = bucket.removeFirst()
                buckets[key] = bucket
                result.append(Sample(symbol: name, truth: params, stratum: key))
            }
            index += 1
        }
        return result
    }
}
