// Views/Presets/PresetGrid.swift
//
// The preset library's grid and the pieces around it: the tile, the section heading,
// the `+` that saves into a scope, and the metrics they share.
//
// Two hosts show the grid. A toolbar popover shows one scope's grid, three fixed
// columns, with no heading — the button that opened it already said which scope. The
// Presets window shows the selected scope in two sections, Built-in and Yours, each
// under a `PresetSectionHeader`, in a grid that adapts to the window's width. Nothing
// here paints a background: both hosts supply their own.
//
// **Nothing here decodes a preset.** The rows arrive as `ResolvedPreset`, resolved once
// by `PresetLibrary` when it reloads; this file's `body`s re-run on every edit to the
// icon, and a decode in one of them would run the whole configuration decoder per
// keystroke.

import SwiftUI

// MARK: - Metrics

/// The grid's geometry, in one place so the thumbnails and the columns cannot
/// disagree about how much room there is.
///
/// Two column rules, one per host: `columns` adapts to whatever width the Presets
/// window gives it, and `fixedColumns(_:)` states a count for the popover, whose width
/// is fixed and comes from `width(forColumns:)`.
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

    /// The arrow in a badge thumbnail's corner, and its inset from the tile's edge.
    static let cornerArrowSize: CGFloat = 10
    static let cornerArrowInset: CGFloat = 6

    /// One adaptive column spec, not N fixed ones.
    ///
    /// The count absorbs the host's width — two at 220pt, three by ~330pt — which is
    /// what a resizable window needs and what a fixed count could not do.
    ///
    /// **No `maximum:`, and that is the fix rather than the loose end.** Capping the
    /// cell at `thumbnailSize` keeps every tile the right width but leaves *all* the
    /// slack at the trailing edge: measured at a 280pt width it was a 72pt
    /// hole down the right-hand side of the grid, which reads as a mistake. Uncapped,
    /// the cells share the width evenly and `PresetTile`'s own
    /// `.frame(width: thumbnailSize)` keeps the render square and centres it in its
    /// cell — so the spacing grows, not the thumbnails. A stretched thumbnail would be
    /// wrong; a stretched *cell* is exactly right.
    static let columns = [
        GridItem(.adaptive(minimum: thumbnailSize), spacing: columnSpacing)
    ]

    /// A fixed column count, for a host whose width is fixed too — a popover reflowing
    /// as it opens reads as broken, so it states its columns and takes `width(forColumns:)`.
    static func fixedColumns(_ count: Int) -> [GridItem] {
        Array(repeating: GridItem(.fixed(thumbnailSize), spacing: columnSpacing), count: count)
    }

    /// How far a popover's scroll view keeps its overlay scroller in from the popover's
    /// bezel. SwiftUI lays popover content flush against the bezel, so an indicator at
    /// the content's edge is drawn under the border and reads as chopped off. See
    /// `PresetPopover` for how it is applied; it is not a padding.
    static let scrollerInset: CGFloat = 8

    /// The width `count` fixed columns of tiles occupy, gaps included and nothing else.
    ///
    /// A fixed-column `LazyVGrid` reports more than this as its ideal width, and a
    /// `ScrollView` whose content is wider than its frame grows past the frame on both
    /// sides — so the grid is pinned to exactly this in a popover.
    static func gridWidth(forColumns count: Int) -> CGFloat {
        CGFloat(count) * thumbnailSize + CGFloat(max(count - 1, 0)) * columnSpacing
    }

    /// The content width `count` fixed columns need, padding included.
    static func width(forColumns count: Int) -> CGFloat {
        gridWidth(forColumns: count) + 2 * horizontalPadding
    }
}

// MARK: - Tile chrome

