// Views/Sidebar/LayerSidebar.swift
import SwiftUI

/// Left sidebar: the two selectable objects (Icon, Badge), each with a tri-state
/// visibility toggle. The layers within a group (foreground / background, plus
/// the badge's layout) are inspector tabs rather than child rows — see
/// `LayerTabPicker` and `InspectorControls`. The Mica/System generation mode is
/// switched from the window toolbar (`GenerationModeMenu`), which shows both groups
/// at once rather than only the selected one.
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
            GroupVisibilityToggle(visibility: visibility, binding: visibilityBinding)
        }
    }
}

/// Tri-state eye for a whole group. `.mixed` shows `eye.half.closed` and clicking
/// hides everything (consistent with the binding's setter).
private struct GroupVisibilityToggle: View {
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
        .help(helpText)
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
        case .on:    return "Hide layers"
        case .off:   return "Show layers"
        case .mixed: return "Hide layers (currently mixed)"
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    @Previewable @State var selection: IconLayerGroup = .icon
    LayerSidebar(iconSettings: $settings, selection: $selection)
        .frame(width: 280, height: 500)
}
