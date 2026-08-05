// App/PreviewDrop.swift
//
// What happens when something is dragged onto the canvas: which layer it lands
// on, and how a drag provider becomes an `ImportedImage`. Item B4 of
// `docs/plans/mac-conventions.md`.
//
// Split out of `ScaledIconPreview` so the routing decision is testable — the
// provider plumbing below is not, but the geometry and the type matching are,
// and those are the parts that can be wrong quietly.
//
// App-only on purpose: a drag does not exist in the CLI, so this file stays out
// of `Models/` and `Services/` and off both `membershipExceptions` lists.

import Foundation
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
    /// Two deliberate narrowings of what the hit tester returns:
    ///
    /// - **Always a background.** An import applies as its group's background —
    ///   that is what `applyBackgroundImage` does, and the only layer an
    ///   arbitrary image can fill. So a drop on the badge *glyph* replaces the
    ///   badge background, exactly as Edit ▸ Paste as Badge Background does.
    ///   Routing to a foreground would mean guessing that a dropped image is
    ///   meant as a symbol, which the four Import as… items already ask
    ///   explicitly.
    /// - **A miss is the icon.** The canvas margin and the chiclet's rounded
    ///   corners hit nothing, and a drop there still lands on the icon
    ///   background — which is what every drop did before this item, so the
    ///   habit survives the change.
    static func target(
        at point: CGPoint,
        settings: IconSettings,
        displaySize: CGFloat
    ) -> PreviewHitTarget {
        let hit = PreviewHitTester.target(at: point, settings: settings, displaySize: displaySize)
        return hit?.group == .badge ? .badgeBackground : .iconBackground
    }

    /// Apply a dropped image to the layer `target` names.
    ///
    /// `defaults` is a parameter rather than a call to `.fromPreferences()` so a
    /// test can pin the fixed rule; the view passes the preference.
    static func apply(
        _ image: ImportedImage,
        to target: PreviewHitTarget,
        in settings: inout IconSettings,
        defaults: ImportDefaults = .fixed
    ) {
        switch target.group {
        case .icon:  settings.icon.applyBackgroundImage(image, defaults: defaults)
        case .badge: settings.badge.applyBackgroundImage(image, defaults: defaults)
        }
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
