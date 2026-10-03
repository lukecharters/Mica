// SymbolCalibration.swift - Shared types for per-symbol SF Symbol sizing calibration
//
// Used by both the production rendering pipeline (SymbolSizingService) and the
// calibration tool (SymbolCalibrationStore in SymbolCalibrationTool).
//
// Entries are per symbol, plus one per container shape.

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
}

// MARK: - Calibration Entry

struct SymbolCalibrationEntry: Codable, Equatable {
    var multiplier: Double
    var xOffset: Double
    var yOffset: Double
    var weight: String   // a `weightTokens` key
    var status: String   // "calibrated", "skipped", "needs-review"
    /// Provenance marker; nil for hand-calibrated entries, "pixel-fit" for entries
    /// fitted to Apple's rendering (`PixelFitter`).
    var source: String? = nil
    /// Soft IoU of a `pixel-fit` entry against Apple's rendering when it was fitted;
    /// nil for every other source.
    var fitScore: Double? = nil
    /// True when a person set a `pixel-fit` entry's status, which Re-flag then leaves alone;
    /// nil otherwise.
    var reviewed: Bool? = nil

    /// The weight of a symbol with no calibration entry, and of an unknown token.
    static let defaultWeight: Font.Weight = .medium
    /// `defaultWeight` as AppKit spells it, for box-fit's tight-bounds measurement.
    static let defaultMeasurementWeight: NSFont.Weight = .medium

    /// The weights the calibration tool offers.
    static let weightTokens: [(token: String, weight: Font.Weight, measurementWeight: NSFont.Weight)] = [
        ("regular", .regular, .regular), ("medium", .medium, .medium),
        ("semibold", .semibold, .semibold), ("bold", .bold, .bold),
    ]

    static func weightToken(for weight: Font.Weight) -> String {
        weightTokens.first { $0.weight == weight }?.token ?? "medium"
    }

    static func fontWeight(fromToken token: String) -> Font.Weight {
        weightTokens.first { $0.token == token }?.weight ?? defaultWeight
    }

    var fontWeight: Font.Weight { Self.fontWeight(fromToken: weight) }

    /// Whether the two would render the same, whatever their status and provenance.
    func hasSameValues(as other: SymbolCalibrationEntry) -> Bool {
        multiplier == other.multiplier && xOffset == other.xOffset && yOffset == other.yOffset
            && fontWeight == other.fontWeight
    }
}

// MARK: - Calibration File

struct SymbolCalibration: Codable {
    var version: Int = 1
    var symbols: [String: SymbolCalibrationEntry] = [:]
    var containers: [String: SymbolCalibrationEntry] = [:]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        symbols = try c.decodeIfPresent([String: SymbolCalibrationEntry].self, forKey: .symbols) ?? [:]
        containers = try c.decodeIfPresent([String: SymbolCalibrationEntry].self, forKey: .containers) ?? [:]
    }

    init(version: Int = 1, symbols: [String: SymbolCalibrationEntry] = [:], containers: [String: SymbolCalibrationEntry] = [:]) {
        self.version = version
        self.symbols = symbols
        self.containers = containers
    }
}
