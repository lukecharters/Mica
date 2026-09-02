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
/// Three groups:
///
/// | Placement | Holds | Because |
/// |---|---|---|
/// | `.principal` (centre) | Zoom and preview size | How the canvas is looked at |
/// | `.principal` (centre) | Icon Presets, Badge Presets | What can be applied to it |
/// | `.automatic` (trailing) | Advanced controls, inspector tab, inspector toggle | The inspector's own controls |
///
/// **Nothing sits at `.navigation`.** Items there push the window title to their right —
/// measured 2026-08-04 and still true — so that placement is reserved for actual
/// navigation controls, and this app has none. The preset buttons are not navigation:
/// they open a library that acts on the canvas, so they sit with the canvas's other
/// controls at `.principal`. **Anything whose subject is the canvas or the inspector
/// belongs at `.principal` or `.automatic`.**
struct IconWindowToolbar: ToolbarContent {
    @Binding var zoomLevel: Double
    @Binding var previewPointSize: CGFloat?
    @Binding var inspectorTab: InspectorTab
    @Binding var showInspector: Bool

    // The preset popovers' half. `iconSettings` is read for one thing — whether each
    // scope can be captured — and the closures are the window's, so an apply lands in
    // this window with this window's undo manager.
    let iconSettings: IconSettings
    let onApplyPreset: (MicaPreset) -> Void
    let onSavePreset: (PresetScope) -> Void
    let onDeletePreset: (MicaPreset) -> Void
    let onPresetsAppear: () -> Void

    var body: some ToolbarContent {
        // How the canvas is looked at. *What* is generated is the group's Mica/System
        // picker, which is back at the top of that group's inspector pane — it sits
        // with the controls it reshapes, and `InspectorGroupHeader` above it names the
        // group, so showing one group at a time is unambiguous.
        ToolbarItemGroup(placement: .principal) {
            ZoomMenu(zoomLevel: $zoomLevel)
            PreviewSizeMenu(previewPointSize: $previewPointSize)
        }

        // What can be applied to the canvas: one popover per scope, in one group so
        // they read as a cluster the way the iWork insert buttons do. Each button owns
        // its popover — see `PresetsToolbarButton`.
        ToolbarItemGroup(placement: .principal) {
            ForEach(PresetScope.allCases) { scope in
                PresetsToolbarButton(
                    scope: scope,
                    iconSettings: iconSettings,
                    onApply: onApplyPreset,
                    onSave: onSavePreset,
                    onDelete: onDeletePreset,
                    onPresetsAppear: onPresetsAppear
                )
            }
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