extension View {
    /// A preset thumbnail's ground, clip and border — in that order, over one shape.
    ///
    /// **The ground is `controlBackgroundColor`**, near-white in light appearance and
    /// near-black in dark, which is what Apple's own apps put behind a symbol or a
    /// shape in a thumbnail. It matters here because every icon is a rounded chiclet
    /// inset from its canvas: without a ground the host's material showed through
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

// MARK: - A section heading

/// A section name as a disclosure control, with room for one control at its trailing
/// end. The Presets window's sections use none; the `+` there is in the toolbar.
///
/// **Hand-rolled rather than a `DisclosureGroup`.** The row has to carry a second,
/// independently clickable control, and a `DisclosureGroup`'s label is entirely a
/// toggle target — the `+` inside one competes with the disclosure for the click.
/// `Section(_:isExpanded:)`, which is how `InspectorControls` does its thirteen,
/// needs a `Form` and would style a thumbnail grid as form rows.
///
/// The chevron is the standard leading disclosure, rotated rather than swapped for
/// a second symbol so it animates. The title is 13pt medium in `.primary`: a
/// `.caption` in `.secondary` reads as a caption on the grid below it rather than as
/// a heading over it.
struct PresetSectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    @Binding var isExpanded: Bool
    let trailing: Trailing

    init(
        _ title: LocalizedStringKey,
        isExpanded: Binding<Bool>,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                }
                // The whole row up to the trailing control is the target, not just
                // the words — a heading you have to hit exactly is a heading people
                // stop using.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Hide these presets" : "Show these presets")
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityAddTraits(.isHeader)

            trailing
        }
    }
}

extension PresetSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey, isExpanded: Binding<Bool>) {
        self.init(title, isExpanded: isExpanded) { EmptyView() }
    }
}

// MARK: - One scope's grid

/// One scope's tiles, in a grid that takes the width it is given.
///
/// The Presets window shows one of these under each section heading; a toolbar
/// popover shows exactly one, with no heading, because the button that opened it
/// already said which scope. `columns` is adaptive by default and fixed where the
/// host's width is fixed.
///
/// **`maxWidth: .infinity` is load-bearing.** A `VStack(alignment: .leading)` sizes to
/// its widest child, so without it the grid reports a width short of its container
/// and the adaptive columns compute against the wrong number, leaving the slack as a
/// hole down the trailing edge. The grid has to be told to take the room.
struct PresetGrid: View {
    let rows: [ResolvedPreset]
    var columns: [GridItem] = PresetGridMetrics.columns
    let onApply: (MicaPreset) -> Void
    let onDelete: (MicaPreset) -> Void

