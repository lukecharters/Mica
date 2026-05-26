// LayerVisibilityTests.swift
// Tests for the group-visibility helpers added to IconSettings: iconHidden,
// badgeHidden, showBadge get/set symmetry, and the tri-state helpers
// iconVisibility() / badgeVisibility(). Also covers iconGenerationMode +
// badgeGenerationMode independence.

import Testing
@testable import Mica

@Suite(.tags(.unit))
struct LayerVisibilityTests {

    // MARK: - showBadge get/set symmetry

    @Test("showBadge get returns true when either badge layer is visible")
    func showBadge_getsTrueWhenEitherLayerVisible() {
        var s = IconSettings()
        s.badgeForegroundHidden = true
        s.badgeBackgroundHidden = true
        #expect(s.showBadge == false)

        s.badgeForegroundHidden = false
        #expect(s.showBadge == true)

        s.badgeForegroundHidden = true
        s.badgeBackgroundHidden = false
        #expect(s.showBadge == true)
    }

    @Test("showBadge set mirrors value into both badge layers")
    func showBadge_setUpdatesBothLayers() {
        var s = IconSettings()
        s.showBadge = true
        #expect(s.badgeForegroundHidden == false)
        #expect(s.badgeBackgroundHidden == false)

        s.showBadge = false
        #expect(s.badgeForegroundHidden == true)
        #expect(s.badgeBackgroundHidden == true)
    }

    // MARK: - iconHidden / badgeHidden group toggles

    @Test("iconHidden is true only when both icon layers are hidden")
    func iconHidden_requiresBothHidden() {
        var s = IconSettings()
        s.iconForegroundHidden = true
        s.iconBackgroundHidden = false
        #expect(s.iconHidden == false)

        s.iconBackgroundHidden = true
        #expect(s.iconHidden == true)
    }

    @Test("iconHidden setter mirrors value into both layers")
    func iconHidden_setMirrors() {
        var s = IconSettings()
        s.iconHidden = true
        #expect(s.iconForegroundHidden == true)
        #expect(s.iconBackgroundHidden == true)

        s.iconHidden = false
        #expect(s.iconForegroundHidden == false)
        #expect(s.iconBackgroundHidden == false)
    }

    @Test("badgeHidden is inverse of showBadge")
    func badgeHidden_isInverseOfShowBadge() {
        var s = IconSettings()
        s.badgeForegroundHidden = false
        s.badgeBackgroundHidden = false
        #expect(s.badgeHidden == false)
        #expect(s.showBadge == true)

        s.badgeHidden = true
        #expect(s.showBadge == false)
        #expect(s.badgeForegroundHidden == true)
        #expect(s.badgeBackgroundHidden == true)
    }

    // MARK: - Tri-state visibility

    @Test("iconVisibility returns on when both visible, off when both hidden, mixed otherwise")
    func iconVisibility_triState() {
        var s = IconSettings()
        s.iconForegroundHidden = false
        s.iconBackgroundHidden = false
        #expect(s.iconVisibility() == .on)

        s.iconForegroundHidden = true
        s.iconBackgroundHidden = true
        #expect(s.iconVisibility() == .off)

        s.iconForegroundHidden = true
        s.iconBackgroundHidden = false
        #expect(s.iconVisibility() == .mixed)

        s.iconForegroundHidden = false
        s.iconBackgroundHidden = true
        #expect(s.iconVisibility() == .mixed)
    }

    @Test("badgeVisibility tri-state matches the badge layer flags")
    func badgeVisibility_triState() {
        var s = IconSettings()
        s.badgeForegroundHidden = false
        s.badgeBackgroundHidden = false
        #expect(s.badgeVisibility() == .on)

        s.badgeForegroundHidden = true
        s.badgeBackgroundHidden = true
        #expect(s.badgeVisibility() == .off)

        s.badgeForegroundHidden = true
        s.badgeBackgroundHidden = false
        #expect(s.badgeVisibility() == .mixed)
    }

    // MARK: - Per-group generation mode

    @Test("iconGenerationMode is stored and independent of badgeGenerationMode")
    func iconGenerationMode_independent() {
        var s = IconSettings()
        s.iconGenerationMode = .appleReference
        s.badgeIconSource = .sfSymbol
        #expect(s.iconGenerationMode == .appleReference)
        #expect(s.badgeGenerationMode == .swiftUI)
    }

    @Test("badgeGenerationMode follows badgeIconSource")
    func badgeGenerationMode_followsSource() {
        var s = IconSettings()
        s.badgeIconSource = .appleReference
        #expect(s.badgeGenerationMode == .appleReference)

        s.badgeIconSource = .sfSymbol
        #expect(s.badgeGenerationMode == .swiftUI)

        s.badgeIconSource = .customImage
        #expect(s.badgeGenerationMode == .swiftUI)
    }

    @Test("Setting badgeGenerationMode .appleReference locks the source")
    func badgeGenerationMode_setAppleRef_locksSource() {
        var s = IconSettings()
        s.badgeIconSource = .sfSymbol
        s.badgeGenerationMode = .appleReference
        #expect(s.badgeIconSource == .appleReference)
    }

    @Test("Setting badgeGenerationMode .swiftUI falls back to sfSymbol when previously appleReference")
    func badgeGenerationMode_setSwiftUI_fallsBack() {
        var s = IconSettings()
        s.badgeIconSource = .appleReference
        s.badgeGenerationMode = .swiftUI
        #expect(s.badgeIconSource == .sfSymbol)
    }

    @Test("Setting badgeGenerationMode .swiftUI when already non-appleReference is a no-op")
    func badgeGenerationMode_setSwiftUI_preservesNonAppleSource() {
        var s = IconSettings()
        s.badgeIconSource = .customImage
        s.badgeGenerationMode = .swiftUI
        #expect(s.badgeIconSource == .customImage)
    }
}
