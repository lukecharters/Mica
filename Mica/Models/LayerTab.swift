// Models/LayerTab.swift
import Foundation

/// Which aspect of the selected group the inspector is editing. Rendered as a
/// segmented tab bar at the top of the inspector (Keynote's Format-inspector
/// pattern) rather than as child rows in the sidebar.
///
/// `.layout` only applies to the badge — the icon's own layout lives inside its
/// foreground/background sections. See `availableTabs(for:isSystem:)`.
enum LayerTab: String, CaseIterable, Identifiable, Hashable {
    case layout
    case foreground
    case background

    var id: String { rawValue }

    var label: String {
        switch self {
        case .layout: "Layout"
        case .foreground: "Foreground"
        case .background: "Background"
        }
    }

    /// Tabs offered for a group. Empty in System mode: the appex pipeline renders
    /// the whole group as one image, so there are no separately editable layers
    /// and the inspector shows a single un-tabbed pane.
    static func availableTabs(for group: IconLayerGroup, isSystem: Bool) -> [LayerTab] {
        guard !isSystem else { return [] }
        switch group {
        case .icon:  return [.foreground, .background]
        case .badge: return [.layout, .foreground, .background]
        }
    }

    /// The tab a group starts on. Badge opens on Layout (position/size is the
    /// most common badge edit); icon opens on Foreground (the symbol).
    static func defaultTab(for group: IconLayerGroup) -> LayerTab {
        switch group {
        case .icon:  return .foreground
        case .badge: return .layout
        }
    }
}
