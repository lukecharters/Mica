// App/PreviewDrop.swift
//
// What happens when something is dragged onto the canvas or a sidebar row: which
// layer it lands on, what the preview outlines while the drag is over it, and how
// a drag provider becomes an `ImportedImage`. Item B4 of the Mac-conventions plan;
// layer-aware routing and the sidebar rows since 2026-10-11.
//
// Split out of `ScaledIconPreview` so the routing decision is testable — the
// provider plumbing below is not, but the geometry and the type matching are,
// and those are the parts that can be wrong quietly.
//
// App-only on purpose: a drag does not exist in the CLI, so this file stays out
// of `Models/` and `Services/` and off both `membershipExceptions` lists.

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A drag Mica accepted and then could not read.
///
/// Distinct from `ImageImportError` because it is about the *drag* rather than
/// the image: the provider advertised a representation and failed to produce
/// one, which is the sender's problem and not the file's. `ImageImportError`
/// also lives in shared code the CLI compiles, where no drag exists.
enum PreviewDropError: LocalizedError {
    case unreadableItem

    var errorDescription: String? {
        switch self {
        case .unreadableItem:
            return "The dragged item couldn’t be read."
        }
    }
}

enum PreviewDrop {

    // MARK: - Routing

    /// The layer a drop at `point` acts on, in the same `displaySize` square
    /// canvas `PreviewHitTester` works in.
    ///
    /// Routing goes through `PreviewHitTester` rather than growing a second
    /// answer to "which layer is under the pointer?" — the review's own
    /// condition on this item, and the reason a drop cannot disagree with what a
    /// click selects.
    ///
    /// - **With the advanced controls on, the drop lands on the layer under the
    ///   pointer**, foreground included. Until 2026-10-11 every drop was narrowed
    ///   to its group's background, because routing to a foreground meant guessing
    ///   that an image was meant as a symbol. The hover-weight outline that now
    ///   tracks the drag removes the guess: the user sees which layer will take
    ///   the image before letting go.
    /// - **With them off, it is still always a background.** The simple pane edits
    ///   each group as one thing and draws no outlines, so there would be nothing
    ///   to say a foreground was about to be replaced.
    /// - **A miss is the icon background** either way. The canvas margin and the
    ///   chiclet's rounded corners hit nothing, and a drop there lands where every
    ///   drop did before item B4, so the habit survives.
    ///
    /// Hidden layers are never hit, so a drop cannot land on one; it falls through
    /// to whatever is drawn beneath it.
    static func target(
        at point: CGPoint,
        settings: IconSettings,
        displaySize: CGFloat,
        advancedControlsEnabled: Bool
    ) -> PreviewHitTarget {
        guard let hit = PreviewHitTester.target(at: point, settings: settings, displaySize: displaySize) else {
            return .iconBackground
        }
        guard advancedControlsEnabled else { return background(of: hit.group) }
        return hit
    }

    /// The layer a drop on a sidebar row acts on, or nil when the row refuses it.
    ///
    /// - A **layer row** names its layer exactly, so the drop lands there. Layer
    ///   rows only exist with the advanced controls on.
    /// - A **group row**, and the badge's **Layout** row, land on the group's
    ///   background — the same rule the simple-mode canvas applies, and the only
    ///   layer an arbitrary image can always fill.
    ///
    /// Refused, so the drag snaps back rather than landing somewhere unseen:
    ///
    /// - **a hidden target layer**, which the canvas skips too (and the badge
    ///   starts hidden, so a badge drop needs the badge turned on first);
    /// - **a System-mode icon**, whose canvas (`AppexPreviewPane`) takes no drop
    ///   either. A System-mode badge is allowed, because the Mica canvas already
    ///   routes a drop on it to its background.
    static func target(
        for row: LayerSidebarRow,
        settings: IconSettings,
        advancedControlsEnabled: Bool
    ) -> PreviewHitTarget? {
        let group = row.group
        if group == .icon, settings.icon.mode == .system { return nil }

        let target: PreviewHitTarget
        switch row.tab {
        case .foreground? where advancedControlsEnabled:
            target = group == .icon ? .iconForeground : .badgeForeground
        default:
            target = background(of: group)
        }
        return isHidden(target, in: settings) ? nil : target
    }

