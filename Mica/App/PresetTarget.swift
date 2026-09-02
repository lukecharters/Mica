// App/PresetTarget.swift
//
// Which icon window a preset applied from the Presets window lands on.
//
// The Presets window is a window of its own, so while the user is clicking in it
// no icon window is key and every `FocusedValue` is nil. The rule that replaces
// focus is the Content Hub's: **the last icon window that was key**, held until
// that window closes. Losing key does not withdraw it — that is the whole point —
// and closing a window that is not the target changes nothing.

import SwiftUI

/// The rule, as a value, so `PresetTargetTests` can exercise it without a window.
struct PresetTargetRule<Handle: Identifiable> {
    private(set) var target: Handle?

    mutating func windowBecameKey(_ handle: Handle) {
        target = handle
    }

    mutating func windowClosed(_ id: Handle.ID) {
        if target?.id == id { target = nil }
    }
}

/// What the Presets window needs from an icon window: the model to apply to, and
/// **that window's** undo manager, so ⌘Z in the icon window undoes the apply.
/// `@Environment(\.undoManager)` in a `WindowGroup` is the window's own manager
/// (see `IconViewModel+Undo`); the Presets window's would record the entry on a
/// window with nothing to undo.
@MainActor
struct IconWindowHandle: Identifiable {
    let id: UUID
    let viewModel: IconViewModel
    let undoManager: UndoManager?

    func apply(_ preset: MicaPreset) {
        viewModel.applyPreset(preset, undoManager: undoManager)
    }

    var iconSettings: IconSettings { viewModel.iconSettings }
}

/// The app's one target. Icon windows publish themselves through
/// `PresetTargetPublisher` in `ContentView`; the Presets window reads `handle` and
/// shows its empty state when it is nil.
@MainActor
@Observable
final class PresetTarget {
    static let shared = PresetTarget()

    private var rule = PresetTargetRule<IconWindowHandle>()

    var handle: IconWindowHandle? { rule.target }

    func windowBecameKey(_ handle: IconWindowHandle) {
        rule.windowBecameKey(handle)
    }

    func windowClosed(_ id: UUID) {
        rule.windowClosed(id)
    }
}
