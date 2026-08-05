// Views/Controls/WindowKeyMonitor.swift
import AppKit
import SwiftUI

/// Sees key-down events in its own window **before** the first responder does, and
/// consumes the ones the handler claims.
///
/// This exists because `.onKeyPress` cannot see a key a focused `TextField` has
/// already claimed. Measured in the symbol picker on 2026-08-05, with the
/// `.searchable` field focused: all four arrow keys, Return and Escape were consumed
/// by the field, and `.onKeyPress` handlers on every ancestor stayed silent. That is
/// not a bug to work around at the SwiftUI level — a text field is *supposed* to own
/// the arrow keys — so the interception has to happen before AppKit dispatches.
///
/// **Scoped to one window on purpose.** A local monitor is app-wide, so without the
/// `event.window` check two open pickers would both move their cursor on one key press.
struct WindowKeyMonitor: NSViewRepresentable {
    /// Returns true to consume the event, false to let it reach the first responder.
    var handler: (NSEvent) -> Bool

    func makeNSView(context: Context) -> MonitorView {
        MonitorView()
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        // Refreshed every body pass: the handler closes over SwiftUI state, so a
        // stale copy would read stale values.
        view.handler = handler
    }

    static func dismantleNSView(_ view: MonitorView, coordinator: ()) {
        view.stopMonitoring()
    }

    final class MonitorView: NSView {
        var handler: ((NSEvent) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { stopMonitoring() } else { startMonitoring() }
        }

        private func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                return self.handler?(event) == true ? nil : event
            }
        }

        /// Called from both `viewDidMoveToWindow` and `dismantleNSView`, because a
        /// removed representable does not reliably get one without the other — and a
        /// `deinit` cannot help here, `NSView` being main-actor isolated.
        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