    var body: some View {
        LazyVGrid(
            columns: columns,
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

// MARK: - The save button

/// The `+` that saves the current icon or badge as a preset of one scope.
///
/// **Saving a badge preset needs a badge**, which is why this can be disabled: a
/// preset captured from a switched-off badge carries no activating key, so applying
/// it would do nothing — and the one thing a badge preset must do is turn a badge on.
/// The help text says why.
///
/// **The glyph is 8×8, and a `.borderless` button is exactly its label** — a quarter
/// of the 20pt a small control should offer. The frame plus `contentShape` is the hit
/// area; the glyph stays the size it looks right at.
struct PresetSaveButton: View {
    let scope: PresetScope
    /// Read for one thing only: whether this scope can be captured right now.
    let iconSettings: IconSettings
    let onSave: (PresetScope) -> Void

    var body: some View {
        let canSave = UserPresetStore.canCapture(iconSettings, scope: scope)

        Button {
            onSave(scope)
        } label: {
            Image(systemName: "plus.circle")
//                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!canSave)
        .help(Self.helpText(for: scope, canSave: canSave))
        .accessibilityLabel(Self.title(for: scope))
    }

    /// The button's name, here and in the Presets window's toolbar.
    static func title(for scope: PresetScope) -> LocalizedStringKey {
        scope == .icon ? "Save Icon Preset" : "Save Badge Preset"
    }

    /// The tooltip, which says why when the button is off.
    static func helpText(for scope: PresetScope, canSave: Bool) -> LocalizedStringKey {
        guard canSave else { return "Add a badge before saving a badge preset" }
        return scope == .icon
            ? "Save the current icon as a preset"
            : "Save the current badge as a preset"
    }
}

// MARK: - One preset

/// A thumbnail and its name. The indicators sit on the name line: `person.fill` leads
/// a user preset's name, and `slider.horizontal.3` trails one that turns the advanced
/// controls on.
private struct PresetTile: View {
    let resolved: ResolvedPreset
    let onApply: () -> Void
    /// Nil for a built-in, which has no file to delete.
    let onDelete: (() -> Void)?

    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    /// The indicators this tile draws, in reading order.
    ///
    /// The rule is `PresetIndicator.indicators`, not a condition written here, so that
    /// the glyphs, the tooltip and the accessibility label below cannot disagree about
    /// which indicators apply — and so that a test can reach it at all.
    private var indicators: [PresetIndicator] {
        PresetIndicator.indicators(
            isUserPreset: resolved.isUserPreset,
            needsAdvancedControls: resolved.needsAdvancedControls,
            advancedControlsEnabled: advancedControlsEnabled
        )
    }

    var body: some View {
        Button(action: onApply) {
            VStack(spacing: 5) {
                PresetThumbnail(resolved: resolved)
                    .presetTileChrome()

                nameLabel
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
        // does not, so the label carries the scope as well as the name — "Settings,
        // icon preset" reads as one item in a rotor rather than as a bare word. The
        // indicators' clauses follow, because their glyphs are hidden from the tree.
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

    /// The name line: identity leads the name and the warning trails it.
    ///
    /// One concatenated `Text` rather than an `HStack`, so the glyphs are part of the
    /// text: they wrap with the name, and the two-line centring the label already does
    /// treats glyphs and name as one run.
    ///
    /// `Text(verbatim:)`, always. **`Text(aString)` takes the verbatim overload
    /// silently**, so writing it that way would look like a localised label and never be
    /// one — the bug is in the parameter type and is invisible at the call site.
    /// `displayName` has already been through the string catalog for a built-in, which
    /// is where that choice is made and where getting it wrong would be visible.
    private var nameLabel: Text {
        var label = Text(verbatim: resolved.displayName)
        if indicators.contains(.userPreset) {
            label = glyph(.userPreset) + Text(verbatim: " ") + label
        }
        if indicators.contains(.advancedControls) {
            label = label + Text(verbatim: " ") + glyph(.advancedControls)
        }
        return label
    }

    private func glyph(_ indicator: PresetIndicator) -> Text {
        Text(Image(systemName: indicator.symbolName)).foregroundStyle(.secondary)
    }

    private var name: String { resolved.displayName }

    private var accessibilityLabel: String {
        let scope = resolved.scope == .icon
            ? String(localized: "icon preset")
            : String(localized: "badge preset")
        return ([name, scope] + indicators.map(\.clause)).joined(separator: ", ")
    }

    private var helpText: String {
        let clauses = indicators.map(\.clause)
        guard !clauses.isEmpty else { return name }
        return "\(name) — \(clauses.joined(separator: ", "))"
    }
}

#Preview {
    // A synthetic user preset in each scope, so the `person.fill` indicator is on
    // screen here — the built-in catalogue cannot show it, and a preview that never
    // draws a control is a preview that cannot be used to judge it.
    let mine = [
        MicaPreset(
            name: "My Icon",
            scope: .icon,
            keys: ["icon-fg": .string("symbol:sparkles"),
                   "icon-bg": .string("custom-gradient"),
                   "icon-bg-gradient-colors": .strings(["purple", "blue"])],
            isBuiltIn: false
        ),
        MicaPreset(
            name: "My Badge",
            scope: .badge,
            keys: ["badge-fg": .string("symbol:bolt.fill"),
                   "badge-bg-color": .string("orange")],
            isBuiltIn: false
        ),
    ]
    ScrollView {
        PresetGrid(
            rows: ResolvedPreset.resolve(PresetCatalog.builtIn + mine),
            onApply: { _ in },
            onDelete: { _ in }
        )
        .padding(PresetGridMetrics.horizontalPadding)
    }
    .frame(width: 320, height: 600)
}
