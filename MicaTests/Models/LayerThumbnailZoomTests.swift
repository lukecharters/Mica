// LayerThumbnailZoomTests.swift
// Tests for `LayerThumbnail.foregroundZoom`, which frames a foreground thumbnail
// on its glyph: the glyph's box, drawn at the zoomed canvas and moved by the
// offset, must land centred in the tile at `foregroundRatio` of its side.

import CoreGraphics
import Testing
@testable import Mica

@MainActor
@Suite(.tags(.unit))
struct LayerThumbnailZoomTests {

    static let size: CGFloat = 32

    /// The glyph's box as the tile shows it: measured on the zoomed canvas, which
    /// the tile centres, then moved by the zoom's offset.
    private static func boxInTile(_ group: IconLayerGroup, _ settings: IconSettings) throws -> CGRect {
        let zoom = try #require(LayerThumbnail.foregroundZoom(
            group: group, layer: .foreground, settings: settings, size: size))
        let canvas = size * zoom.scale
        let selection: PreviewSelection = group == .icon ? .iconForeground : .badgeForeground
        guard case let .roundedRect(box, _) = PreviewHitTester.selectionShape(
            for: selection, settings: settings, displaySize: canvas) else {
            Issue.record("No foreground box for \(group)")
            return .null
        }
        let inset = (canvas - size) / 2
        return box.offsetBy(dx: zoom.offset.width - inset, dy: zoom.offset.height - inset)
    }

    private static func expectCentredAndFilling(_ box: CGRect) {
        let expectedSide = size * LayerThumbnail.foregroundRatio
        #expect(abs(box.midX - size / 2) < 0.001)
        #expect(abs(box.midY - size / 2) < 0.001)
        #expect(abs(max(box.width, box.height) - expectedSide) < 0.001)
    }

    @Test("A foreground's glyph is centred in the tile and fills it",
          arguments: [IconLayerGroup.icon, .badge])
    func glyphIsCentredAndFills(group: IconLayerGroup) throws {
        let settings = try #require(IconSettings().isolatingLayer(group, .foreground))
        Self.expectCentredAndFilling(try Self.boxInTile(group, settings))
    }

    @Test("A nudged foreground is still centred", arguments: [IconLayerGroup.icon, .badge])
    func nudgedGlyphIsCentred(group: IconLayerGroup) throws {
        var settings = IconSettings()
        settings.icon.foreground.offsetX = 0.3
        settings.icon.foreground.offsetY = -0.2
        settings.badge.foreground.offsetX = 0.3
        settings.badge.foreground.offsetY = -0.2
        let isolated = try #require(settings.isolatingLayer(group, .foreground))
        Self.expectCentredAndFilling(try Self.boxInTile(group, isolated))
    }

    @Test("An imported badge glyph is centred in the tile and fills it")
    func importedBadgeGlyphIsCentredAndFills() throws {
        var settings = IconSettings()
        settings.badge.foreground.apply(try ImportedImage.testFixture())
        settings.badge.foreground.imageScale = 1.3
        let isolated = try #require(settings.isolatingLayer(.badge, .foreground))
        Self.expectCentredAndFilling(try Self.boxInTile(.badge, isolated))
    }

    @Test("A background is not zoomed", arguments: [IconLayerGroup.icon, .badge])
    func backgroundIsNotZoomed(group: IconLayerGroup) throws {
        let settings = try #require(IconSettings().isolatingLayer(group, .background))
        #expect(LayerThumbnail.foregroundZoom(
            group: group, layer: .background, settings: settings, size: Self.size) == nil)
    }

    @Test("A tiny glyph's zoom is capped")
    func tinyGlyphZoomIsCapped() throws {
        var settings = IconSettings()
        settings.icon.foreground.symbolScale = 0.01
        let isolated = try #require(settings.isolatingLayer(.icon, .foreground))
        let zoom = try #require(LayerThumbnail.foregroundZoom(
            group: .icon, layer: .foreground, settings: isolated, size: Self.size))
        #expect(zoom.scale == LayerThumbnail.maxZoom)
    }
}
