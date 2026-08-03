// IconPasteboardTests.swift
//
// Copy (item A2 of docs/plans/mac-conventions.md). What matters here is what a
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

    @Test("Copy offers PNG, TIFF and a string from one item")
    func write_offersAllThreeTypes() throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }

        try IconPasteboard.write(document: Self.micaDocument(), symbolName: "star.fill", to: pasteboard)

        let items = try #require(pasteboard.pasteboardItems)
        // One item, not three: three items read as three separate things pasted at
        // once, which makes an image editor paste three copies.
        #expect(items.count == 1)
        let types = items[0].types
        #expect(types.contains(.png))
        #expect(types.contains(.tiff))
        #expect(types.contains(.string))
    }

    @Test("PNG is offered ahead of TIFF and the string")
    func write_ordersPNGFirst() throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }

        try IconPasteboard.write(document: Self.micaDocument(), symbolName: "star.fill", to: pasteboard)

        // Order is the offer order, and it decides what a receiver that understands
        // more than one of them takes. PNG first because it is lossless with alpha,
        // which an icon needs; a receiver that took TIFF instead would still work, but
        // a receiver that took the *string* because it came first would paste the words
        // "star.fill" where the user expected a picture.
        let types = try #require(pasteboard.pasteboardItems?.first?.types)
        let png = try #require(types.firstIndex(of: .png))
        let tiff = try #require(types.firstIndex(of: .tiff))
        let string = try #require(types.firstIndex(of: .string))
        #expect(png < tiff)
        #expect(png < string)
    }

    @Test("The PNG on the pasteboard is the icon at its export size", arguments: [
        CGFloat(64), CGFloat(256),
    ])
    func write_pngIsTheRenderedIcon(size: CGFloat) throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let document = Self.micaDocument(size: size)

        try IconPasteboard.write(document: document, symbolName: "star.fill", to: pasteboard)

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

        try IconPasteboard.write(document: Self.micaDocument(size: 128), symbolName: "star.fill", to: pasteboard)

        // The end-to-end shape of what Preview.app does. `canReadObject` alone would
        // pass on a declared-but-empty type, so the image is actually constructed.
        #expect(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))
        let images = try #require(pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage])
        let image = try #require(images.first)
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @Test("The string fallback is the symbol name")
    func write_stringIsTheSymbolName() throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }

        try IconPasteboard.write(document: Self.micaDocument(), symbolName: "folder.badge.plus", to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "folder.badge.plus")
    }

    @Test("Copying twice leaves only the second icon", arguments: [CGFloat(64)])
    func write_clearsThePreviousContents(size: CGFloat) throws {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }

        try IconPasteboard.write(document: Self.micaDocument(size: size), symbolName: "first", to: pasteboard)
        try IconPasteboard.write(document: Self.micaDocument(size: size), symbolName: "second", to: pasteboard)

        // Without clearContents the previous owner's types survive alongside the new
        // ones, and a receiver can paste something that was never copied this time.
        #expect(pasteboard.pasteboardItems?.count == 1)
        #expect(pasteboard.string(forType: .string) == "second")
    }

    // MARK: - stringFallback

    @Test("An empty symbol name still writes something pasteable", arguments: ["", "   ", "\n"])
    func stringFallback_neverEmpty(name: String) {
        // Pasting nothing into a terminal reads as a Copy that failed.
        #expect(IconPasteboard.stringFallback(for: name) == "Mica icon")
    }

    @Test("A symbol name is trimmed, not otherwise altered")
    func stringFallback_trims() {
        #expect(IconPasteboard.stringFallback(for: "  star.fill  ") == "star.fill")
    }
}
