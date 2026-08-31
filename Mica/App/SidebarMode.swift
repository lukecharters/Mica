// App/SidebarMode.swift
//
// What the sidebar column is showing: the layer list, or the preset library.
import Foundation

/// The two things the sidebar column can be.
///
/// **This is deliberately not a case on `LayerSidebarRow`.** That type is a
/// *projection* of the `(selectedGroup, activeTab)` pair `ContentView` owns, with the
/// invariant that exactly one row is always highlighted, produced by the pure
/// `LayerSidebarRow.selected(group:activeTab:rows:)`. A presets row has no group and
/// no tab, so that function could not produce it and the invariant would have to grow
/// an exception. Showing presets is a change of *what the column draws*, not a change
/// of what the inspector is pointed at — so it is its own piece of state, sibling to
/// `selectedGroup`, and the layer selection survives untouched underneath it.
///
/// It lives in `ContentView` as plain `@State`, not `@AppStorage`: the presets library
/// is somewhere you visit, not a place to be left on relaunch.
enum SidebarMode: String, CaseIterable, Identifiable, Hashable {
    case layers
    case presets

    var id: String { rawValue }

    /// The selector bar's name for this mode.
    ///
    /// Through `String(localized:)` rather than returned as a bare literal:
    /// `FillingSegmentedPicker` hands these to `NSSegmentedControl`, which takes a
    /// `String` and so never reaches the string catalog on its own.
    ///
    /// **The bar draws the glyph, not this** — so this is the segment's accessibility
    /// description and its tooltip, which are then the only things that name it. It is
    /// not decoration, and it is why `Segment` requires a label even for an image.
    var label: String {
        switch self {
        case .layers: String(localized: "Layers")
        case .presets: String(localized: "Presets")
        }
    }

    /// The segment's glyph.
    ///
    /// A pair chosen to read as one idea seen twice, the way the two layer rows are:
    /// stacked planes for the layer list, a shape on a shape for the library of
    /// composed presets. **A misspelled name draws nothing at all, with no error**, so
    /// `SidebarPresentationTests` resolves both through `NSImage` — the same guard
    /// `LayerTabTests` puts on the row glyphs.
    var systemImage: String {
        switch self {
        case .layers: "square.3.layers.3d"
        case .presets: "square.on.circle"
        }
    }
}

/// The sidebar column's whole visible state: which mode, and whether the column is
/// out at all.
///
/// **This exists so the ⌃⌘P rule is a value rather than a closure inside a view.**
/// "Are the presets showing?" is one `Bool` to the View menu and the toolbar toggle,
/// and it is derived from *two* pieces of state — so setting it has to write both, and
/// the two directions are deliberately not symmetric. Showing reveals the column;
/// hiding does **not** hide it. Neither half is a value a view test could read back,
/// which is the same reason `LayerSidebarRow.selected` is a pure function.
///
/// The interaction is new with this shape. While the preset library was a pane in the
/// detail column, ⌃⌘P and ⌃⌘S were independent.
struct SidebarPresentation: Equatable {
    var mode: SidebarMode
    /// Whether the sidebar column is on screen at all — ⌃⌘S.
    var isColumnVisible: Bool

    /// The presets are showing only if the column is out **and** it is in Presets
    /// mode. Reading only `mode` would report success for a mode nobody can see.
    var showsPresets: Bool {
        isColumnVisible && mode == .presets
    }

    /// What ⌃⌘P, or the toolbar toggle, resolves to.
    ///
    /// - Showing reveals the column, because ⌃⌘P with the sidebar hidden would
    ///   otherwise set a mode with nothing on screen to show it.
    /// - Hiding goes back to Layers and **leaves the column alone**. Hiding the whole
    ///   sidebar would make "Hide Presets" throw the layer list away as a side effect,
    ///   which is not what it says — and it would leave ⌃⌘S's own state changed by a
    ///   command that never mentions it.
    func settingPresets(_ showing: Bool) -> SidebarPresentation {
        showing
            ? SidebarPresentation(mode: .presets, isColumnVisible: true)
            : SidebarPresentation(mode: .layers, isColumnVisible: isColumnVisible)
    }
}
