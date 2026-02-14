// CalibrationStore.swift - JSON persistence for per-symbol calibration data
import Foundation

struct CalibrationEntry: Codable, Equatable {
    var multiplier: Double      // absolute pointsize_to_shape_mul (no recipeScaleFactor)
    var xOffset: Double         // fractional offset relative to enclosure
    var yOffset: Double         // fractional offset relative to enclosure
    var weight: String          // "regular" or "medium"
    var status: String          // "calibrated", "skipped", "needs-review"
}

struct CalibrationFile: Codable {
    var version: Int = 1
    var calibrations: [String: CalibrationEntry] = [:]
}

@Observable
class CalibrationStore {
    var entries: [String: CalibrationEntry] = [:]
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Icon Generator", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("icon-calibration.json")
        print("CalibrationStore: \(fileURL.path)")
        load()
    }

    func entry(for symbol: String) -> CalibrationEntry? {
        entries[symbol]
    }

    func setEntry(_ entry: CalibrationEntry, for symbol: String) {
        entries[symbol] = entry
        save()
    }

    func save() {
        let file = CalibrationFile(version: 1, calibrations: entries)
        do {
            let data = try JSONEncoder.prettyCalibration.encode(file)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("CalibrationStore: failed to save — \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let file = try JSONDecoder().decode(CalibrationFile.self, from: data)
            entries = file.calibrations
        } catch {
            print("CalibrationStore: failed to load — \(error)")
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
