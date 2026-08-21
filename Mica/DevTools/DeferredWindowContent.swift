// DevTools/DeferredWindowContent.swift
//
// Defers a DevTools window's content until the window is actually shown.
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
// Debug builds only because Release excludes DevTools.
//
// Wrapping the content moves that cost to the moment the tool window opens.
// Keep the closure non-capturing at the call site so the wrapper diffs cheaply.
import SwiftUI

struct DeferredWindowContent<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}
