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
// **A modifier rather than two calls at each site.** The two preview panes are
// mirrored shapes (see `ContentView.previewPane` and `AppexPreviewPane.previewContent`)
// and this is the third thing that has to be applied to both; the first two got out of
// sync once each. One modifier is also the only place the pinch's base value can live —
// see `pinchBase`.
import AppKit
import SwiftUI

/// Pinch-to-zoom and ⌘-scroll-to-zoom for the preview canvas.
///
/// Apply to the **pane**, outside the `ScrollView`, not to the icon content: the
/// zoomable region is the whole preview column, so a pinch works with the pointer over
/// the empty area beside a small icon. `PreviewScrollZoomMonitor` hit-tests against
/// this view's bounds, which is what makes "outside the `ScrollView`" the placement
/// that gives the right area.
struct PreviewZoomGesture: ViewModifier {
    @Binding var zoom: Double

    /// The zoom level the current pinch started from, or nil between pinches.
    ///
    /// **`MagnifyGesture.magnification` is cumulative for the whole gesture, not a
    /// per-frame delta** — it starts at 1.0 and reports the total ratio since the
    /// fingers went down. So the running value has to be `base × magnification`
    /// against a base captured once. Multiplying the *live* `zoom` by it instead
    /// compounds every frame and runs away to the clamp in a few hundred
    /// milliseconds.
    ///
    /// Capturing the base also makes the gesture reversible through the clamp: pinch
    /// past 8×, then back, and you return along the same values rather than sticking
    /// at the ceiling the way an accumulator would.
    @State private var pinchBase: Double?

    func body(content: Content) -> some View {
        content
            .gesture(magnify)
            // A `.background` rather than an `.overlay`: the monitor view must not sit
            // above the canvas, which has its own click, hover, drop and context-menu
            // handling. It draws nothing and hit-tests nothing — it only needs to be
            // in the view tree, in this window, at this frame.
            .background(
                PreviewScrollZoomMonitor { factor in
                    zoom = PreviewZoom.clamped(zoom * factor)
                }
            )
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBase ?? zoom
                if pinchBase == nil { pinchBase = base }
                zoom = PreviewZoom.clamped(base * value.magnification)
            }
            // Cleared on end *and* on cancel: a gesture interrupted by the window
            // losing focus never sends `onEnded`, and a stale base would make the
            // next pinch jump to wherever the last one started.
            .onEnded { _ in pinchBase = nil }
    }
}

/// Sees `.scrollWheel` events in its own window and turns the ⌘-modified ones into a
/// zoom factor, consuming them so the `ScrollView` does not pan at the same time.
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
    /// Called with a multiplicative zoom factor for one ⌘-scroll event: >1 zooms in.
    var onZoom: (Double) -> Void

    func makeNSView(context: Context) -> MonitorView {
        MonitorView()
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        // Refreshed every body pass — the handler closes over the `zoom` binding, so a
        // stale copy would multiply against a stale level.
        view.onZoom = onZoom
    }

    static func dismantleNSView(_ view: MonitorView, coordinator: ()) {
        view.stopMonitoring()
    }

    final class MonitorView: NSView {
        var onZoom: ((Double) -> Void)?
        private var monitor: Any?

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
                self.onZoom?(Self.zoomFactor(for: event))
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
    /// Adds pinch and ⌘-scroll zoom, writing `zoom`. Apply to the preview **pane** —
    /// see `PreviewZoomGesture`.
    func previewZoomGestures(zoom: Binding<Double>) -> some View {
        modifier(PreviewZoomGesture(zoom: zoom))
    }
}
