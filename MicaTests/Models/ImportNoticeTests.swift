// ImportNoticeTests.swift
// The notice shown after a background import: which settings it reports, what
// its revert puts back, and when there is no notice at all.

import Testing
import AppKit
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct ImportNoticeTests {

    private static func artwork() throws -> ImportedImage {
        try ImportedImage.testFixture(width: 64, height: 64)
    }

    private static func notice(
        _ before: IconSettings, _ mutate: (inout IconSettings) throws -> Void
    ) rethrows -> (ImportNotice?, IconSettings) {
        var after = before
        try mutate(&after)
        return (ImportNotice.detect(from: before, to: after), after)
    }

    // MARK: - What it reports

    @Test("An app icon on the icon background reports all four changes")
    func appIcon_reportsEveryChange() throws {
        let (notice, _) = try Self.notice(IconSettings()) {
            $0.icon.applyBackgroundImage(try .iconFixture())
        }
        let found = try #require(notice)
        #expect(found.group == .icon)
        #expect(found.fields == [.padding, .shadow, .corners, .foreground])
        #expect(found.title == "App Icon Imported")
        #expect(found.subtitle == "Icon Padding off · Shadow off · Corners off · Foreground hidden")
    }

    @Test("Artwork over default settings reports only corners and the hidden foreground")
    func artwork_reportsOnlyWhatChanged() throws {
        let (notice, _) = try Self.notice(IconSettings()) {
            $0.icon.applyBackgroundImage(try Self.artwork())
        }
        let found = try #require(notice)
        #expect(found.fields == [.corners, .foreground])
        #expect(found.title == "Artwork Imported")
    }

    @Test("Artwork after an app icon reports the settings it turned back on")
    func artworkAfterAppIcon_reportsSettingsTurnedOn() throws {
        var start = IconSettings()
        start.icon.applyBackgroundImage(try .iconFixture())
        let (notice, _) = try Self.notice(start) {
            $0.icon.applyBackgroundImage(try Self.artwork())
        }
        let found = try #require(notice)
        #expect(found.fields == [.padding, .shadow])
        #expect(found.subtitle == "Icon Padding on · Shadow on")
    }

    @Test("A badge import reports padding, shadow and foreground, and no corners")
    func badgeImport_hasNoCorners() throws {
        var start = IconSettings()
        start.badge.isVisible = true
        let (notice, _) = try Self.notice(start) {
            $0.badge.applyBackgroundImage(try .iconFixture())
        }
        let found = try #require(notice)
        #expect(found.group == .badge)
        #expect(found.fields == [.padding, .shadow, .foreground])
    }

    // MARK: - When there is none

    @Test("Edits that import no background image raise no notice")
    func noNewBackgroundImage_noNotice() throws {
        var start = IconSettings()
        start.icon.applyBackgroundImage(try .iconFixture())

        #expect(Self.notice(start) { $0.icon.background.shadowStyle = .macOS15 }.0 == nil)
        #expect(try Self.notice(start) { $0.icon.foreground.apply(try Self.artwork()) }.0 == nil)
        // Switching the source back to an image already held is not an import.
        var colour = start
        colour.icon.background.source = .color
        #expect(Self.notice(colour) { $0.icon.background.source = .image }.0 == nil)
    }

    @Test("An import that changes nothing else raises no notice")
    func importChangingNothing_noNotice() throws {
        let keepForeground = ImportDefaults(hidesForeground: false, turnsOffCornerRadius: false)
        let (notice, _) = try Self.notice(IconSettings()) {
            $0.icon.applyBackgroundImage(try Self.artwork(), defaults: keepForeground)
        }
        #expect(notice == nil)
    }

    // MARK: - Revert

    @Test("Revert puts back every reported setting and keeps the image")
    func revert_restoresSettingsAndKeepsImage() throws {
        let start = IconSettings()
        let (notice, imported) = try Self.notice(start) {
            $0.icon.applyBackgroundImage(try .iconFixture())
        }
        var settings = imported
        try #require(notice).revert(&settings)

        #expect(settings.icon.background.image == imported.icon.background.image)
        #expect(settings.icon.background.source == .image)
        #expect(settings.icon.background.compensatesForPadding == start.icon.background.compensatesForPadding)
        #expect(settings.icon.background.shadowStyle == start.icon.background.shadowStyle)
        #expect(settings.icon.background.cornerRadiusStyle == start.icon.background.cornerRadiusStyle)
        #expect(settings.icon.foreground.isHidden == start.icon.foreground.isHidden)
    }

    @Test("Revert on the badge puts back its shadow and padding")
    func revert_badge() throws {
        var start = IconSettings()
        start.badge.isVisible = true
        let (notice, imported) = try Self.notice(start) {
            $0.badge.applyBackgroundImage(try .iconFixture())
        }
        var settings = imported
        try #require(notice).revert(&settings)
        #expect(settings.badge.background.drawsShadow == start.badge.background.drawsShadow)
        #expect(settings.badge.background.compensatesForPadding == start.badge.background.compensatesForPadding)
        #expect(settings.badge.foreground.isHidden == start.badge.foreground.isHidden)
    }

    @Test("Revert does nothing once the import has been replaced or removed")
    func revert_staleNoticeIsANoOp() throws {
        let (notice, imported) = try Self.notice(IconSettings()) {
            $0.icon.applyBackgroundImage(try .iconFixture())
        }
        let found = try #require(notice)

        var replaced = imported
        replaced.icon.applyBackgroundImage(try .iconFixture())
        #expect(!found.isCurrent(in: replaced))
        let before = replaced
        found.revert(&replaced)
        #expect(replaced == before)

        var removed = imported
        removed.icon.removeBackgroundImage()
        #expect(!found.isCurrent(in: removed))
    }

    // MARK: - The view model

    @Test("The view model shows the notice after an import and reverts through it")
    func viewModel_observeAndRevert() throws {
        let viewModel = IconViewModel()
        let previous = viewModel.iconSettings
        viewModel.iconSettings.icon.applyBackgroundImage(try .iconFixture())

        viewModel.observeImport(from: previous)
        #expect(viewModel.importNotice?.fields == [.padding, .shadow, .corners, .foreground])

        viewModel.revertImportNotice()
        #expect(viewModel.importNotice == nil)
        #expect(viewModel.iconSettings.icon.background.shadowStyle == previous.icon.background.shadowStyle)
        #expect(viewModel.iconSettings.icon.background.source == .image)
    }

    @Test("A later edit that is not an import leaves the shown notice alone")
    func viewModel_unrelatedEditKeepsNotice() throws {
        let viewModel = IconViewModel()
        let previous = viewModel.iconSettings
        viewModel.iconSettings.icon.applyBackgroundImage(try .iconFixture())
        viewModel.observeImport(from: previous)
        let shown = viewModel.importNotice?.id

        let beforeEdit = viewModel.iconSettings
        viewModel.iconSettings.icon.background.imageScale = 1.2
        viewModel.observeImport(from: beforeEdit)
        #expect(viewModel.importNotice?.id == shown)
    }
}
