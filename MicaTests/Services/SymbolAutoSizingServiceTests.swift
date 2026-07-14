// SymbolAutoSizingServiceTests.swift
// SymbolAutoSizingService implements the tight-bounds box-fit sizing rule
// (mul = clamp(min(0.77/th, 0.79/tw), 0.43, 0.65)) plus the alpha-scan
// measurement it operates on. Rule math is tested against hand-computed
// values; measurement is tested against symbols with known geometry.

import Testing
import Foundation
import AppKit
@testable import Mica

@Suite(.tags(.unit))
struct SymbolAutoSizingRuleTests {

    private func bounds(tw: Double, th: Double) -> SymbolTightBounds {
        SymbolTightBounds(
            tightWidth: tw, tightHeight: th,
            centerXOffset: 0, centerYOffset: 0,
            frameWidth: tw + 10, frameHeight: th + 10)
    }

    @Test func heightConstrainedSymbolUsesHeightFactor() {
        // th = 1.4, tw = 1.0 → min(0.77/1.4, 0.79/1.0) = 0.55
        let mul = SymbolAutoSizingService.multiplier(for: bounds(tw: 100, th: 140))
        #expect(abs(mul - 0.55) < 0.0001)
    }

    @Test func widthConstrainedSymbolUsesWidthFactor() {
        // tw = 1.58, th = 1.0 → min(0.77, 0.79/1.58) = 0.50
        let mul = SymbolAutoSizingService.multiplier(for: bounds(tw: 158, th: 100))
        #expect(abs(mul - 0.50) < 0.0001)
    }

    @Test func compactSymbolClampsToMaxMultiplier() {
        // Tiny content would produce a huge multiplier — clamp to 0.65.
        let prediction = SymbolAutoSizingService.prediction(for: bounds(tw: 50, th: 50))
        #expect(prediction.multiplier == SymbolAutoSizingService.maxMultiplier)
        #expect(prediction.isClamped)
    }

    @Test func oversizedSymbolClampsToMinMultiplier() {
        let prediction = SymbolAutoSizingService.prediction(for: bounds(tw: 300, th: 300))
        #expect(prediction.multiplier == SymbolAutoSizingService.minMultiplier)
        #expect(prediction.isClamped)
    }

    @Test func unclampedPredictionIsNotFlaggedClamped() {
        let prediction = SymbolAutoSizingService.prediction(for: bounds(tw: 100, th: 140))
        #expect(!prediction.isClamped)
    }

    @Test func degenerateBoundsFallBackToMaxMultiplier() {
        let mul = SymbolAutoSizingService.multiplier(for: bounds(tw: 0, th: 0))
        #expect(mul == SymbolAutoSizingService.maxMultiplier)
    }

    @Test func badgeVariantDetection() {
        #expect(SymbolAutoSizingService.isBadgeVariant("folder.badge.plus"))
        #expect(SymbolAutoSizingService.isBadgeVariant("person.fill.badge.minus"))
        // "badge" as the base name is not a badge composite.
        #expect(!SymbolAutoSizingService.isBadgeVariant("badge.plus.radiowaves.forward"))
        #expect(!SymbolAutoSizingService.isBadgeVariant("folder.fill"))
    }

    @Test func badgeFactorsShrinkHeightConstrainedFit() {
        // th = 1.3 → standard 0.77/1.3, badge 0.75/1.3.
        let standard = SymbolAutoSizingService.multiplier(for: bounds(tw: 100, th: 130))
        let badge = SymbolAutoSizingService.multiplier(for: bounds(tw: 100, th: 130), isBadge: true)
        #expect(abs(standard - 0.77 / 1.3) < 0.0001)
        #expect(abs(badge - 0.75 / 1.3) < 0.0001)
    }

    @Test func badgeFactorsShrinkWidthConstrainedFit() {
        // tw = 1.58 → standard 0.79/1.58 = 0.50, badge 0.74/1.58.
        let badge = SymbolAutoSizingService.multiplier(for: bounds(tw: 158, th: 100), isBadge: true)
        #expect(abs(badge - 0.74 / 1.58) < 0.0001)
    }

    @Test func badgeFitSharesClamps() {
        let prediction = SymbolAutoSizingService.prediction(for: bounds(tw: 50, th: 50), isBadge: true)
        #expect(prediction.multiplier == SymbolAutoSizingService.maxMultiplier)
        #expect(prediction.isClamped)
    }

