// Views/Presets/PresetPane.swift
//
// The slide-out pane of presets, at the leading edge of the detail column.
//
// ## Why it is not a third NavigationSplitView column
//
// `NavigationSplitViewVisibility` has only `.all`, `.doubleColumn` and
// `.detailOnly`, and in a three-column layout `.doubleColumn` means *content +
// detail* — it hides the **sidebar**, not the middle column. So the state the app is
// in almost all the time (sidebar open, presets closed) is not representable, and
// ⌃⌘S would start meaning something else. A third column is out.
//
// This is instead an `HStack` sibling of the preview inside the detail column, with
// a `.move(edge: .leading)` transition — the exact shape the inspector had before it
// became `.inspector`, and the note recording that still stands in `ContentView`. It
// lands immediately right of the sidebar, so it reads as sliding out from it, and
// `columnVisibility` is untouched. The two panes are independent: hide the sidebar
// and this simply butts to the window edge.
//
// Two consequences, both accepted rather than worked around:
//
// - **No sidebar vibrancy.** It is `.thinMaterial` over window content, so it reads
//   as a panel rather than as a second sidebar. That is what it is.
// - **Fixed width, no resize handle.** A thumbnail grid has a natural width, and
//   this avoids a third `PaneWidthPreferences.Pane`. The sidebar's `preferenceKey` is
//   deliberately nil because AppKit autosaves that divider; a detail-column pane has
//   no autosave and would need the full `.reportsPaneWidth` machinery for very
//   little.

import SwiftUI

// MARK: - Metrics

/// The pane's fixed geometry, in one place so the thumbnails and the grid cannot
/// disagree about how much room there is.
enum PresetPaneMetrics {
    /// Two columns of `thumbnailSize`, plus the gutters and the outer padding.
    static let width: CGFloat = 216
    static let thumbnailSize: CGFloat = 84
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 14
    static let horizontalPadding: CGFloat = 14
}

// MARK: - The pane

struct PresetPane: View {
    /// The scope "Save Current as Preset…" saves.
    ///
    /// **The sidebar's selection, and it is the only thing on screen that answers
    /// "which scope".** The *sections* are deliberately not driven by it — both are
    /// visible at once and moving between them changes nothing else — but a save
    /// button has to pick one, and asking in the sheet would be a question the user
    /// has already answered by selecting a group.
    let selectedGroup: IconLayerGroup

    /// The current settings, read for two things only: whether a badge preset can be
    /// saved at all, and what a save captures.
    let iconSettings: IconSettings

    /// Every preset, built-ins first, already decoded.
    ///
    /// **Resolved by the caller, not here.** Decoding a preset is a
    /// `JSONSerialization` round trip plus the whole configuration decoder, and this
    /// view's `body` re-runs on every frame of its own slide-in and on every edit to
    /// `iconSettings`. See `ResolvedPreset`.
    let presets: [ResolvedPreset]
    let onApply: (MicaPreset) -> Void
    let onSave: (PresetScope) -> Void
    let onDelete: (MicaPreset) -> Void
    let onClose: () -> Void

