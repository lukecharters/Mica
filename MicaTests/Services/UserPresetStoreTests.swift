// UserPresetStoreTests.swift
// Tests for saved presets: the file round trip, the per-file failure modes, name
// uniquing, and what a capture of the current icon does and does not carry.
//
// Every test writes into a temporary directory. `UserPresetStore`'s real location is
// the app container, and the store takes the directory as a parameter precisely so
// these never touch it — a test that wrote there would leave presets in the pane of
// whoever ran it.
//
// **The capture tests are the ones worth reading.** A preset carries its symbol even
// when the configuration encoder would not, and that is the one place the two formats
// deliberately disagree. The encoder drops `*-fg` for a layer that does not draw,
// which is right for a file describing a render and wrong for a preset twice over:
// the thumbnail would have nothing to draw, and for the badge `badge-fg` is one of
// only three keys that *activate* a badge at all.

import Testing
import Foundation
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct UserPresetStoreTests {

    // MARK: - Helpers

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mica-preset-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ json: String, named name: String, in directory: URL) throws {
        try json.data(using: .utf8)!.write(to: directory.appendingPathComponent(name))
    }

    // MARK: - Round trip

    @Test("A saved preset reads back identical")
    func roundTrip() throws {
        let directory = try temporaryDirectory()
        let preset = MicaPreset(
            name: "My Installer",
            scope: .icon,
            keys: [
                "icon-fg": .string("symbol:arrow.down.app"),
                "icon-bg-color": .string("blue"),
                "icon-bg-gradient": .bool(false),
                "icon-fg-scale": .number(1.2),
            ]
        )
        try UserPresetStore.save(preset, in: directory)

        let loaded = UserPresetStore.load(from: [directory])
        #expect(loaded.problems.isEmpty)
        #expect(loaded.presets == [preset])
    }

    @Test("A boolean survives the round trip as a boolean")
    func roundTripKeepsBooleanKind() throws {
        // `JSONSerialization` surfaces booleans and numbers alike as `NSNumber`. A
        // `false` read back as `0` still decodes; the codec's `toggle()` reader then
        // rejects it and the key falls back to its default — so a flat preset would
        // silently come back gradient.
        let directory = try temporaryDirectory()
        let preset = MicaPreset(
            name: "Flat",
            scope: .icon,
            keys: ["icon-fg": .string("symbol:star"), "icon-bg-gradient": .bool(false)]
        )
        try UserPresetStore.save(preset, in: directory)

        let loaded = try #require(UserPresetStore.load(from: [directory]).presets.first)
        #expect(loaded.keys["icon-bg-gradient"] == .bool(false))

        let settings = PresetApplication.previewSettings(for: loaded)
        #expect(settings.icon.background.usesGradient == false)
    }

    @Test("A saved preset is a readable configuration with two extra keys")
    func savedFileIsFlattened() throws {
        // The format is the preset flattened, deliberately: the file can be read by
        // eye, edited by hand, and — with the envelope stripped — passed to `--config`
        // directly.
        let directory = try temporaryDirectory()
        let preset = MicaPreset(name: "Flat File", scope: .icon, keys: ["icon-bg-color": .string("red")])
        try UserPresetStore.save(preset, in: directory)

        let data = try Data(contentsOf: UserPresetStore.fileURL(for: preset, in: directory))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["$name"] as? String == "Flat File")
        #expect(object["$scope"] as? String == "icon")
        #expect(object["icon-bg-color"] as? String == "red")
    }

    @Test("The envelope keys cannot collide with a configuration key")
    func envelopeKeysAreOutOfBand() {
        // `$` cannot begin a `generate` long flag name, so it cannot begin a
        // `MicaConfigKey` in any future spelling. That is what makes flattening safe.
        for key in UserPresetStore.EnvelopeKey.all {
            #expect(MicaConfigKey(rawValue: key) == nil)
            #expect(key.hasPrefix("$"))
        }
    }

    @Test("Deleting removes the file")
    func delete() throws {
        let directory = try temporaryDirectory()
        let preset = MicaPreset(name: "Doomed", scope: .badge, keys: ["badge-fg": .string("symbol:plus")])
        try UserPresetStore.save(preset, in: directory)
        #expect(UserPresetStore.load(from: [directory]).presets.count == 1)

        try UserPresetStore.delete(preset, in: directory)
        #expect(UserPresetStore.load(from: [directory]).presets.isEmpty)
    }

    @Test("Deleting a built-in does nothing rather than throwing")
    func deleteBuiltInIsANoOp() throws {
        let directory = try temporaryDirectory()
        try UserPresetStore.delete(PresetCatalog.builtInIcon[0], in: directory)
    }

    // MARK: - Failure is per-file

    @Test("A missing directory is not a problem")
    func missingDirectoryIsSilent() {
        // What a user who has never saved a preset has. Reporting it would put an
        // error in front of everyone on first launch.
        let absent = FileManager.default.temporaryDirectory
            .appendingPathComponent("mica-presets-does-not-exist-\(UUID().uuidString)")
        let loaded = UserPresetStore.load(from: [absent])
        #expect(loaded.presets.isEmpty)
        #expect(loaded.problems.isEmpty)
    }

    @Test("One bad file loses that preset and not the others")
    func oneBadFileIsIsolated() throws {
        let directory = try temporaryDirectory()
        try UserPresetStore.save(
            MicaPreset(name: "Good", scope: .icon, keys: ["icon-bg-color": .string("blue")]),
            in: directory
        )
        try write("{ not json", named: "icon-broken.json", in: directory)

        let loaded = UserPresetStore.load(from: [directory])
        #expect(loaded.presets.map(\.name) == ["Good"])
        #expect(loaded.problems.count == 1)
        #expect(loaded.problems[0].contains("icon-broken.json"))
    }

    @Test("A file with no name or no scope is refused, and says which")
    func envelopeIsRequired() throws {
        let directory = try temporaryDirectory()
        try write(#"{"icon-bg-color": "blue"}"#, named: "a.json", in: directory)
        try write(#"{"$name": "Nameless scope", "icon-bg-color": "blue"}"#, named: "b.json", in: directory)
        try write(#"{"$name": "X", "$scope": "sideways"}"#, named: "c.json", in: directory)

        let loaded = UserPresetStore.load(from: [directory])
        #expect(loaded.presets.isEmpty)
        #expect(loaded.problems.count == 3)
        #expect(loaded.problems.contains { $0.contains("$name") })
        #expect(loaded.problems.contains { $0.contains("$scope") })
    }

    @Test("A preset carrying a key outside its scope is refused and names it")
    func crossScopeFileIsRefused() throws {
        // The scoped copy would drop the key silently. Refusing the file instead is
        // what turns a preset that half-works into one that explains itself — the
        // realistic source being a hand-edited file.
        let directory = try temporaryDirectory()
        try write(
            #"{"$name": "Confused", "$scope": "badge", "badge-fg": "symbol:plus", "icon-bg-color": "red"}"#,
            named: "badge-confused.json",
            in: directory
        )
        let loaded = UserPresetStore.load(from: [directory])
        #expect(loaded.presets.isEmpty)
        #expect(loaded.problems.count == 1)
        #expect(loaded.problems[0].contains("icon-bg-color"))
    }

    @Test("A non-JSON file in the directory is ignored entirely")
    func nonJSONFilesAreSkipped() throws {
        let directory = try temporaryDirectory()
        try write("not a preset", named: "README.txt", in: directory)
        let loaded = UserPresetStore.load(from: [directory])
        #expect(loaded.presets.isEmpty)
        #expect(loaded.problems.isEmpty)
    }

    // MARK: - Filenames

    @Test("A name with characters a filename cannot hold still saves")
    func slugHandlesAwkwardNames() throws {
        let directory = try temporaryDirectory()
        let preset = MicaPreset(name: "Restart / Required!", scope: .badge, keys: ["badge-fg": .string("symbol:power")])
        try UserPresetStore.save(preset, in: directory)

        let loaded = try #require(UserPresetStore.load(from: [directory]).presets.first)
        // The slug is not the identity — `$name` is — so the display name survives
        // intact however the file had to be named.
        #expect(loaded.name == "Restart / Required!")
    }

    @Test("The slug collapses runs and never comes out empty")
    func slugIsWellFormed() {
        #expect(UserPresetStore.slug("Restart  Required!") == "restart-required")
        #expect(UserPresetStore.slug("Installer") == "installer")
        #expect(UserPresetStore.slug("!!!") == "preset")
    }

    @Test("The scope is part of the filename, so the two scopes cannot collide")
    func filenameCarriesScope() {
        let icon = MicaPreset(name: "Update", scope: .icon, keys: [:])
        let badge = MicaPreset(name: "Update", scope: .badge, keys: [:])
        let directory = URL(fileURLWithPath: "/tmp")
        #expect(UserPresetStore.fileURL(for: icon, in: directory)
                != UserPresetStore.fileURL(for: badge, in: directory))
    }

    // MARK: - Unique names

    /// A stand-in catalogue for the uniquing tests.
    ///
    /// **Not `PresetCatalog.builtIn`.** Uniquing is a property of the function, not of
    /// what Mica happens to ship, and asserting it against the shipping catalogue turns
    /// every name mentioned here into a constraint on curation — re-curating a preset
    /// away then arrives as a broken test rather than as a design decision. The names
    /// below exist only in this file, so curation cannot reach them. `isBuiltIn` is
    /// `true` because a built-in is exactly what a user preset must not collide with.
    private static let existing: [MicaPreset] = [
        MicaPreset(name: "Taken", scope: .icon, keys: [:], isBuiltIn: true),
        MicaPreset(name: "Spoken For", scope: .badge, keys: [:], isBuiltIn: true),
    ]

    @Test("A free name is returned unchanged")
    func uniqueName_free() {
        let name = UserPresetStore.uniqueName("Fresh", in: .icon, existing: Self.existing)
        #expect(name == "Fresh")
    }

    @Test("A taken name gains a numeric suffix, and keeps counting")
    func uniqueName_taken() {
        var existing = Self.existing
        #expect(UserPresetStore.uniqueName("Taken", in: .icon, existing: existing) == "Taken 2")

        existing.append(MicaPreset(name: "Taken 2", scope: .icon, keys: [:]))
        #expect(UserPresetStore.uniqueName("Taken", in: .icon, existing: existing) == "Taken 3")
    }

    @Test("Uniquing is case-insensitive and counts built-ins")
    func uniqueName_matchesBuiltIns() {
        // A user preset called "taken" would sit in the same section as the built-in
        // one, and two identically-labelled rows a click apart is the confusion this
        // avoids.
        #expect(UserPresetStore.uniqueName("taken", in: .icon, existing: Self.existing) == "taken 2")
    }

    @Test("The same name in the other scope is free")
    func uniqueName_isPerScope() {
        // Both halves, because the free-in-the-other-scope assertion passes on its own
        // for a name that is taken in *neither* — which is not the property being
        // claimed. "Spoken For" is a badge preset in the fixture above.
        #expect(UserPresetStore.uniqueName("Spoken For", in: .badge, existing: Self.existing) == "Spoken For 2")
        #expect(UserPresetStore.uniqueName("Spoken For", in: .icon, existing: Self.existing) == "Spoken For")
    }

    @Test("A blank name becomes a usable one")
    func uniqueName_blank() {
        #expect(UserPresetStore.uniqueName("   ", in: .icon, existing: []) == "Preset")
    }

    // MARK: - Capture

    @Test("Capturing the icon keeps icon keys and drops everything else")
    func capture_isScoped() throws {
        var settings = IconSettings()
        settings.export.size = 1024
        settings.icon.foreground.symbolName = "hammer.fill"
        settings.icon.background.color = .red
        settings.badge.foreground.isHidden = false
        settings.badge.background.isHidden = false

        let capture = try UserPresetStore.capture(
            settings, appexColors: MicaAppexColors(), scope: .icon, name: "Captured"
        )
        #expect(capture.preset.unscopedKeys.isEmpty)
        #expect(capture.preset.keys["size"] == nil)
        #expect(capture.preset.keys["badge-fg"] == nil)
        #expect(capture.preset.keys["icon-fg"] == .string("symbol:hammer.fill"))
    }

    @Test("A captured preset reproduces the settings it came from")
    func capture_roundTripsThroughApply() throws {
        // The whole point of a save: what comes back has to be what was on screen.
        // Compared per scope, since a capture describes one half.
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "hammer.fill"
        settings.icon.foreground.symbolWeight = .bold
        settings.icon.background.color = .red
        settings.icon.background.usesGradient = false
        settings.icon.background.cornerRadiusStyle = .macOS15

        let capture = try UserPresetStore.capture(
            settings, appexColors: MicaAppexColors(), scope: .icon, name: "Captured"
        )

        var restored = IconSettings()
        var colors = MicaAppexColors()
        try PresetApplication.apply(capture.preset, to: &restored, appexColors: &colors)
        #expect(restored.icon == settings.icon)
    }

    @Test("A captured badge preset always carries its symbol, even from a background-only badge")
    func capture_badgeAlwaysCarriesItsSymbol() throws {
        // **The case that makes the fallback compulsory rather than tidy.** The
        // configuration encoder gates `badge-fg` on the layer drawing, and for a
        // plain-colour background it writes `badge-bg-color` — which is in the badge
        // namespace but is *not* one of the three keys that activate a badge. Without
        // the fallback every key in this capture would be inert, and applying the
        // preset would do nothing at all.
        var settings = IconSettings()
        settings.badge.background.isHidden = false
        settings.badge.foreground.isHidden = true
        settings.badge.foreground.symbolName = "bell.fill"
        settings.badge.background.color = .gray
        #expect(settings.badge.isVisible)

        let capture = try UserPresetStore.capture(
            settings, appexColors: MicaAppexColors(), scope: .badge, name: "Background Only"
        )
        #expect(capture.preset.keys["badge-fg"] == .string("symbol:bell.fill"))

        var applied = IconSettings()
        var colors = MicaAppexColors()
        try PresetApplication.apply(capture.preset, to: &applied, appexColors: &colors)
        #expect(applied.badge.isVisible, "the captured preset activated no badge")
    }

    @Test("A captured icon preset carries its symbol even from a hidden foreground")
    func capture_iconAlwaysCarriesItsSymbol() throws {
        // Same gate, milder symptom: the preset would still apply, but its thumbnail
        // would draw whatever `ForegroundSpec.iconDefault` happens to name rather than
        // the icon the user saved.
        var settings = IconSettings()
        settings.icon.foreground.isHidden = true
        settings.icon.foreground.symbolName = "hammer.fill"

        let capture = try UserPresetStore.capture(
            settings, appexColors: MicaAppexColors(), scope: .icon, name: "Hidden"
        )
        #expect(capture.preset.keys["icon-fg"] == .string("symbol:hammer.fill"))
    }

    @Test("An imported layer is dropped and reported rather than saved as a dead path")
    func capture_dropsImportedArtwork() throws {
        let image = try ImportedImage.testFixture()
        var settings = IconSettings()
        settings.icon.background.source = .image
        settings.icon.background.image = image

        let capture = try UserPresetStore.capture(
            settings, appexColors: MicaAppexColors(), scope: .icon, name: "Imported"
        )
        #expect(capture.droppedImageKeys == ["icon-bg"])
        #expect(capture.preset.keys["icon-bg"] == nil)
    }

    // MARK: - canCapture

    @Test("An icon can always be captured; a switched-off badge cannot")
    func canCapture() {
        var off = IconSettings()
        off.badge.isHidden = true
        #expect(UserPresetStore.canCapture(off, scope: .icon))
        #expect(!UserPresetStore.canCapture(off, scope: .badge))

        var on = IconSettings()
        on.badge.isVisible = true
        #expect(UserPresetStore.canCapture(on, scope: .badge))
    }
}
