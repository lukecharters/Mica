// Models/AppexEnclosureColor.swift
import SwiftUI

/// Named color tokens accepted by ISEnclosureColor in an .appex Info.plist.
/// Raw values are the exact strings Apple's IconServices pipeline expects.
enum AppexEnclosureColor: String, CaseIterable, Identifiable {
    case black
    case blue
    case brown
    case cyan
    case gray
    case green
    case indigo
    case orange
    case pink
    case purple
    case red
    case teal
    case white
    case yellow

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// Approximate SwiftUI color for UI swatches — not used in rendering.
    var previewColor: Color {
        switch self {
        case .black:  return .black
        case .blue:   return .blue
        case .brown:  return .brown
        case .cyan:   return .cyan
        case .gray:   return .gray
        case .green:  return .green
        case .indigo: return .indigo
        case .orange: return .orange
        case .pink:   return .pink
        case .purple: return .purple
        case .red:    return .red
        case .teal:   return .teal
        case .white:  return .white
        case .yellow: return .yellow
        }
    }
}
