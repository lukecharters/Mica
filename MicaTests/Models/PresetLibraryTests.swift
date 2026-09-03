// MicaTests/Models/PresetLibraryTests.swift
// `PresetLibrary` is the one list of presets every surface reads. What it has to get
// right is when it reads the disk (only when asked), what order it presents (built-ins
// first), and that a problem reading a file comes back to the caller instead of
// vanishing.

import Foundation
import Testing
@testable import Mica

@Suite("Preset library", .tags(.unit))
@MainActor
struct PresetLibraryTests {

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mica-library-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func userPreset(_ name: String, scope: PresetScope = .icon) -> MicaPreset {
        MicaPreset(name: name, scope: scope, keys: ["icon-bg-color": .string("red")])
    }

    @Test("Construction reads nothing; the built-ins are there before any reload")
    func constructionDoesNotReadDisk() throws {
        let directory = try temporaryDirectory()
        try UserPresetStore.save(userPreset("Waiting"), in: directory)
        let library = PresetLibrary(directories: [directory])
        #expect(library.user.isEmpty)
        #expect(library.resolved.map(\.preset) == PresetCatalog.builtIn)
    }

    @Test("Reload picks up a preset saved to the directory")
    func reloadReadsSavedPreset() throws {
        let directory = try temporaryDirectory()
        let library = PresetLibrary(directories: [directory])
        try UserPresetStore.save(userPreset("Saved Later"), in: directory)
        let problems = library.reload()
        #expect(problems.isEmpty)
        #expect(library.user.map(\.name) == ["Saved Later"])
        #expect(library.resolved.contains { $0.preset.name == "Saved Later" && $0.isUserPreset })
    }

    /// The save sheet uniques a new name against this, built-ins included, so a user
    /// cannot end up with two identically-labelled tiles a click apart.
    @Test("`all` is the built-ins plus the user's presets")
    func allIsBuiltInsPlusUser() throws {
        let directory = try temporaryDirectory()
        try UserPresetStore.save(userPreset("Mine"), in: directory)
        let library = PresetLibrary(directories: [directory])
        library.reload()
        #expect(library.all.count == PresetCatalog.builtIn.count + 1)
        #expect(library.all.last?.name == "Mine")
    }

    @Test("Built-ins sort before a user preset of the same name")
    func builtInsFirst() throws {
        let directory = try temporaryDirectory()
        let builtIn = try #require(PresetCatalog.builtIn.first)
        try UserPresetStore.save(userPreset(builtIn.name, scope: builtIn.scope), in: directory)
        let library = PresetLibrary(directories: [directory])
        library.reload()
        let sameName = library.resolved.filter { $0.preset.name == builtIn.name && $0.scope == builtIn.scope }
        #expect(sameName.count == 2)
        #expect(sameName.first?.isUserPreset == false)
        #expect(sameName.last?.isUserPreset == true)
    }

    @Test("A file that will not parse comes back as a problem, and the rest still load")
    func problemsAreReturned() throws {
        let directory = try temporaryDirectory()
        try UserPresetStore.save(userPreset("Good"), in: directory)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("icon-bad.json"))
        let library = PresetLibrary(directories: [directory])
        let problems = library.reload()
        #expect(problems.count == 1)
        #expect(library.user.map(\.name) == ["Good"])
    }

    @Test("A deleted preset is gone after the next reload")
    func reloadDropsDeleted() throws {
        let directory = try temporaryDirectory()
        let preset = userPreset("Short Lived")
        try UserPresetStore.save(preset, in: directory)
        let library = PresetLibrary(directories: [directory])
        library.reload()
        #expect(library.user.count == 1)
        try UserPresetStore.delete(preset, in: directory)
        library.reload()
        #expect(library.user.isEmpty)
    }
}
