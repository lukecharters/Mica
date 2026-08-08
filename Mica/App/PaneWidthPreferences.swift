// App/PaneWidthPreferences.swift
//
// The two side panes' widths: where each opens, which one Mica persists, and why
// it is only one. Item C5 of the Mac-conventions plan, 2026-08-07.
//
// `layout.sidebarWidth` and `layout.inspectorWidth` predate the
// `NavigationSplitView` migration and were **read and never written**, under a
// comment describing a divider drag that wrote them. Two dead keys and a comment
// that lied about them. The plan offered deleting both or wiring the write-back;
// measuring on screen said **one of each**, which neither option anticipated.
//
// **The sidebar was never Mica's to persist, and already worked.** A
// `NavigationSplitView` sidebar is an `NSSplitView` underneath with autosaving on,
// so AppKit stores the divider itself — as
// `"NSSplitView Subview Frames …, SidebarNavigationSplitView"` in the same
// preference file — and restores it before SwiftUI's `ideal:` is consulted.
// Measured 2026-08-07, seeding `layout.sidebarWidth = 350` and relaunching:
//
// | AppKit's autosave entry | Sidebar opens at |
// |---|---|
// | present (`273.000000`) | **272pt** — `ideal:` ignored outright |
// | deleted | 350pt — `ideal:` honoured, and AppKit writes a fresh entry |
//
// So a sidebar preference is a *second* mechanism that loses every argument with
// the first, and the width it would have restored is already restored. That is why
// `Pane.sidebar.preferenceKey` is nil rather than a key nobody reads, and why the
// sidebar carries no `.reportsPaneWidth`. **Don't add one back** — it would be
// dead the moment the user drags the divider once, which is the only moment it
// would matter.
//
// **The inspector genuinely needed it.** `.inspector` is not that split view and
// has no autosave of its own: it takes its width from `ideal:` at every launch, so
// a dragged width survived a mode switch and nothing else. Measured on the same
// build — drag the divider to the 460 maximum, quit, relaunch, and the inspector
// comes back at 460 where it used to come back at 380.
//
// **Two feedback loops decided the rest of this file's shape.**
//
// 1. **A pane's stored width must not be a live input to its own layout.**
//    `ideal:` is a layout proposal, so a value that changes while the user drags
//    is a value fighting the drag. `launchWidth` is read **once per window, in
//    `init`**, into a stored `let` — never an `@AppStorage` the body observes.
// 2. **What is written must be what comes back as `ideal:`.** Otherwise a constant
//    offset between the two compounds at every launch and walks the pane to `min`
//    over a few sessions. Measured: they agree. The visible divider sits ~7pt
//    outside the observed content width, but that offset is on the far side of
//    both — seeding 350 opened the sidebar's divider at 357 and rewrote nothing,
//    and the inspector's 460 reopened at 460. `theRoundTripIsStable` is the same
//    claim as arithmetic.
//
// Writes go straight to `UserDefaults` rather than through an `@AppStorage`
// deliberately: an observed property would invalidate `ContentView.body` on every
// frame of a divider drag, and nothing in the window needs to watch a value it
// only ever emits.

import Foundation

enum PaneWidthPreferences {

    /// A resizable side pane: its bounds, where it opens absent a preference, and
    /// whether Mica is the thing that remembers it.
    ///
    /// The range lives here rather than beside the `min:`/`max:` at the call site
    /// so the clamp `widthToPersist` applies and the bounds the column enforces
    /// cannot drift apart — a stored width outside the column's range is one that
    /// can never be reached again.
    enum Pane: String, CaseIterable {
        case sidebar
        case inspector

        /// Where this pane's width is stored, or **nil when something else owns
        /// it**. See the file header: AppKit's `NSSplitView` autosave persists the
        /// sidebar and overrides `ideal:`, so a Mica key for it would be a second
        /// mechanism that always loses.
        var preferenceKey: String? {
            switch self {
            case .sidebar:   nil
            case .inspector: "layout.inspectorWidth"
            }
        }

