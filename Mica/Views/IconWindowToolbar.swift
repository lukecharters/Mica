// Views/IconWindowToolbar.swift
import SwiftUI

/// The icon window's toolbar, as a `ToolbarContent` type rather than an inline
/// `.toolbar { … }` block.
///
/// **This exists because `ContentView.body` does not compile otherwise.** Adding the
/// two generation-mode menus inline failed the build with "the compiler is unable to
/// type-check this expression in reasonable time" — the same wall the configuration
/// dialogs, a fourth inline alert binding, and the View menu's four
/// `.focusedSceneValue`s each hit. Every fix has been the same shape: move the
/// expression out. Anything else the toolbar grows should join this struct rather
/// than go back inline.
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
/// | `.principal` (centre) | Generation mode ×2, then zoom and preview size | Everything about the canvas — what is generated, then how it is looked at |
/// | `.automatic` (trailing) | Advanced controls, inspector tab, inspector toggle | The inspector's own controls |
///
/// **The mode menus are not at `.navigation`**, though leading is where "what am I
/// making" would otherwise belong. Measured 2026-08-04: `.navigation` items push the
/// window title to their right, so the toolbar read `Icon: Mica  Badge: Mica  Mica`
/// — the app's own name landing directly after a menu whose value is also "Mica",
/// where it parses as a third chip. Centring them leaves the title alone at the
/// leading edge, which is where the platform puts it.
struct IconWindowToolbar: ToolbarContent {
    @Binding var iconIsSystem: Bool
    @Binding var badgeIsSystem: Bool
    @Binding var zoomLevel: Double
    @Binding var previewPointSize: CGFloat?
    @Binding var inspectorTab: InspectorTab
    @Binding var showInspector: Bool

    var body: some ToolbarContent {
        // Mode first, then zoom and preview size: what is being generated reads left
        // of how it is being looked at. Both groups show at once and neither depends
        // on the sidebar selection, which is the reason they left the inspector on
        // 2026-08-04.
        ToolbarItemGroup(placement: .principal) {
            GenerationModeMenu(group: .icon, isSystem: $iconIsSystem)
            GenerationModeMenu(group: .badge, isSystem: $badgeIsSystem)
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
