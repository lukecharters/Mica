// App/PreviewZoom.swift
import CoreGraphics
import Foundation

/// The preview's zoom ladder, and the two steps along it.
///
/// One list, read by both surfaces that offer zoom: the toolbar's `ZoomMenu`, which
/// shows every rung, and View ▸ Zoom In / Zoom Out, which walks between them. They
/// were the same nine numbers in one private array until the View menu arrived
/// (item B1 of the Mac-conventions plan); a second copy would have let ⌘+
/// stop at a percentage the menu does not offer.
///
/// **`App/`, not `Views/`** — the CLI has no preview and never compiles this, and
/// the stepping is the part worth testing on its own. See the project notes' rule on which
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

    // MARK: - Continuous zoom

    /// The ends of the ladder, and the range a continuous gesture is held inside.
    ///
    /// **Derived from `levels`, not restated beside it.** A second copy of `8.0` would
    /// let someone add a 16× rung the toolbar menu offers and a pinch cannot reach —
    /// the same failure the type's doc comment describes for the two step functions.
    /// The `?? actualSize` fallbacks are unreachable while `levels` has any element;
    /// they are there so this stays free of force-unwraps.
    static var minimum: Double { levels.first ?? actualSize }
    static var maximum: Double { levels.last ?? actualSize }

    /// Bring an arbitrary scale inside the ladder's range.
    ///
    /// Pinch and ⌘-scroll produce continuous values, and they stop where the rest of
    /// the UI stops: `minimum` and `maximum` are the range the toolbar's `ZoomMenu`
    /// advertises and the points at which Zoom In and Zoom Out disable themselves. A
    /// gesture free to run past them would show a percentage no menu rung can check
    /// and — at the top — size the preview far beyond the largest export.
    ///
    /// **Off-ladder results are the intended output**, not a rounding step on the way
    /// to a rung. `zoomedIn(from:)` and `zoomedOut(from:)` already take any `Double`
    /// (see their notes), so a pinch to 137% leaves ⌘+ and ⌘− working, and neither
    /// snapping nor quantizing is needed to keep the two surfaces agreeing.
    static func clamped(_ zoom: Double) -> Double {
        // NaN would survive a naive `min`/`max` pair and propagate into a frame
        // size, which SwiftUI resolves to a zero-sized view rather than complaining.
        // A gesture cannot produce one today; `magnification` is a ratio and a
        // division by a zero starting scale is the shape that would.
        guard zoom.isFinite else { return actualSize }
        return min(max(zoom, minimum), maximum)
    }

    /// Where the scroll offset must move so the content under `anchor` stays under
    /// `anchor` when the zoom is multiplied by `factor`. One axis; call it twice.
    ///
    /// All lengths are in the viewport's coordinates. `offset` is the *scrolled* amount,
    /// zero at the leading edge — not a scroll view's raw `contentOffset`, which on a
    /// pane inside a window with a sidebar and a toolbar starts at minus the safe-area
    /// insets. `anchor` is the pointer's position within the viewport.
    ///
    /// **The centring padding is why this is not just `(offset + anchor) × factor −
    /// anchor`.** The icon lives in a frame floored at the viewport size, so while it is
    /// *smaller* than the viewport it carries `(viewport − icon) / 2` of padding either
    /// side, and while it is larger it carries none. A step that crosses that boundary
    /// does not scale content positions uniformly, and treating it as if it did keeps
    /// the wrong *feature* under the pointer — off by the old padding times the factor,
    /// measured at ~25pt going from 100% to 121% in a 553pt pane. Converting into the
    /// icon's own space first is exact on both sides of the boundary and across it.
    ///
    /// Two results are floors rather than held points, and both are honest:
    ///
    /// - **An icon that still fits the viewport scrolls not at all.** It is centred, the
    ///   scrollable range is empty, and the answer is zero however the pointer moved.
    /// - **A point close to the leading edge cannot always be held**, because holding it
    ///   would mean scrolling past the content's own start. It slides instead.
    ///
    /// The upper bound is deliberately absent: the scroll view knows the real content
    /// size and clamps into it.
    static func anchoredOffset(
        offset: CGFloat,
        anchor: CGFloat,
        viewportExtent: CGFloat,
        iconExtent: CGFloat,
        factor: Double
    ) -> CGFloat {
        guard factor.isFinite, factor > 0 else { return max(0, offset) }
        // Still fits, so it is centred and there is nothing to scroll. Returning the
        // unclamped arithmetic here would hand the scroll view a value it has to throw
        // away — correct on screen only because of that clamp, which is not a property
        // worth relying on.
        guard iconExtent * factor > viewportExtent else { return 0 }
        // Past the guard the *new* padding is zero, which is what collapses the general
        // form to this.
        let paddingBefore = max(0, (viewportExtent - iconExtent) / 2)
        let withinIcon = (offset + anchor) - paddingBefore
        return max(0, withinIcon * factor - anchor)
    }
}
