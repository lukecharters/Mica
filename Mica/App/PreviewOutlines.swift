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
import SwiftUI

/// How strongly an outline is drawn: the selection, or the layer under the pointer.
///
/// Measured off Icon Composer on a ~510pt canvas: the selected stroke is ~6px of
/// essentially opaque accent blue, the hover ~3px of a much lighter blue. So a
/// hover is exactly half the width **and a different colour** — which is the part
/// the first reading of the measurement got wrong: `(192, 223, 252)` over white
/// looks like accent-at-a-third, and is in fact a solid light blue. The user
/// identified it as `rgb(183, 223, 255)` on 2026-08-22, and that is what this uses.
///
/// The difference is not cosmetic. An accent stroke at 0.3 is *transparent*, so it
/// takes the colour of whatever it is over: measured against Mica's default blue
/// icon, the half of the band lying on the chiclet moved the pixels by
/// `(−4, −7, −2)` — nothing at all — while the half on the white canvas moved them
/// by `(−54, −33, +5)`. A solid stroke has no such failure mode, which is why this
/// replaced a planned "contrast pass" under a translucent one.
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

    /// The stroke's colour.
    ///
    /// The selection follows the user's accent colour, as Mica's one outline always
    /// has. The hover is a **fixed** light blue rather than a lighter accent: it is
    /// what Icon Composer draws, and a tint of the accent would be the same hue as
    /// the selection, so the two weights would differ only in width — on a
    /// foreground box inside a saturated chiclet, that is no difference at all.
    ///
    /// Fixed also means it does not follow the appearance. That is deliberate for
    /// now, matching the measurement, and is the one thing here worth re-checking on
    /// screen in the dark: this is drawn over the *icon*, not over the window, so
    /// the light backdrop it was designed against is Mica's canvas either way.
    var strokeColor: Color {
        switch self {
        case .selected: return .accentColor
        case .hovered:  return Self.hoverColor
        }
    }

    /// `rgb(183, 223, 255)`, Icon Composer's hover blue.
    static let hoverColor = Color(
        .sRGB,
        red: hoverColorComponents.red / 255,
        green: hoverColorComponents.green / 255,
        blue: hoverColorComponents.blue / 255,
        opacity: 1
    )

    /// Kept apart from the `Color` so a test can assert the conversion rather than
    /// restate it — the mistake this guards is 0–255 components read as 0–1, which
    /// yields a stroke so dark it reads as black.
    static let hoverColorComponents = (red: 183.0, green: 223.0, blue: 255.0)

    /// How far outside the layer's own bounds the stroke is drawn, measured from the
    /// bounds to the stroke's **inner** edge.
    ///
    /// Icon Composer leaves a gap in both weights — measured at ~4px on its ~510pt
    /// canvas, so 2 at the 256pt reference — and it does more than look tidy. A
    /// stroke is centred on the path it is given, so an unexpanded outline puts half
    /// its width *inside* the layer: it covers the artwork's own edge, which is the
    /// thing you are trying to see, and on the icon background it lands half on the
    /// chiclet, where it changes colour. Offsetting outward puts the whole stroke on
    /// the backdrop and leaves the layer's edge visible beside it.
    func outset(displaySize: CGFloat) -> CGFloat {
        Self.gap(displaySize: displaySize) + lineWidth(displaySize: displaySize) / 2
    }

    /// The visible gap itself, scaled like everything else off the 256pt reference.
    /// Shared by both weights, which is what makes them read as the same idea at two
    /// strengths — since `outset` adds each weight's own half-width, the *gap* comes
    /// out identical while the paths differ.
    static func gap(displaySize: CGFloat) -> CGFloat {
        min(max(2 * (displaySize / 256), 1), 6)
    }

    static let minSelectedWidth: CGFloat = 1.5
    static let maxSelectedWidth: CGFloat = 8
    static let hoverWidthRatio: CGFloat = 0.5
}

/// What a pointer sample says: where the pointer is, or that it has left the areas
/// the outlines answer to — either canvas, or a sidebar *row*.
///
/// The distinction exists because the two cases fade differently, and measurement
/// is what separated them (Icon Composer, 2026-08-22). Both fades are the same
/// ~0.4s ease-out; what differs is the hold in front of it. Resting inside holds
/// full strength for ~1.55s and then fades — 100% through t=1.52s, then 49%, 7.5%,
/// 0. Leaving starts the same fade **immediately** — 42%, 10%, 2% across
/// back-to-back captures 0.153s apart. That is what reads as "slow when you rest,
/// quick when you leave", and it is one duration, not two.
///
/// The empty space *below* the sidebar's rows counts as away, which matches Icon
/// Composer: a pointer parked there outlines nothing.
enum PreviewPointer: Equatable {
    /// Inside a tracked area, over this layer — or over none of them, which the
    /// canvas margin and the chiclet's rounded corners both produce.
    case over(LayerSidebarRow?)
    /// Gone from the tracked areas.
    case away
}

/// One outline to draw: which layer, and how strongly.
struct PreviewOutline: Equatable {
    let selection: PreviewSelection
    let emphasis: PreviewOutlineEmphasis
}

enum PreviewOutlines {

    /// A shape grown by `outset` on every side, for drawing an outline that clears
    /// the layer's own bounds.
    ///
    /// The corner radius grows with it so the expanded shape stays **concentric**
    /// with the original — an unchanged radius on a bigger rect is a squarer corner,
    /// which reads as a different shape rather than an offset one, and is most
    /// obvious on the chiclet, whose radius is the largest in the app.
    static func expanded(_ shape: PreviewSelectionShape, by outset: CGFloat) -> PreviewSelectionShape {
        switch shape {
        case .roundedRect(let rect, let cornerRadius):
            return .roundedRect(
                rect.insetBy(dx: -outset, dy: -outset),
                cornerRadius: max(cornerRadius + outset, 0)
            )
        case .circle(let center, let radius):
            return .circle(center: center, radius: max(radius + outset, 0))
        }
    }

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
