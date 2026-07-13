// SymbolSizingServiceTests.swift
// SymbolSizingService.resolve(for:) picks one of four sources per symbol:
//  1. family calibration (per-symbol hit)
//  2. container calibration (suffix .circle/.square/.rectangle)
//  3. auto box-fit (real symbol with no calibration entry — measured at runtime)
//  4. default fallback (multiplier 0.55; symbol unknown to the system)
// The bundled family-calibration.json is the source of truth for the
// per-symbol anchors; if Apple/we re-calibrate star.fill, update the
// expected values below.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct SymbolSizingServiceTests {

    // MARK: - Family calibration

    @Test("star.fill hits per-symbol family calibration with shipped values")
    func familyCalibration_starFill() {
        let r = SymbolSizingService.resolve(for: "star.fill")
        #expect(r.source == .familyCalibration)
        #expect(abs(r.multiplier - 0.58) < 0.001)
        #expect(r.xOffset == 0)
        #expect(abs(r.yOffset - (-0.035)) < 0.001)
        #expect(r.weight == .regular)
    }

    @Test("folder.fill hits per-symbol family calibration")
    func familyCalibration_folderFill() {
        let r = SymbolSizingService.resolve(for: "folder.fill")
        #expect(r.source == .familyCalibration)
        #expect(abs(r.multiplier - 0.65) < 0.001)
        #expect(r.weight == .regular)
    }

    // MARK: - Container calibration

    @Test("An invented .circle symbol falls through to container calibration",
          arguments: [
            ("made_up_xyz.circle",    ContainerType.circle),
            ("made_up_xyz.square",    ContainerType.square),
            ("made_up_xyz.rectangle", ContainerType.rectangle),
          ])
    func containerCalibration_suffixDetection(
        _ name: String,
        _ expectedType: ContainerType
    ) {
        let r = SymbolSizingService.resolve(for: name)
        #expect(r.source == .containerCalibration,
                "Expected containerCalibration for \(name), got \(r.source)")
        // All three shipped container calibrations currently use multiplier 0.65.
        // Allow some tolerance in case they're retuned independently.
        #expect(r.multiplier > 0.4 && r.multiplier < 1.0,
                "Unexpected container multiplier \(r.multiplier) for \(expectedType)")
        #expect(r.weight == .regular)
    }

    // MARK: - Auto box-fit

    // These symbols exist in the system but have no per-symbol entry in the
    // shipped family-calibration.json and no container suffix. If they get
    // calibrated later, swap in another symbol from the uncalibrated set.
    @Test("A real symbol with no calibration entry resolves via box-fit prediction",
          arguments: ["soccerball", "accessibility", "apple.terminal"])
    func autoBoxFit_uncalibratedRealSymbol(_ name: String) {
        let r = SymbolSizingService.resolve(for: name)
        #expect(r.source == .autoBoxFit,
                "Expected autoBoxFit for \(name), got \(r.source)")
        #expect(r.multiplier >= SymbolAutoSizingService.minMultiplier)
        #expect(r.multiplier <= SymbolAutoSizingService.maxMultiplier)
        #expect(r.xOffset == 0, "Box-fit predictions are multiplier-only")
        #expect(r.yOffset == 0, "Box-fit predictions are multiplier-only")
        #expect(r.weight == .regular)
    }

    @Test("Box-fit resolution is stable across repeated calls (cache consistency)")
    func autoBoxFit_repeatedCallsAgree() {
        let first = SymbolSizingService.resolve(for: "soccerball")
        let second = SymbolSizingService.resolve(for: "soccerball")
        #expect(first.source == .autoBoxFit)
        #expect(first.multiplier == second.multiplier)
    }

    @Test("Box-fit multiplier matches a direct SymbolAutoSizingService measurement")
    func autoBoxFit_matchesDirectMeasurement() throws {
        let bounds = try #require(
            SymbolAutoSizingService.measureTightBounds(symbol: "soccerball"))
        let expected = SymbolAutoSizingService.multiplier(for: bounds)
        let r = SymbolSizingService.resolve(for: "soccerball")
        #expect(abs(r.multiplier - expected) < 0.0001)
    }

    // MARK: - Default fallback

    @Test("A nonexistent symbol (unmeasurable) returns default 0.55")
    func defaultFallback_unknownSymbol() {
        let r = SymbolSizingService.resolve(for: "definitely_unknown_xyz_no_suffix")
        #expect(r.source == .defaultFallback)
        #expect(r.multiplier == 0.55)
        #expect(r.xOffset == 0)
        #expect(r.yOffset == 0)
        #expect(r.weight == .regular)
    }

    @Test("An empty string falls through to default fallback")
    func defaultFallback_emptyString() {
        let r = SymbolSizingService.resolve(for: "")
        #expect(r.source == .defaultFallback)
        #expect(r.multiplier == 0.55)
    }

    // MARK: - Priority

    @Test("Per-symbol calibration wins over container detection for suffix-bearing names")
    func priority_perSymbolOverContainer() {
        // "circle.badge.plus" both (a) has a .circle suffix that would match
        // container detection and (b) has a per-symbol family-calibration
        // entry with DIFFERENT values (multiplier 0.58 vs container's 0.65).
        // A regression where container detection ran first would produce
        // 0.65; per-symbol priority yields 0.58.
        let r = SymbolSizingService.resolve(for: "circle.badge.plus")
        #expect(r.source == .familyCalibration)
        #expect(abs(r.multiplier - 0.58) < 0.001,
                "Expected per-symbol 0.58, got \(r.multiplier) — priority check failed")
        #expect(abs(r.xOffset - (-0.03)) < 0.001)
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
        let r = SymbolSizingService.resolve(for: symbol)
        #expect(r.multiplier > 0, "Multiplier must be positive for \(symbol)")
        #expect([Font.Weight.regular, .medium].contains(r.weight))
    }
}
