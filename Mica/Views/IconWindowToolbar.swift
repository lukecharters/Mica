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
/// | `.navigation` (leading) | The presets toggle | The pane it opens is the leading one |
/// | `.principal` (centre) | Zoom and preview size | How the canvas is looked at |
/// | `.automatic` (trailing) | Advanced controls, inspector tab, inspector toggle | The inspector's own controls |
///
/// **`.navigation` does push the window title to its right**, measured 2026-08-04 and
/// still true — the title now sits after the sidebar toggle *and* the presets toggle
/// rather than at the leading edge. That ruled the placement out for everything here
/// until the presets pane, which is the first control whose subject is genuinely at
/// the leading edge; it is a deliberate trade of title position for a control that
/// sits over the thing it opens. **Don't take it as a general licence.** Anything
/// whose subject is the canvas or the inspector still belongs at `.principal` or
/// `.automatic`.
struct IconWindowToolbar: ToolbarContent {
    @Binding var zoomLevel: Double
    @Binding var previewPointSize: CGFloat?
    @Binding var inspectorTab: InspectorTab
    @Binding var showInspector: Bool
    @Binding var showPresets: Bool

    var body: some ToolbarContent {
        // How the canvas is looked at. *What* is generated is the group's Mica/System
        // picker, which is back at the top of that group's inspector pane — it sits
        // with the controls it reshapes, and `InspectorGroupHeader` above it names the
        // group, so showing one group at a time is unambiguous.
        ToolbarItemGroup(placement: .principal) {
            ZoomMenu(zoomLevel: $zoomLevel)
            PreviewSizeMenu(previewPointSize: $previewPointSize)
        }

        // Leading, beside AppKit's own sidebar toggle, because the pane it opens is
        // the leading one — it sits over the thing it shows. The cost is the window
        // title moving right by one control; see the note in the header, which is
        // where the trade is recorded.
        //
        // **A `Toggle`, where the inspector button at the far end is a `Button`.**
        // Deliberate rather than an oversight: a toolbar draws a `Toggle` with a
        // pressed state, and the presets pane is *closed* by default — a control that
        // looked identical either way would leave the one pane you might forget you
        // opened unlabelled. The inspector is open by default and visibly occupies a
        // third of the window, so it needs no such tell. Same reasoning as
        // `AdvancedControlsToolbarToggle`, the other Toggle here.
        ToolbarItem(placement: .navigation) {
            Toggle(isOn: $showPresets) {
                Label("Presets", systemImage: "square.grid.2x2")
            }
            .help("Show presets")
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