    /// What the preview outlines while a drag is over `target`: the same answer
    /// the hover would give for that layer, minus the inspector gates.
    ///
    /// The hover outline hides while the Export tab is showing or the inspector is
    /// closed, because then no layer is being edited. A drag is different — the
    /// outline is the only thing saying where the image will land — so only the
    /// advanced-controls gate applies, which is the one that also decides routing.
    static func outline(
        for target: PreviewHitTarget,
        settings: IconSettings,
        advancedControlsEnabled: Bool
    ) -> PreviewSelection? {
        let isSystem: Bool
        switch target.group {
        case .icon:  isSystem = settings.icon.mode == .system
        case .badge: isSystem = settings.badge.mode == .system
        }
        return PreviewSelection.from(
            group: target.group,
            tab: target.tab,
            isSystem: isSystem,
            advancedControlsEnabled: advancedControlsEnabled
        )
    }

    private static func background(of group: IconLayerGroup) -> PreviewHitTarget {
        group == .icon ? .iconBackground : .badgeBackground
    }

    private static func isHidden(_ target: PreviewHitTarget, in settings: IconSettings) -> Bool {
        switch target {
        case .iconForeground:  return settings.icon.foreground.isHidden
        case .iconBackground:  return settings.icon.background.isHidden
        case .badgeForeground: return !settings.badge.isVisible || settings.badge.foreground.isHidden
        case .badgeBackground: return !settings.badge.isVisible || settings.badge.background.isHidden
        }
    }

    /// Apply a dropped image to the layer `target` names.
    ///
    /// A background goes through `applyBackgroundImage`, like every background
    /// import; a foreground through `ImageImportAction.applyForeground`, like the
    /// Import as… and Paste as… items.
    ///
    /// `defaults` is a parameter rather than a call to `.fromPreferences()` so a
    /// test can pin the fixed rule; the view passes the preference.
    static func apply(
        _ image: ImportedImage,
        to target: PreviewHitTarget,
        in settings: inout IconSettings,
        defaults: ImportDefaults = .fixed
    ) {
        switch target.tab {
        case .foreground:
            ImageImportAction.applyForeground(image, to: target.group, in: &settings)
        default:
            ImageImportAction.applyBackground(image, to: target.group, in: &settings, defaults: defaults)
        }
    }

    // MARK: - Accepting a drop

    /// Load the first readable provider and apply it to `target`. Shared by the
    /// canvas and the sidebar rows, so the two cannot treat a drop differently.
    ///
    /// - Returns: whether the drop was *accepted* — whether anything here can
    ///   read it. That is the only question a drop destination is asking, and it
    ///   has to be answered now: the import is asynchronous, so success is not
    ///   known yet. An unreadable drag is refused by the system's own snap-back,
    ///   and one we can read but fail to import surfaces as an alert (B3).
    ///
    /// `target` is resolved by the caller from the geometry as it was when the
    /// drop landed — not inside the task below, which resumes after an arbitrary
    /// delay while a file promise is fulfilled and could route by a badge that
    /// has moved.
    ///
    /// Deliberately does *not* select the layer: that would point the inspector
    /// at it and force the panel open, and a drop is a content action rather than
    /// a navigation one. The artwork appearing is the feedback.
    @MainActor
    static func accept(
        _ providers: [NSItemProvider],
        onto target: PreviewHitTarget,
        settings: Binding<IconSettings>,
        reporter: UserMessageReporter
    ) -> Bool {
        guard let provider = providers.first(where: canRead) else { return false }
        let itemCount = providers.count

        Task { @MainActor in
            do {
                let imported = try await load(provider)
                // Padding compensation on (fill the frame) and shadow off come from
                // the background's own `apply`. The other two import defaults —
                // foreground hidden, corner radius off — are preferences, hence
                // `.fromPreferences()`.
                apply(imported, to: target, in: &settings.wrappedValue, defaults: .fromPreferences())
                if itemCount > 1 {
                    reporter.report(.onlyFirstDroppedItemUsed(count: itemCount, name: imported.sourceName))
                }
            } catch {
                reporter.report(.imageImportFailed(error))
            }
        }
        return true
    }

    // MARK: - Reading a provider

    /// The provider's first registered type that is an image.
    ///
    /// Matched by *conformance* to `.image` rather than by asking the provider
    /// for `public.image` directly: `loadFileRepresentation` wants a concrete
    /// identifier the sender actually registered, and an abstract supertype is
    /// not guaranteed to resolve to one. Takes the identifier list rather than
    /// the provider so it can be tested without building an `NSItemProvider`.
    ///
    /// An unknown identifier — a sender's private type — yields no `UTType` and
    /// is skipped rather than assumed.
    static func imageTypeIdentifier(among identifiers: [String]) -> String? {
        identifiers.first { UTType($0)?.conforms(to: .image) == true }
    }

