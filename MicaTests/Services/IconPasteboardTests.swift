// IconPasteboardTests.swift
//
// Copy (item A2 of the Mac-conventions plan). What matters here is what a
// *receiver* finds, which is the thing the drag-out taught us assertions can miss:
// correct bytes under a wrong description is a passing test and a broken feature.
//
// Every test writes to a uniquely-named pasteboard, never `.general` — a suite that
// clobbers the user's clipboard while it runs is its own bug, and parallel tests
// sharing `.general` would race.

import Testing
import AppKit
import UniformTypeIdentifiers
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct IconPasteboardTests {

    // MARK: - Helpers

    /// A scratch pasteboard, released at the end of the test.
    private static func scratchPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("mica.tests.\(UUID().uuidString)"))
    }

    private static func micaDocument(size: CGFloat = 128) -> PNGExportDocument {
        var settings = IconSettings()
        settings.export.size = size
        settings.export.isRetina = false
        return PNGExportDocument(settings: settings)
    }

    // MARK: - What lands on the pasteboard

    @Test("Copy offers PNG and TIFF from one item")
    func write_offersBothImageTypes() throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }

        try IconPasteboard.write(document: Self.micaDocument(), to: pasteboard)

        let items = try #require(pasteboard.pasteboardItems)
        // One item, not two: separate items read as separate things pasted at once,
        // which makes an image editor paste two copies.
        #expect(items.count == 1)
        let types = items[0].types
        #expect(types.contains(.png))
        #expect(types.contains(.tiff))
    }

    @Test("Copy offers no text at all")
    func write_offersNoString() throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }

        try IconPasteboard.write(document: Self.micaDocument(), to: pasteboard)

        // The symbol name was offered here until 2026-08-04. It was dropped because
        // ⌘C in the Symbol field is the standard Copy and already puts that text on
        // the pasteboard — so this command's result no longer depends on what the
        // receiver happens to understand. A regression would be quiet: pasting into
        // Preview looks identical either way, and only a plain-text target would show
        // the difference.
        #expect(!(pasteboard.pasteboardItems?.first?.types.contains(.string) ?? false))
        #expect(pasteboard.string(forType: .string) == nil)
    }

    @Test("PNG is offered ahead of TIFF")
    func write_ordersPNGFirst() throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }

        try IconPasteboard.write(document: Self.micaDocument(), to: pasteboard)

        // Order is the offer order, and it decides what a receiver that understands
        // both of them takes. PNG first because it is lossless with alpha, which an
        // icon needs; a receiver that took TIFF instead would still work, but it would
        // be the second-best answer to a question we get to choose.
        let types = try #require(pasteboard.pasteboardItems?.first?.types)
        let png = try #require(types.firstIndex(of: .png))
        let tiff = try #require(types.firstIndex(of: .tiff))
        #expect(png < tiff)
    }

    @Test("The PNG on the pasteboard is the icon at its export size", arguments: [
        CGFloat(64), CGFloat(256),
    ])
    func write_pngIsTheRenderedIcon(size: CGFloat) throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let document = Self.micaDocument(size: size)

        try IconPasteboard.write(document: document, to: pasteboard)

        let data = try #require(pasteboard.data(forType: .png))
        // Identical to what ⇧⌘E would write, because both go through
        // PNGExportDocument. Byte equality is sound here: one document, same process,
        // repeated identical render.
        #expect(data == (try document.pngData()))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == Int(size))
    }

    @Test("A receiver reading the pasteboard as an image gets a real one")
    func write_readsBackAsNSImage() throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }

        try IconPasteboard.write(document: Self.micaDocument(size: 128), to: pasteboard)

        // The end-to-end shape of what Preview.app does. `canReadObject` alone would
        // pass on a declared-but-empty type, so the image is actually constructed.
        #expect(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))
        let images = try #require(pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage])
        let image = try #require(images.first)
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @Test("Copying twice leaves only the second icon")
    func write_clearsThePreviousContents() throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let second = Self.micaDocument(size: 128)

        try IconPasteboard.write(document: Self.micaDocument(size: 64), to: pasteboard)
        try IconPasteboard.write(document: second, to: pasteboard)

        // Without clearContents the previous owner's types survive alongside the new
        // ones, and a receiver can paste something that was never copied this time.
        // The two sizes are what makes that visible now the string is gone — same-size
        // renders are byte-identical, so a leaked first item would be undetectable.
        #expect(pasteboard.pasteboardItems?.count == 1)
        #expect(pasteboard.data(forType: .png) == (try second.pngData()))
    }

    // MARK: - representations: the one place that decides

    @Test("PNG leads, and its bytes are the export's")
    func representations_leadWithThePNGExport() throws {
        let document = Self.micaDocument(size: 128)

        let representations = try IconPasteboard.representations(of: document)

        #expect(representations.map(\.type) == [.png, .tiff])
        #expect(representations.first?.data == (try document.pngData()))
    }

    // MARK: - itemProvider: the standard Copy's adapter

    @Test("The copy-command provider advertises the same types in the same order")
    func itemProvider_matchesTheWrittenTypes() throws {
        let document = Self.micaDocument(size: 128)

        let provider = try IconPasteboard.itemProvider(document: document)

        // Both routes to the pasteboard read `representations(of:)`, so this is really
        // asserting that neither has grown its own list. ⌘C on the focused canvas and
        // ⇧⌘C offering different types would be invisible until someone pasted into a
        // receiver that only understands one of them.
        #expect(provider.registeredTypeIdentifiers == [UTType.png.identifier, UTType.tiff.identifier])
    }

    @Test("The copy-command provider resolves to the icon at its export size")
    func itemProvider_resolvesToTheRenderedIcon() async throws {
        let document = Self.micaDocument(size: 128)

        let provider = try IconPasteboard.itemProvider(document: document)
        // Hand-wrapped rather than awaited directly: `loadDataRepresentation` returns a
        // `Progress`, so Swift does not bridge it into an async call.
        let loaded: Data? = try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }

        // Registered eagerly, unlike the drag-out's promise: a Copy has already happened
        // by the time the user looks at it. A provider that declared the type and
        // resolved to nothing would satisfy `itemProvider_matchesTheWrittenTypes` and
        // paste nothing, so the data has to be decoded here.
        //
        // **Not byte-compared against `document.pngData()`**, though the two are the
        // same render: `NSItemProvider` does not hand back the bytes it was given for
        // `public.png`. Measured 2026-08-04 — identical length (9511 B) and different
        // content, so it re-encodes rather than passing the buffer through. Dimensions
        // are the property that matters and the one that survives the round trip.
        let data = try #require(loaded)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 128)
        #expect(image.height == 128)
    }
}
