// App/DraggableIcon.swift
//
// What leaves the app when you drag the preview out — to the Finder, to Slack, to
// an Xcode asset catalog. Added 2026-08-03 as item A1 of
// docs/plans/mac-conventions.md.
//
// **It is a promise, not a render.** `FileRepresentation`'s exporting closure does
// not run when the drag begins; it runs when a receiver accepts the drop. So
// starting a drag costs one struct copy, dragging a 1024px icon around the screen
// renders nothing, and a drag abandoned over the Dock renders nothing either. That
// is the whole reason this is a `FileRepresentation` over a URL rather than a
// `DataRepresentation` over bytes.
//
// The render itself goes through `PNGExportDocument.pngData()`, which is the path
// ⇧⌘E takes. Deliberately: the choice between a Mica render, a bare appex raster
// and an appex raster composited with a badge lives there, and two copies of it
// would mean a drag and a Save panel could disagree about the same settings.
//
// App-only by design — `mica-cli` already writes files, so this never needs to
// join the two `membershipExceptions` lists. See CLAUDE.md, "Adding a file".
import SwiftUI
import UniformTypeIdentifiers

/// A drag-out payload for the rendered icon.
///
/// `@unchecked Sendable` because `Transferable` requires `Sendable` and
/// `PNGExportDocument` carries `NSImage?` (the appex rasters), which is not. The
/// images are finished rasters — produced once by `AppexReferenceService`, then only
/// ever read — and the one place this value is consumed hops to the main actor to do
/// it. Nothing here mutates shared state.
struct DraggableIcon: Transferable, @unchecked Sendable {
    /// The export payload, built at drag start and rendered only if the drop lands.
    let document: PNGExportDocument

    /// Filename stem for the dropped file, before sanitizing. Normally
    /// `IconSettings.exportBaseName`, so a dragged-out file and a ⇧⌘E export of the
    /// same icon arrive under the same name.
    let baseName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { icon in
            SentTransferredFile(try await icon.writeTemporaryPNG())
        }
    }

    /// Render, encode, and write to a uniquely-named temporary directory.
    ///
    /// The file goes in a fresh directory rather than straight into the temporary
    /// directory so its *name* can be exactly `<baseName>.png` — the receiver shows
    /// the name it finds, and two drags of the same icon must not collide over it.
    ///
    /// **Nothing deletes it.** `FileRepresentation` has no completion callback, so
    /// there is no moment at which the file is known to have been copied — deleting it
    /// on any timer risks pulling it out from under a slow receiver. It is one PNG per
    /// completed drag in the container's `tmp`, which the OS reclaims; that is the
    /// right trade against a drop that silently produces an empty file. Verified live:
    /// a drag lands `MicaDrag-<UUID>/command-mica.png` and the receiver gets the bytes.
    ///
    /// `@MainActor` because rendering does: `IconRenderer` is main-actor-isolated,
    /// and the appex compositing path inside `pngData()` asserts it.
    @MainActor
    func writeTemporaryPNG() throws -> URL {
        let data = try document.pngData()
        let directory = URL.temporaryDirectory
            .appending(path: "MicaDrag-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(Self.sanitizedFileName(for: baseName)).png")
        try data.write(to: url)
        return url
    }

    /// Reduce a base name to something legal and visible as a single path component.
    ///
    /// `exportBaseName` derives from an SF Symbol name or an imported file's name, so
    /// it is *mostly* safe — but not reliably:
    ///
    /// - **`/` cannot appear in a path component at all.** POSIX reads it as a
    ///   separator, so `write(to:)` fails rather than producing an oddly-named file.
    /// - **A leading `.` hides the drop.** The file lands, the Finder doesn't show it,
    ///   and the user concludes the drag silently failed.
    /// - **`:` is legal in POSIX but the Finder displays it as `/`**, which reads as a
    ///   corrupt name.
    /// - **A leading `-` makes the file awkward to use from a shell**, where it parses
    ///   as the start of an option. A dropped icon is quite likely to meet a terminal.
    ///
    /// The leading-character strip runs *after* the replacements, which is what makes
    /// a name of pure separators (`"/"`) reduce to nothing rather than to `"-"`.
    /// Anything that reduces to nothing falls back to `Icon`, because a bare `.png` is
    /// itself a hidden file.
    static func sanitizedFileName(for baseName: String) -> String {
        let collapsed = baseName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let visible = collapsed.drop(while: { $0 == "." || $0 == "-" })
        return visible.isEmpty ? "Icon" : String(visible)
    }
}

/// Applies `.draggable` only when there is something correct to drag.
///
/// Two reasons this is a modifier rather than a `.draggable` call at each site:
///
/// 1. **A nil payload must remove the drag, not vend an empty one.** `canExport` is
///    false while a System-mode layer's appex raster is still rendering, and a PNG
///    written in that window silently omits the pending layer — the exact failure
///    `IconViewModel.canExport` exists to prevent for ⇧⌘E. A drag-out is the same
///    export, so it answers to the same rule.
/// 2. The branch changes view identity, so it wants to be in one place where that is
///    visible, and keyed on nothing finer than "can this be dragged at all".
struct IconDragOut: ViewModifier {
    let makePayload: (() -> DraggableIcon)?

    func body(content: Content) -> some View {
        if let makePayload {
            content.draggable(makePayload())
        } else {
            content
        }
    }
}

extension View {
    /// Makes the rendered icon draggable out of the app. `nil` disables the drag —
    /// see `IconDragOut`.
    func iconDragOut(_ makePayload: (() -> DraggableIcon)?) -> some View {
        modifier(IconDragOut(makePayload: makePayload))
    }
}
