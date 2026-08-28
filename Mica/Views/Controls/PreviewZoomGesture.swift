// Views/Controls/PreviewZoomGesture.swift
//
// Continuous zoom for the preview canvas: a trackpad pinch and ⌘-scroll, both
// writing the same `zoomLevel` the toolbar's `ZoomMenu` and View ▸ Zoom In / Zoom Out
// write. Added 2026-08-28.
//
// **Both gestures are continuous and the ladder is not.** `PreviewZoom.levels` stays
// the vocabulary of the *menu* surfaces; these two produce any value between
// `PreviewZoom.minimum` and `PreviewZoom.maximum`. That costs nothing, because the
// step functions were written to take an arbitrary `Double` from the start — a pinch
// to 137% leaves ⌘+ stepping to 150% and ⌘− to 100%. Nothing snaps or quantizes: ⌘0
// is how you get exactly 100%, and Preview.app's pinch does not snap either.
//
// **The zoom is anchored under the pointer**, which is the whole reason this modifier
// knows about the scroll view at all — see `reanchor`. Growing the content without
// moving the scroll offset leaves the viewport looking at the content's origin, so the
// icon appears to zoom into its own top-left corner. That is what shipped first and
// what the user reported; Icon Composer and Photoshop both anchor at the cursor.
//
// **Apply to the `ScrollView`, inside the pane's `GeometryReader`** — it needs the
// viewport size, and `.scrollPosition` / `.onScrollGeometryChange` only mean anything
// attached to the scroll view itself. It stays layout-neutral: no modifier here
// changes what the pane reports as its minimum width, so the macOS 27 crash pin on the
// enclosing frame is untouched.
import AppKit
import SwiftUI

/// Pinch-to-zoom and ⌘-scroll-to-zoom for the preview canvas, anchored at the pointer.
struct PreviewZoomGesture: ViewModifier {
    @Binding var zoom: Double
    /// The pane's size, from the enclosing `GeometryReader`. The anchor arrives in
    /// these coordinates and the offset maths is expressed in them.
    let viewport: CGSize
    /// The icon's current on-screen edge length — `ContentView.previewDisplaySize` and
    /// `AppexPreviewPane.iconDisplaySize`.
    ///
    /// **Needed because the centring padding is not proportional.** The icon sits in a
    /// frame floored at the viewport, so while it is *smaller* than the pane it carries
    /// `(viewport − icon) / 2` of padding on each side and while it is larger it carries
    /// none. A step that crosses that boundary therefore does not scale content points
    /// uniformly, and treating it as if it did drifts by up to half the leftover space —
    /// measured at ~25pt going from 100% to 121% in a 553pt pane.
    let iconSize: CGFloat

    /// The zoom level the current pinch started from, or nil between pinches.
    ///
    /// **`MagnifyGesture.magnification` is cumulative for the whole gesture, not a
    /// per-frame delta** — it starts at 1.0 and reports the total ratio since the
    /// fingers went down. So the running value has to be `base × magnification`
    /// against a base captured once. Multiplying the *live* `zoom` by it instead
    /// compounds every frame and runs away to the clamp in a few hundred
    /// milliseconds.
    @State private var pinchBase: Double?

    /// Written to, to move the viewport after a zoom. Never read — `contentOffset`
    /// below is the read side, because `ScrollPosition.point` is only populated for
    /// positions this code itself set, and the user's own scrolling has to count too.
    @State private var scrollPosition = ScrollPosition()

    /// The live scroll offset, from `.onScrollGeometryChange`. Needed *before* the
    /// zoom is applied, which is why it is tracked continuously rather than read on
    /// demand.
    @State private var contentOffset: CGPoint = .zero

