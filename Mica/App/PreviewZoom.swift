// App/PreviewZoom.swift
import Foundation

/// The preview's zoom ladder, and the two steps along it.
///
/// One list, read by both surfaces that offer zoom: the toolbar's `ZoomMenu`, which
/// shows every rung, and View ▸ Zoom In / Zoom Out, which walks between them. They
/// were the same nine numbers in one private array until the View menu arrived
/// (item B1 of `docs/plans/mac-conventions.md`); a second copy would have let ⌘+
/// stop at a percentage the menu does not offer.
///
/// **`App/`, not `Views/`** — the CLI has no preview and never compiles this, and
/// the stepping is the part worth testing on its own. See NOTES.md's rule on which
/// list a new file joins.
enum PreviewZoom {
    /// The rungs, ascending. `1.0` is Actual Size; the extremes are the ends that
    /// disable Zoom Out and Zoom In.
    static let levels: [Double] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0]

    /// What View ▸ Actual Size sets, and the level a window opens at.
    static let actualSize: Double = 1.0

    /// The next rung above `zoom`, or nil if there is none.
    ///
    /// Deliberately "the smallest level strictly greater than" rather than an index
    /// lookup, because `zoomLevel` is a plain `Double` that need not be on the
    /// ladder: `0` is `ContentView`'s Fit sentinel, and a future control could set
    /// anything. An index lookup would return nil for those and silently disable
    /// both commands.
    static func zoomedIn(from zoom: Double) -> Double? {
        levels.first { $0 > zoom }
    }

    /// The next rung below `zoom`, or nil if there is none.
    static func zoomedOut(from zoom: Double) -> Double? {
        levels.last { $0 < zoom }
    }
}
