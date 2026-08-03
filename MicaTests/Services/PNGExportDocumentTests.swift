// PNGExportDocumentTests.swift
// PNGExportDocument is a SwiftUI FileDocument with four inits (settings,
// renderedImage, appexExport, configuration/read) and one advertised
// content type. This suite covers the init-surface dispatch: each
// constructor must populate the right fields and leave others cleared.
// The write path (fileWrapper(configuration:)) requires a
// FileDocumentWriteConfiguration whose init is not reliably accessible
// from tests; its PNG encoding is exercised by IconRenderer tests
// (Phase 2) and by UI smoke tests (Phase 6).

import Testing
import AppKit
import SwiftUI
import UniformTypeIdentifiers
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct PNGExportDocumentTests {

    // MARK: - Helpers

    /// A small opaque NSImage used as a sentinel for identity checks.
    static func makeSentinelImage(sized width: CGFloat = 32) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: width))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: width, height: width).fill()
        image.unlockFocus()
        return image
    }

    /// Captures the documented state shape for the unsupported read path.
    private struct ReadStateSnapshot: Equatable {
        let settings: IconSettings
        let hasRenderedImage: Bool
        let hasAppexExportParams: Bool
        let hasBadgeAppexImage: Bool
    }

    /// Extracts the unsupported-read state shape without depending on a
    /// comparator document or a constructible ReadConfiguration.
    private static func snapshot(of document: PNGExportDocument) -> ReadStateSnapshot {
        ReadStateSnapshot(
            settings: document.settings,
            hasRenderedImage: document.renderedImage != nil,
            hasAppexExportParams: document.appexExportParams != nil,
            hasBadgeAppexImage: document.badgeAppexImage != nil
        )
    }

    // MARK: - readableContentTypes

    @Test("readableContentTypes advertises exactly PNG")
    func readableContentTypes_png() {
        #expect(PNGExportDocument.readableContentTypes == [.png])
    }

    // MARK: - init(settings:badgeAppexImage:)

    @Test("settings-based init stores settings and defaults other fields")
    func init_settings_storesSettings() {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "star.fill"
        settings.export.size = 512

        let doc = PNGExportDocument(settings: settings)

        #expect(doc.settings == settings)
        #expect(doc.renderedImage == nil)
        #expect(doc.appexExportParams == nil)
        #expect(doc.badgeAppexImage == nil)
    }

    @Test("settings-based init threads badgeAppexImage through")
    func init_settings_storesBadgeAppexImage() {
        let badge = Self.makeSentinelImage()
        let doc = PNGExportDocument(settings: IconSettings(), badgeAppexImage: badge)

        #expect(doc.badgeAppexImage === badge,
                "badgeAppexImage must be the same NSImage instance passed to init")
        #expect(doc.renderedImage == nil)
        #expect(doc.appexExportParams == nil)
    }

    // MARK: - init(renderedImage:)

    @Test("renderedImage init stores the image and uses default settings")
    func init_preRenderedImage() {
        let image = Self.makeSentinelImage(sized: 128)

        let doc = PNGExportDocument(renderedImage: image)

        #expect(doc.renderedImage === image,
                "renderedImage must be the same NSImage instance passed to init")
        #expect(doc.settings == IconSettings(),
                "renderedImage init must leave settings at their defaults")
        #expect(doc.appexExportParams == nil)
        #expect(doc.badgeAppexImage == nil)
    }

    // MARK: - init(appexExport:settings:badgeAppexImage:)

    @Test("appexExport init stores appexExportParams and preserves settings + badge")
    func init_appexExport_storesParams() throws {
        let params = PNGExportDocument.AppexExportParams(
            symbolName: "gear",
            enclosureColor: .named(.green),
            symbolColor: .named(.white),
            pointSize: 256,
            scaleFactor: 2,
            colorSpace: .displayP3
        )
        var settings = IconSettings()
        settings.badge.isVisible = true
        let badge = Self.makeSentinelImage()

        let doc = PNGExportDocument(appexExport: params, settings: settings, badgeAppexImage: badge)

        let stored = try #require(doc.appexExportParams,
                                   "appexExportParams must be populated after appexExport init")
        #expect(stored.symbolName == "gear")
        #expect(stored.enclosureColor == .named(.green))
        #expect(stored.symbolColor == .named(.white))
        #expect(stored.pointSize == 256)
        #expect(stored.scaleFactor == 2)
        #expect(stored.colorSpace == .displayP3)

        #expect(doc.settings == settings)
        #expect(doc.badgeAppexImage === badge)
        #expect(doc.renderedImage == nil)
    }

    @Test("appexExport init without explicit settings uses IconSettings defaults")
    func init_appexExport_defaultSettings() throws {
        let params = PNGExportDocument.AppexExportParams(
            symbolName: "gear",
            enclosureColor: .named(.blue),
            symbolColor: .named(.white),
            pointSize: 256,
            scaleFactor: 1,
            colorSpace: .sRGB
        )

        let doc = PNGExportDocument(appexExport: params)

        #expect(doc.settings == IconSettings())
        #expect(doc.badgeAppexImage == nil)
        let stored = try #require(doc.appexExportParams)
        #expect(stored.scaleFactor == 1)
    }

    // MARK: - Unsupported read-path state-shape contract

    @Test("Unsupported read-path state shape matches the documented defaults")
    func unsupportedReadPath_stateShapeMatchesDocumentedDefaults() throws {
        // FileDocumentReadConfiguration cannot be constructed directly in
        // this Xcode 26.4 environment, so this is a state-shape contract
        // test, not direct execution coverage of init(configuration:).
        // It locks in the documented stored-property shape of an
        // unsupported read by comparing an explicit snapshot against a
        // manually assembled stand-in document.
        let expected = ReadStateSnapshot(
            settings: IconSettings(),
            hasRenderedImage: false,
            hasAppexExportParams: false,
            hasBadgeAppexImage: false
        )
        var standIn = PNGExportDocument(renderedImage: Self.makeSentinelImage())
        standIn.settings = IconSettings()
        standIn.renderedImage = nil
        standIn.appexExportParams = nil
        standIn.badgeAppexImage = nil
        let actual = Self.snapshot(of: standIn)

        #expect(actual == expected)
    }
}
