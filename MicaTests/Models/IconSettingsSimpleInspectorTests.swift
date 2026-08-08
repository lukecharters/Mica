// IconSettingsSimpleInspectorTests.swift
// Tests for IconSettings+SimpleInspector: the state folding that keeps the
// inspector's simple pane (Mica mode with "Show Advanced Controls" off) able to
// describe the settings with one row each, the imported-source detection that
// reveals the advanced controls again, and group visibility.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
struct IconSettingsSimpleInspectorTests {

    // MARK: - usesImportedSources

    @Test("Defaults use no imported sources")
    func usesImportedSources_defaults() {
        #expect(IconSettings().usesImportedSources == false)
    }

    @Test("Each imported layer is detected")
    func usesImportedSources_perLayer() {
        var iconForeground = IconSettings()
        iconForeground.icon.foreground.source = .image
        #expect(iconForeground.usesImportedSources)

        var iconBackground = IconSettings()
        iconBackground.icon.background.source = .image
        #expect(iconBackground.usesImportedSources)

        var badgeForeground = IconSettings()
        badgeForeground.badge.foreground.source = .image
        #expect(badgeForeground.usesImportedSources)

        var badgeBackground = IconSettings()
        badgeBackground.badge.background.source = .image
        #expect(badgeBackground.usesImportedSources)
    }

    @Test("A pre-rendered background is not an imported source")
    func usesImportedSources_preRenderedIsNot() {
        var settings = IconSettings()
        settings.icon.background.source = .preRendered
        // It still can't be shown in the simple pane, but it can only be chosen
        // from the advanced controls, so it never needs to reveal them.
        #expect(settings.usesImportedSources == false)
    }

    // MARK: - resetToSimpleControls

    @Test("Imported and pre-rendered sources fold back to symbol + colour")
    func reset_foldsSources() throws {
        var settings = IconSettings()
        settings.icon.foreground.source = .image
        settings.icon.background.source = .image
        settings.badge.foreground.source = .image
        settings.badge.background.source = .image

        settings.resetToSimpleControls()

        #expect(settings.icon.foreground.source == .symbol)
        #expect(settings.icon.background.source == .color)
        #expect(settings.badge.foreground.source == .symbol)
        #expect(settings.badge.background.source == .color)
        #expect(settings.usesImportedSources == false)
    }

    @Test("A pre-rendered background folds back to the plain colour background")
    func reset_foldsPreRendered() {
        var settings = IconSettings()
        settings.icon.background.source = .preRendered

        settings.resetToSimpleControls()

        #expect(settings.icon.background.source == .color)
    }

    @Test("Rendering modes and custom gradients fold away, since they add rows")
    func reset_foldsMultiRowAppearance() {
        var settings = IconSettings()
        settings.icon.foreground.renderingStyle = .palette
        settings.badge.foreground.renderingStyle = .hierarchical
        settings.icon.background.usesCustomGradient = true
        settings.badge.background.usesCustomGradient = true

        settings.resetToSimpleControls()

        #expect(settings.icon.foreground.renderingStyle == .monochrome)
        #expect(settings.badge.foreground.renderingStyle == .monochrome)
        #expect(settings.icon.background.usesCustomGradient == false)
        #expect(settings.badge.background.usesCustomGradient == false)
    }

    @Test("Folding is non-destructive: artwork and colours survive")
    func reset_retainsUnderlyingValues() throws {
        var settings = IconSettings()
        let iconImage = try ImportedImage.testFixture(sourceName: "icon.png")
        let badgeImage = try ImportedImage.testFixture(sourceName: "badge.png")
        settings.icon.foreground.source = .image
        settings.icon.foreground.image = iconImage
        settings.icon.background.source = .preRendered
        settings.icon.background.preRenderedColorName = "Orange"
        settings.badge.background.source = .image
        settings.badge.background.image = badgeImage
        settings.icon.background.usesCustomGradient = true
        settings.icon.background.gradientStartColor = .red
        settings.icon.background.gradientEndColor = .green
        settings.icon.foreground.renderingStyle = .palette
        settings.icon.foreground.palettePrimaryColor = .pink

        settings.resetToSimpleControls()

        #expect(settings.icon.foreground.image == iconImage)
        #expect(settings.badge.background.image == badgeImage)
        #expect(settings.icon.background.preRenderedColorName == "Orange")
        #expect(settings.icon.background.gradientStartColor == .red)
        #expect(settings.icon.background.gradientEndColor == .green)
        #expect(settings.icon.foreground.palettePrimaryColor == .pink)
    }

