// FamilyCalibration.swift - Shared types for family-based SF Symbol calibration
//
// Used by both the production rendering pipeline (SymbolSizingService) and
// the calibration playground (FamilyCalStore in DimensionCalibrationPlayground).

import SwiftUI

// MARK: - Container Type

enum ContainerType: String, CaseIterable {
    case circle, square, rectangle

    var dimKey: String {
        switch self {
        case .circle: return "117.0000_114.0000"
        case .square: return "115.0000_104.0000"
        case .rectangle: return "141.0000_104.0000"
        }
    }

    var suffixComponent: String { rawValue }

    static let allDimKeys: Set<String> = Set(allCases.map(\.dimKey))
}

// MARK: - Calibration Entry

struct FamilyCalEntry: Codable, Equatable {
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

struct FamilyCalFile: Codable {
    var version: Int = 1
    var symbols: [String: FamilyCalEntry] = [:]
    var containers: [String: FamilyCalEntry] = [:]
    var familyOverrides: [String: String] = [:]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        symbols = try c.decodeIfPresent([String: FamilyCalEntry].self, forKey: .symbols) ?? [:]
        containers = try c.decodeIfPresent([String: FamilyCalEntry].self, forKey: .containers) ?? [:]
        familyOverrides = try c.decodeIfPresent([String: String].self, forKey: .familyOverrides) ?? [:]
    }

    init(version: Int = 1, symbols: [String: FamilyCalEntry] = [:], containers: [String: FamilyCalEntry] = [:], familyOverrides: [String: String] = [:]) {
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