    func body(content: Content) -> some View {
        content
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: ScrollSnapshot.self) { geometry in
                ScrollSnapshot(
                    // **`contentOffset` is not zero at rest.** The pane's scroll view
                    // extends under the window's safe area, so `contentInsets` carries
                    // the sidebar's width and the toolbar's height (measured: 280, 52)
                    // and an unscrolled view reports `contentOffset == -insets`. Adding
                    // them back gives the scrolled amount, which starts at zero — the
                    // space `scrollTo(point:)` expects.
                    offset: CGPoint(x: geometry.contentOffset.x + geometry.contentInsets.leading,
                                    y: geometry.contentOffset.y + geometry.contentInsets.top))
            } action: { _, snapshot in
                contentOffset = snapshot.offset
            }
            .gesture(magnify)
            // A `.background` rather than an `.overlay`: the monitor view must not sit
            // above the canvas, which has its own click, hover, drop and context-menu
            // handling. It draws nothing and hit-tests nothing — it only needs to be
            // in the view tree, in this window, at this frame.
            .background(
                PreviewScrollZoomMonitor { factor, anchor in
                    applyZoom(factor: factor, at: anchor)
                }
            )
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBase ?? zoom
                if pinchBase == nil { pinchBase = base }
                // `startLocation` is in the modified view's local space, which is the
                // scroll view's — the viewport — so it needs no conversion. It is also
                // fixed for the whole gesture, which is what we want: the pinch centre
                // must not drift as the fingers move.
                apply(newZoom: PreviewZoom.clamped(base * value.magnification),
                      anchor: value.startLocation)
            }
            .onEnded { _ in pinchBase = nil }
    }

    private func applyZoom(factor: Double, at anchor: CGPoint) {
        apply(newZoom: PreviewZoom.clamped(zoom * factor), anchor: anchor)
    }

    private func apply(newZoom: Double, anchor: CGPoint) {
        let old = zoom
        guard newZoom != old, old > 0 else { return }
        zoom = newZoom
        reanchor(from: old, to: newZoom, at: anchor)
    }

    /// Move the scroll offset so the content under `anchor` stays under `anchor`.
    ///
    /// The content is re-rendered at the new size rather than scaled, so a point that
    /// sat `p` from the content's origin sits `p × f` from it afterwards. Keeping it
    /// under the same viewport position means the new offset is
    /// `(offset + anchor) × f − anchor`, all in viewport coordinates.
    ///
    /// **The upper bound is left to the scroll view**, which clamps `scrollTo(point:)`
    /// into the real range once the content has resized. Only the floor is applied here.
    /// The remaining inexactness is honest rather than a bug: keeping a point fixed can
    /// require scrolling past the content's own edge, and there the point slides instead.
    private func reanchor(from old: Double, to new: Double, at anchor: CGPoint) {
        let f = new / old
        let target = CGPoint(
            x: axisTarget(offset: contentOffset.x, anchor: anchor.x, extent: viewport.width, f: f),
            y: axisTarget(offset: contentOffset.y, anchor: anchor.y, extent: viewport.height, f: f)
        )
        // **The scroll has to land after the content has resized, or it is clamped
        // away.** `zoom` was written a line ago and the icon's frame grows with it, but
        // that has not happened yet: a `scrollTo` issued in the same turn is clamped
        // against the *old* content size, and at 100% the icon is smaller than the pane
        // so that maximum is **zero**. Every anchored scroll silently became `.zero`,
        // and the measured result was a zoom that ignored the pointer entirely —
        // identical output for a cursor at the pane's top-left and at its bottom-right.
        //
        // `target` is computed from the pre-zoom geometry captured above, so deferring
        // only the application is correct: by the time this runs the content is the new
        // size and the scroll view clamps against that instead.
        // Synchronous, and it does not need to wait for the content to resize: the
        // point is in the scrolled space, which the scroll view clamps against the new
        // content size when it applies it. Verified by an edge-scroll probe.
        //
        // No animation — this runs once per scroll event and once per pinch frame, and
        // an implicit animation would fight the next one and lag behind the pointer.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollPosition.scrollTo(point: target)
        }
    }

    /// One axis of the anchor maths. The arithmetic is `PreviewZoom.anchoredOffset`,
    /// which is where its reasoning and its tests live.
    private func axisTarget(offset: CGFloat, anchor: CGFloat, extent: CGFloat, f: Double) -> CGFloat {
        PreviewZoom.anchoredOffset(offset: offset, anchor: anchor,
                                  viewportExtent: extent, iconExtent: iconSize, factor: f)
    }
}

/// The one piece of scroll geometry the anchor maths needs, wrapped so
/// `.onScrollGeometryChange` has an `Equatable` to compare.
private struct ScrollSnapshot: Equatable {
    var offset: CGPoint
}