    /// Whether this provider carries something the importer can use. Mirrors the
    /// branches of `load(_:completion:)` exactly, so a provider that passes here
    /// cannot fall through there.
    static func canRead(_ provider: NSItemProvider) -> Bool {
        provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            || imageTypeIdentifier(among: provider.registeredTypeIdentifiers) != nil
    }

    /// Turn a drag provider into an `ImportedImage`.
    ///
    /// Two branches, and the order matters:
    ///
    /// 1. **A file URL**, preferred whenever one is offered. It costs no copy, it
    ///    keeps the file's real name for `sourceName`, and it is the only branch
    ///    that reaches `extractFileIcon` — so dropping an app bundle, or any
    ///    other file `NSImage` cannot read, still imports its Finder icon.
    /// 2. **Anything image-shaped**, via `loadFileRepresentation`. That one call
    ///    covers both raw data and a file *promise*: for a promise it triggers
    ///    fulfilment, and for data it materialises a temp file named from the
    ///    sender's `suggestedName`, so the artwork arrives with a name rather
    ///    than as "Dropped Image".
    ///
    /// **The import must finish inside the completion handler**, which is why
    /// both branches resume the continuation with an already-imported value
    /// rather than with a URL. `loadFileRepresentation` deletes its temp file as
    /// soon as the handler returns, so awaiting anything before reading it would
    /// race the delete and fail intermittently.
    /// `@MainActor` because an `NSItemProvider` handed over by a drop is
    /// main-actor isolated and a `@concurrent` signature would have to send it.
    /// It costs nothing: this function only *starts* the load, and the decode
    /// happens inside `NSItemProvider`'s own callback, which arrives on a
    /// background queue whatever actor asked for it.
    @MainActor
    static func load(_ provider: NSItemProvider) async throws -> ImportedImage {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return try await withCheckedThrowingContinuation { continuation in
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        continuation.resume(throwing: error ?? PreviewDropError.unreadableItem)
                        return
                    }
                    continuation.resume(with: Result { try ImageImportService.importFromURL(url) })
                }
            }
        }

        guard let identifier = imageTypeIdentifier(among: provider.registeredTypeIdentifiers) else {
            throw PreviewDropError.unreadableItem
        }

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, error in
                guard let url else {
                    continuation.resume(throwing: error ?? PreviewDropError.unreadableItem)
                    return
                }
                continuation.resume(with: Result { try ImageImportService.importFromURL(url) })
            }
        }
    }
}

// MARK: - Drop destination

/// The drop destination for the canvas and for each sidebar row.
///
/// A `DropDelegate` rather than `.onDrop(of:isTargeted:)` because the outline has
/// to follow the drag: **`.onContinuousHover` reports nothing while a drag session
/// is in progress**, so the hover outline cannot see a drag, and `isTargeted` only
/// says that one is somewhere over the view. `dropUpdated` reports the location on
/// every move, which is what lets the outline name the layer under the pointer.
struct LayerDropDelegate: DropDelegate {
    /// The layer a drop at this location would land on, or nil to refuse it.
    /// The location is in the destination view's own coordinates.
    let target: (CGPoint) -> PreviewHitTarget?
    /// The layer under the drag as it moves; nil when it leaves or lands.
    let onTarget: (PreviewHitTarget?) -> Void
    /// Accepts the drop onto the resolved layer. See `PreviewDrop.accept`.
    let perform: ([NSItemProvider], PreviewHitTarget) -> Bool
    /// Whether a drag is over the view at all, for the canvas's accent ring.
    var isTargeted: Binding<Bool>? = nil

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: ImageImportService.allDropTypes) && target(info.location) != nil
    }

    func dropEntered(info: DropInfo) {
        isTargeted?.wrappedValue = true
        onTarget(target(info.location))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let resolved = target(info.location)
        onTarget(resolved)
        return DropProposal(operation: resolved == nil ? .forbidden : .copy)
    }

    func dropExited(info: DropInfo) {
        isTargeted?.wrappedValue = false
        onTarget(nil)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted?.wrappedValue = false
        onTarget(nil)
        guard let resolved = target(info.location) else { return false }
        return perform(info.itemProviders(for: ImageImportService.allDropTypes), resolved)
    }
}
