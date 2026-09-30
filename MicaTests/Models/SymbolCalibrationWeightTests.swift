// SymbolCalibrationWeightTests.swift
// The weight token a calibration entry stores, and the weight it renders at.

import Testing
import SwiftUI
import AppKit
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct SymbolCalibrationWeightTests {

    @Test("Every offered weight survives a write and a read",
          arguments: [Font.Weight.regular, .medium, .semibold, .bold])
    func weightRoundTrips(_ weight: Font.Weight) {
        let token = SymbolCalibrationEntry.weightToken(for: weight)
        #expect(SymbolCalibrationEntry.fontWeight(fromToken: token) == weight)
    }

    @Test func offeredWeightsHaveDistinctTokens() {
        let tokens = SymbolCalibrationEntry.weightTokens.map(\.token)
        #expect(Set(tokens).count == tokens.count)
    }

    @Test func anUnknownTokenReadsAsTheDefault() {
        #expect(SymbolCalibrationEntry.fontWeight(fromToken: "heavy-ish") == SymbolCalibrationEntry.defaultWeight)
    }

    @Test func defaultWeightIsOneRowOfTheTable() {
        let row = SymbolCalibrationEntry.weightTokens.first { $0.weight == SymbolCalibrationEntry.defaultWeight }
        #expect(row?.measurementWeight == SymbolCalibrationEntry.defaultMeasurementWeight)
    }

    @Test func boxFitMeasuresAtTheDefaultWeight() throws {
        let byDefault = try #require(SymbolAutoSizingService.measureTightBounds(symbol: "star.fill"))
        let medium = try #require(SymbolAutoSizingService.measureTightBounds(symbol: "star.fill", weight: .medium))
        let regular = try #require(SymbolAutoSizingService.measureTightBounds(symbol: "star.fill", weight: .regular))
        #expect(byDefault == medium)
        #expect(byDefault != regular)
    }

    @Test("The resolver renders a stored weight rather than collapsing it",
          arguments: [Font.Weight.semibold, .bold])
    func resolverKeepsTheStoredWeight(_ weight: Font.Weight) {
        let entry = SymbolCalibrationEntry(
            multiplier: 0.6, xOffset: 0, yOffset: 0,
            weight: SymbolCalibrationEntry.weightToken(for: weight), status: "calibrated")
        let calibration = SymbolCalibration(
            symbols: ["star.fill": entry],
            containers: [ContainerType.circle.containerKey: entry])

        for name in ["star.fill", "made_up_xyz.circle"] {
            let r = SymbolSizingService.resolve(for: name, calibration: calibration)
            #expect(r.weight == weight, "\(name)")
        }
    }
}
