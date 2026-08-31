// Views/IconWindowToolbar.swift
import SwiftUI

/// The icon window's toolbar, as a `ToolbarContent` type rather than an inline
/// `.toolbar { … }` block.
///
/// **This exists because `ContentView.body` does not compile otherwise.** Adding two
/// generation-mode menus inline failed the build with "the compiler is unable to
/// type-check this expression in reasonable time" — the same wall the configuration
/// dialogs, a fourth inline alert binding, and the View menu's four
/// `.focusedSceneValue`s each hit. Every fix has been the same shape: move the
/// expression out. **Those menus are gone** — the generation mode went back to the
/// inspector on 2026-08-16 — but this type stays: it is the shape Apple's SwiftUI
/// guidance asks for, and it is the reason `body` has headroom. Anything else the
/// toolbar grows should join this struct rather than go back inline.
///
/// It holds no state of its own. `ToolbarContent` is not a `View`, so dynamic
/// property wrappers are not dependable here — `AdvancedControlsToolbarToggle` reads
/// its own `@AppStorage` from inside a real view instead, and everything else arrives
/// as a binding.
///
/// Two regions:
///
/// | Placement | Holds | Because |
/// |---|---|---|
/// | `.principal` (centre) | Zoom and preview size | How the canvas is looked at |
/// | `.automatic` (trailing) | Advanced controls, inspector tab, inspector toggle | The inspector's own controls |
///
/// **Nothing sits at `.navigation`, and that is the standing rule again.** Items there
/// push the window title to their right — measured 2026-08-04 and still true. A presets
/// `Toggle` was the one deliberate exception between 2026-08-30 and 2026-08-31, on the
/// grounds that the pane it opened was at the leading edge. It went when the library
/// moved into the sidebar column and grew its own selector bar: the toolbar control was
/// then a second surface on the same state, sitting beside AppKit's sidebar toggle and
/// costing the title its position for a switch already visible a few points below it.
/// ⌃⌘P still reaches the library, and it still reveals a hidden column. **Anything whose
/// subject is the canvas or the inspector belongs at `.principal` or `.automatic`.**
struct IconWindowToolbar: ToolbarContent {
    @Binding var zoomLevel: Double
    @Binding var previewPointSize: CGFloat?
    @Binding var inspectorTab: InspectorTab
    @Binding var showInspector: Bool

    var body: some ToolbarContent {
        // How the canvas is looked at. *What* is generated is the group's Mica/System
        // picker, which is back at the top of that group's inspector pane — it sits
        // with the controls it reshapes, and `InspectorGroupHeader` above it names the
        // group, so showing one group at a time is unambiguous.
        ToolbarItemGroup(placement: .principal) {
            ZoomMenu(zoomLevel: $zoomLevel)
            PreviewSizeMenu(previewPointSize: $previewPointSize)
        }

        // Trailing, beside the inspector's own two controls — the flag changes what
        // that panel contains, so it belongs with them rather than with the canvas.
        ToolbarItem(placement: .automatic) {
            AdvancedControlsToolbarToggle()
        }

        ToolbarItem(placement: .automatic) {
            Picker("Styling/Export", selection: $inspectorTab) {
                Label("Controls", systemImage: InspectorTab.controls.systemImage)
                    .tag(InspectorTab.controls)
                Label("Export", systemImage: InspectorTab.export.systemImage)
                    .tag(InspectorTab.export)
            }
            .pickerStyle(.segmented)
            .help("Inspector tab")
            // Selecting a tab reveals the inspector if it's hidden.
            .onChange(of: inspectorTab) {
                if !showInspector { showInspector = true }
            }
        }

        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showInspector.toggle()
            } label: {
                Label("Show Inspector", systemImage: "sidebar.right")
            }
            .help("Toggle Inspector")
        }
    }
}
