// Views/Sidebar/SidebarColumn.swift
import SwiftUI

/// The whole sidebar column: a selector bar, and beneath it either the layer list or
/// the preset library.
///
/// ## Why the column has two modes rather than the presets having their own pane
///
/// The presets library was a slide-out pane in the *detail* column until 2026-08-31 —
/// see the history in `PresetList`. Moving it here buys the sidebar's real material
/// and gives the canvas its full width back, and it keeps the preset library and the
/// inspector's controls **visible at the same time**, which is the shape of the actual
/// workflow: apply a preset, then adjust it. A third `InspectorTab` was the other
/// candidate and loses exactly that — it would put the library and the controls in the
/// same real estate and make apply-then-adjust a tab flip each way.
///
/// ## The selector is a bar, not a back button
///
/// A row that pushes the sidebar to a second screen with a back chevron is the
/// iPadOS navigation-stack pattern. The Mac pattern for "this sidebar shows a
/// different thing" is a selector bar at the top of the column — Xcode's navigator —
/// and per `FillingSegmentedPicker` those bars are `NSSegmentedControl` with
/// `role: .tabs`, which is the control this project already has. Two segments, both
/// always reachable in one click, and no hidden second level.
///
/// ## What does *not* change with the mode
///
/// The layer selection. `selectedGroup` and the two `LayerTab`s live in `ContentView`,
/// and `LayerSidebar` is only a projection of them — so switching this column to
/// Presets leaves the inspector pointed where it was, the canvas outlining what it
/// was, and a canvas click still writing the same pair. Nothing downstream can tell
/// the difference. That is the property that made this shape cheap, and it is why
/// `SidebarMode` is its own state rather than a case on `LayerSidebarRow`.
struct SidebarColumn: View {
    @Binding var mode: SidebarMode

    // The layer list's half.
    @Binding var iconSettings: IconSettings
    @Binding var selection: IconLayerGroup
    @Binding var iconTab: LayerTab
    @Binding var badgeTab: LayerTab
    var onPointer: ((PreviewPointer) -> Void)? = nil

    // The preset library's half.
    let presets: [ResolvedPreset]
    let onApplyPreset: (MicaPreset) -> Void
    let onSavePreset: (PresetScope) -> Void
    let onDeletePreset: (MicaPreset) -> Void
    /// Re-read the user presets directory. Called when the library appears rather
    /// than from an `.onChange` in `ContentView.body`, which sits at the
    /// type-checker's ceiling — and reading the directory from a `body` would touch
    /// the filesystem on every view update.
    let onPresetsAppear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SidebarSelector(mode: $mode)
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .layers:
            LayerSidebar(
                iconSettings: $iconSettings,
                selection: $selection,
                iconTab: $iconTab,
                badgeTab: $badgeTab,
                onPointer: onPointer
            )
        case .presets:
            PresetList(
                iconSettings: iconSettings,
                presets: presets,
                onApply: onApplyPreset,
                onSave: onSavePreset,
                onDelete: onDeletePreset
            )
            .onAppear(perform: onPresetsAppear)
        }
    }
}

// MARK: - The selector bar

/// Two segments at the top of the sidebar column, filling its width.
///
/// `role: .tabs` because these are two views of the column rather than two values of
/// a setting — on macOS 27 that draws the neutral raised pill instead of the accent
/// fill, which is what Xcode's navigator selector looks like. `FillingSegmentedPicker`
/// rather than `.pickerStyle(.tabs)` for the reason recorded on that type: a SwiftUI
/// picker cannot be stretched, so the tabs style would render ~156pt wide in a 280pt
/// column. Don't swap it.
///
/// **Glyphs, not words.** Two segments across a 220–360pt column left each label
/// floating in far more room than it needed, and the words competed with the section
/// headers immediately below them. `SidebarMode.label` still carries the text — it is
/// the accessibility description and the tooltip, which are now the only things that
/// name a segment.
private struct SidebarSelector: View {
    @Binding var mode: SidebarMode

    var body: some View {
        FillingSegmentedPicker(
            segments: SidebarMode.allCases.map {
                .init($0.label, systemImage: $0.systemImage, value: $0)
            },
            selection: $mode,
            accessibilityLabel: "Sidebar",
            role: .tabs
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

#Preview {
    @Previewable @State var mode: SidebarMode = .layers
    @Previewable @State var settings = IconSettings()
    @Previewable @State var selection: IconLayerGroup = .icon
    @Previewable @State var iconTab: LayerTab = .foreground
    @Previewable @State var badgeTab: LayerTab = .layout
    SidebarColumn(
        mode: $mode,
        iconSettings: $settings,
        selection: $selection,
        iconTab: $iconTab,
        badgeTab: $badgeTab,
        presets: ResolvedPreset.resolve(PresetCatalog.builtIn),
        onApplyPreset: { _ in },
        onSavePreset: { _ in },
        onDeletePreset: { _ in },
        onPresetsAppear: {}
    )
    .frame(width: 280, height: 600)
}


