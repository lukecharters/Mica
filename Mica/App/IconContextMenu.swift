// App/IconContextMenu.swift
//
// What a right-click offers, and where each row's work happens. Item C2 of
// the Mac-conventions plan; the candidate list is review finding 12.
//
// The decision is here rather than in the two menu views because it is the part
// that can be wrong quietly: a row that should not be offered (paste a
// background onto a System-mode icon, which the appex pipeline ignores) looks
// exactly like one that should, and clicking it appears to do nothing. The views
// below `Views/Preview/` and `Views/Sidebar/` render whatever this returns.
//
// App-only on purpose: a context menu does not exist in the CLI, so this file
// stays out of `Models/` and `Services/` and off both `membershipExceptions`
// lists. See the project notes, "Adding a file".

import Foundation
import os

/// One row of a context menu.
///
/// Split into `edit` and `command` by **who can do the work**, which is the only
/// distinction the two menu views need: an edit is a mutation of `IconSettings`
/// and nothing else, so `IconContextMenu.apply` performs every one of them and is
/// exhaustive; a command needs the render, the pasteboard or an export panel, so
/// it goes back to the window that owns them.
///
/// The alternative — one flat enum with a partial `apply` that no-ops on four
/// cases — is how a row goes silently dead. Here a new command cannot be added
/// without the switch in `PreviewContextMenuContent` failing to compile.
enum IconContextItem: Equatable {
    case separator
    case edit(IconContextEdit)
    case command(IconContextCommand)
}

/// A row that is performed by mutating the settings. See `IconContextMenu.apply`.
enum IconContextEdit: Equatable {
    /// Undo the two guesses an imported background made — see
    /// `IconSpec.removeBackgroundImage()`.
    case removeBackgroundImage(IconLayerGroup)
    /// Go back to drawing the symbol — see `ForegroundSpec.removeImage()`, which
    /// keeps `symbolName` and so restores the exact symbol that was there.
    case removeForegroundImage(IconLayerGroup)
    /// Zero the badge's manual nudge. Deliberately **not** its anchor: `position`
    /// is a picker the user set on purpose, where the offsets are what a drag or
    /// an arrow press accumulates and therefore the only part of "position" that
    /// can want undoing without touching a choice.
    case resetBadgePosition
    /// The group eye, as a menu row. Carries the state it will write rather than
    /// toggling, so `title` is decided by the case alone.
    case setGroupHidden(IconLayerGroup, Bool)
    /// Everything about how the group looks, back to defaults — see
    /// `IconSpec.reset()`, which keeps the generation mode and the visibility.
    case resetGroup(IconLayerGroup)

    var title: String {
        switch self {
        case .removeBackgroundImage(let group):
            // The group is named even though the click already implied it: this
            // row appears in the canvas menu *and* on a sidebar row, and it is
            // the destructive one of the pair. It also matches the Edit menu's
            // "Paste as Icon Background" wording, so the two read as inverses.
            return "Remove Imported \(group.label) Background"
        case .removeForegroundImage(let group):
            // "Symbol" rather than "Foreground", because that is what the Edit
            // menu calls this layer ("Paste as Icon Symbol") even when what lands
            // in it is an image. Two names for one layer is worse than one
            // slightly loose name.
            return "Remove Imported \(group.label) Symbol"
        case .resetBadgePosition:
            return "Reset Badge Position"
        case .setGroupHidden(let group, let hidden):
            return "\(hidden ? "Hide" : "Show") \(group.label) Layers"
        case .resetGroup(let group):
            return "Reset \(group.label)"
        }
    }
}

/// A row the window performs, because the settings cannot reach what it needs.
///
/// All three already exist as menu commands; a context menu is a second route to
/// them and must not become a second implementation of them. `ContentView` maps
/// each to the same call the File or Edit menu makes.
enum IconContextCommand: Equatable {
    case copyIcon
    case exportPNG
    case pasteBackground(IconLayerGroup)
    case pasteForeground(IconLayerGroup)

    var title: String {
        switch self {
        case .copyIcon:
            return "Copy Icon"
        case .exportPNG:
            return "Export as PNG…"
        case .pasteBackground(let group):
            // Word for word the Edit menu's item. One command reading two ways in
            // two places is how a user learns it is two commands.
            return "Paste as \(group.label) Background"
        case .pasteForeground(let group):
            return "Paste as \(group.label) Symbol"
        }
    }
}

enum IconContextMenu {

    // MARK: - Which group was clicked

