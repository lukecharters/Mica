// App/BadgeModeMemory.swift
import Foundation

/// Remembers the badge's last non-System foreground source, so switching the badge
/// between generation modes returns it to the source the user picked rather than
/// forcing `.symbol` on the way back.
///
/// The badge has no stored `mode`. `BadgeSpec.mode` is *derived* from
/// `foreground.source == .system`, so switching mode means overwriting the source —
/// and the previous value is gone. This is the one piece of state that outlives it.
///
/// A value type rather than a `@State` in the control that drives it, because the
/// control moved: the Mica/System pickers were per-group inspector panes until
/// 2026-08-04 and are now two window-toolbar menus. Keeping the switch out of the
/// view is what lets it be tested (`BadgeModeMemoryTests`) rather than only the
/// view that happens to host it.
struct BadgeModeMemory {
    /// Seeded to the badge's own default, so a badge that *starts* on System still
    /// has somewhere to come back to.
    private(set) var lastNonSystemSource: ForegroundSource = .symbol

    /// Record a source the badge arrived at from anywhere else — the inspector, a
    /// pasted image, a decoded configuration — so the remembered value cannot go
    /// stale while the mode menu sits untouched.
    ///
    /// `.system` is ignored: that is the state we are remembering the way *out* of.
    mutating func observe(_ source: ForegroundSource) {
        if source != .system { lastNonSystemSource = source }
    }

    /// Switch the badge's generation mode.
    ///
    /// Banks the current source on the way *in* rather than trusting `observe` to
    /// have been called, so the value restored is always the one that was on screen.
    mutating func setSystem(_ isSystem: Bool, in settings: inout IconSettings) {
        if isSystem {
            observe(settings.badge.foreground.source)
            settings.badge.foreground.source = .system
        } else {
            settings.badge.foreground.source = lastNonSystemSource
        }
    }
}
