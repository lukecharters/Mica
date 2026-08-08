// DraggableIconTests.swift
//
// DraggableIcon is the drag-out payload (item A1 of the Mac-conventions plan).
// Two things here are worth testing and one is not:
//
// - `sanitizedFileName` is pure and has four named hazards, so it gets a table.
// - `writeTemporaryPNG()` is where the promise is redeemed: the right *name*, the
//   right *bytes*, and a fresh directory per call so two drags cannot collide.
// - The `.draggable` wiring itself is not testable from here — whether a press on
//   the badge moves the badge or drags a file out is gesture arbitration, which has
//   no value-level surface. That is checked by driving the app; see the plan.

import Testing
import AppKit
import UniformTypeIdentifiers
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct DraggableIconTests {

    // MARK: - Helpers

    private static func micaModeIcon(size: CGFloat = 128, baseName: String = "star.fill-mica") -> DraggableIcon {
        var settings = IconSettings()
        settings.export.size = size
        settings.export.isRetina = false
        return DraggableIcon(
            document: PNGExportDocument(settings: settings),
            baseName: baseName
        )
    }

    /// How many `MicaDrag-*` directories exist right now. Used to prove the render is
    /// deferred: building a payload must not create one.
    private static func micaDragDirectoryCount() -> Int {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: URL.temporaryDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents.filter { $0.lastPathComponent.hasPrefix("MicaDrag-") }.count
    }

    /// Pixel width of PNG bytes, read back through ImageIO rather than NSImage —
    /// `NSImage.size` is in points and halves at 2x, which would make a size
    /// assertion quietly wrong.
    private static func pixelWidth(ofPNG data: Data) throws -> Int {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return image.width
    }

    // MARK: - sanitizedFileName

    @Test("An ordinary export base name passes through untouched")
    func sanitize_ordinaryNameUnchanged() {
        #expect(DraggableIcon.sanitizedFileName(for: "star.fill-mica") == "star.fill-mica")
    }

    @Test("Path separators and Finder-hostile characters are replaced", arguments: [
        // A `/` cannot appear in a path component at all — `write(to:)` would fail.
        ("folder/badge-mica", "folder-badge-mica"),
        // Legal in POSIX, but the Finder displays `:` as `/`, which reads as corrupt.
        ("10:30-mica", "10-30-mica"),
        ("a/b:c", "a-b-c"),
    ])
    func sanitize_replacesIllegalCharacters(input: String, expected: String) {
        #expect(DraggableIcon.sanitizedFileName(for: input) == expected)
    }

    @Test("Leading dots and dashes are stripped", arguments: [
        // A leading dot hides the drop in the Finder.
        (".hidden-mica", "hidden-mica"),
        ("...hidden", "hidden"),
        // A leading dash parses as an option to any shell that later meets the file.
        ("-mica", "mica"),
        ("-.star", "star"),
    ])
    func sanitize_stripsLeadingDotsAndDashes(input: String, expected: String) {
        #expect(DraggableIcon.sanitizedFileName(for: input) == expected)
    }

    @Test("A dash inside the name is left alone")
    func sanitize_keepsInteriorDashes() {
        #expect(DraggableIcon.sanitizedFileName(for: "star.fill-mica") == "star.fill-mica")
    }

    @Test("A name with nothing left falls back to Icon, never a bare extension", arguments: [
        // "/" and ":" get here via the replacement above: they become "-", which the
        // leading-dash strip then removes. That ordering is the point.
        "", "   ", "...", "/", ":", "---", "//",
    ])
    func sanitize_fallsBackForEmptyResult(input: String) {
        // A bare ".png" would be a hidden file — the same failure as a leading dot.
        #expect(DraggableIcon.sanitizedFileName(for: input) == "Icon")
    }

    @Test("Surrounding whitespace is trimmed")
    func sanitize_trimsWhitespace() {
        #expect(DraggableIcon.sanitizedFileName(for: "  star.fill  ") == "star.fill")
    }

    // MARK: - Naming handed to the receiver

    @Test("suggestedName is the stem, with no extension")
    func provider_suggestedNameHasNoExtension() {
        let icon = Self.micaModeIcon(baseName: "star.fill-mica")

        // Pinned because getting this wrong is silent and only visible at the
        // receiver: NSItemProvider appends the registered type's extension itself, so
        // a stem of "star.fill-mica.png" lands as "star.fill-mica.png.png".
        #expect(icon.fileNameStem == "star.fill-mica")
        #expect(icon.itemProvider().suggestedName == "star.fill-mica")
        #expect(icon.fileNameStem.hasSuffix(".png") == false)
    }

    @Test("The temporary file keeps the full name, extension included")
    func fileName_includesTheExtension() {
        #expect(Self.micaModeIcon(baseName: "star.fill-mica").fileName == "star.fill-mica.png")
    }

    @Test("The provider registers PNG")
    func provider_registersPNG() {
        #expect(Self.micaModeIcon().itemProvider()
            .registeredTypeIdentifiers.contains(UTType.png.identifier))
    }

    @Test("Building the provider renders nothing — the promise is not redeemed early")
    func provider_doesNotRenderAtDragStart() {
        // Counted, not inspected: a drag that renders on pickup instead of on drop is
        // the difference between "free to start a drag" and "stall the UI whenever the
        // pointer twitches over the canvas", and it is invisible from the outside.
        let before = Self.micaDragDirectoryCount()

        _ = Self.micaModeIcon().itemProvider()

        #expect(Self.micaDragDirectoryCount() == before)
    }

    // MARK: - writeTemporaryPNG

    @Test("The dropped file is named from the sanitized base name")
    func write_namesFileFromBaseName() throws {
        let url = try Self.micaModeIcon(baseName: "folder/star-mica").writeTemporaryPNG()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(url.lastPathComponent == "folder-star-mica.png")
    }

    @Test("The written bytes are exactly what the export document renders")
    func write_bytesMatchTheExportDocument() throws {
        let icon = Self.micaModeIcon()
        let url = try icon.writeTemporaryPNG()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        // The point of the assertion: a drag and ⇧⌘E must not be able to disagree,
        // because both go through PNGExportDocument.pngData(). Same process, same
        // inputs, repeated identical render — so byte equality is sound here, unlike
        // a comparison between two different render paths.
        #expect(try Data(contentsOf: url) == icon.document.pngData())
    }

    @Test("The written file is a PNG at the icon's export pixel size", arguments: [
        CGFloat(64), CGFloat(128), CGFloat(512),
    ])
    func write_producesPNGAtExportSize(size: CGFloat) throws {
        let icon = Self.micaModeIcon(size: size)
        let url = try icon.writeTemporaryPNG()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let data = try Data(contentsOf: url)
        #expect(data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        #expect(try Self.pixelWidth(ofPNG: data) == Int(icon.document.settings.export.pixelSize))
    }

    @Test("A 2x export drags out at twice the point size")
    func write_honoursRetinaScale() throws {
        var settings = IconSettings()
        settings.export.size = 128
        settings.export.isRetina = true
        let icon = DraggableIcon(document: PNGExportDocument(settings: settings), baseName: "star.fill")

        let url = try icon.writeTemporaryPNG()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(try Self.pixelWidth(ofPNG: Data(contentsOf: url)) == 256)
    }

    @Test("Each drag gets its own directory, so two drags of one icon cannot collide")
    func write_usesAFreshDirectoryPerCall() throws {
        let icon = Self.micaModeIcon()
        let first = try icon.writeTemporaryPNG()
        let second = try icon.writeTemporaryPNG()
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        // Same file name — that is the point of the per-drag directory.
        #expect(first.lastPathComponent == second.lastPathComponent)
        #expect(first != second)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }
}
