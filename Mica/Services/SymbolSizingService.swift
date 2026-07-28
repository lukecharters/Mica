// SymbolSizingService.swift - Unified SF Symbol sizing resolver
//
// Resolves the font-size multiplier, offsets, and weight for any SF Symbol.
// Priority: family calibration -> container calibration -> box-fit prediction
// -> default (0.55). Calibration data loaded once lazily from
// symbol-calibration.json; box-fit measures the symbol's tight bounds at
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
    case symbolCalibration
    case containerCalibration
    case autoBoxFit
    case defaultFallback
}

// MARK: - Service

struct SymbolSizingService {
    /// Resolve sizing for a symbol. `calibration` is an injection seam for
    /// tests (pass `bundledCalibration()` to pin against shipped values);
    /// production callers omit it and get the cached 2-tier data, which
    /// prefers a user-writable Application Support override.
    static func resolve(
        for symbolName: String,
        calibration: SymbolCalibration? = nil
    ) -> ResolvedSymbolSizing {
        let calibrationData = calibration ?? Self.calibrationData
        // 1. Per-symbol calibration
        if let entry = calibrationData.symbols[symbolName], entry.status == "calibrated" {
            return ResolvedSymbolSizing(
                multiplier: entry.multiplier,
                xOffset: entry.xOffset,
                yOffset: entry.yOffset,
                weight: fontWeight(from: entry.weight),
                source: .symbolCalibration
            )
        }

        // 2. Container calibration (container keyword in any dot-component)
        if let containerType = detectContainerType(symbolName),
           let entry = calibrationData.containers[containerType.containerKey],
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

    /// The bundled symbol-calibration.json, ignoring any user override.
    /// Internal (not private) so tests can pin assertions to shipped values
    /// regardless of calibration-playground edits in Application Support.
    static func bundledCalibration() -> SymbolCalibration? {
        guard let bundleURL = Bundle.main.url(forResource: "symbol-calibration", withExtension: "json"),
              let data = try? Data(contentsOf: bundleURL),
              let file = try? JSONDecoder().decode(SymbolCalibration.self, from: data) else {
            return nil
        }
        return file
    }

    /// 2-tier loading: Application Support (playground edits) → bundled fallback
    private static let calibrationData: SymbolCalibration = {
        // 1. Application Support override (written by calibration playground)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let overrideURL = appSupport
            .appendingPathComponent("Mica", isDirectory: true)
            .appendingPathComponent("symbol-calibration.json")
        if let data = try? Data(contentsOf: overrideURL),
           let file = try? JSONDecoder().decode(SymbolCalibration.self, from: data) {
            return file
        }

        // 2. Bundled fallback
        return bundledCalibration() ?? SymbolCalibration()
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
