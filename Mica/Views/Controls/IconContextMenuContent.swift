// Views/Controls/IconContextMenuContent.swift
//
// The rows of a context menu, rendered from whatever `IconContextMenu` decided.
// Item C2 of `docs/plans/mac-conventions.md`.
//
// One view for all three menus — the canvas, both sidebar rows — because the
// difference between them is which items they ask for, not how a row is drawn. A
// second implementation is how the same command ends up worded two ways.

import SwiftUI

struct IconContextMenuContent: View {
    @Binding var settings: IconSettings
    let items: [IconContextItem]

    /// What performs the rows the settings cannot. The sidebar's menus hold only
    /// edits, so they leave this at the logging default rather than threading a
    /// handler they have no use for — and if one ever does grow a command row, it
    /// says so in Console instead of going quiet. See `PreviewContextActions`.
    var actions: PreviewContextActions = .unavailable

    var body: some View {
        // Keyed by position, not by the item: `.separator` repeats, and two
        // groups can legitimately offer the same row.
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            row(item)
        }
    }

    @ViewBuilder
    private func row(_ item: IconContextItem) -> some View {
        switch item {
        case .separator:
            Divider()
        case .edit(let edit):
            // Straight into the binding: an edit is a settings mutation and
            // nothing else, so it needs no route back to the window. Undo is
            // automatic — `ContentView` observes `iconSettings` centrally and
            // `IconViewModel+Undo` names the action from the diff.
            Button(edit.title) {
                IconContextMenu.apply(edit, to: &settings)
            }
        case .command(let command):
            Button(command.title) {
                actions.perform(command)
            }
        }
    }
}
