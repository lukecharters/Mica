// Views/Presets/SavePresetSheet.swift
//
// "Save Current as Preset…": one field and two buttons.
//
// The scope is not asked for. It comes from the sidebar selection, which is the only
// thing on screen that answers "which scope" — and asking again would be asking the
// user to repeat a choice they made by selecting a group.
//
// Duplicate names are not refused either. `UserPresetStore.uniqueName` appends " 2",
// the Finder's convention for the same problem, and the sheet says so ahead of time
// rather than rejecting a save the user has already committed to. A modal that
// refuses is worse than one that adjusts and tells you.

import SwiftUI

struct SavePresetSheet: View {
    let scope: PresetScope
    /// Everything already in the scope, built-ins included — what the name is
    /// uniqued against, and what the preview below reads.
    let existing: [MicaPreset]
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    /// The field owns the keyboard while it has focus — arrows, Return and Escape all
    /// go to it — so the two buttons carry their key equivalents through
    /// `.keyboardShortcut` rather than through any key handler of this view's.
    @FocusState private var nameIsFocused: Bool

    /// What the preset will actually be called. Shown when it differs from what was
    /// typed, so the rename is visible before the save rather than after it.
    private var resolvedName: String {
        UserPresetStore.uniqueName(name, in: scope, existing: existing)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(scope == .icon ? "Save Icon Preset" : "Save Badge Preset")
                .font(.headline)

            Text(scope == .icon
                 ? "Saves the icon’s current settings. The badge isn’t included."
                 : "Saves the badge’s current settings, including its corner.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameIsFocused)

            if !trimmedName.isEmpty, resolvedName != trimmedName {
                Label(
                    "There’s already a preset called “\(trimmedName)”. This one will be saved as “\(resolvedName)”.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(resolvedName) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { nameIsFocused = true }
    }
}
