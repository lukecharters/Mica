// Views/Inspector/InspectorGroupHeader.swift
import SwiftUI

/// Names the group whose controls the inspector is showing — Icon or Badge — and,
/// where the group is divided into layers, the layer being edited beside it.
///
/// The sidebar's selected row said this and nothing else did, so hiding the sidebar
/// (⌃⌘S) left the panel unlabelled: two groups with near-identical panes and no way
/// to tell which one was being edited. The generation-mode menus in the toolbar are
/// per group but always both present, so they don't answer it either.
///
/// The sublayer follows the sidebar's child rows exactly — `sublayer(for:in:…)` is
/// `LayerTab.sidebarRows` asked a yes/no question — so the header names a layer
/// precisely when there is a row for it: advanced controls on, Mica mode. With the
/// advanced controls off the pane edits the group as one thing and the sidebar has
/// no child rows, so naming a layer here would describe a selection the panel is
/// not honouring.
///
/// **Pinned above the `ScrollView`, not inside it**, so it stays put — a title that
/// scrolls away stops answering the question the moment you use the panel.
///
/// Text only, deliberately. The sidebar row carries a filled `app`/`app.badge` glyph
/// and the toolbar menus carry the outline pair; a third copy here would have to pick
/// one and would put the same idea in three places.
///
/// Shown for the layer controls only. `ExportSettingsSection` is not per group — it
/// edits the whole icon's export — so a group name over it would be a lie.
struct InspectorGroupHeader: View {
    let group: IconLayerGroup
    var sublayer: LayerTab? = nil

    /// The layer the header should name beside the group, or nil for the group alone.
    ///
    /// Answers with `tab` exactly when the sidebar would draw a child row for it, so
    /// the two surfaces stay in step by construction: System mode and the simple
    /// pane both yield nil, and so does a tab the group does not offer.
    nonisolated static func sublayer(
        for tab: LayerTab,
        in group: IconLayerGroup,
        isSystem: Bool,
        advancedControlsEnabled: Bool
    ) -> LayerTab? {
        let rows = LayerTab.sidebarRows(
            for: group,
            isSystem: isSystem,
            advancedControlsEnabled: advancedControlsEnabled
        )
        return rows.contains(tab) ? tab : nil
    }

    var body: some View {
        // `group.label` and `sublayer.label` are `String` variables, which resolve
        // to `Text`'s non-localizing overload — so no `verbatim:` needed here, and
        // no `LocalizedStringKey` interpolation to go wrong. See the project notes.
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(group.label)
            if let sublayer {
                Text(sublayer.label)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.title.bold())
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Icon") {
    InspectorGroupHeader(group: .icon)
        .frame(width: 340)
        .padding()
}

#Preview("Badge") {
    InspectorGroupHeader(group: .badge)
        .frame(width: 340)
        .padding()
}

#Preview("Badge, Layout layer") {
    InspectorGroupHeader(group: .badge, sublayer: .layout)
        .frame(width: 340)
        .padding()
}
