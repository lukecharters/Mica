// App/IconPasteboard.swift
//
// Copy: what the rendered icon looks like on the pasteboard. Item A2 of
// the Mac-conventions plan.
//
// An icon and nothing else. Copying *text* is the standard Copy's job and has
// always worked in Mica's text fields — see `write(document:to:)`.
//
// Renders through `PNGExportDocument.resolvedImage()`, the same path ⇧⌘E and the
// drag-out take, so Copy cannot disagree with either about the same settings.
//
// App-only — `mica-cli` has no pasteboard — so this never joins the two
// `membershipExceptions` lists. See the project notes, "Adding a file".
import AppKit
import UniformTypeIdentifiers

enum IconPasteboard {

    /// Write the icon to a pasteboard as PNG and TIFF.
    ///
    /// **One item carrying two types, not two items.** A receiver reads the richest
    /// type it understands from a single item; separate items would read as separate
    /// things pasted at once, which is what makes an image editor paste two copies.
    ///
    /// The order the types are set is the order they are offered:
    ///
    /// 1. **PNG** — lossless with an alpha channel, which an icon needs. Preview,
    ///    Pixelmator and asset catalogs all take this.
    /// 2. **TIFF** — `NSImage`'s own currency. Older AppKit apps and some Electron
    ///    receivers only look for this, so it is cheap insurance rather than a duplicate.
    ///
    /// **The symbol name is deliberately not offered**, though it was until 2026-08-04.
    /// It existed as a fallback for a receiver that cannot take an image, but the app
    /// already has a better way to put that string on the pasteboard: ⌘C in the Symbol
    /// field, which is the standard Copy and copies exactly the text the user selected.
    /// Offering the name here as well meant one command whose result depended on the
    /// receiver — an icon into Preview, the words `star.fill` into a terminal — which is
    /// a worse thing to explain than a Copy Icon that always copies an icon.
    ///
    /// `pasteboard` is a parameter so tests can use a uniquely-named pasteboard instead
    /// of clobbering the user's `.general` while the suite runs.
    @MainActor
    static func write(
        document: PNGExportDocument,
        to pasteboard: NSPasteboard = .general
    ) throws {
        let item = NSPasteboardItem()
        for representation in try representations(of: document) {
            item.setData(representation.data, forType: representation.type)
        }

        // clearContents *then* write: a pasteboard is not a queue, and without the
        // clear the previous owner's types survive alongside the new ones — so a
        // receiver can paste a stale image that was never copied this time.
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    /// The same icon as one `NSItemProvider`, for the standard Copy command.
    ///
    /// `.onCopyCommand` hands SwiftUI item providers rather than letting us write the
    /// pasteboard, so this is a second *adapter* — but not a second decision: both it
    /// and `write(document:to:)` get their types and their order from
    /// `representations(of:)`, so ⇧⌘C and a focused-canvas ⌘C cannot start offering
    /// different things.
    ///
    /// **Registered eagerly, with the bytes already rendered.** A Copy has already
    /// happened by the time the user looks at it, and a pasteboard holding an
    /// unresolved promise is one a receiver may decline to paste at all.
    @MainActor
    static func itemProvider(document: PNGExportDocument) throws -> NSItemProvider {
        let provider = NSItemProvider()
        for representation in try representations(of: document) {
            provider.registerDataRepresentation(
                forTypeIdentifier: representation.type.rawValue,
                visibility: .all
            ) { completion in
                completion(representation.data, nil)
                return nil
            }
        }
        return provider
    }

    /// Write a symbol *name* — the one string in Mica worth copying on its own.
    ///
    /// This does not contradict the note above about the name being dropped from
    /// `write(document:)`. What was wrong there was one command offering both an
    /// image and a string, so its result depended on the receiver; Copy Symbol Name
    /// in the symbol browser's context menu says what it copies and copies only
    /// that. Item C2 of the Mac-conventions plan.
    ///
    /// No `throws`: a string has no representation that can fail.
    @MainActor
    static func write(symbolName: String, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(symbolName, forType: .string)
    }

    /// What an icon is offered as, richest first. **The one place that decides.**
    ///
    /// Order is the offer order, and it decides what a receiver that understands more
    /// than one of them takes. PNG leads because it is lossless with alpha, which an
    /// icon needs; TIFF follows for older AppKit receivers that look for nothing else.
    ///
    /// The TIFF is not guarded with a `throw`: a missing TIFF representation would mean
    /// an `NSImage` that already produced PNG bytes cannot describe itself, and losing
    /// one fallback type is not worth failing a Copy the user asked for.
    @MainActor
    static func representations(
        of document: PNGExportDocument
    ) throws -> [(type: NSPasteboard.PasteboardType, data: Data)] {
        let resolved = try document.resolvedImage()
        var representations: [(type: NSPasteboard.PasteboardType, data: Data)] = [
            (.png, try PNGExporter.pngData(from: resolved.image, scaleFactor: resolved.scaleFactor)),
        ]
        if let tiff = resolved.image.tiffRepresentation {
            representations.append((.tiff, tiff))
        }
        return representations
    }
}