    /// The group a right-click at `point` acts on, in the same `displaySize`
    /// square canvas coordinates `PreviewHitTester` works in.
    ///
    /// Routing goes through `PreviewHitTester` — the review's own condition on
    /// this item, and the same rule `PreviewDrop.target` follows — so a
    /// right-click cannot disagree with what a left-click selects. Two things it
    /// narrows:
    ///
    /// - **A layer answer collapses to its group.** A context menu on a
    ///   foreground and one on the background behind it would differ only in rows
    ///   that name the group anyway, and the click that opens the menu does not
    ///   move the inspector's selection, so there is nothing for the finer answer
    ///   to point at.
    /// - **A miss is the icon**, as it is for a drop: the canvas margin and the
    ///   chiclet's rounded corners hit nothing, and the icon is what a menu opened
    ///   out there is about.
    ///
    /// `point` is optional because the location has to be remembered from the
    /// pointer's last hover — `.contextMenu` reports no location of its own — and
    /// a menu opened before the pointer has ever moved over the canvas has none.
    /// That resolves to the icon rather than to a special case.
    static func group(
        at point: CGPoint?,
        settings: IconSettings,
        displaySize: CGFloat,
        isSystem: Bool
    ) -> IconLayerGroup {
        guard let point else { return .icon }
        let hit = isSystem
            ? PreviewHitTester.systemTarget(at: point, settings: settings, iconSize: displaySize)
            : PreviewHitTester.target(at: point, settings: settings, displaySize: displaySize)
        return hit?.group ?? .icon
    }

    // MARK: - The rows

    /// The canvas menu for `group`.
    ///
    /// Ordered as the platform orders a context menu: what the user most likely
    /// wants first (the icon leaving the app, which is what the canvas is for),
    /// then the content actions, then the state ones. Every row is either always
    /// applicable or gated on something that makes it *do* nothing — a disabled
    /// row would be more honest than a dead one, but an absent row is more honest
    /// still in a menu the user opened over a specific thing.
    static func canvasItems(
        for group: IconLayerGroup,
        settings: IconSettings,
        canExport: Bool
    ) -> [IconContextItem] {
        var items: [IconContextItem] = []

        // Gated together on `canExport`, exactly as ⇧⌘E, ⇧⌘C and the drag-out
        // are: while a System-mode layer's appex raster is pending, all three
        // would produce an icon with that layer missing. Copy, export and drag
        // answer to one rule, and this is a fourth face of the same export.
        if canExport {
            items.append(.command(.copyIcon))
            items.append(.command(.exportPNG))
        }

        // Nothing in this section reaches a System-mode render: the appex
        // pipeline takes a symbol and two colours and ignores every background or
        // imported-symbol key, so offering a paste here would be a row that
        // quietly does nothing.
        //
        // **Both layers are always offered, in the Edit menu's order** (background
        // then symbol), rather than leading with whichever layer the pointer is
        // over. Ordering by the hit was tried on paper and rejected twice over: the
        // titles already say which layer each row is for, so nothing is ambiguous
        // to begin with; and a menu whose rows reorder according to a sub-layer hit
        // the user cannot see the bounds of is less predictable than a fixed one,
        // not more. The group still comes from the hit — that part is worth having,
        // because it decides *which* pair of layers is on offer.
        if mode(of: group, in: settings) == .mica {
            var content: [IconContextItem] = [
                .command(.pasteBackground(group)),
                .command(.pasteForeground(group)),
            ]
            if hasBackgroundImage(group, in: settings) {
                content.append(.edit(.removeBackgroundImage(group)))
            }
            if hasForegroundImage(group, in: settings) {
                content.append(.edit(.removeForegroundImage(group)))
            }
            items.appendSection(content)
        }

        var state: [IconContextItem] = []
        // Badge only, and only when there is a nudge to undo — this row exists
        // for a drag or an arrow press that went too far, so on an untouched
        // badge it would be a no-op.
        if group == .badge, settings.badge.offsetX != 0 || settings.badge.offsetY != 0 {
            state.append(.edit(.resetBadgePosition))
        }
        state.append(.edit(.setGroupHidden(group, !isHidden(group, in: settings))))
        items.appendSection(state)

        return items
    }

    /// The menu for a sidebar row.
    ///
    /// Shorter than the canvas menu, and deliberately not a copy of it: the row
    /// is the *group*, so the rows here are the ones that are about a group
    /// rather than about the icon as a picture. Copy Icon and Export as PNG… stay
    /// on the canvas, which is the thing they act on.
    ///
    /// `Reset` appears here only. It is the group menu's most destructive row and
    /// the canvas menu is already the longer of the two; a right-click on the
    /// artwork is also the likeliest to be a mis-aimed click.
    static func sidebarItems(
        for group: IconLayerGroup,
        settings: IconSettings
    ) -> [IconContextItem] {
        var items: [IconContextItem] = [
            .edit(.setGroupHidden(group, !isHidden(group, in: settings)))
        ]
        if mode(of: group, in: settings) == .mica {
            if hasBackgroundImage(group, in: settings) {
                items.append(.edit(.removeBackgroundImage(group)))
            }
            if hasForegroundImage(group, in: settings) {
                items.append(.edit(.removeForegroundImage(group)))
            }
        }
        items.appendSection([.edit(.resetGroup(group))])
        return items
    }