        var range: ClosedRange<Double> {
            switch self {
            case .sidebar:   220...360
            case .inspector: 330...460
            }
        }

        /// Where the pane opens with nothing stored — which for the sidebar is
        /// every launch until AppKit has autosaved a divider, and thereafter never.
        var defaultWidth: Double {
            switch self {
            case .sidebar:   280
            case .inspector: 380
            }
        }
    }

    /// Widths closer together than this are the same width.
    ///
    /// A divider drag lands on fractional points and a layout pass can re-report a
    /// width it has already reported, so an exact comparison would write on frames
    /// where nothing moved. Half a point is below anything a user can express and
    /// well above the jitter.
    static let tolerance: Double = 0.5

    // MARK: - The decisions, as pure functions

    /// The width to store for an observed pane width, or nil to leave the stored
    /// value alone.
    ///
    /// Three ways an observation is not a resize, and all three arrive from a
    /// `GeometryReader` in normal use:
    ///
    /// - **Zero, or not finite.** A pane reports zero width while it is torn down
    ///   and on the first frame of a hide animation. Persisting that would store a
    ///   width the user can never restore, and it is the failure that makes naive
    ///   width persistence infamous: hide the pane, quit, and it comes back 0pt
    ///   wide forever.
    /// - **Outside the pane's range.** Not reachable by dragging, but reachable
    ///   from a build whose range was wider — clamped rather than dropped, so an
    ///   old preference is corrected the first time the window is resized rather
    ///   than left to be silently ignored at every launch.
    /// - **Unchanged.** See `tolerance`.
    static func widthToPersist(
        observed: Double,
        stored: Double,
        range: ClosedRange<Double>,
        tolerance: Double = PaneWidthPreferences.tolerance
    ) -> Double? {
        guard observed.isFinite, observed > 0 else { return nil }
        let clamped = min(max(observed, range.lowerBound), range.upperBound)
        guard abs(clamped - stored) >= tolerance else { return nil }
        return clamped
    }

    /// The width a pane should open at, given whatever is in the preference.
    ///
    /// Absent (`0`, which is what `UserDefaults.double(forKey:)` returns for a key
    /// that was never written) or unusable falls back to the pane's default; a
    /// usable value is clamped into range, so narrowing a pane's bounds in a later
    /// build cannot strand a window outside them.
    static func launchWidth(
        stored: Double,
        range: ClosedRange<Double>,
        fallback: Double
    ) -> Double {
        guard stored.isFinite, stored > 0 else { return fallback }
        return min(max(stored, range.lowerBound), range.upperBound)
    }

    // MARK: - The preference store

    /// The width to open `pane` at in a new window.
    ///
    /// A pane Mica does not persist opens at its default, every time — which for
    /// the sidebar is right, because AppKit has already restored the real width by
    /// the time this value is used, or there is no real width to restore yet.
    static func launchWidth(_ pane: Pane, defaults: UserDefaults = .standard) -> Double {
        guard let key = pane.preferenceKey else { return pane.defaultWidth }
        return launchWidth(
            stored: defaults.double(forKey: key),
            range: pane.range,
            fallback: pane.defaultWidth
        )
    }

    /// Record an observed width for `pane`, if it is one worth recording.
    ///
    /// Returns what was written, or nil when nothing was — including for a pane
    /// with no key of its own, which cannot be written at all.
    @discardableResult
    static func persist(
        observed: Double,
        for pane: Pane,
        defaults: UserDefaults = .standard
    ) -> Double? {
        guard let key = pane.preferenceKey else { return nil }
        guard let width = widthToPersist(
            observed: observed,
            stored: defaults.double(forKey: key),
            range: pane.range
        ) else { return nil }
        defaults.set(width, forKey: key)
        return width
    }
}
