// Views/Inspector/InspectorGroupHeader.swift
import SwiftUI

/// Names the group whose controls the inspector is showing — Icon or Badge.
///
/// The sidebar's selected row said this and nothing else did, so hiding the sidebar
/// (⌃⌘S) left the panel unlabelled: two groups with near-identical panes and no way
/// to tell which one was being edited. The generation-mode menus in the toolbar are
/// per group but always both present, so they don't answer it either.
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

    var body: some View {
        // `group.label` is a `String` variable, which resolves to `Text`'s
        // non-localizing overload — so no `verbatim:` needed here, and no
        // `LocalizedStringKey` interpolation to go wrong. See NOTES.md.
        Text(group.label)
            .font(.title2.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
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
