// Models/AppexEnclosureColor.swift
import SwiftUI

/// Named color tokens accepted by ISEnclosureColor in an .appex Info.plist.
/// Raw values are the exact strings Apple's IconServices pipeline expects.
enum AppexEnclosureColor: String, CaseIterable, Identifiable {
    case blue
    case orange
    case red
    case green
    case purple
    case gray
    case yellow
    case pink
    case teal
    case indigo
    case brown
    case cyan

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// Approximate SwiftUI color for UI swatches — not used in rendering.
    var previewColor: Color {
        switch self {
        case .blue:   return .blue
        case .orange: return .orange
        case .red:    return .red
        case .green:  return .green
        case .purple: return .purple
        case .gray:   return .gray
        case .yellow: return .yellow
        case .pink:   return .pink
        case .teal:   return .teal
        case .indigo: return .indigo
        case .brown:  return .brown
        case .cyan:   return .cyan
        }
    }
}
