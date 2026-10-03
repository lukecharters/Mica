// PixelFitTests.swift
// The pixel fit's coverage estimate and descent, against synthetic references whose
// values are known, so nothing here depends on Apple's rendering or on the shipped data.

import Testing
import AppKit
@testable import Mica

@Suite(.tags(.rendering))
@MainActor
struct PixelFitTests {
    static let symbol = "star"
    static let truth = PixelFitter.Values(multiplier: 0.6, xOffset: 0.02, yOffset: -0.03, weight: "semibold")

    /// Mica's own glyph at `values`, composited onto an enclosure the way the appex draws
    /// one: the glyph shaded from `top` to `bottom` over its height.
    private func synthetic(_ values: PixelFitter.Values, glyph top: Double, _ bottom: Double,
                           enclosure: (Double, Double, Double)) throws -> (image: CGImage, truth: GlyphCoverage) {
        let coverage = try #require(PixelFitter.micaCoverage(Self.symbol, values))
        let box = try #require(coverage.box)
        let n = coverage.size
        let inside = PixelBuffers.enclosureMask(size: n, margin: 0)
        var rgba = [UInt8](repeating: 0, count: n * n * 4)
        for y in 0..<n {
            let t = min(max(Double(y - box.minY) / Double(box.maxY - box.minY), 0), 1)
            let level = top + (bottom - top) * t
            for x in 0..<n where inside[y * n + x] {
                let i = y * n + x
                let a = Double(coverage.values[i])
                rgba[i * 4] = UInt8(enclosure.0 * (1 - a) + level * a)
                rgba[i * 4 + 1] = UInt8(enclosure.1 * (1 - a) + level * a)
                rgba[i * 4 + 2] = UInt8(enclosure.2 * (1 - a) + level * a)
                rgba[i * 4 + 3] = 255
            }
        }
        let image = try #require(CGImage(
            width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(rgba) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        return (image, coverage)
    }

    @Test func softIoUIsOneForIdenticalAndZeroForDisjointCoverage() {
        let n = 8
        var left = [Float](repeating: 0, count: n * n), right = left
        for y in 0..<n { for x in 0..<(n / 2) { left[y * n + x] = 1; right[y * n + x + n / 2] = 1 } }
        let a = GlyphCoverage(size: n, values: left), b = GlyphCoverage(size: n, values: right)
        #expect(a.softIoU(a) == 1)
        #expect(a.softIoU(b) == 0)
        var half = left
        for i in half.indices where half[i] == 1 { half[i] = 0.5 }
        #expect(a.softIoU(GlyphCoverage(size: n, values: half)) == 0.5)
    }

    @Test func theEstimateCancelsAGradientAcrossTheGlyph() throws {
        let reference = try synthetic(Self.truth, glyph: 255, 150, enclosure: (0, 130, 255))
        let estimate = ReferenceGlyphCoverage.estimate(from: reference.image, size: PixelFitter.size)
        #expect(estimate.softIoU(reference.truth) > 0.98)
    }

    @Test func theEstimateReadsADarkGlyphOnALightEnclosure() throws {
        let reference = try synthetic(Self.truth, glyph: 20, 80, enclosure: (245, 245, 245))
        let estimate = ReferenceGlyphCoverage.estimate(from: reference.image, size: PixelFitter.size)
        #expect(estimate.softIoU(reference.truth) > 0.98)
    }

    @Test func theFitRecoversKnownValuesAndWeight() async throws {
        let reference = try synthetic(Self.truth, glyph: 255, 190, enclosure: (0, 130, 255))
        let target = ReferenceGlyphCoverage.estimate(from: reference.image, size: PixelFitter.size)
        let start = PixelFitter.Values(multiplier: 0.66, xOffset: 0, yOffset: 0, weight: "regular")
        let result = try #require(await PixelFitter.fit(Self.symbol, target: target, start: start))
        #expect(abs(result.values.multiplier - Self.truth.multiplier) <= 0.002)
        #expect(abs(result.values.xOffset - Self.truth.xOffset) <= 0.002)
        #expect(abs(result.values.yOffset - Self.truth.yOffset) <= 0.002)
        #expect(result.values.weight == Self.truth.weight)
        #expect(result.score > 0.97)
    }

    @Test func aScoreBelowTheThresholdIsFlaggedForReview() {
        #expect(PixelFitter.status(forScore: 0.84, threshold: 0.85) == "needs-review")
        #expect(PixelFitter.status(forScore: 0.85, threshold: 0.85) == "calibrated")
    }

    @Test func aFittedEntryCarriesItsSourceAndScore() {
        let result = PixelFitter.Result(values: Self.truth, score: 0.912345)
        let entry = PixelFitter.entry(for: result, threshold: 0.95)
        #expect(entry.source == PixelFitter.source)
        #expect(entry.fitScore == 0.9123)
        #expect(entry.status == "needs-review")
        #expect(entry.weight == Self.truth.weight)
    }
}

