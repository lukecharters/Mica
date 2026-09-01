// Views/Presets/PresetList.swift
//
// The preset library, as the content of the sidebar column's Presets mode.
//
// ## It was a slide-out pane in the detail column until 2026-08-31
//
// The first shape was an `HStack` sibling of the preview inside the detail column,
// with a `.move(edge: .leading)` transition, a fixed 216pt width and its own
// `.thinMaterial` background — the shape the inspector had before it became
// `.inspector`. It worked, and it carried two costs its own doc comment recorded as
// accepted: **no sidebar vibrancy** (it read as a panel, not as a second sidebar) and
// **216pt off the canvas** for as long as it was open.
//
// Both of those are what moving into the sidebar column pays off. The column already
// has the material, the width and the drag-resize, and the canvas keeps its full
// width. What replaces the pane's own chrome:
//
// | The pane had | The sidebar has |
// |---|---|
// | A "Presets" title and a close button | The `SidebarSelector` bar above it |
// | A fixed 216pt width, two fixed columns | The column's 220–360pt, an adaptive grid |
// | `.thinMaterial` over window content | The split view's real sidebar material |
// | One footer button, scoped by the sidebar selection | A `+` in each section header |
//
// **The footer button is the change worth understanding.** It read
// `Save Icon Preset…` / `Save Badge Preset…` off `selectedGroup`, on the stated
// grounds that the sidebar's selected row was already the user's answer to "which
// scope" and asking again would be a redundant question. In this shape the layer rows
// are *behind* the Presets tab while you are looking at presets, so that answer is no
// longer on screen and the justification lapses with it. A `+` in each section header
// says which scope by position, needs no selection to read, and puts the badge's
// "you need a badge first" disabled state next to the badge section rather than in
// help text on a single shared button. `selectedGroup` is not a parameter here any
// more, which is the tell that the dependency is really gone.
//
// The three-column question does not arise in this shape: the sidebar column already
// exists and this is its content, so `NavigationSplitViewVisibility` is untouched and
// ⌃⌘S keeps meaning exactly what it meant.

import SwiftUI

// MARK: - Metrics

/// The grid's geometry, in one place so the thumbnails and the columns cannot
/// disagree about how much room there is.
///
/// **There is no `width` here any more.** The pane owned its width; the sidebar
/// column owns this one, it is drag-resizable between 220 and 360, and AppKit
/// autosaves the divider — so the column count has to follow the width rather than be
/// fixed at two. See `columns`.
enum PresetGridMetrics {
    static let thumbnailSize: CGFloat = 84
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 14
    static let horizontalPadding: CGFloat = 14

    /// The tile's corner radius — **one number, because there were two.**
    ///
    /// The thumbnails stroked a 6pt-radius rectangle while the tile clipped to a 10pt
    /// *continuous* one, so the clip sheared the corners off the border it was drawn
    /// inside. Both now come from `tileShape`, and the stroke is a `strokeBorder` so
    /// its full width sits inside the shape rather than half of it straddling the clip.
    static let tileCornerRadius: CGFloat = 10

    /// The one shape the ground, the clip and the border all use.
    static var tileShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
    }

    /// One adaptive column spec, not N fixed ones.
    ///
    /// The count absorbs the column's width — two at 220pt, three by ~330pt — which is
    /// what a drag-resizable sidebar needs and what two fixed columns could not do.
    ///
    /// **No `maximum:`, and that is the fix rather than the loose end.** Capping the
    /// cell at `thumbnailSize` keeps every tile the right width but leaves *all* the
    /// slack at the trailing edge: measured at the default 280pt column it was a 72pt
    /// hole down the right-hand side of the grid, which reads as a mistake. Uncapped,
    /// the cells share the width evenly and `PresetTile`'s own
    /// `.frame(width: thumbnailSize)` keeps the render square and centres it in its
    /// cell — so the spacing grows, not the thumbnails. A stretched thumbnail would be
    /// wrong; a stretched *cell* is exactly right.
    static let columns = [
        GridItem(.adaptive(minimum: thumbnailSize), spacing: columnSpacing)
    ]
}

