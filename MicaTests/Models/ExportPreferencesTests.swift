// ExportPreferencesTests.swift
// Settings ▸ Export — the default size and colour space a new window opens with.
//
// See item B2 of the Mac-conventions plan. The load-bearing assertions are
// `fixedSpec_isNotTheUsersPreferences` and `viewModel_usesTheFixedSpec`: everything
// else here would still pass if the preference leaked into `ExportSpec()`, and that
// leak has no visible symptom — it would quietly re-point every test, every SwiftUI
// preview, the CLI and the configuration decoder at one machine's settings.

import Testing
import Foundation
@testable import Mica

@Suite("Export preferences")
struct ExportPreferencesTests {

    /// A throwaway domain, so no test can depend on — or disturb — the real one.
    private func emptyDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.ExportPreferencesTests.\(UUID().uuidString)")!
    }

    // MARK: - Reading the preference

    @Test("Absent preferences read as the built-in defaults")
    func absentPreferences_giveTheBuiltInDefaults() {
        #expect(ExportSpec.fromPreferences(emptyDefaults()) == ExportSpec())
    }

    @Test("Both preferences are honoured")
    func bothPreferences_areHonoured() {
        let defaults = emptyDefaults()
        defaults.set(1024.0, forKey: ExportPreferences.defaultSizeKey)
        defaults.set(ExportColorSpace.displayP3.rawValue,
                     forKey: ExportPreferences.defaultColorSpaceKey)

        let spec = ExportSpec.fromPreferences(defaults)

        #expect(spec.size == 1024)
        #expect(spec.colorSpace == .displayP3)
        // Not a preference, so it stays at the struct's default either way.
        #expect(spec.isRetina == false)
    }

    @Test("Each preference is independent of the other")
    func eachPreference_isIndependent() {
        let sizeOnly = emptyDefaults()
        sizeOnly.set(64.0, forKey: ExportPreferences.defaultSizeKey)
        #expect(ExportSpec.fromPreferences(sizeOnly).size == 64)
        #expect(ExportSpec.fromPreferences(sizeOnly).colorSpace == ExportSpec().colorSpace)

        let spaceOnly = emptyDefaults()
        spaceOnly.set(ExportColorSpace.displayP3.rawValue,
                      forKey: ExportPreferences.defaultColorSpaceKey)
        #expect(ExportSpec.fromPreferences(spaceOnly).size == ExportSpec().size)
        #expect(ExportSpec.fromPreferences(spaceOnly).colorSpace == .displayP3)
    }

    // MARK: - Values the preference cannot honour

    @Test("An out-of-range size falls back rather than clamping",
          arguments: [0.0, 8.0, 2048.0, -512.0])
    func outOfRangeSize_fallsBack(_ stored: Double) {
        let defaults = emptyDefaults()
        defaults.set(stored, forKey: ExportPreferences.defaultSizeKey)

        // Deliberately not `minSize`/`maxSize`: clamping would hand back a size the
        // user never chose, with no UI to say so.
        #expect(ExportSpec.fromPreferences(defaults).size == ExportSpec.defaultSize)
    }

    @Test("A size stored as the wrong type is ignored")
    func nonNumericSize_isIgnored() {
        let defaults = emptyDefaults()
        defaults.set("512", forKey: ExportPreferences.defaultSizeKey)

        #expect(ExportSpec.fromPreferences(defaults).size == ExportSpec.defaultSize)
    }

    @Test("An unrecognised colour space falls back")
    func unknownColorSpace_fallsBack() {
        let defaults = emptyDefaults()
        defaults.set("rec2020", forKey: ExportPreferences.defaultColorSpaceKey)

        #expect(ExportSpec.fromPreferences(defaults).colorSpace == ExportSpec().colorSpace)
    }

    @Test("The stored colour space is the CLI's own token")
    func storedColorSpace_isTheCLIToken() {
        // The value written to defaults is `rawValue`, which is also what
        // `--color-space` takes. Round-tripping through it is what keeps the two
        // spellings from drifting into a translation table.
        for colorSpace in ExportColorSpace.allCases {
            let defaults = emptyDefaults()
            defaults.set(colorSpace.rawValue, forKey: ExportPreferences.defaultColorSpaceKey)
            #expect(ExportSpec.fromPreferences(defaults).colorSpace == colorSpace)
        }
    }

    // MARK: - The preference must not reach the CLI, the codec, or the tests

    @Test("`ExportSpec()` is not the user's preferences")
    func fixedSpec_isNotTheUsersPreferences() {
        // `ExportSpec()` is what the CLI, the configuration decoder and every test
        // get. If it ever reads the preference, one configuration renders at two
        // different sizes on two machines — and the suite's own baselines move with
        // whatever the developer last picked in Settings.
        #expect(ExportSpec().size == 512)
        #expect(ExportSpec().colorSpace == .sRGB)
        #expect(ExportSpec().isRetina == false)
    }

    @Test("`IconViewModel()` opens at the fixed defaults, not the preference")
    @MainActor
    func viewModel_usesTheFixedSpec() {
        // Only `ContentView.init()` passes `.fromPreferences()`. The bare
        // initialiser is what every test above and every SwiftUI preview uses.
        #expect(IconViewModel().iconSettings.export == ExportSpec())

        // …and it does take one when asked, which is the seam ContentView uses.
        var seeded = ExportSpec()
        seeded.size = 128
        seeded.colorSpace = .displayP3
        #expect(IconViewModel(export: seeded).iconSettings.export == seeded)
    }

    // MARK: - The size menu

    @Test("Every offered size is a legal one, and the default is offered")
    func sizeChoices_areLegalAndIncludeTheDefault() {
        let legal = ExportSpec.minSize...ExportSpec.maxSize
        for size in ExportPreferences.sizeChoices {
            #expect(legal.contains(size), "\(size)pt is offered but out of range")
        }
        // Otherwise Settings ▸ Export would open with nothing selected on a fresh
        // install, since the picker's rows are these seven.
        #expect(ExportPreferences.sizeChoices.contains(ExportSpec.defaultSize))
    }
}
