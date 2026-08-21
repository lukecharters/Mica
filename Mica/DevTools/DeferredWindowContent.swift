// DevTools/DeferredWindowContent.swift
//
// Wraps every developer tool's window content, and does two jobs.
//
// **1. Defers the content until the window is actually shown.**
//
// A `Window` scene runs its content closure — and therefore the content view's
// `init` — on every evaluation of `MicaApp.body`, even while the window has
// never been opened. Only `body` waits for the window. The App body re-evaluates
// on every focused-scene-value change, which means on every settings edit, and
// on every app activation and first-responder change.
//
// Several tools do real work in `init` (`SymbolCalibrationTool` decodes the
// ~7k-symbol metrics file plus the calibration store; the tools that browse every
// symbol load `sf-symbols.txt`). Measured with Time Profiler on 2026-07-31: ~200 ms of
// main-thread JSON decoding per toggle click in the *document* window, and
// 330–500 ms hangs on activation — the "every control is laggy" bug, present in
// Debug builds only because Release excluded DevTools.
//
// Wrapping the content moves that cost to the moment the tool window opens.
// Keep the closure non-capturing at the call site so the wrapper diffs cheaply.
//
// **2. Gates the content on the developer preference.**
//
// Added 2026-08-21, when the tools started shipping in Release. The menu is
// conditional and the scenes give up their Window-menu items, but neither stops
// **macOS state restoration** from reopening a tool window that was open when the
// preference was last on — measured: relaunched with the preference off and the
// Symbol Calibration window came straight back. `SceneBuilder` accepts no
// conditionals, so the scene cannot be withdrawn; the content can, and this is
// where. It is also the deferral's natural home, since the gate decides whether
// the expensive `init` runs at all.
import SwiftUI

struct DeferredWindowContent<Content: View>: View {
    @AppStorage(DeveloperToolsPreference.enabledKey) private var developerToolsEnabled = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        if developerToolsEnabled {
            content()
        } else {
            // Says what happened and where the switch is. A blank window would
            // read as the tool having crashed on launch.
            ContentUnavailableView {
                Label("Developer Tools Are Off", systemImage: "hammer")
            } description: {
                Text("Turn them on in Settings ▸ Developer to use this window.")
            }
        }
    }
}