// MARK: - Tile chrome

extension View {
    /// A preset thumbnail's ground, clip and border — in that order, over one shape.
    ///
    /// **The ground is `controlBackgroundColor`**, near-white in light appearance and
    /// near-black in dark, which is what Apple's own apps put behind a symbol or a
    /// shape in a thumbnail. It matters here because every icon is a rounded chiclet
    /// inset from its canvas: without a ground the sidebar's material showed through
    /// the corners, so each tile read as a floating shape rather than as a swatch.
    ///
    /// **Applied in one place on purpose.** The clip and the border were in two —
    /// `PresetTile` clipped, each thumbnail stroked — with different radii and
    /// different corner styles, which is how the border lost its corners.
    func presetTileChrome() -> some View {
        background(Color(nsColor: .controlBackgroundColor), in: PresetGridMetrics.tileShape)
            .clipShape(PresetGridMetrics.tileShape)
            .overlay(
                PresetGridMetrics.tileShape
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
}

// MARK: - The list

struct PresetList: View {
    /// The current settings, read for one thing only: whether each scope can be
    /// captured, which is what enables its section's `+`.
    let iconSettings: IconSettings

    /// Every preset, built-ins first, already decoded.
    ///
    /// **Resolved by the caller, not here.** Decoding a preset is a
    /// `JSONSerialization` round trip plus the whole configuration decoder, and this
    /// view's `body` re-runs on every edit to `iconSettings`. See `ResolvedPreset`.
    let presets: [ResolvedPreset]
    let onApply: (MicaPreset) -> Void
    let onSave: (PresetScope) -> Void
    let onDelete: (MicaPreset) -> Void

    /// Per-section expansion, persisted.
    ///
    /// **`@AppStorage` under the `sidebar.*.expanded` prefix**, which is the key
    /// namespace `InspectorControls` already keeps its thirteen section states in — a
    /// collapsed section is a lasting preference about the shape of the pane, not
    /// per-window view state like `SidebarMode`. Read directly here rather than
    /// threaded from `ContentView`, the way every other reader of a preference in this
    /// project does.
    @AppStorage("sidebar.iconPresets.expanded") private var iconPresetsExpanded = true
    @AppStorage("sidebar.badgePresets.expanded") private var badgePresetsExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section(.icon, title: "Icon Presets", isExpanded: $iconPresetsExpanded)
                section(.badge, title: "Badge Presets", isExpanded: $badgePresetsExpanded)
            }
            .padding(.horizontal, PresetGridMetrics.horizontalPadding)
            .padding(.vertical, 14)
        }
        // No background of its own: the `NavigationSplitView` sidebar column paints
        // the material behind this, which is the whole point of being here.
    }

    // MARK: Sections

    /// One scope's presets, headed by its name and its own save button.
    ///
    /// Both sections are always shown, and deliberately not filtered by anything: a
    /// user looking for a badge preset should not have to first select the badge to
    /// see that badge presets exist. That was true of the pane and is true here.
    @ViewBuilder
    private func section(
        _ scope: PresetScope,
        title: LocalizedStringKey,
        isExpanded: Binding<Bool>
    ) -> some View {
        let rows = presets.filter { $0.scope == scope }

        VStack(alignment: .leading, spacing: 8) {
            header(scope, title: title, isExpanded: isExpanded)

            if isExpanded.wrappedValue {
                // **`maxWidth: .infinity` is load-bearing.** Without it the grid sized
                // to its own content and reported 207pt inside a 252pt content area —
                // so the adaptive columns were computing against the wrong width and
                // the slack came back as a trailing hole, the very thing dropping
                // `maximum:` was meant to fix. A `VStack(alignment: .leading)` sizes to
                // its widest child; the grid has to be told to take the room instead.
                LazyVGrid(
                    columns: PresetGridMetrics.columns,
                    alignment: .leading,
                    spacing: PresetGridMetrics.rowSpacing
                ) {
                    ForEach(rows) { row in
                        PresetTile(
                            resolved: row,
                            onApply: { onApply(row.preset) },
                            onDelete: row.preset.isBuiltIn ? nil : { onDelete(row.preset) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// The section name as a disclosure control, and the `+` that saves into it.
    ///
    /// **Hand-rolled rather than a `DisclosureGroup`.** The row has to carry a second,
    /// independently clickable control, and a `DisclosureGroup`'s label is entirely a
    /// toggle target — the `+` inside one competes with the disclosure for the click.
    /// `Section(_:isExpanded:)`, which is how `InspectorControls` does its thirteen,
    /// needs a `Form` and would style a thumbnail grid as form rows.
    ///
    /// The chevron is the standard leading disclosure, rotated rather than swapped for
    /// a second symbol so it animates. The title is `.subheadline.weight(.semibold)` in
    /// `.primary` — it was `.caption` in `.secondary`, which read as a caption on the
    /// grid below it rather than as a heading over it.
    ///
    /// **Saving a badge preset needs a badge**, which is why the badge's button can be
    /// disabled: a preset captured from a switched-off badge carries no activating key,
    /// so applying it would do nothing — and the one thing a badge preset must do is
    /// turn a badge on. Sitting in the badge section, the disabled control says which
    /// scope is unavailable without the help text having to; the help text says why.
    private func header(
        _ scope: PresetScope,
        title: LocalizedStringKey,
        isExpanded: Binding<Bool>
    ) -> some View {
        let canSave = UserPresetStore.canCapture(iconSettings, scope: scope)

        return HStack(spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                }
                // The whole row up to the `+` is the target, not just the words —
                // a heading you have to hit exactly is a heading people stop using.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isExpanded.wrappedValue ? "Hide these presets" : "Show these presets")
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded.wrappedValue ? "Expanded" : "Collapsed")
            .accessibilityAddTraits(.isHeader)

            Button {
                onSave(scope)
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
                    // **The glyph is 8×8, and a `.borderless` button is exactly its
                    // label.** Measured in the AX tree at 8×8pt — a quarter of the
                    // 20pt a small control should offer and far under the 28pt Apple
                    // asks for a primary target. The frame plus `contentShape` is the
                    // hit area; the glyph stays the size it looks right at.
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!canSave)
            .help(helpText(for: scope, canSave: canSave))
            .accessibilityLabel(scope == .icon
                                ? "Save Icon Preset"
                                : "Save Badge Preset")
        }
    }

    private func helpText(for scope: PresetScope, canSave: Bool) -> LocalizedStringKey {
        guard canSave else { return "Add a badge before saving a badge preset" }
        return scope == .icon
            ? "Save the current icon as a preset"
            : "Save the current badge as a preset"
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
                    .presetTileChrome()
                    .overlay(alignment: .bottomTrailing) {
                        if showsIndicator { indicator }
                    }

                // `Text(verbatim:)`, always. **`Text(aString)` takes the verbatim
                // overload silently**, so writing it that way would look like a
                // localised label and never be one — the bug is in the parameter type
                // and is invisible at the call site. `displayName` has already been
                // through the string catalog for a built-in, which is where that
                // choice is made and where getting it wrong would be visible.
                Text(verbatim: resolved.displayName)
                .font(.subheadline)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
            }
            .frame(width: PresetGridMetrics.thumbnailSize)
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
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(5)
            .background(Circle().fill(.regularMaterial))
            .padding(-5)
            .help("Requires Advanced Controls to be enabled")
            .accessibilityHidden(true)   // Said in the label instead.
    }

    private var name: String { resolved.displayName }

    private var accessibilityLabel: String {
        let scope = resolved.scope == .icon
            ? String(localized: "icon preset")
            : String(localized: "badge preset")
        guard showsIndicator else { return "\(name), \(scope)" }
        return "\(name), \(scope), \(String(localized: "requires Advanced Controls to be enabled"))"
    }

    private var helpText: String {
        showsIndicator
            ? "\(name) — requires Advanced Controls to be enabled"
            : name
    }
}

#Preview {
    PresetList(
        iconSettings: IconSettings(),
        presets: ResolvedPreset.resolve(PresetCatalog.builtIn),
        onApply: { _ in },
        onSave: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 280, height: 600)
}
