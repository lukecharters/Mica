// CalibrationAdvanceTests.swift
// Where the symbol calibration tool lands after Space or Escape.

import Testing
@testable import Mica

@Suite(.tags(.unit))
struct CalibrationAdvanceTests {

    @Test func movesToTheNextSymbol() {
        let list = ["a", "b", "c"]
        #expect(CalibrationAdvance.next(symbol: "a", before: list, after: list) == .index(1))
    }

    @Test func aSymbolThatLeavesTheFilterDoesNotSkipTheNextOne() {
        let step = CalibrationAdvance.next(symbol: "b", before: ["a", "b", "c"], after: ["a", "c"])
        #expect(step == .index(1))
    }

    @Test func theLastSymbolStays() {
        let list = ["a", "b"]
        #expect(CalibrationAdvance.next(symbol: "b", before: list, after: list) == .stay)
    }

    @Test func theLastSymbolLeavingTheFilterLandsOnTheNewLast() {
        #expect(CalibrationAdvance.next(symbol: "b", before: ["a", "b"], after: ["a"]) == .index(0))
    }

    @Test func anEmptiedFilterStays() {
        #expect(CalibrationAdvance.next(symbol: "a", before: ["a"], after: []) == .stay)
    }
}

@Suite(.tags(.unit))
struct CalibrationReviewListTests {
    private static func fitted(_ score: Double, status: String = "calibrated", reviewed: Bool? = nil) -> SymbolCalibrationEntry {
        var entry = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0, yOffset: 0, weight: "regular",
                                           status: status, source: "pixel-fit", fitScore: score)
        entry.reviewed = reviewed
        return entry
    }

    private static let hand = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0, yOffset: 0,
                                                     weight: "regular", status: "calibrated")

    private static let entries: [String: SymbolCalibrationEntry] = [
        "good": fitted(0.97),
        "flagged": fitted(0.70, status: "needs-review"),
        "accepted": fitted(0.80, reviewed: true),
        "skipped": fitted(0.90, status: "skipped", reviewed: true),
        "hand": hand,
        "retired": hand,
    ]

    private static let catalog = ["good", "flagged", "accepted", "skipped", "hand", "missing"]

    private func list(_ filter: CalibrationReviewFilter, sort: CalibrationReviewSort = .name,
                      search: String = "") -> [String] {
        CalibrationReviewList.symbols(catalog: Self.catalog, entries: Self.entries, filter: filter,
                                      threshold: 0.85, search: search, sort: sort)
    }

    @Test func allShowsCatalogNamesAndEntriesOutsideIt() {
        #expect(list(.all) == ["accepted", "flagged", "good", "hand", "missing", "retired", "skipped"])
    }

    @Test(arguments: [
        (CalibrationReviewFilter.needsReview, ["flagged"]),
        (.lowScore, ["accepted", "flagged"]),
        (.reviewed, ["accepted", "skipped"]),
        (.handEdited, ["hand", "retired"]),
        (.skipped, ["skipped"]),
        (.unfitted, ["missing"]),
    ])
    func eachFilterSelectsItsEntries(_ filter: CalibrationReviewFilter, _ expected: [String]) {
        #expect(list(filter) == expected)
    }

    @Test func scoreOrderPutsTheWorstFirstAndUnscoredLast() {
        #expect(list(.all, sort: .score) == ["flagged", "accepted", "skipped", "good", "hand", "missing", "retired"])
    }

    @Test func searchNarrowsTheFilter() {
        #expect(list(.reviewed, search: "SKIP") == ["skipped"])
    }
}
