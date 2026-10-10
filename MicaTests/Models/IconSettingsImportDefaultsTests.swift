// IconSettingsImportDefaultsTests.swift
// Covers the per-slot imported-image helpers on IconSettings. Every image
// import (menu, paste, drag, sidebar, CLI) routes through these so the
// defaults stay consistent. A background's padding and shadow depend on the
// image: an app icon (transparent edges) gets padding compensation with its
// shadow off, artwork that reaches its edges gets neither. Corners go off for
// either. A foreground import leaves the shadow alone.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct IconSettingsImportDefaultsTests {

    // MARK: - Detection

    @Test("An image with transparent edges has an icon margin")
    func detection_insetSquareHasMargin() throws {
        #expect(try ImportedImage.iconFixture().hasIconMargin)
    }

    @Test("An image that reaches its edges has no icon margin")
    func detection_fullBleedHasNoMargin() throws {
        #expect(try ImportedImage.testFixture(width: 64, height: 64).hasIconMargin == false)
    }

    @Test("Content inside the checked band counts as reaching the edge")
    func detection_contentInsideBandIsFullBleed() throws {
        // 2% in from each side is inside the 4% band.
        #expect(try ImportedImage.iconFixture(size: 100, inset: 0.02).hasIconMargin == false)
    }

    @Test("A non-square image centred on its canvas is not an app icon")
    func detection_letterboxedImageIsFullBleed() throws {
        // Wide artwork normalised to a square leaves transparent bars on two sides only.
        let data = try ImportedImage.pngData(width: 64, height: 64, fill: .systemRed)
        let wide = try #require(NSImage(data: data))
        let canvas = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { _ in
            wide.draw(in: NSRect(x: 0, y: 16, width: 64, height: 32))
            return true
        }
        let tiff = try #require(canvas.tiffRepresentation)
        let png = try #require(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
        let image = ImportedImage(id: UUID(), imageData: png, sourceName: "wide", isFileIcon: false)
        #expect(image.hasIconMargin == false)
    }

    @Test("Data that does not decode reads as an app icon")
    func detection_undecodableReadsAsIcon() {
        let image = ImportedImage(id: UUID(), imageData: Data(), sourceName: "test", isFileIcon: false)
        #expect(image.hasIconMargin)
    }

    // MARK: - Foregrounds

    @Test("Importing an icon foreground sets the source and image and keeps the shadow",
          arguments: [DropShadowStyle.macOS27, .macOS15, .off])
    func iconForeground_keepsShadow(style: DropShadowStyle) throws {
        var settings = IconSettings()
        settings.icon.foreground.shadowStyle = style
        let image = try ImportedImage.iconFixture()

        settings.icon.foreground.apply(image)

        #expect(settings.icon.foreground.source == .image)
        #expect(settings.icon.foreground.image == image)
        #expect(settings.icon.foreground.shadowStyle == style)
    }

    @Test("Importing a badge foreground keeps the shadow")
    func badgeForeground_keepsShadow() throws {
        var settings = IconSettings()
        settings.badge.foreground.shadowStyle = .macOS26

        settings.badge.foreground.apply(try ImportedImage.testFixture())

        #expect(settings.badge.foreground.source == .image)
        #expect(settings.badge.foreground.shadowStyle == .macOS26)
    }

    @Test("Removing a foreground image leaves the shadow as it is")
    func foregroundRemoval_keepsShadow() throws {
        var settings = IconSettings()
        settings.icon.foreground.apply(try ImportedImage.testFixture())
        settings.icon.foreground.shadowStyle = .off

        settings.icon.foreground.removeImage()

        #expect(settings.icon.foreground.source == .symbol)
        #expect(settings.icon.foreground.shadowStyle == .off)
    }

    // MARK: - Icon background

    @Test("Importing an app icon as the icon background fills the frame and turns shadow and corners off")
    func iconBackground_appIcon() throws {
        var settings = IconSettings()
        settings.icon.background.shadowStyle = .macOS26
        let image = try ImportedImage.iconFixture()

        settings.icon.applyBackgroundImage(image)

        #expect(settings.icon.background.source == .image)
        #expect(settings.icon.background.image == image)
        #expect(settings.icon.background.compensatesForPadding == true)
        #expect(settings.icon.background.shadowStyle == .off)
        #expect(settings.icon.background.cornerRadiusStyle == .off)
    }

    @Test("Importing full-bleed artwork as the icon background keeps its edges and shadow, and turns corners off")
    func iconBackground_fullBleedKeepsStyles() throws {
        var settings = IconSettings()
        settings.icon.background.shadowStyle = .macOS15
        settings.icon.background.cornerRadiusStyle = .macOS15

        settings.icon.applyBackgroundImage(try ImportedImage.testFixture(width: 64, height: 64))

        #expect(settings.icon.background.compensatesForPadding == false)
        #expect(settings.icon.background.shadowStyle == .macOS15)
        #expect(settings.icon.background.cornerRadiusStyle == .off)
    }

    @Test("Full-bleed artwork after an app icon turns the shadow back on and leaves corners off")
    func iconBackground_fullBleedAfterAppIcon() throws {
        var settings = IconSettings()
        settings.icon.applyBackgroundImage(try ImportedImage.iconFixture())

        settings.icon.applyBackgroundImage(try ImportedImage.testFixture(width: 64, height: 64))

        #expect(settings.icon.background.compensatesForPadding == false)
        #expect(settings.icon.background.shadowStyle == IconBackgroundSpec().shadowStyle)
        #expect(settings.icon.background.cornerRadiusStyle == .off)
    }

    @Test("With the corner preference off, every import keeps the corners it had")
    func iconBackground_cornerPreferenceOffKeepsCorners() throws {
        let keepCorners = ImportDefaults(hidesForeground: true, turnsOffCornerRadius: false)

        var icon = IconSettings()
        icon.icon.applyBackgroundImage(try ImportedImage.iconFixture(), defaults: keepCorners)
        #expect(icon.icon.background.cornerRadiusStyle == IconBackgroundSpec().cornerRadiusStyle)

        var artwork = IconSettings()
        artwork.icon.background.cornerRadiusStyle = .macOS15
        artwork.icon.applyBackgroundImage(try ImportedImage.testFixture(width: 64, height: 64), defaults: keepCorners)
        #expect(artwork.icon.background.cornerRadiusStyle == .macOS15)
    }

    // MARK: - Badge background

    @Test("Importing an app icon as the badge background fills the frame and turns shadow off")
    func badgeBackground_appIcon() throws {
        var settings = IconSettings()
        let image = try ImportedImage.iconFixture()

        settings.badge.applyBackgroundImage(image)

        #expect(settings.badge.background.source == .image)
        #expect(settings.badge.background.image == image)
        #expect(settings.badge.background.compensatesForPadding == true)
        #expect(settings.badge.background.drawsShadow == false)
    }

    @Test("Importing full-bleed artwork as the badge background keeps its edges and shadow")
    func badgeBackground_fullBleed() throws {
        var settings = IconSettings()
        settings.badge.background.drawsShadow = false
        settings.badge.background.compensatesForPadding = true

        settings.badge.applyBackgroundImage(try ImportedImage.testFixture(width: 64, height: 64))

        #expect(settings.badge.background.compensatesForPadding == false)
        #expect(settings.badge.background.drawsShadow == true)
    }

    // MARK: - Unrelated shadows untouched

    @Test("Importing a background does not change the foreground's shadow")
    func backgroundImportLeavesForegroundShadow() throws {
        var settings = IconSettings()
        #expect(settings.icon.foreground.shadowStyle == .macOS27)
        settings.icon.background.apply(try ImportedImage.iconFixture())
        #expect(settings.icon.foreground.shadowStyle == .macOS27)
    }
}
