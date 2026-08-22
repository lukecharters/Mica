// App/PreviewOutlines.swift
//
// What the preview outlines, in what weight, and when the outlines fade — the
// three decisions behind the two-weight hover/selection outline Mica took from
// Icon Composer. Pure types with no view dependencies, so each one is testable
// without a canvas.
//
// The behaviour they encode was measured against the running Icon Composer on
// 2026-08-22; the numbers and the method are in
// `docs/plans/hover-and-selection-outlines-2026-08-22.md` §1. Two of those
// findings are load-bearing here and are not visible in a screenshot:
//
//   - **Both outlines share one idle timer.** Resting the pointer fades the
//     selected outline too, and any pointer motion over the canvas or the sidebar
//     rows revives both. That is why the fade cannot live in the view that draws a
//     stroke — see `PreviewOutlineOverlay` — and why `PreviewOutlineActivity` is a
//     property of the window rather than of an outline.
//   - **Hovering the layer you already have selected shows the selected weight
//     only**, not a hover stroke over the top of it. That is `resolve`'s first rule.

import CoreGraphics
import Foundation

/// How strongly an outline is drawn: the selection, or the layer under the pointer.
///
/// Measured off Icon Composer on a ~510pt canvas: the selected stroke is ~6px and
/// essentially opaque accent blue, the hover stroke ~3px of the same blue at
/// roughly 0.3. So a hover is *exactly* half the width and about a third of the
/// opacity — not a different colour.
enum PreviewOutlineEmphasis: Equatable, CaseIterable {
    case selected
    case hovered

    /// Stroke width at a given canvas side length.
    ///
    /// Scaled off the canvas the same way everything else in the preview is, so it
    /// stays hairline-thin zoomed out and doesn't become a band zoomed in. The
    /// coefficient is 3 at the 256pt reference rather than the 2 Mica used while
    /// there was only one weight: 3 lands on the measured ~6px where the canvas is
    /// ~512pt.
    ///
    /// **The clamp is applied to the selected width and the hover is halved after
    /// it**, so "a hover is half a selection" holds at every size — including the
    /// extremes, where clamping each separately would quietly make them equal.
    func lineWidth(displaySize: CGFloat) -> CGFloat {
        let selected = min(max(3 * (displaySize / 256), Self.minSelectedWidth), Self.maxSelectedWidth)
        switch self {
        case .selected: return selected
        case .hovered:  return selected * Self.hoverWidthRatio
        }
    }

    /// Opacity of the accent colour. A hover is a hint about where the pointer is,
    /// so it reads as a tint rather than as a second selection.
    var opacity: Double {
        switch self {
        case .selected: return 1
        case .hovered:  return 0.3
        }
    }

    static let minSelectedWidth: CGFloat = 1.5
    static let maxSelectedWidth: CGFloat = 8
    static let hoverWidthRatio: CGFloat = 0.5
}

/// One outline to draw: which layer, and how strongly.
struct PreviewOutline: Equatable {
    let selection: PreviewSelection
    let emphasis: PreviewOutlineEmphasis
}

enum PreviewOutlines {

    /// The outlines to draw, in draw order — **hovered first, so the selected
    /// stroke wins wherever the two overlap.**
    ///
    /// Both inputs are already-resolved `PreviewSelection`s, which is what keeps
    /// the gates in one place: `ContentView` resolves the selection and the hover
    /// through the same function, so neither can outline something the inspector
    /// cannot edit (the advanced controls off, the Export tab, a hidden inspector),
    /// and a hovered *group* row resolves to the same layer selecting it would.
    ///
    /// - Returns: 0, 1 or 2 outlines. Empty when there is nothing to draw; one when
    ///   the pointer is over the layer that is already selected, since the selected
    ///   weight is the stronger claim and drawing both reads as a doubled border.
    static func resolve(
        selected: PreviewSelection?,
        hovered: PreviewSelection?
    ) -> [PreviewOutline] {
        switch (selected, hovered) {
        case (nil, nil):
            return []
        case (let selected?, nil):
            return [PreviewOutline(selection: selected, emphasis: .selected)]
        case (nil, let hovered?):
            return [PreviewOutline(selection: hovered, emphasis: .hovered)]
        case (let selected?, let hovered?):
            guard selected != hovered else {
                return [PreviewOutline(selection: selected, emphasis: .selected)]
            }
            return [
                PreviewOutline(selection: hovered, emphasis: .hovered),
                PreviewOutline(selection: selected, emphasis: .selected)
            ]
        }
    }
}

/// Throttles "the pointer moved" into the wake signal the outlines' fade restarts
/// on.
///
/// `.onContinuousHover` reports every pointer sample — 60 or more a second — and
/// the fade is a `.task(id:)`, so feeding it raw motion would cancel and restart a
/// `Task` on every frame the pointer is moving. The throttle bounds that to one
/// restart per window while keeping the semantic the measurement asked for: the
/// outlines fade a fixed time after the pointer *stops*, not after it started
/// moving.
///
/// The window is deliberately far shorter than the hold, so a wake it swallows is
/// always followed by one it admits while the outlines are still up.
struct PreviewOutlineActivity: Equatable {

    /// Shortest gap between two wakes. 250ms against a 1.5s hold: a pointer in
    /// continuous motion wakes the outlines four times a second, and the last wake
    /// before it stops is at most 250ms stale.
    static let throttle: TimeInterval = 0.25

    /// When the last admitted wake happened, on the caller's clock. Nil until the
    /// first one, which is always admitted — a first motion after the outlines have
    /// faded must never be the one that gets swallowed.
    private var lastWake: TimeInterval?

    init() {}

    /// - Parameter now: a monotonic timestamp, e.g. `ProcessInfo.processInfo.systemUptime`.
    ///   Injected rather than read here so the throttle is testable.
    /// - Returns: whether the caller should bump its wake counter.
    mutating func noteMotion(now: TimeInterval) -> Bool {
        // `now < last` can only mean the caller changed clocks. Waking is the safe
        // reading of it: the alternative is outlines that stay faded until the
        // difference elapses.
        if let lastWake, now >= lastWake, now - lastWake < Self.throttle {
            return false
        }
        lastWake = now
        return true
    }
}
