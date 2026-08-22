// Views/Sidebar/LayerSidebar.swift
import SwiftUI

/// Left sidebar: the two objects (Icon, Badge), each with a tri-state visibility
/// toggle, and beneath each one a row per editable layer — Foreground and
/// Background, plus Layout for the badge.
///
/// The child rows were the inspector's `LayerTabPicker` between 2026-07-25 and
/// 2026-08-16. What came back is the *control*, not the state: `ContentView` still
/// owns the selected group and each group's active `LayerTab` as separate values,
/// because a canvas click writes the same pair and `PreviewSelection` reads it.
/// This view projects those onto a `LayerSidebarRow` and writes the projection back.
///
/// The child rows are shown only where the inspector actually divides a group into
/// layers — Mica mode with the advanced controls on. See `LayerTab.sidebarRows`.
/// The Mica/System picker itself stays at the top of the group's inspector pane
/// (`GroupModePicker`).
struct LayerSidebar: View {
    @Binding var iconSettings: IconSettings
    @Binding var selection: IconLayerGroup
    /// Each group's active layer, owned by `ContentView` so a canvas click and this
    /// sidebar drive the same value. Per group rather than one shared tab, so
    /// moving between Icon and Badge returns to where you left each of them.
    @Binding var iconTab: LayerTab
    @Binding var badgeTab: LayerTab
    /// Reports the row under the pointer so the canvas can outline that layer at the
    /// hover weight — the sidebar half of Icon Composer's two-way hover.
    ///
    /// **Hover flows sidebar → canvas only** (D9 of the plan): a canvas hover does
    /// not light a row up here. The canvas already answers "which layer is this", and
    /// a second highlight competing with the selection highlight in one list is
    /// noise.
    ///
    /// Called on every pointer sample rather than on entry and exit, for the same
    /// reason the canvas is: the owner needs the motion itself, because that is what
    /// restarts the outlines' fade. Resting on a row lets them fade; moving within it
    /// brings them back.
    var onPointer: ((PreviewPointer) -> Void)? = nil

