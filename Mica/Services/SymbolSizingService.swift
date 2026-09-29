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
        calibration: SymbolCalibration? = nil,
        catalog: SymbolCatalog = .bundled,
        os: MacOSVersion = .running
    ) -> ResolvedSymbolSizing {
        let calibrationData = calibration ?? Self.calibrationData
        let drawableName = catalog.drawableName(for: symbolName, on: os)
        // 1. Per-symbol calibration, under any spelling of the symbol
        if let entry = calibrationEntry(for: symbolName, drawableName: drawableName, in: calibrationData, catalog: catalog) {
            return calibrated(entry, source: .symbolCalibration)
        }

        // 2. Container calibration (container keyword in any dot-component of any spelling)
        if let containerType = containerType(for: symbolName, catalog: catalog),
           let entry = calibrationData.containers[containerType.containerKey],
           entry.status == "calibrated" {
            return calibrated(entry, source: .containerCalibration)
        }

        // 3. Box-fit prediction from measured tight bounds. Offsets stay
        // zero: xOffset is optical and yOffset only partially predictable,
        // so predictions are multiplier-only.
        if let multiplier = boxFitMultiplier(for: drawableName) {
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

    /// The bounds a calibration entry is clamped to. The shipped file sits well
    /// inside them; they exist for a hand-edited Application Support override.
    static let multiplierRange: ClosedRange<Double> = 0.05...5
    static let offsetRange: ClosedRange<Double> = -1...1

    // MARK: - Private

    /// The name asked about wins, then the spelling drawn, then the current name and
    /// the aliases, so a symbol renamed after it was calibrated keeps its calibration.
    private static func calibrationEntry(
        for symbolName: String,
        drawableName: String,
        in calibration: SymbolCalibration,
        catalog: SymbolCatalog
    ) -> SymbolCalibrationEntry? {
        var candidates = [symbolName, drawableName]
        if let current = catalog.currentName(for: symbolName) { candidates.append(current) }
        candidates += catalog.aliases(of: symbolName)
        return candidates.lazy
            .compactMap { calibration.symbols[$0] }
            .first { $0.status == "calibrated" }
    }

    private static func calibrated(_ entry: SymbolCalibrationEntry, source: SizingSource) -> ResolvedSymbolSizing {
        ResolvedSymbolSizing(
            multiplier: clamp(entry.multiplier, to: multiplierRange),
            xOffset: clamp(entry.xOffset, to: offsetRange),
            yOffset: clamp(entry.yOffset, to: offsetRange),
            weight: fontWeight(from: entry.weight),
            source: source
        )
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

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

    /// 2-tier loading: Application Support (calibration-tool edits) → bundled
    /// fallback. **The first tier is gated on the developer tools being enabled**,
    /// which is the whole reason `DeveloperToolsPreference` is in `Services/`.
    ///
    /// Before the tools could ship (2026-08-21) this tier was unconditional, and
    /// that was survivable only because nothing in a Release build could write
    /// the file. It is a foot-gun the moment one can: `SymbolCalibrationStore`
    /// autosaves on every slider drag, so one accidental nudge would silently
    /// re-pin symbol sizing for every icon that user renders afterwards, with the
    /// file buried in the sandbox container. Off by default, so anyone who never
    /// opts in renders with exactly what Mica shipped.
    ///
    /// **A `static let`, so the gate is read once per process.** Turning the
    /// preference off therefore does not un-apply an override until relaunch —
    /// Settings says so, and the alternative is re-reading a 800 KB JSON on a
    /// path that resolves a symbol's size.
    private static let calibrationData: SymbolCalibration = {
        // 1. Application Support override, developer tools only.
        if DeveloperToolsPreference.isEnabled() {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let overrideURL = appSupport
                .appendingPathComponent("Mica", isDirectory: true)
                .appendingPathComponent("symbol-calibration.json")
            if let data = try? Data(contentsOf: overrideURL),
               let file = try? JSONDecoder().decode(SymbolCalibration.self, from: data) {
                return file
            }
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

    /// Checks the current name, then the aliases, so every spelling of a symbol gets the same answer.
    private static func containerType(for symbolName: String, catalog: SymbolCatalog) -> ContainerType? {
        let spellings = catalog.currentName(for: symbolName).map { [$0] + catalog.aliases(of: $0) } ?? [symbolName]
        return spellings.lazy.compactMap(detectContainerType).first
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