    @Test func suggestedYOffsetOpposesContentCenterOffset() {
        // Content below center (positive centerYOffset) → negative offset hint.
        var b = bounds(tw: 100, th: 100)
        b.centerYOffset = 5
        let prediction = SymbolAutoSizingService.prediction(for: b)
        #expect(prediction.suggestedYOffset < 0)
        #expect(abs(prediction.suggestedYOffset - (-0.78 * 5 / 100)) < 0.0001)
    }
}

@Suite(.tags(.unit))
@MainActor
struct SymbolTightBoundsMeasurementTests {

    @Test func measuresKnownSymbol() throws {
        let b = try #require(SymbolAutoSizingService.measureTightBounds(symbol: "square.fill"))
        #expect(b.tightWidth > 0)
        #expect(b.tightHeight > 0)
        // Tight content bounds can never exceed the typographic frame.
        #expect(b.tightWidth <= b.frameWidth + 0.001)
        #expect(b.tightHeight <= b.frameHeight + 0.001)
        // square.fill is a solid square: near-1 aspect, near-centered.
        #expect(abs(b.tightWidth / b.tightHeight - 1.0) < 0.05)
        #expect(abs(b.centerXOffset) < 3)
    }

    @Test func unknownSymbolReturnsNil() {
        #expect(SymbolAutoSizingService.measureTightBounds(symbol: "not.a.real.symbol.zzz") == nil)
    }

    @Test func endToEndPredictionIsWithinRuleRange() throws {
        let prediction = try #require(SymbolAutoSizingService.prediction(forSymbol: "folder.fill"))
        #expect(prediction.multiplier >= SymbolAutoSizingService.minMultiplier)
        #expect(prediction.multiplier <= SymbolAutoSizingService.maxMultiplier)
    }

    @Test func nameBasedPredictionUsesBadgeFactorsForBadgeSymbols() throws {
        // folder.badge.plus sits inside the clamp range under both parameter
        // sets, so the badge fit must come out strictly smaller.
        let bounds = try #require(SymbolAutoSizingService.measureTightBounds(symbol: "folder.badge.plus"))
        let byName = try #require(SymbolAutoSizingService.prediction(forSymbol: "folder.badge.plus"))
        let badgeFit = SymbolAutoSizingService.prediction(for: bounds, isBadge: true)
        let standardFit = SymbolAutoSizingService.prediction(for: bounds)
        #expect(byName.multiplier == badgeFit.multiplier)
        #expect(byName.multiplier < standardFit.multiplier)
    }
}

@Suite(.tags(.unit))
struct ContainerRecipeCatalogTests {

    @Test func parsesRecipeFixture() throws {
        let plist: [String: Any] = [
            "version": 2,
            "symbols": [
                "folder.fill": ["shapes": [:]],
                "wifi": ["shapes": [:]],
            ],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("recipes-\(UUID().uuidString).plist")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let names = ContainerRecipeCatalog.loadSymbolNames(from: url.path)
        #expect(names == ["folder.fill", "wifi"])
    }

    @Test func missingFileReturnsEmptySet() {
        #expect(ContainerRecipeCatalog.loadSymbolNames(from: "/nonexistent/path.plist").isEmpty)
    }
}

@Suite(.tags(.unit))
struct FamilyCalEntrySourceFieldTests {

    @Test func decodesLegacyEntryWithoutSource() throws {
        let json = #"{"multiplier":0.62,"xOffset":0,"yOffset":0,"weight":"regular","status":"calibrated"}"#
        let entry = try JSONDecoder().decode(FamilyCalEntry.self, from: Data(json.utf8))
        #expect(entry.source == nil)
        #expect(entry.multiplier == 0.62)
    }

    @Test func roundTripsSourceField() throws {
        let entry = FamilyCalEntry(
            multiplier: 0.55, xOffset: 0, yOffset: 0,
            weight: "regular", status: "calibrated", source: "auto-boxfit")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(FamilyCalEntry.self, from: data)
        #expect(decoded == entry)
        #expect(decoded.source == "auto-boxfit")
    }

    @Test func nilSourceIsOmittedFromEncodedJSON() throws {
        let entry = FamilyCalEntry(
            multiplier: 0.55, xOffset: 0, yOffset: 0,
            weight: "regular", status: "calibrated")
        let json = String(decoding: try JSONEncoder().encode(entry), as: UTF8.self)
        #expect(!json.contains("source"))
    }
}
