// Views/Sidebar/GenerationModeSwitch.swift
import SwiftUI

/// Two-segment grouping for the sidebar: Custom (SwiftUI rendering) vs System (Apple reference rendering).
/// Used by `GroupModePicker` to drive each group's per-segment icon + label.
enum IconModeSegment: Int, CaseIterable, Identifiable {
    case custom = 0
    case system = 1

    var id: Int { rawValue }

    var systemImageName: String {
        switch self {
        case .custom: "slider.horizontal.3"
        case .system: "command"
        }
    }

    var label: String {
        switch self {
        case .custom: "Mica"
        case .system: "System"
        }
    }
}
