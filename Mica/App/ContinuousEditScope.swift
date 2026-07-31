// App/ContinuousEditScope.swift
//
// How a continuous control says that the run of changes it is about to make is *one*
// edit, so undo steps over the whole gesture rather than frame by frame.
//
// It goes through the environment rather than the view model because the inspector
// sections take nothing but `@Binding var iconSettings` — they are deliberately
// ignorant of undo, and threading a view model into them to report gesture boundaries
// would undo that. A no-op default also means a section still works in a preview, or
// anywhere else there is no undo manager to tell.
//
// Only controls whose gesture has a beginning and an end need this. Everything else
// is handled centrally: a run of rapid changes to the *same* setting coalesces on a
// time window (see `IconViewModel+Undo.swift`), which is what covers the colour
// panel, whose drag SwiftUI reports no boundaries for at all.

import SwiftUI

/// Gesture boundaries for one continuous edit. Defaults to doing nothing, so a view
/// that reports them is safe to use anywhere.
struct ContinuousEditScope {
    /// Called when the gesture starts. Calling it again while one is already live is
    /// ignored, so a `DragGesture.onChanged` may call it on every frame.
    ///
    /// `name` overrides the undo action name for the whole gesture. Pass one when the
    /// gesture writes more than one setting — the badge drag writes both offsets, so
    /// the diff can only report a generic "Change Settings" and "Move Badge" is the
    /// truth. Pass `nil` for a single-setting control such as a slider and the change
    /// will name itself.
    var begin: (_ name: String?) -> Void = { _ in }

    /// Called when the gesture ends. Safe to call without a matching `begin`.
    var end: () -> Void = {}

    /// `Slider(onEditingChanged:)` in the shape it wants. Sliders always drive a single
    /// setting, so the name comes from the diff.
    var sliderEditing: (Bool) -> Void {
        { editing in editing ? begin(nil) : end() }
    }
}

extension EnvironmentValues {
    /// Set by `ContentView`; a no-op everywhere else.
    @Entry var continuousEdit = ContinuousEditScope()
}
