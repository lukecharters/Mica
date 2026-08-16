// Views/Controls/AdvancedControlsToolbarToggle.swift
import SwiftUI

/// The advanced-controls switch, as a toolbar toggle button.
///
/// A `Toggle` rather than a menu of Show/Hide: it is a boolean, and a toolbar draws a
/// Toggle with a pressed state, so it reads its own value and costs one click. This
/// is the third surface for the same flag — View ▸ Show Advanced Controls and
/// Settings ▸ General are the others — and it owns its `@AppStorage` rather than
/// taking a binding, so nothing has to be threaded through `ContentView.body`.
/// (That matters here: `ToolbarContent` is not a `View`, so `IconWindowToolbar`
/// cannot hold dynamic property wrappers of its own.)
///
/// It does not carry the folding behaviour that follows switching the flag *off*:
/// `InspectorControls` observes the key and calls `resetToSimpleControls()`, however
/// the flag was changed.
///
/// It shared a file with the two generation-mode menus until 2026-08-16, when those
/// went back to the inspector as `GroupModePicker`. This one stays: unlike the
/// generation mode, it is a preference about the inspector rather than a property of
/// the icon, and it deliberately does not live in the panel it reconfigures.
struct AdvancedControlsToolbarToggle: View {
    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    var body: some View {
        Toggle(isOn: $advancedControlsEnabled) {
            Label("Advanced Controls", systemImage: "slider.horizontal.3")
        }
        .help("Show advanced controls")
    }
}

#Preview("Advanced controls toggle") {
    AdvancedControlsToolbarToggle()
        .padding()
}