@Suite(.tags(.rendering))
@MainActor
struct PixelFitPartsTests {
    static let symbol = "ellipsis"
    static let truth = PixelFitter.Values(multiplier: 0.6, xOffset: 0, yOffset: 0, weight: "regular")

    /// `coverage` with piece `k` moved by `shifts[k]` part radii, edges and all.
    private func moved(_ coverage: GlyphCoverage, by shifts: [(x: Double, y: Double)]) -> GlyphCoverage {
        let n = coverage.size
        let pieces = GlyphPieces(coverage).pieces.filter { $0.area >= MisplacedParts.minimumArea }.sorted { $0.cx < $1.cx }
        var out = coverage
        var moves: [(region: PixelRegion, dx: Int, dy: Int)] = []
        for (piece, shift) in zip(pieces, shifts) {
            let region = PixelRegion.halo(of: piece.pixels, size: n, radius: MisplacedParts.edgeHalo)
            moves.append((region, Int((shift.x * piece.radius).rounded()), Int((shift.y * piece.radius).rounded())))
            for ly in 0..<region.height { for lx in 0..<region.width where region.member[ly * region.width + lx] {
                out.values[(region.y0 + ly) * n + region.x0 + lx] = 0
            } }
        }
        for move in moves {
            let r = move.region
            for ly in 0..<r.height { for lx in 0..<r.width where r.member[ly * r.width + lx] {
                let x = r.x0 + lx + move.dx, y = r.y0 + ly + move.dy
                out.values[y * n + x] = max(out.values[y * n + x], coverage.values[(r.y0 + ly) * n + r.x0 + lx])
            } }
        }
        return out
    }

    private func fits(_ values: PixelFitter.Values) throws -> [(weight: String, coverage: GlyphCoverage)] {
        try SymbolCalibrationEntry.weightTokens.map(\.token).map { weight in
            var v = values
            v.weight = weight
            return (weight, try #require(PixelFitter.micaCoverage(Self.symbol, v)))
        }
    }

    @Test func piecesAreLabelledWithTheirCentres() {
        let n = 20
        var values = [Float](repeating: 0, count: n * n)
        for y in 2..<6 { for x in 2..<6 { values[y * n + x] = 1 } }
        for y in 10..<16 { for x in 12..<18 { values[y * n + x] = 0.8 } }
        let pieces = GlyphPieces(GlyphCoverage(size: n, values: values)).pieces
        #expect(pieces.count == 2)
        #expect(pieces.map(\.area).sorted() == [16, 36])
        #expect(pieces.contains { $0.cx == 3.5 && $0.cy == 3.5 })
        #expect(pieces.contains { $0.cx == 14.5 && $0.cy == 12.5 })
    }

    @Test func aGlyphMicaDrawsInPlaceHasNoMisplacedParts() throws {
        let target = try #require(PixelFitter.micaCoverage(Self.symbol, Self.truth))
        #expect(MisplacedParts.find(in: target, fits: try fits(Self.truth)) == nil)
    }

    @Test func aMovedPartIsScoredWhereverItSits() throws {
        let mica = try #require(PixelFitter.micaCoverage(Self.symbol, Self.truth))
        let target = moved(mica, by: [(0, 0), (0, 0.8), (0, 0)])
        let parts = try #require(MisplacedParts.find(in: target, fits: try fits(Self.truth)))
        #expect(parts.parts.count == 1)
        #expect(parts.isDisplaced(atWeight: "regular"))
        #expect(parts.score(mica) > 0.97)
        #expect(parts.score(mica) > target.softIoU(mica) + 0.05)
    }

    @Test func aPartDisplacedOnlyAtAnotherWeightLeavesTheFirstPassStanding() throws {
        let mica = try #require(PixelFitter.micaCoverage(Self.symbol, Self.truth))
        let target = moved(mica, by: [(0, 0), (0, 0.8), (0, 0)])
        let parts = try #require(MisplacedParts.find(in: target, fits: [(weight: "regular", coverage: target),
                                                                       (weight: "bold", coverage: mica)]))
        #expect(!parts.isDisplaced(atWeight: "regular"))
        #expect(parts.isDisplaced(atWeight: "bold"))
    }

    @Test func theFitKeepsTheTrueWeightWhenPartsAreMoved() async throws {
        let mica = try #require(PixelFitter.micaCoverage(Self.symbol, Self.truth))
        let target = moved(mica, by: [(0, -0.8), (0, 0.8), (0, -0.8)])
        let start = PixelFitter.Values(multiplier: 0.62, xOffset: 0, yOffset: 0, weight: "regular")
        let result = try #require(await PixelFitter.fit(Self.symbol, target: target, start: start))
        #expect(result.values.weight == Self.truth.weight)
        #expect(abs(result.values.multiplier - Self.truth.multiplier) <= 0.005)
        #expect(result.score > 0.95)
    }
}

