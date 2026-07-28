// App/ReferenceCalibrationStore.swift
//
// JSON persistence for the Apple Reference (⇧⌘K) tool's ground-truth capture —
// icon-calibration.json, one entry per symbol measured against Apple's appex
// render.
//
// Not to be confused with SymbolCalibration / SymbolCalibrationStore, which is
// the *shipped sizing* data the renderer reads (symbol-calibration.json). This
// store feeds that one by hand; the renderer never reads this file.
import Foundation

struct ReferenceCalibrationEntry: Codable, Equatable {
    var multiplier: Double      // absolute pointsize_to_shape_mul (no recipeScaleFactor)
    var xOffset: Double         // fractional offset relative to enclosure
    var yOffset: Double         // fractional offset relative to enclosure
    var weight: String          // "regular" or "medium"
    var status: String          // "calibrated", "skipped", "needs-review"
}

struct ReferenceCalibration: Codable {
    var version: Int = 1
    var calibrations: [String: ReferenceCalibrationEntry] = [:]
}

@Observable
class ReferenceCalibrationStore {
    var entries: [String: ReferenceCalibrationEntry] = [:]
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("Mica", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("icon-calibration.json")
        }
        print("ReferenceCalibrationStore: \(self.fileURL.path)")
        load()
    }

    func entry(for symbol: String) -> ReferenceCalibrationEntry? {
        entries[symbol]
    }

    func setEntry(_ entry: ReferenceCalibrationEntry, for symbol: String) {
        entries[symbol] = entry
        save()
    }

    func save() {
        let file = ReferenceCalibration(version: 1, calibrations: entries)
        do {
            let data = try JSONEncoder.prettyCalibration.encode(file)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ReferenceCalibrationStore: failed to save — \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let file = try JSONDecoder().decode(ReferenceCalibration.self, from: data)
            entries = file.calibrations
        } catch {
            print("ReferenceCalibrationStore: failed to load — \(error)")
        }
    }

    // MARK: - Stats

    var calibratedCount: Int {
        entries.values.filter { $0.status == "calibrated" }.count
    }

    var skippedCount: Int {
        entries.values.filter { $0.status == "skipped" }.count
    }
}

private extension JSONEncoder {
    static let prettyCalibration: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
