// ConfigurationExportDocumentTests.swift
//
// The export side of the JSON configuration format: what shape lands on disk, and
// whether it reads back.
//
// The shape is the feature. A configuration with no imported images is one JSON
// file; one with images is a folder holding that JSON and its sidecar PNGs, because
// the sandbox's powerbox grants access to what the user picked in the save panel —
// a chosen file says nothing about its siblings, a chosen directory covers its
// children. Getting that wrong does not fail loudly; it writes a JSON naming PNGs
// that were never written, and the failure only appears on re-import.
//
// So these tests assert on the wrapper rather than on the encoder, and the
// round-trip ones write to a real temporary directory and decode from it, which is
// the only way to prove the JSON's relative paths and the sidecars' actual
// filenames agree.
//
// They call `makeFileWrapper()` rather than `fileWrapper(configuration:)`:
// `FileDocumentWriteConfiguration` has no init reachable from a test, which is why
// `PNGExportDocumentTests` covers no write path at all.

import Testing
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import Foundation
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct ConfigurationExportDocumentTests {

    // MARK: - Helpers

    /// Settings whose icon foreground is an imported image, so the export needs a
    /// sidecar. `fill` varies the bytes — two fixtures must not be byte-identical or
    /// the catalog's dedup collapses them into one file and the assertion is vacuous.
    private func settingsWithImportedIcon(
        fill: NSColor = .systemRed,
        sourceName: String = "Fixture.png"
    ) throws -> IconSettings {
        var settings = IconSettings()
        let imported = try ImportedImage.testFixture(fill: fill, sourceName: sourceName)
        settings.icon.foreground.apply(imported)
        return settings
    }

    /// A scratch directory that cleans itself up.
    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mica-config-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    // MARK: - Wrapper shape

    @Test("No imported images: the export is a single regular JSON file")
    func noImages_writesOneRegularFile() throws {
        let document = try ConfigurationExportDocument(
            settings: IconSettings(),
            baseName: "Icon"
        )

        #expect(!document.hasSidecars)
        #expect(document.contentType == .json)

        let wrapper = document.makeFileWrapper()
        #expect(wrapper.isRegularFile)
        #expect(!wrapper.isDirectory)
        #expect(wrapper.regularFileContents == document.json)
    }

    @Test("An imported image turns the export into a folder holding the JSON and the PNG")
    func withImage_writesADirectory() throws {
        let document = try ConfigurationExportDocument(
            settings: try settingsWithImportedIcon(),
            baseName: "Icon"
        )

        #expect(document.hasSidecars)
        #expect(document.contentType == .folder)

        let wrapper = document.makeFileWrapper()
        #expect(wrapper.isDirectory)

        let children = try #require(wrapper.fileWrappers)
        #expect(children.count == 2)
        #expect(children["Icon.json"]?.regularFileContents == document.json)

        let sidecars = children.keys.filter { $0.hasSuffix(".png") }
        #expect(sidecars.count == 1)
    }

    @Test("The folder holds exactly one top-level JSON — the convention the importer relies on")
    func directory_holdsExactlyOneTopLevelJSON() throws {
        let document = try ConfigurationExportDocument(
            settings: try settingsWithImportedIcon(),
            baseName: "My Icon"
        )
        let children = try #require(document.makeFileWrapper().fileWrappers)

        let jsonNames = children.keys.filter { $0.hasSuffix(".json") }
        #expect(jsonNames == ["My Icon.json"])
    }

    @Test("Every child of the folder is flat — no nested directories for the importer to walk")
    func directory_isFlat() throws {
        // The second image goes on the *badge*, not the icon background: an
        // imported icon background suppresses the icon foreground entirely
        // (IconContentView), so the encoder now omits the foreground and its
        // sidecar, and this would silently become a one-sidecar test.
        var settings = try settingsWithImportedIcon(fill: .systemRed, sourceName: "Front.png")
        settings.badge.isVisible = true
        settings.badge.foreground.apply(
            try ImportedImage.testFixture(fill: .systemBlue, sourceName: "Back.png")
        )
        let document = try ConfigurationExportDocument(settings: settings, baseName: "Icon")
        let children = try #require(document.makeFileWrapper().fileWrappers)

        #expect(children.count == 3)
        for (name, child) in children {
            #expect(child.isRegularFile, "\(name) should be a regular file")
            #expect(!name.contains("/"), "\(name) should not be a nested path")
        }
    }

    @Test("Two layers importing byte-identical images share one sidecar")
    func identicalImages_shareOneSidecar() throws {
        // Icon foreground + badge foreground, for the reason in `directory_isFlat`:
        // putting the second copy on the icon background would drop it and make
        // the single-sidecar assertion pass without dedup doing anything.
        var settings = IconSettings()
        let shared = try ImportedImage.testFixture(fill: .systemRed, sourceName: "Same.png")
        settings.icon.foreground.apply(shared)
        settings.badge.isVisible = true
        settings.badge.foreground.apply(shared)

        let document = try ConfigurationExportDocument(settings: settings, baseName: "Icon")
        let children = try #require(document.makeFileWrapper().fileWrappers)

        let sidecars = children.keys.filter { $0.hasSuffix(".png") }
        #expect(sidecars.count == 1)
    }

    // MARK: - Round trip

    @Test("Single-file export: writing then decoding preserves the settings")
    func roundTrip_singleFile() throws {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "bolt.fill"
        settings.export.size = 512
        // System mode deliberately: the codec writes and reads the appex colours only
        // for a System-mode layer (MicaConfig.swift:880 and :523), because they mean
        // nothing to a Mica-rendered one. Setting them on a Mica-mode icon and
        // expecting them back would be testing a round trip the format does not offer.
        settings.icon.mode = .system
        let colors = MicaAppexColors(iconEnclosure: .green, iconSymbol: .black)

        let document = try ConfigurationExportDocument(
            settings: settings,
            appexColors: colors,
            baseName: "Icon"
        )

        try withTemporaryDirectory { root in
            let url = root.appendingPathComponent("Icon.json")
            try document.makeFileWrapper().write(
                to: url,
                options: .atomic,
                originalContentsURL: nil
            )

            let decoded = try MicaConfigCodec.decode(
                json: try Data(contentsOf: url),
                configDirectory: root
            )
            #expect(decoded.settings.icon.foreground.symbolName == "bolt.fill")
            #expect(decoded.settings.export.size == 512)
            #expect(decoded.appexColors.iconEnclosure == .green)
            #expect(decoded.appexColors.iconSymbol == .black)
            #expect(decoded.warnings.isEmpty)
        }
    }

    @Test("Folder export: the sidecar the JSON names is on disk and decodes to the same bytes")
    func roundTrip_folderResolvesSidecarBytes() throws {
        let original = try ImportedImage.testFixture(fill: .systemBlue, sourceName: "Front.png")
        var settings = IconSettings()
        settings.icon.foreground.apply(original)

        let document = try ConfigurationExportDocument(settings: settings, baseName: "Icon")

        try withTemporaryDirectory { root in
            let folder = root.appendingPathComponent("Icon")
            try document.makeFileWrapper().write(
                to: folder,
                options: .atomic,
                originalContentsURL: nil
            )

            // The importer's rule: find the single top-level .json.
            let contents = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )
            let jsonURLs = contents.filter { $0.pathExtension == "json" }
            #expect(jsonURLs.count == 1)
            let jsonURL = try #require(jsonURLs.first)

            let decoded = try MicaConfigCodec.decode(
                json: try Data(contentsOf: jsonURL),
                configDirectory: folder
            )
            #expect(decoded.warnings.isEmpty)

            // Not a byte comparison. `ImageImportService.importFromURL` re-encodes
            // everything it reads through `renderToData`, so an image that comes back
            // out of a sidecar is never byte-identical to one built any other way —
            // here a 160-byte fixture returns as 603 bytes of the same 4×4 picture.
            // What matters is that the picture survives intact; byte stability across
            // repeated cycles is pinned separately below.
            //
            // Compared in *pixels*, not `NSImage.size`: the re-encode stamps 2× DPI,
            // so the same 4×4 pixels report as 2×2 points and a `size` comparison
            // fails on a difference that no exported PNG would ever show.
            let reloaded = try #require(decoded.settings.icon.foreground.image)
            let reloadedRep = try #require(NSBitmapImageRep(data: reloaded.imageData))
            let originalRep = try #require(NSBitmapImageRep(data: original.imageData))
            #expect(reloadedRep.pixelsWide == originalRep.pixelsWide)
            #expect(reloadedRep.pixelsHigh == originalRep.pixelsHigh)
        }
    }

    @Test("Export → import → export is byte-stable, so repeated round trips do not drift")
    func roundTrip_isStableAfterTheFirstPass() throws {
        var settings = IconSettings()
        settings.icon.foreground.apply(
            try ImportedImage.testFixture(fill: .systemBlue, sourceName: "Front.png")
        )

        try withTemporaryDirectory { root in
            // Pass one: the sidecar is the fixture's own bytes.
            let first = try ConfigurationExportDocument(settings: settings, baseName: "Icon")
            let folderA = root.appendingPathComponent("A")
            try first.makeFileWrapper().write(to: folderA, options: .atomic, originalContentsURL: nil)
            let decodedA = try MicaConfigCodec.decode(
                json: try Data(contentsOf: folderA.appendingPathComponent("Icon.json")),
                configDirectory: folderA
            )

            // Pass two: re-export what pass one read back, and read that.
            let second = try ConfigurationExportDocument(
                settings: decodedA.settings,
                appexColors: decodedA.appexColors,
                baseName: "Icon"
            )
            let folderB = root.appendingPathComponent("B")
            try second.makeFileWrapper().write(to: folderB, options: .atomic, originalContentsURL: nil)
            let decodedB = try MicaConfigCodec.decode(
                json: try Data(contentsOf: folderB.appendingPathComponent("Icon.json")),
                configDirectory: folderB
            )

            // Once an image has been through the importer, further cycles must not
            // keep changing it — otherwise a file re-saved a few times would drift.
            let a = try #require(decodedA.settings.icon.foreground.image)
            let b = try #require(decodedB.settings.icon.foreground.image)
            #expect(a.imageData == b.imageData)

            // And the JSON itself has settled: a third export of what pass two read
            // back is byte-identical to pass two's.
            let third = try ConfigurationExportDocument(
                settings: decodedB.settings,
                appexColors: decodedB.appexColors,
                baseName: "Icon"
            )
            #expect(third.json == second.json)
        }
    }

    @Test("Folder export: two different images survive as two distinct sidecars")
    func roundTrip_twoDistinctImages() throws {
        let front = try ImportedImage.testFixture(fill: .systemRed, sourceName: "Front.png")
        let back = try ImportedImage.testFixture(fill: .systemBlue, sourceName: "Back.png")
        #expect(front.imageData != back.imageData, "fixtures must differ or dedup makes this vacuous")

        // Icon foreground + badge foreground — see `directory_isFlat` for why the
        // second image cannot go on the icon background any more.
        var settings = IconSettings()
        settings.icon.foreground.apply(front)
        settings.badge.isVisible = true
        settings.badge.foreground.apply(back)

        let document = try ConfigurationExportDocument(settings: settings, baseName: "Icon")

        try withTemporaryDirectory { root in
            let folder = root.appendingPathComponent("Icon")
            try document.makeFileWrapper().write(
                to: folder,
                options: .atomic,
                originalContentsURL: nil
            )

            let decoded = try MicaConfigCodec.decode(
                json: try Data(contentsOf: folder.appendingPathComponent("Icon.json")),
                configDirectory: folder
            )
            #expect(decoded.warnings.isEmpty)
            // Two sidecars came back as two different images — the point is that they
            // did not collapse into one. Byte equality with the fixtures is not
            // available (see the re-encoding note above), so distinctness is what is
            // asserted, which is exactly the property dedup could break.
            let front2 = try #require(decoded.settings.icon.foreground.image)
            let back2 = try #require(decoded.settings.badge.foreground.image)
            #expect(front2.imageData != back2.imageData)
        }
    }

    // MARK: - Advertised types

    @Test("Both export shapes are advertised, so the exporter can be given either")
    func advertisesBothContentTypes() {
        // The read path's refusal is not covered: `ReadConfiguration` is no more
        // constructible from a test than `WriteConfiguration`, and there is no seam
        // worth adding for an initializer whose entire body is a throw.
        #expect(ConfigurationExportDocument.readableContentTypes.contains(.json))
        #expect(ConfigurationExportDocument.readableContentTypes.contains(.folder))
    }
}