/// Sees `.scrollWheel` events in its own window and turns the ⌘-modified ones into a
/// zoom factor and an anchor point, consuming them so the `ScrollView` does not pan at
/// the same time.
///
/// The shape is `WindowKeyMonitor`'s, for the same reason: SwiftUI has no scroll-wheel
/// API on macOS at all, so there is nothing to attach a handler to and the event has to
/// be intercepted before AppKit dispatches it. Read that type first — the
/// `viewDidMoveToWindow` / `dismantleNSView` pairing and the `event.window` check are
/// explained there and apply here unchanged.
///
/// **This one adds a hit test, which `WindowKeyMonitor` does not need.** A local
/// monitor is app-wide and a key press has a first responder to disambiguate it; a
/// scroll has only a location. Without the bounds check, ⌘-scrolling over the
/// inspector's `Form` would zoom the preview *and* swallow the inspector's own scroll —
/// two wrong things from one event.
struct PreviewScrollZoomMonitor: NSViewRepresentable {
    /// Called with a multiplicative zoom factor (>1 zooms in) and the pointer position
    /// in the monitor's own coordinates, which are the pane's.
    var onZoom: (Double, CGPoint) -> Void

    func makeNSView(context: Context) -> MonitorView {
        MonitorView()
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        // Refreshed every body pass — the handler closes over the `zoom` binding and
        // the scroll geometry, so a stale copy would compute against stale values.
        view.onZoom = onZoom
    }

    static func dismantleNSView(_ view: MonitorView, coordinator: ()) {
        view.stopMonitoring()
    }

    final class MonitorView: NSView {
        var onZoom: ((Double, CGPoint) -> Void)?
        private var monitor: Any?

        /// **Flipped, so the anchor arrives in SwiftUI's coordinates.** An unflipped
        /// `NSView` has its origin at the bottom left, so the y this hands SwiftUI
        /// would be measured from the wrong edge — and the failure is not obvious,
        /// because it looks correct whenever the pointer is near the vertical middle.
        override var isFlipped: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { stopMonitoring() } else { startMonitoring() }
        }

        private func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                guard event.modifierFlags.contains(.command) else { return event }
                // `locationInWindow` is in window coordinates and this view's bounds
                // are its own, so the conversion is not optional — an unconverted
                // comparison reads as "works" for a pane at the window's origin.
                let point = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(point) else { return event }
                self.onZoom?(Self.zoomFactor(for: event), point)
                return nil
            }
        }

        /// Called from both `viewDidMoveToWindow` and `dismantleNSView` — see
        /// `WindowKeyMonitor.stopMonitoring()` for why one is not enough.
        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        /// One scroll event's worth of zoom, as a factor to multiply the level by.
        ///
        /// **`exp` rather than `1 + delta × k`**, so the gesture is symmetric: scroll
        /// up by some amount and back down by the same amount and you land on the
        /// level you started from. The additive form does not — `×1.1` then `×0.9` is
        /// `×0.99` — and the drift is visible within a couple of seconds of fiddling.
        ///
        /// **The two device classes report different units.** A trackpad or Magic Mouse
        /// sets `hasPreciseScrollingDeltas` and reports pixel deltas, tens per gesture;
        /// a notched wheel reports *lines*, ±1 per click. Without the multiplier a
        /// wheel click moves the zoom by 0.4% and reads as broken. The constants were
        /// tuned on screen, not derived.
        private static func zoomFactor(for event: NSEvent) -> Double {
            let delta = event.hasPreciseScrollingDeltas
                ? Double(event.scrollingDeltaY)
                : Double(event.scrollingDeltaY) * 12
            return exp(delta * 0.004)
        }
    }
}

extension View {
    /// Adds pointer-anchored pinch and ⌘-scroll zoom. Apply to the **`ScrollView`**,
    /// passing the enclosing `GeometryReader`'s size — see `PreviewZoomGesture`.
    func previewZoomGestures(zoom: Binding<Double>, viewport: CGSize, iconSize: CGFloat) -> some View {
        modifier(PreviewZoomGesture(zoom: zoom, viewport: viewport, iconSize: iconSize))
    }
}
