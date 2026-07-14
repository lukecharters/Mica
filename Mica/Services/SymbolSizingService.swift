// SymbolSizingService.swift - Unified SF Symbol sizing resolver
//
// Resolves the font-size multiplier, offsets, and weight for any SF Symbol.
// Priority: family calibration -> container calibration -> box-fit prediction
// -> default (0.55). Calibration data loaded once lazily from
// family-calibration.json; box-fit measures the symbol's tight bounds at
// runtime (cached per process) via SymbolAutoSizingService.

import SwiftUI
import Synchronization

// MARK: - Resolved Sizing

struct ResolvedSymbolSizing {
    let multiplier: Double
    let xOffset: Double
    let yOffset: Double
    let weight: Font.Weight
    let source: SizingSource
}

enum SizingSource: String {
    case familyCalibration
    case containerCalibration
    case autoBoxFit
    case defaultFallback
}

// MARK: - Service

struct SymbolSizingService {
    static func resolve(for symbolName: String) -> ResolvedSymbolSizing {
        // 1. Per-symbol calibration
        if let entry = calibrationData.symbols[symbolName], entry.status == "calibrated" {
            return ResolvedSymbolSizing(
                multiplier: entry.multiplier,
                xOffset: entry.xOffset,
                yOffset: entry.yOffset,
                weight: fontWeight(from: entry.weight),
                source: .familyCalibration
            )
        }

        // 2. Container calibration (by suffix detection)
        if let containerType = detectContainerType(symbolName),
           let entry = calibrationData.containers[containerType.dimKey],
           entry.status == "calibrated" {
            return ResolvedSymbolSizing(
                multiplier: entry.multiplier,
                xOffset: entry.xOffset,
                yOffset: entry.yOffset,
                weight: fontWeight(from: entry.weight),
                source: .containerCalibration
            )
        }

        // 3. Box-fit prediction from measured tight bounds. Offsets stay
        // zero: xOffset is optical and yOffset only partially predictable,
        // so predictions are multiplier-only.
        if let multiplier = boxFitMultiplier(for: symbolName) {
            return ResolvedSymbolSizing(
                multiplier: multiplier,
                xOffset: 0,
                yOffset: 0,
                weight: .regular,
                source: .autoBoxFit
            )
        }

        // 4. Default (symbol unknown to the system — nothing to measure)
        return ResolvedSymbolSizing(
            multiplier: 0.55,
            xOffset: 0,
            yOffset: 0,
            weight: .regular,
            source: .defaultFallback
        )
    }

    // MARK: - Private

    /// 2-tier loading: Application Support (playground edits) → bundled fallback
    private static let calibrationData: FamilyCalFile = {
        // 1. Application Support override (written by calibration playground)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let overrideURL = appSupport
            .appendingPathComponent("Mica", isDirectory: true)
            .appendingPathComponent("family-calibration.json")
        if let data = try? Data(contentsOf: overrideURL),
           let file = try? JSONDecoder().decode(FamilyCalFile.self, from: data) {
            return file
        }

        // 2. Bundled fallback
        if let bundleURL = Bundle.main.url(forResource: "family-calibration", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let file = try? JSONDecoder().decode(FamilyCalFile.self, from: data) {
            return file
        }

        return FamilyCalFile()
    }()

    /// Measured box-fit multipliers, one entry per symbol per process.
    /// `nil` values mark symbols that failed to render so they aren't
    /// re-measured on every resolve.
    private static let boxFitCache = Mutex<[String: Double?]>([:])

    private static func boxFitMultiplier(for symbolName: String) -> Double? {
        if let cached = boxFitCache.withLock({ $0[symbolName] }) {
            return cached
        }
        let multiplier = SymbolAutoSizingService
            .measureTightBounds(symbol: symbolName)
            .map { SymbolAutoSizingService.multiplier(
                for: $0, isBadge: SymbolAutoSizingService.isBadgeVariant(symbolName)) }
        boxFitCache.withLock { $0[symbolName] = multiplier }
        return multiplier
    }

    private static func detectContainerType(_ symbolName: String) -> ContainerType? {
        let components = symbolName.split(separator: ".")
        guard components.count >= 2 else { return nil }
        for type in ContainerType.allCases {
            if components.contains(Substring(type.suffixComponent)) {
                return type
            }
        }
        return nil
    }

    private static func fontWeight(from string: String) -> Font.Weight {
        string == "medium" ? .medium : .regular
    }
}