    private var saveScope: PresetScope {
        selectedGroup == .badge ? .badge : .icon
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            presetList
            Divider()
            footer
        }
        .frame(width: PresetPaneMetrics.width)
        .background(.thinMaterial)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            Text("Presets")
                .font(.headline)
            Spacer(minLength: 0)
            // The pane's own way out, beside the View menu's ⌃⌘P. A pane that can
            // only be closed from a menu is a pane people leave open.
            Button(action: onClose) {
                Image(systemName: "sidebar.leading")
            }
            .buttonStyle(.borderless)
            .help("Hide Presets")
            .accessibilityLabel("Hide Presets")
        }
        .padding(.horizontal, PresetPaneMetrics.horizontalPadding)
        .padding(.vertical, 10)
    }

    // MARK: Sections

    /// Both sections, in one scrolling pane.
    ///
    /// Deliberately not filtered by the sidebar selection, and deliberately not a
    /// third piece of selection state: a user looking for a badge preset should not
    /// have to first select the badge to see that badge presets exist.
    private var presetList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section(.icon, title: "Icon Presets")
                section(.badge, title: "Badge Presets")
            }
            .padding(.horizontal, PresetPaneMetrics.horizontalPadding)
            .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private func section(_ scope: PresetScope, title: LocalizedStringKey) -> some View {
        let rows = presets.filter { $0.scope == scope }

        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.fixed(PresetPaneMetrics.thumbnailSize), spacing: PresetPaneMetrics.columnSpacing),
                    GridItem(.fixed(PresetPaneMetrics.thumbnailSize), spacing: PresetPaneMetrics.columnSpacing),
                ],
                alignment: .leading,
                spacing: PresetPaneMetrics.rowSpacing
            ) {
                ForEach(rows) { row in
                    PresetTile(
                        resolved: row,
                        onApply: { onApply(row.preset) },
                        onDelete: row.preset.isBuiltIn ? nil : { onDelete(row.preset) }
                    )
                }
            }
        }
    }

    // MARK: Footer

    /// One button, scoped by the sidebar selection.
    ///
    /// **Saving a badge preset needs a badge**, which is why this can be disabled: a
    /// preset captured from a switched-off badge carries no activating key, so
    /// applying it would do nothing — and the one thing a badge preset must do is
    /// turn a badge on. The help text says so rather than leaving a dead button.
    private var footer: some View {
        let canSave = UserPresetStore.canCapture(iconSettings, scope: saveScope)

        return Button {
            onSave(saveScope)
        } label: {
            Label(
                saveScope == .icon ? "Save Icon Preset…" : "Save Badge Preset…",
                systemImage: "plus"
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .disabled(!canSave)
        .help(canSave
              ? "Save the current \(saveScope == .icon ? "icon" : "badge") as a preset"
              : "Add a badge before saving a badge preset")
        .padding(.horizontal, PresetPaneMetrics.horizontalPadding)
        .padding(.vertical, 10)
    }
}

// MARK: - One preset

/// A thumbnail, its name, and — when it applies — the advanced-controls indicator.
private struct PresetTile: View {
    let resolved: ResolvedPreset
    let onApply: () -> Void
    /// Nil for a built-in, which has no file to delete.
    let onDelete: (() -> Void)?

    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    /// Shown only while the simple controls are active.
    ///
    /// Applying this preset will turn "Show Advanced Controls" on — mirroring the
    /// existing rule for imported sources — and the indicator is what stops that
    /// being a surprise. With the advanced controls already on there is nothing to
    /// warn about, so the marker would be noise.
    ///
    /// **Derived, not authored**: see `MicaPreset.needsAdvancedControls`. It is finer
    /// than "anything fancy" — only a custom two-colour gradient or a non-monochrome
    /// rendering mode qualifies. The derived gradient, corner styles, symbol weights
    /// and shadows are all hidden-but-applied and carry no indicator.
    private var showsIndicator: Bool {
        !advancedControlsEnabled && resolved.needsAdvancedControls
    }

    var body: some View {
        Button(action: onApply) {
            VStack(spacing: 5) {
                PresetThumbnail(resolved: resolved)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if showsIndicator { indicator }
                    }

                // `Text(verbatim:)`, always. **`Text(aString)` takes the verbatim
                // overload silently**, so writing it that way would look like a
                // localised label and never be one — the bug is in the parameter type
                // and is invisible at the call site. `displayName` has already been
                // through the string catalog for a built-in, which is where that
                // choice is made and where getting it wrong would be visible.
                Text(verbatim: resolved.displayName)
                .font(.caption)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
            }
            .frame(width: PresetPaneMetrics.thumbnailSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Two presets can differ only in colour, which a thumbnail shows and a name
        // does not, so the label carries the scope as well as the name — "Installer,
        // icon preset" reads as one item in a rotor rather than as a bare word.
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(resolved.scope == .icon
                           ? "Replaces the icon’s settings"
                           : "Replaces the badge’s settings")
        .help(helpText)
        .contextMenu {
            if let onDelete {
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
    }

    private var indicator: some View {
        Image(systemName: "slider.horizontal.3")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(3)
            .background(Circle().fill(.tint))
            .padding(4)
            .help("Turns on Show Advanced Controls")
            .accessibilityHidden(true)   // Said in the label instead.
    }

    private var name: String { resolved.displayName }

    private var accessibilityLabel: String {
        let scope = resolved.scope == .icon
            ? String(localized: "icon preset")
            : String(localized: "badge preset")
        guard showsIndicator else { return "\(name), \(scope)" }
        return "\(name), \(scope), \(String(localized: "turns on advanced controls"))"
    }

    private var helpText: String {
        showsIndicator
            ? "\(name) — turns on Show Advanced Controls"
            : name
    }
}
