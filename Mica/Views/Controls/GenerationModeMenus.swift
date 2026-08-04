// Views/Controls/GenerationModeMenus.swift
import SwiftUI

/// Views-layer display metadata for `GenerationMode` (kept out of the shared model
/// so the CLI doesn't carry UI strings).
extension GenerationMode {
    var label: String {
        switch self {
        case .mica: "Mica"
        case .system: "System"
        }
    }
}

/// Views-layer toolbar metadata for `IconLayerGroup`. `label` itself lives on the
/// model in `App/LayerSelection.swift`, which the sidebar reads too.
extension IconLayerGroup {
    /// Distinguishes the two toolbar menus at a glance: a plain app tile against the
    /// same tile wearing a badge.
    var toolbarSymbolName: String {
        switch self {
        case .icon: "app"
        case .badge: "app.badge"
        }
    }
}

/// One group's generation-mode menu, shown in the window toolbar.
///
/// Mica vs System for the icon and for the badge are independent — each group is
/// rendered by its own pipeline — so there are two of these rather than one control.
/// They sat at the top of each group's inspector pane as a `FillingSegmentedPicker`
/// until 2026-08-04; the toolbar shows both at once and does not depend on which
/// group the sidebar has selected, which is the point of the move.
///
/// The label reports the current mode, so a glance at the toolbar answers "what am I
/// generating?" without opening anything. Its titles are `Text(verbatim:)` because
/// "Mica" is a product name rather than prose.
struct GenerationModeMenu: View {
    let group: IconLayerGroup
    @Binding var isSystem: Bool

    private var mode: GenerationMode { isSystem ? .system : .mica }

    var body: some View {
        Menu {
            // `Section` for the header and `Toggle` rows for the checkmark gutter —
            // a bare `Text` as a menu's first row is a *disabled item*, not a
            // header, and a `Button` gets no checkmark to say which mode is live.
            // Same spelling as `PreviewSizeMenuContent`.
            Section("\(group.label) Generation Mode") {
                ForEach(GenerationMode.allCases) { candidate in
                    Toggle(isOn: binding(for: candidate)) {
                        Text(verbatim: candidate.label)
                    }
                }
            }
        } label: {
            Label {
                Text(verbatim: "\(mode.label)")
            } icon: {
                Image(systemName: group.toolbarSymbolName)
            }
        }
        // A toolbar `Menu` shows its `Label`'s icon alone by default; the mode is
        // the whole reason this label exists, so ask for both.
        .labelStyle(.titleAndIcon)
        .help("\(group.label) generation mode")
    }

    /// The two modes are mutually exclusive and one is always current, so switching a
    /// row *off* is meaningless and ignored — matching `ZoomMenu`'s rungs.
    private func binding(for candidate: GenerationMode) -> Binding<Bool> {
        Binding(
            get: { mode == candidate },
            set: { if $0 { isSystem = (candidate == .system) } }
        )
    }
}

/// The advanced-controls switch, as a toolbar toggle button.
///
/// A `Toggle` rather than a menu of Show/Hide: it is a boolean, and a toolbar draws a
/// Toggle with a pressed state, so it reads its own value and costs one click. This
/// is the third surface for the same flag — View ▸ Show Advanced Controls and
/// Settings ▸ General are the others — and it owns its `@AppStorage` rather than
/// taking a binding, so nothing has to be threaded through `ContentView.body`.
///
/// It does not carry the folding behaviour that follows switching the flag *off*:
/// `InspectorControls` observes the key and calls `resetToSimpleControls()`, however
/// the flag was changed.
struct AdvancedControlsToolbarToggle: View {
    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    var body: some View {
        Toggle(isOn: $advancedControlsEnabled) {
            Label("Advanced Controls", systemImage: "slider.horizontal.3")
        }
        .help("Show advanced controls")
    }
}

#Preview("Generation mode menus") {
    @Previewable @State var iconIsSystem = false
    @Previewable @State var badgeIsSystem = true
    HStack {
        GenerationModeMenu(group: .icon, isSystem: $iconIsSystem)
        GenerationModeMenu(group: .badge, isSystem: $badgeIsSystem)
        AdvancedControlsToolbarToggle()
    }
    .padding()
}
