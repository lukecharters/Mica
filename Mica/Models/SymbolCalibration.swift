// SymbolCalibration.swift - Shared types for per-symbol SF Symbol sizing calibration
//
// Used by both the production rendering pipeline (SymbolSizingService) and the
// calibration tool (SymbolCalibrationStore in SymbolCalibrationTool).
//
// Entries are per symbol, plus one per container shape. Symbols are *grouped*
// into families for review in the tool — see `SymbolFamily` and
// `familyOverrides` — but nothing here is stored per family.

import SwiftUI

// MARK: - Container Type

enum ContainerType: String, CaseIterable {
    case circle, square, rectangle

    /// Key under `containers` in symbol-calibration.json.
    ///
    /// Identical to `suffixComponent` — these keys used to be dimension strings
    /// ("117.0000_114.0000" for circle, from the superseded dimension-grouping
    /// scheme) and were replaced with the container name in the 2026-07-28
    /// calibration rename. Kept as a separate accessor because the two mean
    /// different things: one indexes the calibration file, the other matches a
    /// dot-component of a symbol name.
    var containerKey: String { rawValue }

    /// The dot-component this container contributes to a symbol name, e.g. the
    /// `circle` in `person.crop.circle`.
    var suffixComponent: String { rawValue }

    /// Measured width and height at 100pt that identify this container shape.
    var dimensions: (width: Double, height: Double) {
        switch self {
        case .circle:    return (117, 114)
        case .square:    return (115, 104)
        case .rectangle: return (141, 104)
        }
    }

    /// The `"%.4f_%.4f"` signature the calibration tool derives from
    /// symbol_metrics.json to recognise a container variant by its measured size.
    ///
    /// Distinct from `containerKey`: this identifies a container *from
    /// measurements*, while `containerKey` is how it is *stored*. The two were a
    /// single string before the 2026-07-28 rename, which is why the storage key
    /// used to be a dimension string.
    var dimensionSignature: String {
        String(format: "%.4f_%.4f", dimensions.width, dimensions.height)
    }

    /// The container whose measured size matches `signature`, or nil for a
    /// non-container symbol.
    static func matching(dimensionSignature signature: String) -> ContainerType? {
        allCases.first { $0.dimensionSignature == signature }
    }

    static let allKeys: Set<String> = Set(allCases.map(\.containerKey))
}

// MARK: - Calibration Entry

struct SymbolCalibrationEntry: Codable, Equatable {
    var multiplier: Double
    var xOffset: Double
    var yOffset: Double
    var weight: String   // "regular" or "medium"
    var status: String   // "calibrated", "skipped", "needs-review"
    /// Provenance marker; nil for hand-calibrated entries, "auto-boxfit" for
    /// entries accepted from the Auto Calibration playground's predicted rule.
    var source: String? = nil
}

// MARK: - Calibration File

struct SymbolCalibration: Codable {
    var version: Int = 1
    var symbols: [String: SymbolCalibrationEntry] = [:]
    var containers: [String: SymbolCalibrationEntry] = [:]
    var familyOverrides: [String: String] = [:]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        symbols = try c.decodeIfPresent([String: SymbolCalibrationEntry].self, forKey: .symbols) ?? [:]
        containers = try c.decodeIfPresent([String: SymbolCalibrationEntry].self, forKey: .containers) ?? [:]
        familyOverrides = try c.decodeIfPresent([String: String].self, forKey: .familyOverrides) ?? [:]
    }

    init(version: Int = 1, symbols: [String: SymbolCalibrationEntry] = [:], containers: [String: SymbolCalibrationEntry] = [:], familyOverrides: [String: String] = [:]) {
        self.version = version
        self.symbols = symbols
        self.containers = containers
        self.familyOverrides = familyOverrides
    }
}

// MARK: - Symbol Family

struct SymbolFamily: Identifiable {
    let id: String // family key (e.g. "star") or "container.circle"
    let members: [String]
    let isContainer: Bool
    let containerLabel: String? // "circle", "square", "rectangle"
    let width: Double   // representative's width at 100pt
    let height: Double  // representative's height at 100pt

    var count: Int { members.count }
    var representative: String { members[0] }

    var displayLabel: String {
        if let label = containerLabel {
            return ".\(label) (\(String(format: "%.0f x %.0f", width, height)))"
        }
        return id
    }
}
