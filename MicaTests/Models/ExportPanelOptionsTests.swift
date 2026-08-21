// ExportPanelOptionsTests.swift
// The save panel's accessory view — the three export settings, edited for one
// export only.
//
// The load-bearing assertions are the two at the bottom: that swapping the
// override into a copy of the settings changes the *rendered pixel size* and
// leaves the window's own settings alone. Everything above them would still pass
// if the override never reached the render, or if it reached `iconSettings` on the
// way — and neither failure has a visible symptom short of exporting a file and
// measuring it.

import Testing
import AppKit
import ImageIO
@testable import Mica

@Suite("Export panel options")
@MainActor
struct ExportPanelOptionsTests {

    // MARK: - Seeding

    @Test("A fresh panel opens on the window's settings and overrides nothing")
    func seed_isTheStartingPoint() {
        var spec = ExportSpec()
        spec.size = 256
        spec.colorSpace = .displayP3

        let options = ExportPanelOptions(seed: spec)

        #expect(options.spec == spec)
        #expect(options.seed == spec)
        #expect(options.isOverridden == false)
    }

    /// One case per stored setting on `ExportSpec`, so each is checked to count as
    /// an override on its own. A closure per case would be the obvious spelling and
    /// does not compile: Swift Testing's arguments must be `Sendable`, and a
    /// function type is not.
    enum Setting: CaseIterable {
        case size, retina, colorSpace
    }

    @Test("Changing any one setting is an override", arguments: Setting.allCases)
    func anyChange_isAnOverride(setting: Setting) {
        var options = ExportPanelOptions(seed: ExportSpec())
        switch setting {
        case .size:       options.spec.size = 128
        case .retina:     options.spec.isRetina = true
        case .colorSpace: options.spec.colorSpace = .displayP3
        }

        #expect(options.isOverridden)
        #expect(options.seed == ExportSpec(), "the seed is what the window said, and never moves")
    }

    @Test("Reset goes back to the window's settings")
    func reset_restoresTheSeed() {
        var options = ExportPanelOptions(seed: ExportSpec())
        options.spec.size = 64
        options.spec.isRetina = true

        options.reset()

        #expect(options.isOverridden == false)
        #expect(options.spec == options.seed)
    }

    /// `isOverridden` compares whole specs, so a fourth export setting is covered
    /// the day it is added — but only while that stays true. Three stored
    /// properties today: size, isRetina, colorSpace.
    @Test("ExportSpec has three stored settings, all of them covered")
    func exportSpec_hasThreeStoredSettings() {
        #expect(Mirror(reflecting: ExportSpec()).children.count == 3)
    }

    // MARK: - The size menu

    @Test("A standard size offers exactly the shared list")
    func standardSize_offersTheSharedChoices() {
        let options = ExportPanelOptions(seed: ExportSpec())

        #expect(options.spec.size == 512, "the default is one of the offered sizes")
        #expect(options.sizeChoices == ExportPreferences.sizeChoices)
    }

    @Test("An off-list size joins the menu in its sorted place")
    func offListSize_isOffered() {
        var spec = ExportSpec()
        spec.size = 300

        let choices = ExportPanelOptions(seed: spec).sizeChoices

        #expect(choices.contains(300), "a Picker whose selection matches no tag renders empty")
        #expect(choices == choices.sorted())
        #expect(choices.count == ExportPreferences.sizeChoices.count + 1)
        #expect(Set(choices).count == choices.count)
    }

    // MARK: - The caption

    @Test("The caption reports the pixel size", arguments: [
        (CGFloat(512), false, "512×512px"),
        (CGFloat(512), true, "1024×1024px"),
        (CGFloat(16), false, "16×16px"),
    ])
    func pixelDescription_reportsTheExportedPixels(size: CGFloat, retina: Bool, expected: String) {
        var spec = ExportSpec()
        spec.size = size
        spec.isRetina = retina

        #expect(ExportPanelOptions(seed: spec).pixelDescription == expected)
    }

    /// The digits are grouped by the locale's number formatter the moment they go
    /// through a `LocalizedStringKey`, and this machine's region renders 1024 as
    /// "1,024". A comma here means the caption was built with `Text("\(anInt)")`.
    @Test("Four-digit sizes are not grouped")
    func pixelDescription_doesNotGroupDigits() {
        var spec = ExportSpec()
        spec.size = 1024

        #expect(ExportPanelOptions(seed: spec).pixelDescription.contains(",") == false)
    }

    // MARK: - Reaching the render

    /// The composition `ContentView.pngExportDocument(export:)` performs: the
    /// override swapped into a *copy* of the window's settings.
    private func exportSettings(_ base: IconSettings, overriding options: ExportPanelOptions) -> IconSettings {
        var settings = base
        settings.export = options.spec
        return settings
    }

    @Test("The override decides the exported pixel size")
    func override_decidesTheRenderedSize() throws {
        var base = IconSettings()
        base.export.size = 64
        base.icon.foreground.symbolName = "star.fill"

        var options = ExportPanelOptions(seed: base.export)
        options.spec.size = 128
        options.spec.isRetina = true

        let data = try PNGExportDocument(settings: exportSettings(base, overriding: options)).pngData()

        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 256)
        #expect(image.height == 256)
    }

    @Test("An override changes the one export and nothing about the icon")
    func override_leavesTheWindowSettingsAlone() {
        var base = IconSettings()
        base.export.size = 64
        base.icon.foreground.symbolName = "star.fill"
        base.badge.foreground.isHidden = false
        let untouched = base

        var options = ExportPanelOptions(seed: base.export)
        options.spec.size = 1024
        options.spec.colorSpace = .displayP3

        let exported = exportSettings(base, overriding: options)

        #expect(base == untouched, "the window's settings are a value type, and the override copies")
        #expect(exported.export == options.spec)
        #expect(exported.icon == untouched.icon)
        #expect(exported.badge == untouched.badge)
        #expect(exported.exportBaseName == untouched.exportBaseName, "the filename follows the icon, not the size")
    }
}
