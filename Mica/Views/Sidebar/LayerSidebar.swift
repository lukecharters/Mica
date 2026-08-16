// Views/Sidebar/LayerSidebar.swift
import SwiftUI

/// Left sidebar: the two selectable objects (Icon, Badge), each with a tri-state
/// visibility toggle. The layers within a group (foreground / background, plus
/// the badge's layout) are inspector tabs rather than child rows — see
/// `LayerTabPicker` and `InspectorControls`. The Mica/System generation-mode
/// picker lives at the top of the group's inspector (`GroupModePicker`).
struct LayerSidebar: View {
    @Binding var iconSettings: IconSettings
    @Binding var selection: IconLayerGroup

    var body: some View {
        List(selection: selectionBinding) {
            ForEach(IconLayerGroup.allCases) { group in
                GroupRow(
                    group: group,
                    visibility: visibility(for: group),
                    visibilityBinding: groupVisibilityBinding(for: group)
                )
                .tag(group)
                // Attached here rather than inside `GroupRow` so the row view
                // keeps taking the two values it draws instead of the whole
                // settings binding. The menu holds only edits, so it needs no
                // handler from `ContentView` — see `IconContextMenu.sidebarItems`,
                // which is deliberately not a copy of the canvas menu.
                .contextMenu {
                    IconContextMenuContent(
                        settings: $iconSettings,
                        items: IconContextMenu.sidebarItems(for: group, settings: iconSettings)
                    )
                }
            }
        }
        .listStyle(.sidebar)
    }

    /// `List` single-selection wants a `Binding<IconLayerGroup?>`. Bridge from the
    /// non-optional binding and ignore nils so the sidebar always keeps a selection
    /// (clicking empty space never deselects).
    private var selectionBinding: Binding<IconLayerGroup?> {
        Binding(
            get: { selection },
            set: { if let new = $0 { selection = new } }
        )
    }

    // MARK: - Per-group helpers

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

#Preview {
    @Previewable @State var settings = IconSettings()
    @Previewable @State var selection: IconLayerGroup = .icon
    LayerSidebar(iconSettings: $settings, selection: $selection)
        .frame(width: 280, height: 500)
}
