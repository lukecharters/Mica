// App/LayerSelection.swift
//
// What the inspector is pointed at: which group the sidebar has selected
// (`IconLayerGroup`) and which layer within it the inspector is editing
// (`LayerTab`), plus `LayerSidebarRow`, the pair as a single `List` selection tag.
// Three small types in one file because each is defined in terms of the ones above
// it — the file is named for the selection, not for any one of them.
import Foundation

/// Top-level object selected in the LayerSidebar. Each group owns a generation
/// mode and, in Mica mode, a set of editable layers exposed as inspector tabs
/// (see `LayerTab`).
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

/// Which aspect of the selected group the inspector is editing. Chosen by the
/// child rows under a group in the `LayerSidebar` (Photoshop's layer-list pattern).
///
/// It was a segmented tab bar at the top of the inspector — Keynote's
/// Format-inspector pattern — between 2026-07-25 and 2026-08-16, when the
/// selection went back to the sidebar and `LayerTabPicker` was deleted. The enum
/// stayed exactly as it was, because it is the currency `PreviewHitTarget`,
/// `PreviewSelection` and the inspector all trade in; only the control that
/// writes it moved.
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

    /// The sidebar row's glyph.
    ///
    /// The two layers are the same stacked-planes symbol with the top or the bottom
    /// sheet filled, so the pair reads as one idea seen twice rather than as two
    /// unrelated pictures — and which of the two is *above* the other is exactly
    /// what the render order is. Layout is the move/resize arrows, deliberately
    /// from a different family: it is not a layer, and the row has no eye for the
    /// same reason.
    var systemImage: String {
        switch self {
        case .layout: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        case .foreground: "square.2.layers.3d.top.filled"
        case .background: "square.2.layers.3d.bottom.filled"
        }
    }

    /// Whether this row is a layer that can be hidden. Layout is the badge as a
    /// whole — position, offset and size — so there is nothing for an eye to act on.
    var isHideable: Bool { self != .layout }

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

    /// The child rows the sidebar shows beneath a group.
    ///
    /// `availableTabs`, gated on the advanced-controls preference as well: with
    /// them off the inspector collapses each group to a single un-tabbed pane that
    /// edits the group as one thing, so child rows would offer a selection the
    /// panel has no way to honour. That is the same rule `PreviewSelection.from`
    /// applies to the canvas outline, for the same reason — with the advanced
    /// controls off, a group is not divided into layers anywhere in the UI.
    static func sidebarRows(
        for group: IconLayerGroup,
        isSystem: Bool,
        advancedControlsEnabled: Bool
    ) -> [LayerTab] {
        guard advancedControlsEnabled else { return [] }
        return availableTabs(for: group, isSystem: isSystem)
    }
}

/// One selectable row in the `LayerSidebar`: a whole group, or one layer within it.
///
/// A `List`'s single selection needs one `Hashable` tag per row, and the sidebar's
/// rows are two shapes. It is deliberately *not* the sidebar's stored state —
/// `ContentView` keeps the selected group and each group's active tab as separate
/// values, because a canvas click, `PreviewSelection` and `PreviewHitTarget` all
/// speak in that pair. This is the projection of those values onto a row, and back.
///
/// It replaced a near-identical `LayerSelection` deleted on 2026-07-25 along with
/// the child rows. The difference is the second associated value: that one carried
/// a `LayerRole` of its own, this one carries the `LayerTab` the rest of the app
/// already uses, so there is one vocabulary for "which layer" rather than two.
enum LayerSidebarRow: Hashable {
    case group(IconLayerGroup)
    case layer(IconLayerGroup, LayerTab)

    var group: IconLayerGroup {
        switch self {
        case .group(let group), .layer(let group, _): return group
        }
    }

    /// The layer this row selects, or nil for a group row.
    var tab: LayerTab? {
        switch self {
        case .group: return nil
        case .layer(_, let tab): return tab
        }
    }

    /// Which row the sidebar highlights, given the selected group, that group's
    /// active layer, and the rows it is showing (`LayerTab.sidebarRows`).
    ///
    /// **A group row is never the answer while its layers have rows**, which is
    /// what makes clicking one resolve to a layer: the click writes only the group,
    /// and this sends the highlight down to the layer that group was last left on.
    /// The alternative — a group row that stays selected alongside its children —
    /// needs a fourth inspector pane meaning "the whole group in Mica mode", which
    /// the panel does not have.
    ///
    /// It falls back to the group row when `rows` is empty (System mode, or the
    /// advanced controls off) and when the active layer somehow is not among them,
    /// so the sidebar always has exactly one row highlighted.
    static func selected(
        group: IconLayerGroup,
        activeTab: LayerTab,
        rows: [LayerTab]
    ) -> LayerSidebarRow {
        rows.contains(activeTab) ? .layer(group, activeTab) : .group(group)
    }
}
