// ConfigurationImportSourceTests.swift
//
// Resolving what the user picked in the open panel back to a JSON file and the
// directory its relative image paths are measured from.
//
// The folder's JSON is found by being the only one rather than by its name, so these
// tests deliberately use folder and file names that do not match — renaming an exported
// folder is an obvious thing for a user to do, and re-import has to survive it.

import Testing
import Foundation
@testable import Mica

@Suite(.tags(.unit))
struct ConfigurationImportSourceTests {

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mica-config-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func write(_ name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data("{}".utf8).write(to: url)
        return url
    }

    // MARK: - Which shape was picked

    @Test("A bare .json resolves to itself, anchored on its own directory")
    func bareJSON() throws {
        try withTemporaryDirectory { root in
            let json = try write("Icon.json", in: root)

            let source = try ConfigurationImportSource(url: json)

            #expect(source.isBareJSON)
            #expect(source.jsonURL == json)
            // Compared as paths: `deletingLastPathComponent()` returns a URL with a
            // trailing slash and `standardizedFileURL` does not strip it, so the URLs
            // differ while naming the same directory.
            #expect(source.directory.path == root.path)
        }
    }

    @Test("A folder resolves to the single JSON inside it, whatever either is called")
    func folderWithOneJSON() throws {
        try withTemporaryDirectory { root in
            let folder = root.appendingPathComponent("Renamed By The User")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let json = try write("something-else.json", in: folder)
            _ = try write("Front.png", in: folder)

            let source = try ConfigurationImportSource(url: folder)

            #expect(!source.isBareJSON)
            #expect(source.jsonURL.lastPathComponent == json.lastPathComponent)
            #expect(source.directory.path == folder.path)
        }
    }

    @Test("A folder with no JSON is rejected rather than silently importing nothing")
    func folderWithNoJSON() throws {
        try withTemporaryDirectory { root in
            let folder = root.appendingPathComponent("Empty")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            _ = try write("Front.png", in: folder)

            #expect(throws: ConfigurationImportError.noConfigurationInFolder) {
                _ = try ConfigurationImportSource(url: folder)
            }
        }
    }

    @Test("A folder with several JSONs is rejected — there is no way to pick one")
    func folderWithSeveralJSONs() throws {
        try withTemporaryDirectory { root in
            let folder = root.appendingPathComponent("Ambiguous")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            _ = try write("One.json", in: folder)
            _ = try write("Two.json", in: folder)

            #expect(throws: ConfigurationImportError.severalConfigurationsInFolder(2)) {
                _ = try ConfigurationImportSource(url: folder)
            }
        }
    }

    // MARK: - The sandbox advisory

    @Test("Picking a bare JSON whose images failed adds the advice to import the folder")
    func bareJSON_advisesImportingTheFolder() throws {
        try withTemporaryDirectory { root in
            let source = try ConfigurationImportSource(url: try write("Icon.json", in: root))
            let decoded = [MicaConfigWarning(key: "icon-fg", message: "image … could not be loaded")]

            let advised = source.warningsAdvising(decoded)

            #expect(advised.count == 2)
            #expect(advised.first == decoded.first, "the decoder's own warning is kept")
            #expect(advised.last?.key == "images")
        }
    }

    @Test("A bare JSON with no image trouble gets no advisory")
    func bareJSON_withoutImageWarnings_addsNothing() throws {
        try withTemporaryDirectory { root in
            let source = try ConfigurationImportSource(url: try write("Icon.json", in: root))
            // An unrelated warning must not trigger advice about images.
            let decoded = [MicaConfigWarning(key: "size", message: "out of range")]

            #expect(source.warningsAdvising(decoded) == decoded)
        }
    }

    @Test("A folder import never advises importing the folder — it already is one")
    func folder_addsNothing() throws {
        try withTemporaryDirectory { root in
            let folder = root.appendingPathComponent("Icon")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            _ = try write("Icon.json", in: folder)
            let source = try ConfigurationImportSource(url: folder)
            let decoded = [MicaConfigWarning(key: "icon-fg", message: "image … could not be loaded")]

            #expect(source.warningsAdvising(decoded) == decoded)
        }
    }
}
