// CalibrationStoreTests.swift
// CalibrationStore persists per-symbol calibration to JSON on disk. Tests
// drive it against an injected fileURL in NSTemporaryDirectory so no real
// user data in Application Support is ever read or written.

import Testing
import Foundation
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct CalibrationStoreTests {

    // MARK: - Helpers

    /// A fresh temp directory unique to this test; cleaned up via deinit pattern.
    final class TempDir {
        let url: URL
        init() {
            url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("CalibrationStoreTests-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        deinit {
            try? FileManager.default.removeItem(at: url)
        }

        func fileURL(named name: String = "icon-calibration.json") -> URL {
            url.appendingPathComponent(name)
        }
    }

    static func sampleEntry(
        multiplier: Double = 0.62,
        xOffset: Double = 0.01,
        yOffset: Double = -0.02,
        weight: String = "regular",
        status: String = "calibrated"
    ) -> CalibrationEntry {
        CalibrationEntry(
            multiplier: multiplier,
            xOffset: xOffset,
            yOffset: yOffset,
            weight: weight,
            status: status
        )
    }

    // MARK: - Tests

    @Test("Fresh store at an empty fileURL has no entries")
    func freshStore_empty() {
        let temp = TempDir()
        let store = CalibrationStore(fileURL: temp.fileURL())
        #expect(store.entries.isEmpty)
        #expect(store.entry(for: "star.fill") == nil)
    }

    @Test("setEntry persists to disk; a new store reads it back")
    func setEntry_roundTrip() throws {
        let temp = TempDir()
        let path = temp.fileURL()

        let store1 = CalibrationStore(fileURL: path)
        store1.setEntry(Self.sampleEntry(), for: "star.fill")

        // The file must exist after setEntry.
        #expect(FileManager.default.fileExists(atPath: path.path))

        // A second store pointed at the same file reads the entry.
        let store2 = CalibrationStore(fileURL: path)
        let readBack = try #require(store2.entry(for: "star.fill"))
        #expect(readBack.multiplier == 0.62)
        #expect(readBack.xOffset == 0.01)
        #expect(readBack.yOffset == -0.02)
        #expect(readBack.weight == "regular")
        #expect(readBack.status == "calibrated")
    }

    @Test("calibratedCount and skippedCount classify entries by status")
    func stats_classifyByStatus() {
        let temp = TempDir()
        let store = CalibrationStore(fileURL: temp.fileURL())
        store.setEntry(Self.sampleEntry(status: "calibrated"),   for: "a")
        store.setEntry(Self.sampleEntry(status: "calibrated"),   for: "b")
        store.setEntry(Self.sampleEntry(status: "skipped"),      for: "c")
        store.setEntry(Self.sampleEntry(status: "needs-review"), for: "d")

        #expect(store.calibratedCount == 2)
        #expect(store.skippedCount == 1)
    }

    @Test("Overwriting an entry replaces the previous value")
    func setEntry_overwrites() throws {
        let temp = TempDir()
        let store = CalibrationStore(fileURL: temp.fileURL())
        store.setEntry(Self.sampleEntry(multiplier: 0.40), for: "star.fill")
        store.setEntry(Self.sampleEntry(multiplier: 0.70), for: "star.fill")
        let entry = try #require(store.entry(for: "star.fill"))
        #expect(entry.multiplier == 0.70)
    }

    @Test("Corrupt file data leaves entries empty without crashing")
    func corruptFile_ignoredSilently() throws {
        let temp = TempDir()
        let path = temp.fileURL()
        try "not json".data(using: .utf8)!.write(to: path)

        let store = CalibrationStore(fileURL: path)
        #expect(store.entries.isEmpty)
    }
}
