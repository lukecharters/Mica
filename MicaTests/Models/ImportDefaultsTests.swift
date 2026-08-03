// ImportDefaultsTests.swift
// The two background-import seams and the preferences behind them.
//
// See §5 of docs/plans/visibility-activation-and-imported-backgrounds.md. The
// load-bearing assertion in here is `fixedDefaults_areNotTheUsersPreferences`:
// everything else would still pass if a preference leaked into the CLI or the
// configuration codec, and that leak is the one failure mode with no visible
// symptom — a configuration would decode to different icons on two machines.

import Testing
import AppKit
@testable import Mica

@Suite("Import defaults")
@MainActor
struct ImportDefaultsTests {

    // MARK: - The seams

    @Test("The icon seam hides the foreground and turns the corner radius off")
    func iconSeam_appliesBothDefaults() throws {
        var settings = IconSettings()
        #expect(settings.icon.foreground.isHidden == false)
        #expect(settings.icon.background.cornerRadiusStyle == .macOS26)

        settings.icon.applyBackgroundImage(try ImportedImage.testFixture())

        #expect(settings.icon.background.source == .image)
        #expect(settings.icon.background.image != nil)
        #expect(settings.icon.foreground.isHidden == true)
        #expect(settings.icon.background.cornerRadiusStyle == .off)
        // Still the pre-existing `IconBackgroundSpec.apply(_:)` behaviour.
        #expect(settings.icon.background.shadowStyle == .off)
        #expect(settings.icon.background.compensatesForPadding == true)
    }

    @Test("The badge seam hides the foreground; there is no corner radius to turn off")
    func badgeSeam_appliesTheForegroundDefault() throws {
        var settings = IconSettings()
        settings.badge.isVisible = true
        #expect(settings.badge.foreground.isHidden == false)

        settings.badge.applyBackgroundImage(try ImportedImage.testFixture())

        #expect(settings.badge.background.source == .image)
        #expect(settings.badge.background.image != nil)
        #expect(settings.badge.foreground.isHidden == true)
        #expect(settings.badge.background.drawsShadow == false)
        #expect(settings.badge.background.compensatesForPadding == true)
    }

    @Test("Hiding the foreground is a default, not a veto — it can be switched back on")
    func hiddenForeground_canBeSwitchedBackOn() throws {
        var settings = IconSettings()
        settings.icon.applyBackgroundImage(try ImportedImage.testFixture())
        #expect(settings.icon.foreground.isHidden == true)

        settings.icon.foreground.isHidden = false

        // The artwork is untouched by revealing the foreground: the point of the
        // change is that the two coexist.
        #expect(settings.icon.foreground.isHidden == false)
        #expect(settings.icon.background.image != nil)
        #expect(settings.icon.background.source == .image)
    }

    // MARK: - Both branches of both preferences

    @Test("Each default can be turned off independently, over both seams",
          arguments: [
            ImportDefaults(hidesForeground: true, turnsOffCornerRadius: true),
            ImportDefaults(hidesForeground: true, turnsOffCornerRadius: false),
            ImportDefaults(hidesForeground: false, turnsOffCornerRadius: true),
            ImportDefaults(hidesForeground: false, turnsOffCornerRadius: false),
          ])
    func bothDefaults_areIndependentlyHonoured(_ defaults: ImportDefaults) throws {
        var settings = IconSettings()
        settings.badge.isVisible = true

        settings.icon.applyBackgroundImage(try ImportedImage.testFixture(), defaults: defaults)
        settings.badge.applyBackgroundImage(try ImportedImage.testFixture(), defaults: defaults)

        #expect(settings.icon.foreground.isHidden == defaults.hidesForeground)
        #expect(settings.badge.foreground.isHidden == defaults.hidesForeground)
        #expect(settings.icon.background.cornerRadiusStyle
                    == (defaults.turnsOffCornerRadius ? .off : .macOS26))
    }

    @Test("`turnsOffCornerRadius` is ignored by the badge rather than absent")
    func badgeIgnoresTheCornerRadiusDefault() throws {
        var settings = IconSettings()
        settings.badge.applyBackgroundImage(
            try ImportedImage.testFixture(),
            defaults: ImportDefaults(hidesForeground: false, turnsOffCornerRadius: true))

        // One `ImportDefaults` serves both seams, so the badge takes the field and
        // does nothing with it — importantly, without reaching across to the icon.
        #expect(settings.icon.background.cornerRadiusStyle == .macOS26)
    }

    // MARK: - The preference must not reach the CLI or the format

    @Test("`.fixed` is not the user's preferences")
    func fixedDefaults_areNotTheUsersPreferences() {
        // A throwaway domain so the test cannot depend on, or disturb, the real one.
        let defaults = UserDefaults(suiteName: "test.ImportDefaultsTests.\(UUID().uuidString)")!
        defaults.set(false, forKey: InspectorPreferences.hidesForegroundOnBackgroundImportKey)
        defaults.set(false, forKey: InspectorPreferences.turnsOffCornerRadiusOnBackgroundImportKey)

        #expect(ImportDefaults.fromPreferences(defaults)
                    == ImportDefaults(hidesForeground: false, turnsOffCornerRadius: false))

        // `.fixed` is what the CLI and the codec get from the default argument, and
        // it does not move. If this ever reads the preference, one configuration
        // decodes to two different icons on two machines.
        #expect(ImportDefaults.fixed == ImportDefaults(hidesForeground: true,
                                                       turnsOffCornerRadius: true))
    }

    @Test("Absent preferences read as on, not as false")
    func absentPreferences_defaultToOn() {
        // The trap `fromPreferences` exists to avoid: both preferences default to
        // *on*, and `UserDefaults.bool(forKey:)` returns false for an absent key —
        // so a fresh install would silently import with neither default applied.
        let defaults = UserDefaults(suiteName: "test.ImportDefaultsTests.\(UUID().uuidString)")!
        #expect(ImportDefaults.fromPreferences(defaults) == .fixed)
    }

    @Test("An explicitly-set preference survives, including false")
    func explicitFalse_isDistinguishedFromAbsent() {
        let defaults = UserDefaults(suiteName: "test.ImportDefaultsTests.\(UUID().uuidString)")!
        defaults.set(false, forKey: InspectorPreferences.hidesForegroundOnBackgroundImportKey)
        defaults.set(true, forKey: InspectorPreferences.turnsOffCornerRadiusOnBackgroundImportKey)

        #expect(ImportDefaults.fromPreferences(defaults)
                    == ImportDefaults(hidesForeground: false, turnsOffCornerRadius: true))
    }
}
