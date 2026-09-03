// Views/IconWindowToolbar.swift
import SwiftUI

/// The icon window's toolbar, as a `CustomizableToolbarContent` type rather than an
/// inline `.toolbar { … }` block.
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
/// **Two halves, attached in two places, one toolbar id.** This type holds the canvas
/// half and `ContentView` attaches it to the detail column; `InspectorToolbar` below
/// holds the inspector half and is attached to the inspector's *content*. That is what
/// gives the window Pages' layout: AppKit inserts a tracking separator at the inspector
/// divider, the inspector items lay out in their own section — Export at its leading
/// edge, the controls at its trailing edge, a flexible spacer between — and they stay
/// in the toolbar when the inspector is hidden. Attaching one toolbar to the
/// `NavigationSplitView` after `.inspector` gets none of this: every `ToolbarSpacer`
/// in the trailing run is dropped and the buttons share one glass capsule (measured
/// 2026-09-03, macOS 27, in a three-window reproduction outside Mica).
///
/// | Half | Placement | Holds | Because |
/// |---|---|---|---|
/// | canvas | `.principal` (centre) | Icon Presets, Badge Presets | What can be applied to the canvas |
/// | canvas | `.principal` (centre) | Preview size and zoom | How the canvas is looked at |
/// | inspector | leading | Export | What is done with the result, where Pages keeps Share |
/// | inspector | trailing | Advanced controls, inspector tab, inspector toggle | The inspector's own controls |
///
/// **Nothing sits at `.navigation`.** Items there push the window title to their right —
/// measured 2026-08-04 and still true — so that placement is reserved for actual
/// navigation controls, and this app has none. The preset buttons are not navigation:
/// they open a library that acts on the canvas, so they sit with the canvas's other
/// controls at `.principal`. **Anything whose subject is the canvas or the inspector
/// belongs at `.principal` or `.automatic`.**
///
/// **Every item carries an id, and `ContentView` installs this with `.toolbar(id:)`.**
/// That is what makes the toolbar an AppKit toolbar that autosaves its configuration,
/// and the display mode — Icon and Text or Icon Only, chosen from the toolbar's
/// context menu — is part of that configuration. A toolbar without an id forgets the
/// choice on every launch. The ids and the toolbar's own id are UserDefaults keys
/// (`NSToolbar Configuration <id>`), so renaming one silently resets a user's toolbar.
struct IconWindowToolbar: CustomizableToolbarContent {
    @Binding var zoomLevel: Double
    @Binding var previewPointSize: CGFloat?

    // The preset popovers' half. `iconSettings` is read for one thing — whether each
    // scope can be captured — and the closures are the window's, so an apply lands in
    // this window with this window's undo manager.
    let iconSettings: IconSettings
    let onApplyPreset: (MicaPreset) -> Void
    let onSavePreset: (PresetScope) -> Void
    let onDeletePreset: (MicaPreset) -> Void
    let onPresetsAppear: () -> Void

    var body: some CustomizableToolbarContent {
        // How the canvas is looked at. *What* is generated is the group's Mica/System
        // picker, which is back at the top of that group's inspector pane — it sits
        // with the controls it reshapes, and `InspectorGroupHeader` above it names the
        // group, so showing one group at a time is unambiguous.
        // What can be applied to the canvas: one popover per scope, side by side so
        // they read as a cluster the way the iWork insert buttons do. Each button owns
        // its popover — see `PresetsToolbarButton`.
        ToolbarItem(id: "iconPresets", placement: .principal) {
            presetsButton(for: .icon)
        }
        ToolbarItem(id: "badgePresets", placement: .principal) {
            presetsButton(for: .badge)
        }
        ToolbarItem(id: "previewSize", placement: .principal) {
            PreviewSizeMenu(previewPointSize: $previewPointSize)
        }
        ToolbarItem(id: "zoom", placement: .principal) {
            ZoomMenu(zoomLevel: $zoomLevel)
        }
    }

    private func presetsButton(for scope: PresetScope) -> some View {
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

/// The inspector half of the window toolbar; see `IconWindowToolbar` for why it is a
/// separate type attached to the inspector's content.
struct InspectorToolbar: CustomizableToolbarContent {
    @Binding var inspectorTab: InspectorTab
    @Binding var showInspector: Bool

    // The same flag and the same gate as File ▸ Export as PNG… (⇧⌘E), so the two can
    // never disagree about whether there is an icon to save.
    @Binding var showExportDialog: Bool
    let canExport: Bool

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "export", placement: .automatic) {
            Button {
                showExportDialog = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export as PNG")
            .disabled(!canExport)
        }

        if #available(macOS 26.0, *) {
            ToolbarSpacer(.flexible)
        }

        // The flag changes what the inspector contains, so it sits with the
        // inspector's own two controls rather than beside Export.
        ToolbarItem(id: "advancedControls", placement: .automatic) {
            AdvancedControlsToolbarToggle()
        }

        ToolbarItem(id: "inspectorTab", placement: .automatic) {
            Picker("Format  Document", selection: $inspectorTab) {
                Label("Format", systemImage: InspectorTab.controls.systemImage)
                    .tag(InspectorTab.controls)
                Label("Document", systemImage: InspectorTab.export.systemImage)
                    .tag(InspectorTab.export)
            }
            .pickerStyle(.segmented)
            .help("Select Format or Document tab")
            // Selecting a tab reveals the inspector if it's hidden.
            .onChange(of: inspectorTab) {
                if !showInspector { showInspector = true }
            }
        }

        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed)
        }

        ToolbarItem(id: "inspector", placement: .automatic) {
            Button {
                showInspector.toggle()
            } label: {
                Label("Show/Hide Inspector", systemImage: "sidebar.right")
            }
            .help("Show or hide Inspector")
        }
    }
}
