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
        iconForeground.iconSource = .customImage
        #expect(iconForeground.usesImportedSources)

        var iconBackground = IconSettings()
        iconBackground.backgroundMode = .importedImage
        #expect(iconBackground.usesImportedSources)

        var badgeForeground = IconSettings()
        badgeForeground.badgeIconSource = .customImage
        #expect(badgeForeground.usesImportedSources)

        var badgeBackground = IconSettings()
        badgeBackground.badgeUseImportedBackground = true
        #expect(badgeBackground.usesImportedSources)
    }

    @Test("A pre-rendered background is not an imported source")
    func usesImportedSources_preRenderedIsNot() {
        var settings = IconSettings()
        settings.backgroundMode = .preRendered
        // It still can't be shown in the simple pane, but it can only be chosen
        // from the advanced controls, so it never needs to reveal them.
        #expect(settings.usesImportedSources == false)
    }

    // MARK: - resetToSimpleControls

    @Test("Imported and pre-rendered sources fold back to symbol + colour")
    func reset_foldsSources() throws {
        var settings = IconSettings()
        settings.iconSource = .customImage
        settings.backgroundMode = .importedImage
        settings.badgeIconSource = .customImage
        settings.badgeUseImportedBackground = true

        settings.resetToSimpleControls()

        #expect(settings.iconSource == .sfSymbol)
        #expect(settings.backgroundMode == .custom)
        #expect(settings.badgeIconSource == .sfSymbol)
        #expect(settings.badgeUseImportedBackground == false)
        #expect(settings.usesImportedSources == false)
    }

    @Test("A pre-rendered background folds back to the plain colour background")
    func reset_foldsPreRendered() {
        var settings = IconSettings()
        settings.backgroundMode = .preRendered

        settings.resetToSimpleControls()

        #expect(settings.backgroundMode == .custom)
    }

    @Test("Rendering modes and custom gradients fold away, since they add rows")
    func reset_foldsMultiRowAppearance() {
        var settings = IconSettings()
        settings.symbolRenderingMode = .palette
        settings.badgeSymbolRenderingMode = .hierarchical
        settings.useCustomColors = true
        settings.badgeUseCustomColors = true

        settings.resetToSimpleControls()

        #expect(settings.symbolRenderingMode == .monochrome)
        #expect(settings.badgeSymbolRenderingMode == .monochrome)
        #expect(settings.useCustomColors == false)
        #expect(settings.badgeUseCustomColors == false)
    }

    @Test("Folding is non-destructive: artwork and colours survive")
    func reset_retainsUnderlyingValues() throws {
        var settings = IconSettings()
        let iconImage = try ImportedImage.testFixture(sourceName: "icon.png")
        let badgeImage = try ImportedImage.testFixture(sourceName: "badge.png")
        settings.iconSource = .customImage
        settings.importedImage = iconImage
        settings.backgroundMode = .preRendered
        settings.preRenderedColorName = "Orange"
        settings.badgeUseImportedBackground = true
        settings.badgeImportedBackground = badgeImage
        settings.useCustomColors = true
        settings.customPrimaryColor = .red
        settings.customSecondaryColor = .green
        settings.symbolRenderingMode = .palette
        settings.paletteSymbolPrimaryColor = .pink

        settings.resetToSimpleControls()

        #expect(settings.importedImage == iconImage)
        #expect(settings.badgeImportedBackground == badgeImage)
        #expect(settings.preRenderedColorName == "Orange")
        #expect(settings.customPrimaryColor == .red)
        #expect(settings.customSecondaryColor == .green)
        #expect(settings.paletteSymbolPrimaryColor == .pink)
    }

    @Test("Settings that only change rendering are left alone")
    func reset_leavesRenderingOnlySettings() {
        var settings = IconSettings()
        settings.enableBackgroundGradient = false
        settings.symbolWeight = .bold
        settings.cornerRadiusStyle = .macOS11
        settings.manualSymbolScale = 0.8
        settings.badgeSymbolScale = 0.7

        settings.resetToSimpleControls()

        #expect(settings.enableBackgroundGradient == false)
        #expect(settings.symbolWeight == .bold)
        #expect(settings.cornerRadiusStyle == .macOS11)
        #expect(settings.manualSymbolScale == 0.8)
        #expect(settings.badgeSymbolScale == 0.7)
    }

    @Test("A System badge stays in System mode")
    func reset_leavesSystemBadgeAlone() {
        var settings = IconSettings()
        settings.badgeIconSource = .system

        settings.resetToSimpleControls()

        // badgeGenerationMode is derived from badgeIconSource, so overwriting it
        // would silently knock the badge out of System mode.
        #expect(settings.badgeIconSource == .system)
        #expect(settings.badgeGenerationMode == .system)
    }

    @Test("A System icon stays in System mode")
    func reset_leavesSystemIconAlone() {
        var settings = IconSettings()
        settings.iconGenerationMode = .system

        settings.resetToSimpleControls()

        #expect(settings.iconGenerationMode == .system)
    }

    @Test("Folding is idempotent")
    func reset_isIdempotent() {
        var once = IconSettings()
        once.iconSource = .customImage
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
        case .icon:  settings.iconForegroundHidden = true
        case .badge: settings.badgeForegroundHidden = true
        }
        #expect(settings.isGroupFullyVisible(group) == false)
    }

    @Test("Showing a group clears a per-layer hidden flag")
    func setGroupVisible_clearsLayerFlags() {
        var settings = IconSettings()
        settings.iconForegroundHidden = true
        settings.badgeBackgroundHidden = true
        settings.badgeForegroundHidden = false

        settings.setGroupVisible(true, for: .icon)
        settings.setGroupVisible(true, for: .badge)

        #expect(settings.iconForegroundHidden == false)
        #expect(settings.iconBackgroundHidden == false)
        #expect(settings.badgeForegroundHidden == false)
        #expect(settings.badgeBackgroundHidden == false)
    }

    @Test("Hiding a group hides every layer in it", arguments: IconLayerGroup.allCases)
    func setGroupVisible_hidesWholeGroup(group: IconLayerGroup) {
        var settings = IconSettings()
        settings.setGroupVisible(true, for: group)
        settings.setGroupVisible(false, for: group)

        switch group {
        case .icon:
            #expect(settings.iconHidden)
            #expect(settings.iconForegroundHidden)
            #expect(settings.iconBackgroundHidden)
        case .badge:
            #expect(settings.badgeHidden)
            #expect(settings.badgeForegroundHidden)
            #expect(settings.badgeBackgroundHidden)
        }
    }

    @Test("Group visibility leaves the other group alone")
    func setGroupVisible_isScopedToItsGroup() {
        var settings = IconSettings()
        settings.setGroupVisible(true, for: .badge)
        settings.setGroupVisible(false, for: .icon)

        #expect(settings.iconHidden)
        #expect(settings.isGroupFullyVisible(.badge))
    }
}
