// SymbolSizingServiceTests.swift
// SymbolSizingService.resolve(for:) picks one of four sources per symbol:
//  1. family calibration (per-symbol hit)
//  2. container calibration (.circle/.square/.rectangle keyword in any dot-component)
//  3. auto box-fit (real symbol with no calibration entry — measured at runtime)
//  4. default fallback (multiplier 0.55; symbol unknown to the system)
// The bundled symbol-calibration.json is the source of truth for the
// per-symbol anchors; if Apple/we re-calibrate star.fill, update the
// expected values below.
//
// Every resolve here passes the BUNDLED calibration explicitly. Without that,
// resolve() prefers the user-writable Application Support override (edited by
// the Shift+Cmd+L calibration playground), and these value assertions would
// fail — or silently validate stale user data — on any machine with saved edits.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct SymbolSizingServiceTests {

    /// Shipped calibration, immune to Application Support overrides.
    private static let bundled: SymbolCalibration = {
        guard let file = SymbolSizingService.bundledCalibration() else {
            fatalError("bundled symbol-calibration.json missing from test host")
        }
        return file
    }()

    private func resolve(_ name: String) -> ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: name, calibration: Self.bundled)
    }

    // MARK: - Family calibration

    @Test("star.fill hits per-symbol family calibration with shipped values")
    func symbolCalibration_starFill() {
        let r = resolve("star.fill")
        #expect(r.source == .symbolCalibration)
        #expect(abs(r.multiplier - 0.58) < 0.001)
        #expect(r.xOffset == 0)
        #expect(abs(r.yOffset - (-0.035)) < 0.001)
    }

    @Test("folder.fill hits per-symbol family calibration")
    func symbolCalibration_folderFill() {
        let r = resolve("folder.fill")
        #expect(r.source == .symbolCalibration)
        #expect(abs(r.multiplier - 0.65) < 0.001)
    }

    // MARK: - Container calibration

    @Test("An invented symbol with a container keyword falls through to container calibration",
          arguments: [
            ("made_up_xyz.circle",    ContainerType.circle),
            ("made_up_xyz.square",    ContainerType.square),
            ("made_up_xyz.rectangle", ContainerType.rectangle),
          ])
    func containerCalibration_keywordDetection(
        _ name: String,
        _ expectedType: ContainerType
    ) {
        let r = resolve(name)
        #expect(r.source == .containerCalibration,
                "Expected containerCalibration for \(name), got \(r.source)")
        #expect(r.multiplier > 0.4 && r.multiplier < 1.0,
                "Unexpected container multiplier \(r.multiplier) for \(expectedType)")
    }

    // MARK: - Auto box-fit

    // These symbols exist in the system but have no per-symbol entry in the
    // shipped symbol-calibration.json and no container keyword. If they get
    // calibrated later, swap in another symbol from the uncalibrated set.
    @Test("A real symbol with no calibration entry resolves via box-fit prediction",
          arguments: ["soccerball", "accessibility", "apple.terminal"])
    func autoBoxFit_uncalibratedRealSymbol(_ name: String) {
        let r = resolve(name)
        #expect(r.source == .autoBoxFit,
                "Expected autoBoxFit for \(name), got \(r.source)")
        #expect(r.multiplier >= SymbolAutoSizingService.minMultiplier)
        #expect(r.multiplier <= SymbolAutoSizingService.maxMultiplier)
        #expect(r.xOffset == 0, "Box-fit predictions are multiplier-only")
        #expect(r.yOffset == 0, "Box-fit predictions are multiplier-only")
        #expect(r.weight == .medium)
    }

    @Test("Box-fit resolution is stable across repeated calls (cache consistency)")
    func autoBoxFit_repeatedCallsAgree() {
        let first = resolve("soccerball")
        let second = resolve("soccerball")
        #expect(first.source == .autoBoxFit)
        #expect(first.multiplier == second.multiplier)
    }

    @Test("Box-fit multiplier matches a direct SymbolAutoSizingService measurement")
    func autoBoxFit_matchesDirectMeasurement() throws {
        let bounds = try #require(
            SymbolAutoSizingService.measureTightBounds(symbol: "soccerball"))
        let expected = SymbolAutoSizingService.multiplier(for: bounds)
        let r = resolve("soccerball")
        #expect(abs(r.multiplier - expected) < 0.0001)
    }

    // MARK: - Default fallback

    @Test("A nonexistent symbol (unmeasurable) returns default 0.55")
    func defaultFallback_unknownSymbol() {
        let r = resolve("definitely_unknown_xyz_no_suffix")
        #expect(r.source == .defaultFallback)
        #expect(r.multiplier == 0.55)
        #expect(r.xOffset == 0)
        #expect(r.yOffset == 0)
        #expect(r.weight == .medium)
    }

    @Test("An empty string falls through to default fallback")
    func defaultFallback_emptyString() {
        let r = resolve("")
        #expect(r.source == .defaultFallback)
        #expect(r.multiplier == 0.55)
    }

    // MARK: - Priority

    @Test("Per-symbol calibration wins over container detection for suffix-bearing names")
    func priority_perSymbolOverContainer() {
        // "circle.badge.plus" both (a) has a .circle suffix that would match
        // container detection and (b) has a per-symbol symbol-calibration
        // entry with DIFFERENT values (multiplier 0.58 vs container's 0.65).
        // A regression where container detection ran first would produce
        // 0.65; per-symbol priority yields 0.58.
        let r = resolve("circle.badge.plus")
        #expect(r.source == .symbolCalibration)
        #expect(abs(r.multiplier - 0.58) < 0.001,
                "Expected per-symbol 0.58, got \(r.multiplier) — priority check failed")
        #expect(abs(r.xOffset - (-0.03)) < 0.001)
    }

    // MARK: - Out-of-range calibration

    @Test("A calibration entry outside the bounds is clamped, in both calibrated tiers",
          arguments: [(1e300, 1e300), (-1e300, -1e300), (0, 0)])
    func calibratedEntry_isClamped(_ multiplier: Double, _ offset: Double) {
        let entry = SymbolCalibrationEntry(
            multiplier: multiplier, xOffset: offset, yOffset: offset,
            weight: "regular", status: "calibrated")
        let calibration = SymbolCalibration(
            symbols: ["star.fill": entry],
            containers: [ContainerType.circle.containerKey: entry])

        for name in ["star.fill", "made_up_xyz.circle"] {
            let r = SymbolSizingService.resolve(for: name, calibration: calibration)
            #expect(SymbolSizingService.multiplierRange.contains(r.multiplier), "\(name): \(r.multiplier)")
            #expect(SymbolSizingService.offsetRange.contains(r.xOffset), "\(name): \(r.xOffset)")
            #expect(SymbolSizingService.offsetRange.contains(r.yOffset), "\(name): \(r.yOffset)")
        }
    }

    // MARK: - Renamed symbols

    /// `fixture.renamed` is new in 27; on older systems it is drawn as `star`.
    private static let renamingCatalog = try! SymbolCatalog(data: Data(#"""
    {"formatVersion": 1, "symbols": [
      {"name": "fixture.renamed", "macOS": "27.0", "aliases": [{"name": "star", "macOS": "11.0"}]}
    ]}
    """#.utf8))

    private func calibration(_ entries: [String: Double]) -> SymbolCalibration {
        SymbolCalibration(symbols: entries.mapValues {
            SymbolCalibrationEntry(multiplier: $0, xOffset: 0, yOffset: 0, weight: "regular", status: "calibrated")
        })
    }

    private func resolveRenamed(_ name: String, calibration: SymbolCalibration, os: MacOSVersion = MacOSVersion(27)) -> ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: name, calibration: calibration, catalog: Self.renamingCatalog, os: os)
    }

    @Test("A new name finds the calibration stored under its old name")
    func calibrationFoundThroughAlias() {
        let r = resolveRenamed("fixture.renamed", calibration: calibration(["star": 0.61]))
        #expect(r.source == .symbolCalibration)
        #expect(abs(r.multiplier - 0.61) < 0.001)
    }

    @Test("An old name finds the calibration stored under its new name")
    func calibrationFoundThroughCurrentName() {
        let r = resolveRenamed("star", calibration: calibration(["fixture.renamed": 0.62]))
        #expect(r.source == .symbolCalibration)
        #expect(abs(r.multiplier - 0.62) < 0.001)
    }

    @Test("The name asked about wins over its other spellings")
    func exactNameWins() {
        let r = resolveRenamed("fixture.renamed", calibration: calibration(["star": 0.61, "fixture.renamed": 0.63]))
        #expect(abs(r.multiplier - 0.63) < 0.001)
    }

    @Test("Box-fit measures the spelling that exists on the OS")
    func boxFitMeasuresTheDrawnSpelling() {
        let empty = SymbolCalibration()
        #expect(resolveRenamed("fixture.renamed", calibration: empty, os: MacOSVersion(15)).source == .autoBoxFit)
        #expect(resolveRenamed("fixture.renamed", calibration: empty, os: MacOSVersion(27)).source == .defaultFallback)
    }

    @Test("A container keyword in any spelling applies to every spelling",
          arguments: ["fixture.plain", "fixture.old.circle"])
    func containerFoundThroughAnySpelling(_ name: String) {
        let catalog = try! SymbolCatalog(data: Data(#"""
        {"formatVersion": 1, "symbols": [
          {"name": "fixture.plain", "macOS": "11.0", "aliases": [{"name": "fixture.old.circle", "macOS": "11.0"}]}
        ]}
        """#.utf8))
        let circle = SymbolCalibrationEntry(multiplier: 0.64, xOffset: 0, yOffset: 0, weight: "regular", status: "calibrated")
        let calibration = SymbolCalibration(symbols: [:], containers: [ContainerType.circle.containerKey: circle])
        let r = SymbolSizingService.resolve(for: name, calibration: calibration, catalog: catalog, os: MacOSVersion(27))
        #expect(r.source == .containerCalibration)
        #expect(abs(r.multiplier - 0.64) < 0.001)
    }

    // MARK: - ResolvedSymbolSizing basic properties

    @Test("Resolved multiplier is positive and weight is auto/regular/medium for any input",
          arguments: [
            "star.fill",
            "folder.fill",
            "made_up_xyz.circle",
            "definitely_unknown_xyz",
            ""
          ])
    func resolved_invariants(_ symbol: String) {
        let r = resolve(symbol)
        #expect(r.multiplier > 0, "Multiplier must be positive for \(symbol)")
        #expect([Font.Weight.regular, .medium].contains(r.weight))
    }
}
