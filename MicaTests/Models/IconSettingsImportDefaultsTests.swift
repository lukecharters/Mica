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
        settings.icon.foreground.drawsShadow = true // explicit on, mirrors struct default
        let image = makeImage()

        settings.icon.foreground.apply(image)

        #expect(settings.icon.foreground.source == .image)
        #expect(settings.icon.foreground.image == image)
        #expect(settings.icon.foreground.drawsShadow == false)
    }

    // MARK: - Icon background

    @Test("Importing an icon background fills the frame and turns shadow off")
    func iconBackground_appliesDefaults() {
        var settings = IconSettings()
        settings.icon.background.shadowStyle = .macOS26
        settings.icon.background.compensatesForPadding = false
        let image = makeImage()

        settings.icon.background.apply(image)

        #expect(settings.icon.background.source == .image)
        #expect(settings.icon.background.image == image)
        #expect(settings.icon.background.compensatesForPadding == true)
        #expect(settings.icon.background.shadowStyle == .off)
    }

    @Test("Icon background padding compensation defaults on regardless of isFileIcon")
    func iconBackground_paddingOnForNonAppIcon() {
        var settings = IconSettings()
        settings.icon.background.apply(makeImage(isFileIcon: false))
        #expect(settings.icon.background.compensatesForPadding == true)
    }

    // MARK: - Badge foreground

    @Test("Importing a badge foreground sets the source, image, and turns shadow off")
    func badgeForeground_appliesDefaults() {
        var settings = IconSettings()
        settings.badge.foreground.drawsShadow = true
        let image = makeImage()

        settings.badge.foreground.apply(image)

        #expect(settings.badge.foreground.source == .image)
        #expect(settings.badge.foreground.image == image)
        #expect(settings.badge.foreground.drawsShadow == false)
    }

    // MARK: - Badge background

    @Test("Importing a badge background fills the frame and turns shadow off")
    func badgeBackground_appliesDefaults() {
        var settings = IconSettings()
        settings.badge.background.drawsShadow = true
        settings.badge.background.compensatesForPadding = false
        let image = makeImage()

        settings.badge.background.apply(image)

        #expect(settings.badge.background.source == .image)
        #expect(settings.badge.background.image == image)
        #expect(settings.badge.background.compensatesForPadding == true)
        #expect(settings.badge.background.drawsShadow == false)
    }

    // MARK: - SF Symbol shadow untouched

    @Test("Import helpers do not change the SF Symbol shadow default for the other layer")
    func helpersDoNotAffectUnrelatedShadows() {
        var settings = IconSettings()
        // A default settings struct keeps symbol shadows on.
        #expect(settings.icon.foreground.drawsShadow == true)
        #expect(settings.badge.foreground.drawsShadow == true)

        // Importing an icon background must not flip the foreground symbol shadow.
        settings.icon.background.apply(makeImage())
        #expect(settings.icon.foreground.drawsShadow == true)
    }
}