    /// Read directly rather than passed in, the way every other reader of this key
    /// does. Nothing threads through `ContentView.body`, which sits at the
    /// type-checker's ceiling.
    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    var body: some View {
        List(selection: selectionBinding) {
            ForEach(IconLayerGroup.allCases) { group in
                Section {
                    GroupRow(
                        group: group,
                        visibility: visibility(for: group),
                        visibilityBinding: groupVisibilityBinding(for: group)
                    )
                    .tag(LayerSidebarRow.group(group))
                    .contextMenu { contextMenu(for: group) }
                    .reportsHover(.group(group), to: onPointer)

                    ForEach(rows(for: group)) { tab in
                        LayerRow(
                            group: group,
                            tab: tab,
                            visibilityBinding: layerVisibilityBinding(for: group, tab: tab)
                        )
                        .tag(LayerSidebarRow.layer(group, tab))
                        // Indent children under their group. `.listRowInsets`
                        // rather than `.padding`: padding insets the row's
                        // *content* and leaves the selection highlight full-width,
                        // so the indent would vanish the moment a row is selected.
                        .listRowInsets(.init(top: 0, leading: Self.childIndent, bottom: 0, trailing: 0))
                        .contextMenu { contextMenu(for: group) }
                        .reportsHover(.layer(group, tab), to: onPointer)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    /// Leading inset on a layer row.
    ///
    /// **Measured off the labels, not the glyph columns.** Both rows reserve the
    /// same 36pt glyph box (see `LayerRow.glyphBox`), so whatever this is, it is
    /// also the gap between a group's name and its layers' names — 28pt, which is
    /// what the indent was worth when layer rows were half the height and used a
    /// 20pt box. Aligning the two glyph *columns* instead would be an indent of
    /// zero, since the boxes are now the same width.
    private static let childIndent: CGFloat = 36

    /// The group's menu, offered from its layer rows too.
    ///
    /// Every row in a section is a way of pointing at that group, and the menu's
    /// rows name the layer they act on ("Remove Background Image"), so which row
    /// was right-clicked adds nothing. Attached at the call site rather than inside
    /// the row views — as the hover reporting is, for the same reason — so those
    /// keep taking only the values they draw. See
    /// `IconContextMenu.sidebarItems`, which is deliberately not a copy of the
    /// canvas menu.
    @ViewBuilder
    private func contextMenu(for group: IconLayerGroup) -> some View {
        IconContextMenuContent(
            settings: $iconSettings,
            items: IconContextMenu.sidebarItems(for: group, settings: iconSettings)
        )
    }

    // MARK: - Selection

    /// `List` single-selection wants a `Binding<LayerSidebarRow?>`. Bridge from the
    /// group + tab pair `ContentView` owns, ignoring nils so the sidebar always
    /// keeps a selection (clicking empty space never deselects).
    ///
    /// **Clicking a group row resolves to that group's active layer**, which is why
    /// the setter writes only the group and the getter decides the rest: with child
    /// rows showing there is no separate "the group itself" state for the inspector
    /// to be in, so a parent click lands on the layer the group was last left on
    /// (its `defaultTab` until the user moves it). The highlight follows to the
    /// child row, which is the visible half of the same answer.
    private var selectionBinding: Binding<LayerSidebarRow?> {
        Binding(
            get: { currentRow },
            set: { row in
                guard let row else { return }
                selection = row.group
                guard let tab = row.tab else { return }
                switch row.group {
                case .icon:  iconTab = tab
                case .badge: badgeTab = tab
                }
            }
        )
    }

    /// Which row is highlighted. The rule is `LayerSidebarRow.selected`, kept out
    /// here as a pure function because it is the half of the parent-click behaviour
    /// no view test could reach.
    private var currentRow: LayerSidebarRow {
        LayerSidebarRow.selected(
            group: selection,
            activeTab: activeTab(for: selection),
            rows: rows(for: selection)
        )
    }

    private func activeTab(for group: IconLayerGroup) -> LayerTab {
        switch group {
        case .icon:  return iconTab
        case .badge: return badgeTab
        }
    }

    private func rows(for group: IconLayerGroup) -> [LayerTab] {
        LayerTab.sidebarRows(
            for: group,
            isSystem: isSystem(group),
            advancedControlsEnabled: advancedControlsEnabled
        )
    }

    // MARK: - Per-group helpers

    private func isSystem(_ group: IconLayerGroup) -> Bool {
        switch group {
        case .icon:  return iconSettings.icon.mode == .system
        case .badge: return iconSettings.badge.mode == .system
        }
    }

    private func visibility(for group: IconLayerGroup) -> LayerGroupVisibility {
        switch group {
        case .icon:  return iconSettings.icon.visibility
        case .badge: return iconSettings.badge.visibility
        }
    }

    /// Group-eye toggle behavior: any layer visible (`.on` or `.mixed`) → click
    /// hides all; everything hidden → click shows all. Must stay consistent
    /// with `GroupVisibilityToggle`'s tooltips.
    private func groupVisibilityBinding(for group: IconLayerGroup) -> Binding<Bool> {
        switch group {
        case .icon:
            return Binding(
                get: { iconSettings.icon.visibility != .off },
                set: { iconSettings.icon.isHidden = !$0 }
            )
        case .badge:
            return Binding(
                get: { iconSettings.badge.visibility != .off },
                set: { iconSettings.badge.isHidden = !$0 }
            )
        }
    }

    /// A single layer's eye, or nil for a row that is not a layer.
    ///
    /// The same flags the inspector's `LayerVisibleToggle` writes — two controls
    /// over one value, which is what makes the group eye read `.mixed`.
    private func layerVisibilityBinding(for group: IconLayerGroup, tab: LayerTab) -> Binding<Bool>? {
        switch (group, tab) {
        case (_, .layout):
            return nil
        case (.icon, .foreground):
            return Binding(
                get: { !iconSettings.icon.foreground.isHidden },
                set: { iconSettings.icon.foreground.isHidden = !$0 }
            )
        case (.icon, .background):
            return Binding(
                get: { !iconSettings.icon.background.isHidden },
                set: { iconSettings.icon.background.isHidden = !$0 }
            )
        case (.badge, .foreground):
            return Binding(
                get: { !iconSettings.badge.foreground.isHidden },
                set: { iconSettings.badge.foreground.isHidden = !$0 }
            )
        case (.badge, .background):
            return Binding(
                get: { !iconSettings.badge.background.isHidden },
                set: { iconSettings.badge.background.isHidden = !$0 }
            )
        }
    }
}

// MARK: - Hover reporting

private extension View {
    /// Reports `row` while the pointer is over it, nil when it leaves.
    ///
    /// `.contentShape` first, and it is not optional: a row is an `HStack` with a
    /// `Spacer` in it, so without one the gap between the label and the eye is not
    /// part of the row for hit-testing purposes and the hover drops out halfway
    /// across — which reads as a flickering outline rather than as a missing shape.
    ///
    /// Leaving one row for another can deliver the new row's first sample before the
    /// old row's exit, which would clear a hover that has just started. It
    /// self-heals within a frame, because the pointer inside the new row keeps
    /// reporting, so this stays the simple version rather than tracking which row
    /// owns the exit.
    func reportsHover(_ row: LayerSidebarRow, to report: ((PreviewPointer) -> Void)?) -> some View {
        contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active: report?(.over(row))
                case .ended:  report?(.away)
                }
            }
    }
}

// MARK: - Group row

private struct GroupRow: View {
    let group: IconLayerGroup
    let visibility: LayerGroupVisibility
    let visibilityBinding: Binding<Bool>

    private var iconName: String {
        switch group {
        case .icon:  return "app.fill"
        case .badge: return "app.badge.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 26, weight: .medium))
                .frame(width: 36, height: 36)

            Text(group.label)
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 8)
            GroupVisibilityToggle(group: group, visibility: visibility, binding: visibilityBinding)
        }
    }
}

/// Tri-state eye for a whole group. `.mixed` shows `eye.half.closed` and clicking
/// hides everything (consistent with the binding's setter).
private struct GroupVisibilityToggle: View {
    /// Only the spoken and hovered text needs this. The two eyes are otherwise
    /// identical controls, and were **read identically by VoiceOver** — review
    /// finding 8, and the reason this takes a group rather than just a binding.
    let group: IconLayerGroup
    let visibility: LayerGroupVisibility
    let binding: Binding<Bool>

    var body: some View {
        Button {
            binding.wrappedValue.toggle()
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(visibility == .off ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Label, value and tooltip say three different things on purpose: *what
        // this is*, *what state it is in* — the tri-state is a glyph difference
        // and nothing else conveyed `.mixed` — and *what a click will do*. The
        // `.help()` was carrying all three on its own, which is the failure C1's
        // rule names: a tooltip may accompany an accessibility label and must
        // never be the only description of a control.
        .accessibilityLabel("\(group.label) layers visible")
        .accessibilityValue(visibilityDescription)
        .help(helpText)
    }

    private var visibilityDescription: String {
        switch visibility {
        case .on:    return "All visible"
        case .off:   return "All hidden"
        case .mixed: return "Some hidden"
        }
    }

    private var symbolName: String {
        switch visibility {
        case .on:    return "eye"
        case .off:   return "eye.slash"
        case .mixed: return "eye.half.closed"
        }
    }

    private var helpText: String {
        switch visibility {
        case .on:    return "Hide the \(group.label.lowercased()) layers"
        case .off:   return "Show the \(group.label.lowercased()) layers"
        case .mixed: return "Hide the \(group.label.lowercased()) layers (currently mixed)"
        }
    }
}

// MARK: - Layer row

/// One layer beneath its group: a glyph, the layer's name, and its own eye.
///
/// Deliberately no thumbnail. The four that were here until 2026-07-25 each
/// re-implemented a slice of `IconContentView` at 36pt — the symbol's rendering
/// mode, the background's gradient, the badge's imported artwork — and a fifth
/// copy of the render is a fifth thing to keep in step with the pipeline, the
/// visibility gates and the hit tester. The row's job is to be clicked and to say
/// what is hidden; the preview two panes over is the picture.
private struct LayerRow: View {
    let group: IconLayerGroup
    let tab: LayerTab
    /// nil for Layout, which is the badge's position and size rather than a layer,
    /// so there is nothing for an eye to hide. See `LayerTab.isHideable`.
    let visibilityBinding: Binding<Bool>?

    /// "Icon foreground" — what the eye's label and tooltip name, since "Visible"
    /// on its own was read identically by VoiceOver for all six of these.
    private var layerName: String {
        "\(group.label) \(tab.label.lowercased())"
    }

    /// The same glyph box `GroupRow` uses, so a layer row is the same height as the
    /// group row above it and the list reads as one set of rows rather than two.
    /// The glyph *drawn* in it is smaller and secondary — with every row the same
    /// height, the type and the indent are what carry the hierarchy.
    private static let glyphBox: CGFloat = 36

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 18))
                .frame(width: Self.glyphBox, height: Self.glyphBox)

            // `tab.label` is a `String` variable, so this is `Text`'s
            // non-localizing overload — correct here: the three layer names are
            // spelled identically in every English variant Mica ships.
            Text(tab.label)
                .font(.system(size: 13))

            Spacer(minLength: 8)

            if let visibilityBinding {
                LayerVisibilityToggle(layerName: layerName, isVisible: visibilityBinding)
            }
        }
    }
}

/// Two-state eye for one layer, the counterpart of the inspector's
/// `LayerVisibleToggle` row. Same three-way split of label / value / tooltip as
/// `GroupVisibilityToggle` above, and for the same reason.
private struct LayerVisibilityToggle: View {
    let layerName: String
    @Binding var isVisible: Bool

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            Image(systemName: isVisible ? "eye" : "eye.slash")
                .font(.system(size: 14))
                .foregroundStyle(isVisible ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(layerName) visible")
        .accessibilityValue(isVisible ? "Visible" : "Hidden")
        .help(isVisible ? "Hide the \(layerName.lowercased())" : "Show the \(layerName.lowercased())")
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    @Previewable @State var selection: IconLayerGroup = .icon
    @Previewable @State var iconTab: LayerTab = .foreground
    @Previewable @State var badgeTab: LayerTab = .layout
    LayerSidebar(
        iconSettings: $settings,
        selection: $selection,
        iconTab: $iconTab,
        badgeTab: $badgeTab
    )
    .frame(width: 280, height: 500)
}
