// IconSettingsImportDefaultsTests.swift
// Covers the per-slot imported-image helpers on IconSettings. Every image
// import (menu, paste, drag, sidebar, CLI) routes through these so the
// defaults stay consistent: "Icon Padding" compensation on (fill the frame)
// for the background slots, and the imported-image drop shadow off for all
// four slots. SF Symbol shadow defaults must be left untouched.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct IconSettingsImportDefaultsTests {

    private func makeImage(isFileIcon: Bool = false) -> ImportedImage {
        ImportedImage(id: UUID(), imageData: Data(), sourceName: "test", isFileIcon: isFileIcon)
    }

    // MARK: - Icon foreground

    @Test("Importing an icon foreground sets the source, image, and turns shadow off")
    func iconForeground_appliesDefaults() {
        var settings = IconSettings()
        settings.enableSymbolShadow = true // explicit on, mirrors struct default
        let image = makeImage()

        settings.applyImportedIconForeground(image)

        #expect(settings.iconSource == .image)
        #expect(settings.importedImage == image)
        #expect(settings.enableSymbolShadow == false)
    }

    // MARK: - Icon background

    @Test("Importing an icon background fills the frame and turns shadow off")
    func iconBackground_appliesDefaults() {
        var settings = IconSettings()
        settings.backgroundShadowStyle = .macOS26
        settings.importedBackgroundPaddingCompensation = false
        let image = makeImage()

        settings.applyImportedIconBackground(image)

        #expect(settings.backgroundMode == .image)
        #expect(settings.importedBackground == image)
        #expect(settings.importedBackgroundPaddingCompensation == true)
        #expect(settings.backgroundShadowStyle == .off)
    }

    @Test("Icon background padding compensation defaults on regardless of isFileIcon")
    func iconBackground_paddingOnForNonAppIcon() {
        var settings = IconSettings()
        settings.applyImportedIconBackground(makeImage(isFileIcon: false))
        #expect(settings.importedBackgroundPaddingCompensation == true)
    }

    // MARK: - Badge foreground

    @Test("Importing a badge foreground sets the source, image, and turns shadow off")
    func badgeForeground_appliesDefaults() {
        var settings = IconSettings()
        settings.badgeEnableSymbolShadow = true
        let image = makeImage()

        settings.applyImportedBadgeForeground(image)

        #expect(settings.badgeIconSource == .image)
        #expect(settings.badgeImportedImage == image)
        #expect(settings.badgeEnableSymbolShadow == false)
    }

    // MARK: - Badge background

    @Test("Importing a badge background fills the frame and turns shadow off")
    func badgeBackground_appliesDefaults() {
        var settings = IconSettings()
        settings.badgeEnableBackgroundShadow = true
        settings.badgeImportedBackgroundPaddingCompensation = false
        let image = makeImage()

        settings.applyImportedBadgeBackground(image)

        #expect(settings.badgeUseImportedBackground == true)
        #expect(settings.badgeImportedBackground == image)
        #expect(settings.badgeImportedBackgroundPaddingCompensation == true)
        #expect(settings.badgeEnableBackgroundShadow == false)
    }

    // MARK: - SF Symbol shadow untouched

    @Test("Import helpers do not change the SF Symbol shadow default for the other layer")
    func helpersDoNotAffectUnrelatedShadows() {
        var settings = IconSettings()
        // A default settings struct keeps symbol shadows on.
        #expect(settings.enableSymbolShadow == true)
        #expect(settings.badgeEnableSymbolShadow == true)

        // Importing an icon background must not flip the foreground symbol shadow.
        settings.applyImportedIconBackground(makeImage())
        #expect(settings.enableSymbolShadow == true)
    }
}