@Suite(.tags(.unit))
@MainActor
struct PixelFitReviewTests {
    static let fitted = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0.01, yOffset: 0, weight: "medium",
                                               status: "needs-review", source: PixelFitter.source, fitScore: 0.7)

    @Test func markingAFittedEntryUnchangedKeepsItsScoreAndMarksItReviewed() {
        let edited = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0.01, yOffset: 0, weight: "medium", status: "calibrated")
        let marked = PixelFitter.marked(edited, over: Self.fitted)
        #expect(marked.status == "calibrated")
        #expect(marked.source == PixelFitter.source)
        #expect(marked.fitScore == 0.7)
        #expect(marked.reviewed == true)
    }

    @Test func markingAFittedEntryWithChangedValuesIsAHandEdit() {
        let edited = SymbolCalibrationEntry(multiplier: 0.62, xOffset: 0.01, yOffset: 0, weight: "medium", status: "calibrated")
        #expect(PixelFitter.marked(edited, over: Self.fitted) == edited)
    }

    @Test func markingAHandEntryIsAHandEdit() {
        let hand = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0.01, yOffset: 0, weight: "medium", status: "needs-review")
        let edited = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0.01, yOffset: 0, weight: "medium", status: "calibrated")
        #expect(PixelFitter.marked(edited, over: hand) == edited)
        #expect(PixelFitter.marked(edited, over: nil) == edited)
    }

    @Test func reflagSetsUnreviewedFittedEntriesFromTheirScore() {
        var accepted = Self.fitted
        accepted.status = "calibrated"
        let hand = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0, yOffset: 0, weight: "medium", status: "skipped")
        let result = PixelFitter.reflagged(["low": accepted, "hand": hand], threshold: 0.85)
        #expect(result["low"]?.status == "needs-review")
        #expect(result["hand"] == hand)
    }

    @Test func reflagLeavesReviewedEntriesAlone() {
        var reviewed = Self.fitted
        reviewed.status = "calibrated"
        reviewed.reviewed = true
        #expect(PixelFitter.reflagged(["s": reviewed], threshold: 0.85)["s"] == reviewed)
    }

    @Test func anUnreviewedEntryLeavesTheFlagOutOfTheFile() throws {
        let json = try #require(String(data: JSONEncoder().encode(Self.fitted), encoding: .utf8))
        #expect(!json.contains("reviewed"))
    }
}

@Suite(.tags(.unit))
struct SymbolCalibrationEntryFitScoreTests {
    @Test func anEntryWithoutAScoreDecodesAsNil() throws {
        let json = #"{"multiplier":0.6,"xOffset":0,"yOffset":0,"weight":"regular","status":"calibrated"}"#
        let entry = try JSONDecoder().decode(SymbolCalibrationEntry.self, from: Data(json.utf8))
        #expect(entry.fitScore == nil)
    }

    @Test func aNilScoreIsLeftOutOfTheFile() throws {
        let entry = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0, yOffset: 0, weight: "regular", status: "calibrated")
        let json = try #require(String(data: JSONEncoder().encode(entry), encoding: .utf8))
        #expect(!json.contains("fitScore"))
    }

    @Test func sameValuesIgnoreStatusAndProvenance() {
        let fitted = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0.01, yOffset: 0, weight: "medium",
                                            status: "needs-review", source: "pixel-fit", fitScore: 0.8)
        let edited = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0.01, yOffset: 0, weight: "medium", status: "calibrated")
        #expect(edited.hasSameValues(as: fitted))
    }

    @Test("A changed value or weight is not the same", arguments: [
        SymbolCalibrationEntry(multiplier: 0.601, xOffset: 0.01, yOffset: 0, weight: "medium", status: "calibrated"),
        SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0.011, yOffset: 0, weight: "medium", status: "calibrated"),
        SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0.01, yOffset: 0.001, weight: "medium", status: "calibrated"),
        SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0.01, yOffset: 0, weight: "bold", status: "calibrated"),
    ])
    func aChangedValueIsNotTheSame(_ changed: SymbolCalibrationEntry) {
        let original = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0.01, yOffset: 0, weight: "medium", status: "calibrated")
        #expect(!changed.hasSameValues(as: original))
    }

    @Test func aScoreRoundTrips() throws {
        let entry = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0, yOffset: 0, weight: "medium",
                                           status: "calibrated", source: "pixel-fit", fitScore: 0.9731)
        let decoded = try JSONDecoder().decode(SymbolCalibrationEntry.self, from: JSONEncoder().encode(entry))
        #expect(decoded == entry)
    }
}