    @Test("Settings that only change rendering are left alone")
    func reset_leavesRenderingOnlySettings() {
        var settings = IconSettings()
        settings.icon.background.usesGradient = false
        settings.icon.foreground.symbolWeight = .bold
        settings.icon.background.cornerRadiusStyle = .macOS15
        settings.icon.foreground.symbolScale = 0.8
        settings.badge.foreground.symbolScale = 0.7

        settings.resetToSimpleControls()

        #expect(settings.icon.background.usesGradient == false)
        #expect(settings.icon.foreground.symbolWeight == .bold)
        #expect(settings.icon.background.cornerRadiusStyle == .macOS15)
        #expect(settings.icon.foreground.symbolScale == 0.8)
        #expect(settings.badge.foreground.symbolScale == 0.7)
    }

    @Test("A System badge stays in System mode")
    func reset_leavesSystemBadgeAlone() {
        var settings = IconSettings()
        settings.badge.foreground.source = .system

        settings.resetToSimpleControls()

        // badge.mode is derived from badge.foreground.source, so overwriting it
        // would silently knock the badge out of System mode.
        #expect(settings.badge.foreground.source == .system)
        #expect(settings.badge.mode == .system)
    }

    @Test("A System icon stays in System mode")
    func reset_leavesSystemIconAlone() {
        var settings = IconSettings()
        settings.icon.mode = .system

        settings.resetToSimpleControls()

        #expect(settings.icon.mode == .system)
    }

    @Test("Folding is idempotent")
    func reset_isIdempotent() {
        var once = IconSettings()
        once.icon.foreground.source = .image
        once.resetToSimpleControls()

        var twice = once
        twice.resetToSimpleControls()

        #expect(once == twice)
    }

    // MARK: - Group visibility

    @Test("A group is fully visible only when every layer is", arguments: IconLayerGroup.allCases)
    func isGroupFullyVisible(group: IconLayerGroup) {
        var settings = IconSettings()
        settings.setGroupVisible(true, for: group)
        #expect(settings.isGroupFullyVisible(group))

        // One layer hidden — the simple pane's single toggle must read as off, so
        // switching it on is what clears the leftover flag.
        switch group {
        case .icon:  settings.icon.foreground.isHidden = true
        case .badge: settings.badge.foreground.isHidden = true
        }
        #expect(settings.isGroupFullyVisible(group) == false)
    }

    @Test("Showing a group clears a per-layer hidden flag")
    func setGroupVisible_clearsLayerFlags() {
        var settings = IconSettings()
        settings.icon.foreground.isHidden = true
        settings.badge.background.isHidden = true
        settings.badge.foreground.isHidden = false

        settings.setGroupVisible(true, for: .icon)
        settings.setGroupVisible(true, for: .badge)

        #expect(settings.icon.foreground.isHidden == false)
        #expect(settings.icon.background.isHidden == false)
        #expect(settings.badge.foreground.isHidden == false)
        #expect(settings.badge.background.isHidden == false)
    }

    @Test("Hiding a group hides every layer in it", arguments: IconLayerGroup.allCases)
    func setGroupVisible_hidesWholeGroup(group: IconLayerGroup) {
        var settings = IconSettings()
        settings.setGroupVisible(true, for: group)
        settings.setGroupVisible(false, for: group)

        switch group {
        case .icon:
            #expect(settings.icon.isHidden)
            #expect(settings.icon.foreground.isHidden)
            #expect(settings.icon.background.isHidden)
        case .badge:
            #expect(settings.badge.isHidden)
            #expect(settings.badge.foreground.isHidden)
            #expect(settings.badge.background.isHidden)
        }
    }

    @Test("Group visibility leaves the other group alone")
    func setGroupVisible_isScopedToItsGroup() {
        var settings = IconSettings()
        settings.setGroupVisible(true, for: .badge)
        settings.setGroupVisible(false, for: .icon)

        #expect(settings.icon.isHidden)
        #expect(settings.isGroupFullyVisible(.badge))
    }
}
