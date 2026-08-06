// App/ImageImportAction.swift
//
// Pasting an image into a layer, in one place. Extracted from `MicaApp`'s
// `pasteImage` helper when the canvas context menu (item C2 of
// `docs/plans/mac-conventions.md`) became its second caller.
//
// The extraction is the point rather than a tidy-up. B3's note on the eight
// import commands says converging error handling could have replaced eight copies
// with eight other copies, and that the helpers are what stop the next import
// command being written with a ninth spelling. A context menu row that pasted an
// image *and* decided for itself what an empty pasteboard means would be exactly
// that ninth spelling — in a surface where the difference is invisible until
// someone right-clicks with nothing copied.
//
// App-only: `mica-cli` has no pasteboard.

import Foundation

enum ImageImportAction {

    /// Read an image off the pasteboard and hand it to `apply`.
    ///
    /// `apply` is the only thing that differs between the paste sites — which
    /// layer of which group the image lands on.
    ///
    /// Nothing happens to `settings` when the pasteboard holds no image, and the
    /// user is told so: `ImageImportService.importFromPasteboard()` returns nil
    /// rather than throwing, because an empty pasteboard is not a failure, and
    /// before `UserMessage.nothingToPaste` existed the four Paste as… items did
    /// nothing whatever — indistinguishable from a command that had not run.
    @MainActor
    static func paste(
        into settings: inout IconSettings,
        reporter: UserMessageReporter,
        apply: (inout IconSettings, ImportedImage) -> Void
    ) {
        do {
            guard let imported = try ImageImportService.importFromPasteboard() else {
                reporter.report(.nothingToPaste)
                return
            }
            apply(&settings, imported)
        } catch {
            reporter.report(.imageImportFailed(error))
        }
    }

    /// Apply a pasted image as a group's background, with the import defaults the
    /// user's preferences ask for.
    ///
    /// Routes through `applyBackgroundImage`, which is the rule for **every**
    /// background import — the File and Edit menus, the inspector, the canvas
    /// drop, the CLI and the configuration decoder all go through it, and leaving
    /// one out is the failure mode. A context menu is no exception.
    static func applyBackground(
        _ image: ImportedImage,
        to group: IconLayerGroup,
        in settings: inout IconSettings,
        defaults: ImportDefaults = .fixed
    ) {
        switch group {
        case .icon:  settings.icon.applyBackgroundImage(image, defaults: defaults)
        case .badge: settings.badge.applyBackgroundImage(image, defaults: defaults)
        }
    }
}