    // MARK: - Performing an edit

    /// Perform an edit row. Total over `IconContextEdit`, which is the point of
    /// that type existing separately from `IconContextCommand`.
    static func apply(_ edit: IconContextEdit, to settings: inout IconSettings) {
        switch edit {
        case .removeBackgroundImage(let group):
            switch group {
            case .icon:  settings.icon.removeBackgroundImage()
            case .badge: settings.badge.removeBackgroundImage()
            }
        case .removeForegroundImage(let group):
            switch group {
            case .icon:  settings.icon.foreground.removeImage()
            case .badge: settings.badge.foreground.removeImage()
            }
        case .resetBadgePosition:
            settings.badge.offsetX = 0
            settings.badge.offsetY = 0
        case .setGroupHidden(let group, let hidden):
            switch group {
            case .icon:  settings.icon.isHidden = hidden
            case .badge: settings.badge.isHidden = hidden
            }
        case .resetGroup(let group):
            switch group {
            case .icon:  settings.icon.reset()
            case .badge: settings.badge.reset()
            }
        }
    }

    // MARK: - Reading a group

    private static func mode(of group: IconLayerGroup, in settings: IconSettings) -> GenerationMode {
        switch group {
        case .icon:  return settings.icon.mode
        case .badge: return settings.badge.mode
        }
    }

    private static func isHidden(_ group: IconLayerGroup, in settings: IconSettings) -> Bool {
        switch group {
        case .icon:  return settings.icon.isHidden
        case .badge: return settings.badge.isHidden
        }
    }

    /// Whether this group has artwork a Remove row could remove.
    ///
    /// `source == .image` alone is not enough: the inspector's Type picker writes
    /// that before any image is chosen, and in that state the layer falls back to
    /// its colour — so the row would offer to remove something that is not there.
    private static func hasBackgroundImage(_ group: IconLayerGroup, in settings: IconSettings) -> Bool {
        switch group {
        case .icon:
            return settings.icon.background.source == .image && settings.icon.background.image != nil
        case .badge:
            return settings.badge.background.source == .image && settings.badge.background.image != nil
        }
    }

    /// Whether this group's *foreground* is drawing imported artwork rather than a
    /// symbol. Same two-part test as the background's, and for the same reason —
    /// the inspector's Type picker can leave `source == .image` with no image.
    private static func hasForegroundImage(_ group: IconLayerGroup, in settings: IconSettings) -> Bool {
        let foreground = group == .icon ? settings.icon.foreground : settings.badge.foreground
        return foreground.source == .image && foreground.image != nil
    }
}

private extension Array where Element == IconContextItem {
    /// Append a group of rows behind a separator, or nothing at all if the group
    /// is empty — which is what keeps a trailing or doubled `Divider()` out of a
    /// menu whose middle section was gated away.
    mutating func appendSection(_ rows: [IconContextItem]) {
        guard !rows.isEmpty else { return }
        if !isEmpty { append(.separator) }
        append(contentsOf: rows)
    }
}

// MARK: - What the window does for the canvas menu

/// The three canvas rows the settings cannot perform, plus the one fact that
/// decides whether two of them are offered at all.
///
/// One value rather than four parameters on both preview views, because
/// `ContentView.body` sits at the type-checker's ceiling and has been pushed over
/// it four times — every extra argument in that call is a real cost. It is built
/// in a computed property there for the same reason.
/// `Sendable` because `unavailable` is a static let, and a non-`Sendable` one is a
/// concurrency error under Swift 6 — the same reason `UserMessageReporter` is. It
/// gets there differently, though: the closure is `@MainActor` rather than
/// `@Sendable`, because the window's handler reaches `IconViewModel` and the
/// pasteboard, neither of which leaves the main actor. A global-actor-isolated
/// function type is `Sendable` already, and `View.body` is `@MainActor`, so every
/// call site is in the right place by construction.
struct PreviewContextActions: Sendable {
    /// `IconViewModel.canExport`. False withdraws Copy Icon and Export as PNG…
    /// from the menu.
    let canExport: Bool
    let perform: @MainActor (IconContextCommand) -> Void

    /// The default for SwiftUI previews, which have no window behind them.
    ///
    /// **It logs rather than swallowing**, on the same rule as
    /// `UserMessageReporter.unattached`: a neutral default is how a menu row goes
    /// quiet with every call site still looking correct and no test able to tell.
    static let unavailable = PreviewContextActions(canExport: false) { command in
        Logger(subsystem: "com.lukecharters.Mica", category: "ContextMenu")
            .error("No handler installed — dropped \(command.title, privacy: .public)")
    }
}
