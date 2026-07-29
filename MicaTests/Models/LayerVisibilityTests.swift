// LayerVisibilityTests.swift
// Tests for the group-visibility helpers added to IconSettings: icon.isHidden,
// badge.isHidden, badge.isVisible get/set symmetry, and the tri-state helpers
// icon.visibility / badge.visibility. Also covers icon.mode +
// badge.mode independence.

import Testing
@testable import Mica

@Suite(.tags(.unit))
struct LayerVisibilityTests {

    // MARK: - badge.isVisible get/set symmetry

    @Test("badge.isVisible get returns true when either badge layer is visible")
    func showBadge_getsTrueWhenEitherLayerVisible() {
        var s = IconSettings()
        s.badge.foreground.isHidden = true
        s.badge.background.isHidden = true
        #expect(s.badge.isVisible == false)

        s.badge.foreground.isHidden = false
        #expect(s.badge.isVisible == true)

        s.badge.foreground.isHidden = true
        s.badge.background.isHidden = false
        #expect(s.badge.isVisible == true)
    }

    @Test("badge.isVisible set mirrors value into both badge layers")
    func showBadge_setUpdatesBothLayers() {
        var s = IconSettings()
        s.badge.isVisible = true
        #expect(s.badge.foreground.isHidden == false)
        #expect(s.badge.background.isHidden == false)

        s.badge.isVisible = false
        #expect(s.badge.foreground.isHidden == true)
        #expect(s.badge.background.isHidden == true)
    }

    // MARK: - icon.isHidden / badge.isHidden group toggles

    @Test("icon.isHidden is true only when both icon layers are hidden")
    func iconHidden_requiresBothHidden() {
        var s = IconSettings()
        s.icon.foreground.isHidden = true
        s.icon.background.isHidden = false
        #expect(s.icon.isHidden == false)

        s.icon.background.isHidden = true
        #expect(s.icon.isHidden == true)
    }

    @Test("icon.isHidden setter mirrors value into both layers")
    func iconHidden_setMirrors() {
        var s = IconSettings()
        s.icon.isHidden = true
        #expect(s.icon.foreground.isHidden == true)
        #expect(s.icon.background.isHidden == true)

        s.icon.isHidden = false
        #expect(s.icon.foreground.isHidden == false)
        #expect(s.icon.background.isHidden == false)
    }

    @Test("badge.isHidden is inverse of badge.isVisible")
    func badgeHidden_isInverseOfShowBadge() {
        var s = IconSettings()
        s.badge.foreground.isHidden = false
        s.badge.background.isHidden = false
        #expect(s.badge.isHidden == false)
        #expect(s.badge.isVisible == true)

        s.badge.isHidden = true
        #expect(s.badge.isVisible == false)
        #expect(s.badge.foreground.isHidden == true)
        #expect(s.badge.background.isHidden == true)
    }

    // MARK: - Tri-state visibility

    @Test("iconVisibility returns on when both visible, off when both hidden, mixed otherwise")
    func iconVisibility_triState() {
        var s = IconSettings()
        s.icon.foreground.isHidden = false
        s.icon.background.isHidden = false
        #expect(s.icon.visibility == .on)

        s.icon.foreground.isHidden = true
        s.icon.background.isHidden = true
        #expect(s.icon.visibility == .off)

        s.icon.foreground.isHidden = true
        s.icon.background.isHidden = false
        #expect(s.icon.visibility == .mixed)

        s.icon.foreground.isHidden = false
        s.icon.background.isHidden = true
        #expect(s.icon.visibility == .mixed)
    }

    @Test("badgeVisibility tri-state matches the badge layer flags")
    func badgeVisibility_triState() {
        var s = IconSettings()
        s.badge.foreground.isHidden = false
        s.badge.background.isHidden = false
        #expect(s.badge.visibility == .on)

        s.badge.foreground.isHidden = true
        s.badge.background.isHidden = true
        #expect(s.badge.visibility == .off)

        s.badge.foreground.isHidden = true
        s.badge.background.isHidden = false
        #expect(s.badge.visibility == .mixed)
    }

    // MARK: - Per-group generation mode

    @Test("icon.mode is stored and independent of badge.mode")
    func iconGenerationMode_independent() {
        var s = IconSettings()
        s.icon.mode = .system
        s.badge.foreground.source = .symbol
        #expect(s.icon.mode == .system)
        #expect(s.badge.mode == .mica)
    }

    @Test("badge.mode follows badge.foreground.source")
    func badgeGenerationMode_followsSource() {
        var s = IconSettings()
        s.badge.foreground.source = .system
        #expect(s.badge.mode == .system)

        s.badge.foreground.source = .symbol
        #expect(s.badge.mode == .mica)

        s.badge.foreground.source = .image
        #expect(s.badge.mode == .mica)
    }

    @Test("Setting badge.mode .system locks the source")
    func badgeGenerationMode_setAppleRef_locksSource() {
        var s = IconSettings()
        s.badge.foreground.source = .symbol
        s.badge.mode = .system
        #expect(s.badge.foreground.source == .system)
    }

    @Test("Setting badge.mode .mica falls back to .symbol when previously .system")
    func badgeGenerationMode_setSwiftUI_fallsBack() {
        var s = IconSettings()
        s.badge.foreground.source = .system
        s.badge.mode = .mica
        #expect(s.badge.foreground.source == .symbol)
    }

    @Test("Setting badge.mode .mica when already non-.system is a no-op")
    func badgeGenerationMode_setSwiftUI_preservesNonAppleSource() {
        var s = IconSettings()
        s.badge.foreground.source = .image
        s.badge.mode = .mica
        #expect(s.badge.foreground.source == .image)
    }
}
