// Models/LayerSelection.swift
import Foundation

/// Top-level grouping in the LayerSidebar. Each group owns a generation mode and
/// has two child layers (foreground + background) when in Custom mode.
enum IconLayerGroup: String, CaseIterable, Identifiable, Hashable {
    case icon
    case badge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .icon: "Icon"
        case .badge: "Badge"
        }
    }
}

/// Sub-layer role within a group.
enum LayerRole: String, CaseIterable, Identifiable, Hashable {
    case foreground
    case background

    var id: String { rawValue }

    var label: String {
        switch self {
        case .foreground: "Foreground"
        case .background: "Background"
        }
    }
}

/// What's currently selected in the LayerSidebar. The Inspector reads this to
/// decide which controls to show — group-level controls (mode, group layout)
/// when a group header is selected; per-layer controls (source, appearance) when
/// a child row is selected.
enum LayerSelection: Hashable {
    case group(IconLayerGroup)
    case layer(IconLayerGroup, LayerRole)

    var group: IconLayerGroup {
        switch self {
        case .group(let g), .layer(let g, _): return g
        }
    }

    var role: LayerRole? {
        switch self {
        case .group: return nil
        case .layer(_, let r): return r
        }
    }

    var isGroup: Bool {
        if case .group = self { return true } else { return false }
    }
}
