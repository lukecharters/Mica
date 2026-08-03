// App/IconPasteboard.swift
//
// Copy: what the rendered icon looks like on the pasteboard. Item A2 of
// docs/plans/mac-conventions.md.
//
// Renders through `PNGExportDocument.resolvedImage()`, the same path ⇧⌘E and the
// drag-out take, so Copy cannot disagree with either about the same settings.
//
// App-only — `mica-cli` has no pasteboard — so this never joins the two
// `membershipExceptions` lists. See CLAUDE.md, "Adding a file".
import AppKit
import UniformTypeIdentifiers

enum IconPasteboard {

    /// Write the icon to a pasteboard as PNG, TIFF and the symbol name.
    ///
    /// **One item carrying three types, not three items.** A receiver reads the richest
    /// type it understands from a single item; three items would read as three separate
    /// things pasted at once, which is what makes an image editor paste three copies.
    ///
    /// The order the types are set is the order they are offered:
    ///
    /// 1. **PNG** — lossless with an alpha channel, which an icon needs. Preview,
    ///    Pixelmator and asset catalogs all take this.
    /// 2. **TIFF** — `NSImage`'s own currency. Older AppKit apps and some Electron
    ///    receivers only look for this, so it is cheap insurance rather than a duplicate.
    /// 3. **The symbol name as a string** — the fallback for somewhere that cannot take
    ///    an image at all, like a terminal or a plain-text editor.
    ///
    /// A rich-text editor offered all three takes the *image*, which is correct
    /// behaviour and not a bug: TextEdit in rich mode pastes the icon, and only in plain
    /// text mode pastes the name. The plan's acceptance note ("into TextEdit gives the
    /// symbol name") is true only of the plain-text case.
    ///
    /// `pasteboard` is a parameter so tests can use a uniquely-named pasteboard instead
    /// of clobbering the user's `.general` while the suite runs.
    @MainActor
    static func write(
        document: PNGExportDocument,
        symbolName: String,
        to pasteboard: NSPasteboard = .general
    ) throws {
        let resolved = try document.resolvedImage()
        let png = try PNGExporter.pngData(from: resolved.image, scaleFactor: resolved.scaleFactor)

        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        // Not guarded with a `throw`: a missing TIFF representation would mean an
        // NSImage that already produced PNG bytes cannot describe itself, and losing
        // one fallback type is not worth failing a Copy the user asked for.
        if let tiff = resolved.image.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }
        item.setString(Self.stringFallback(for: symbolName), forType: .string)

        // clearContents *then* write: a pasteboard is not a queue, and without the
        // clear the previous owner's types survive alongside the new ones — so a
        // receiver can paste a stale image that was never copied this time.
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    /// The text a paste lands in something that cannot take an image.
    ///
    /// Trimmed, and empty falls back to a name rather than writing an empty string —
    /// pasting nothing into a terminal reads as a Copy that failed.
    static func stringFallback(for symbolName: String) -> String {
        let trimmed = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Mica icon" : trimmed
    }
}
