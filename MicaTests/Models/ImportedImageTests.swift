// ImportedImageTests.swift
// ImportedImage equality is intentionally identity-based (by UUID), not
// content-based — the identity survives scale/color mutations elsewhere
// in the settings graph.

import Testing
import AppKit
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct ImportedImageTests {

    // MARK: - Helpers

    /// Produces a tiny solid-color PNG as Data. Used to populate ImportedImage
    /// in place of a real bundled asset (keeps tests dependency-free).
    static func makePNGData(
        width: Int = 4,
        height: Int = 4,
        fill: NSColor = .red
    ) -> Data {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        fill.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        return rep.representation(using: .png, properties: [:])!
    }

    // MARK: - ImportedImage equality

    @Test("Two ImportedImages with the same UUID are equal (identity-based equality)")
    func equality_sameUUID() {
        let id = UUID()
        let a = ImportedImage(id: id, imageData: Self.makePNGData(fill: .red),
                              sourceName: "a.png", isFileIcon: false)
        let b = ImportedImage(id: id, imageData: Self.makePNGData(fill: .blue),
                              sourceName: "b.png", isFileIcon: true)
        #expect(a == b)
    }

    @Test("Two ImportedImages with different UUIDs are not equal")
    func equality_differentUUID() {
        let data = Self.makePNGData()
        let a = ImportedImage(id: UUID(), imageData: data,
                              sourceName: "same.png", isFileIcon: false)
        let b = ImportedImage(id: UUID(), imageData: data,
                              sourceName: "same.png", isFileIcon: false)
        #expect(a != b)
    }

    // MARK: - nsImage

    @Test("nsImage decodes the stored PNG data")
    func nsImage_decodesPNG() throws {
        let data = Self.makePNGData(width: 8, height: 12)
        let imported = ImportedImage(
            id: UUID(),
            imageData: data,
            sourceName: "test.png",
            isFileIcon: false
        )
        let decoded = try #require(imported.nsImage)
        #expect(decoded.size.width > 0)
        #expect(decoded.size.height > 0)
    }

    @Test("nsImage is nil for garbage data")
    func nsImage_nilForGarbage() {
        let imported = ImportedImage(
            id: UUID(),
            imageData: Data([0xDE, 0xAD, 0xBE, 0xEF]),
            sourceName: "broken.bin",
            isFileIcon: false
        )
        #expect(imported.nsImage == nil)
    }

    // MARK: - IconSource

    @Test("IconSource has three cases")
    func iconSource_count() {
        #expect(IconSource.allCases.count == 3)
    }

    @Test("IconSource raw values match user-facing labels")
    func iconSource_rawValues() {
        #expect(IconSource.sfSymbol.rawValue == "SF Symbol")
        #expect(IconSource.customImage.rawValue == "Custom Image")
        #expect(IconSource.system.rawValue == "System")
    }

    @Test("IconSource rawValue round-trips", arguments: IconSource.allCases)
    func iconSource_roundTrip(_ source: IconSource) throws {
        let rt = try #require(IconSource(rawValue: source.rawValue))
        #expect(rt == source)
        #expect(rt.id == source.rawValue)
    }
}
