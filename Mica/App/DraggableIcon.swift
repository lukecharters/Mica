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
// join the two `membershipExceptions` lists. See NOTES.md, "Adding a file".
import SwiftUI
import UniformTypeIdentifiers

/// A drag-out payload for the rendered icon.
///
/// **This vends an `NSItemProvider` rather than conforming to `Transferable`, and the
/// reason is the file name.** Both were tried live on 2026-08-03:
///
/// | Approach | Bytes | Name at the receiver |
/// |---|---|---|
/// | `.draggable` + `FileRepresentation` | correct | `PNG image.png` |
/// | …with `allowAccessingOriginalFile: true` | correct | `PNG image.png` |
/// | `.onDrag` + `suggestedName` including `.png` | correct | `command-mica.png.png` |
/// | `.onDrag` + `suggestedName` as the stem | correct | `command-mica.png` |
///
/// SwiftUI's `Transferable` advertises the payload as `public.png` data as well as a
/// file, and the Finder takes the data — then names it the way it names any dropped
/// image, discarding the URL's last path component. `NSItemProvider.suggestedName` is
/// the only knob either API exposes that the Finder actually honours.
///
/// The failure mode is worth remembering because of how quiet it is: the drop
/// succeeds, the pixels are right, the bytes match the promise by SHA-256, and
/// **every content-level assertion passes**. Only the name is wrong, and an icon
/// generator that drops `PNG image.png` into an asset catalog has failed at the
/// point of the feature.
///
/// `@unchecked Sendable` because the promise's load handler hops to the main actor to
/// render, which requires capturing this value, and `PNGExportDocument` carries
/// `NSImage?` (the appex rasters). Those are finished rasters — produced once by
/// `AppexReferenceService`, thereafter only read — and nothing here mutates shared
/// state.
struct DraggableIcon: @unchecked Sendable {
    /// The export payload, built at drag start and rendered only if the drop lands.
    let document: PNGExportDocument

    /// Filename stem for the dropped file, before sanitizing. Normally
    /// `IconSettings.exportBaseName`, so a dragged-out file and a ⇧⌘E export of the
    /// same icon arrive under the same name.
    let baseName: String

    /// The name the dropped file arrives under, **without** its extension.
    ///
    /// `NSItemProvider.suggestedName` wants the stem: it appends the extension for the
    /// registered type identifier itself. Handing it `"command-mica.png"` produced
    /// `command-mica.png.png` at the receiver (observed 2026-08-03).
    var fileNameStem: String {
        Self.sanitizedFileName(for: baseName)
    }

    /// The full name for the temporary file the promise writes.
    var fileName: String {
        "\(fileNameStem).png"
    }

    /// A promise for the rendered PNG, named so the receiver keeps the name.
    ///
    /// Still a promise: `registerFileRepresentation`'s load handler runs when a
    /// receiver accepts the drop, so a drag that is started and abandoned renders
    /// nothing.
    @MainActor
    func itemProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        // The whole point — see the type's doc comment. Stem only, no extension.
        provider.suggestedName = fileNameStem
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.png.identifier,
            fileOptions: [],
            visibility: .all
        ) { completion in
            Task { @MainActor in
                do {
                    completion(try self.writeTemporaryPNG(), false, nil)
                } catch {
                    // Surfaced to the receiver rather than swallowed; a failed promise
                    // must not hand over a zero-byte PNG that looks like a real one.
                    completion(nil, false, error)
                }
            }
            return nil
        }
        return provider
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
        let url = directory.appending(path: fileName)
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

/// Makes a view a drag source for the rendered icon, when there is something correct
/// to drag.
///
/// Two reasons this is a modifier rather than an `.onDrag` call at each site:
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
            // `.onDrag`, not `.draggable` — the file name is the reason. See
            // `DraggableIcon`'s doc comment for the three variants that were measured.
            // The drag preview is SwiftUI's own snapshot of the modified view, which
            // for the icon layer is exactly the right picture.
            content.onDrag { makePayload().itemProvider() }
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