@Suite(.tags(.unit))
@MainActor
struct CalibrationSetTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CalibrationSetTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private let entry = SymbolCalibrationEntry(multiplier: 0.5, xOffset: 0.01, yOffset: -0.01, weight: "bold",
                                               status: "calibrated", source: "pixel-fit", fitScore: 0.95)
    private let hand = SymbolCalibrationEntry(multiplier: 0.6, xOffset: 0, yOffset: 0, weight: "medium", status: "calibrated")
    private let circle = SymbolCalibrationEntry(multiplier: 0.65, xOffset: 0, yOffset: 0, weight: "medium", status: "calibrated")

    /// Writes a stored `symbol-calibration.json` into `directory`, as Adopt would.
    private func writeStored(_ symbols: [String: SymbolCalibrationEntry], in directory: URL) throws {
        let file = SymbolCalibration(symbols: symbols, containers: [ContainerType.circle.containerKey: circle])
        try JSONEncoder().encode(file).write(to: directory.appendingPathComponent(SymbolCalibrationStore.storedFileName))
    }

    private func readStored(in directory: URL) throws -> SymbolCalibration {
        try JSONDecoder().decode(SymbolCalibration.self, from: Data(contentsOf:
            directory.appendingPathComponent(SymbolCalibrationStore.storedFileName)))
    }

    @Test func withoutAFittedFileTheStoredCalibrationIsShownAndNothingIsWritten() throws {
        let directory = try temporaryDirectory()
        try writeStored(["fixture.stored": hand], in: directory)
        let store = SymbolCalibrationStore(directory: directory)
        #expect(store.symbolEntries == ["fixture.stored": hand])
        #expect(!FileManager.default.fileExists(atPath: store.fittedURL.path))
    }

    @Test func editsGoToTheFittedFileAndLeaveTheStoredOneAlone() throws {
        let directory = try temporaryDirectory()
        try writeStored(["fixture.stored": hand], in: directory)
        let store = SymbolCalibrationStore(directory: directory)
        store.setEntry(entry, forSymbol: "fixture.symbol")

        #expect(try readStored(in: directory).symbols == ["fixture.stored": hand])
        let reopened = SymbolCalibrationStore(directory: directory)
        #expect(reopened.symbolEntries["fixture.symbol"] == entry)
        #expect(reopened.symbolEntries["fixture.stored"] == hand)
    }

    @Test func restoringTheBundledCalibrationRemovesTheOverrideAndKeepsTheFittedSet() throws {
        let directory = try temporaryDirectory()
        try writeStored([:], in: directory)
        let store = SymbolCalibrationStore(directory: directory)
        store.setEntry(entry, forSymbol: "fixture.symbol")
        #expect(store.hasOverride)

        store.restoreBundledCalibration()

        #expect(!store.hasOverride)
        #expect(SymbolCalibrationStore(directory: directory).symbolEntries["fixture.symbol"] == entry)
    }

    @Test func adoptingReplacesStoredEntriesAndKeepsTheRest() throws {
        let directory = try temporaryDirectory()
        try writeStored(["fixture.both": hand, "fixture.stored": hand], in: directory)
        let store = SymbolCalibrationStore(directory: directory)
        store.symbolEntries = [:]
        store.setEntry(entry, forSymbol: "fixture.both")
        store.setEntry(entry, forSymbol: "fixture.fitted")

        let copy = try #require(try store.adoptFittedSet())

        let adopted = try readStored(in: directory)
        #expect(adopted.symbols == ["fixture.both": entry, "fixture.fitted": entry, "fixture.stored": hand])
        #expect(adopted.containers == [ContainerType.circle.containerKey: circle])
        let previous = try JSONDecoder().decode(SymbolCalibration.self, from: Data(contentsOf: copy))
        #expect(previous.symbols == ["fixture.both": hand, "fixture.stored": hand])
    }

    @Test func adoptingTwiceKeepsBothPreviousStoredFiles() throws {
        let directory = try temporaryDirectory()
        try writeStored([:], in: directory)
        let store = SymbolCalibrationStore(directory: directory)
        store.setEntry(entry, forSymbol: "fixture.fitted")
        let first = try #require(try store.adoptFittedSet(at: Date(timeIntervalSince1970: 0)))
        let second = try #require(try store.adoptFittedSet(at: Date(timeIntervalSince1970: 60)))
        #expect(first != second)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test func adoptingWithoutAFittedFileChangesNothing() throws {
        let directory = try temporaryDirectory()
        let store = SymbolCalibrationStore(directory: directory)
        #expect(throws: (any Error).self) { try store.adoptFittedSet() }
        #expect(!store.hasOverride)
    }
}
