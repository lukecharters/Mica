// LayerThumbnailIsolationTests.swift
// Tests for `IconSettings.isolatingLayer(_:_:)`, the staging a sidebar layer
// thumbnail renders: exactly one layer drawn, and nothing else changed.

import Testing
@testable import Mica

@Suite(.tags(.unit))
struct LayerThumbnailIsolationTests {

    /// Every (group, layer) pair that has a thumbnail.
    static let layers: [(IconLayerGroup, LayerTab)] = [
        (.icon, .foreground), (.icon, .background),
        (.badge, .foreground), (.badge, .background),
    ]

    private static func hiddenFlags(_ s: IconSettings) -> [Bool] {
        [s.icon.foreground.isHidden, s.icon.background.isHidden,
         s.badge.foreground.isHidden, s.badge.background.isHidden]
    }

    @Test("Only the isolated layer is visible", arguments: 0..<4)
    func onlyTheIsolatedLayerIsVisible(index: Int) throws {
        let (group, tab) = Self.layers[index]
        var settings = IconSettings()
        settings.badge.isVisible = true

        let isolated = try #require(settings.isolatingLayer(group, tab))

        var expected = [true, true, true, true]
        expected[index] = false
        #expect(Self.hiddenFlags(isolated) == expected)
    }

    @Test("A hidden layer is drawn in its own thumbnail", arguments: 0..<4)
    func aHiddenLayerIsForcedVisible(index: Int) throws {
        let (group, tab) = Self.layers[index]
        var settings = IconSettings()
        settings.icon.isHidden = true
        settings.badge.isHidden = true

        let isolated = try #require(settings.isolatingLayer(group, tab))

        #expect(Self.hiddenFlags(isolated)[index] == false)
    }

    @Test("Isolating changes nothing but the four visibility flags", arguments: 0..<4)
    func nothingElseChanges(index: Int) throws {
        let (group, tab) = Self.layers[index]
        var settings = IconSettings()
        settings.icon.background.shadowStyle = .off
        settings.icon.foreground.symbolScale = 1.2
        settings.badge.scale = 1.3

        var isolated = try #require(settings.isolatingLayer(group, tab))
        isolated.icon.foreground.isHidden = settings.icon.foreground.isHidden
        isolated.icon.background.isHidden = settings.icon.background.isHidden
        isolated.badge.foreground.isHidden = settings.badge.foreground.isHidden
        isolated.badge.background.isHidden = settings.badge.background.isHidden

        #expect(isolated == settings)
    }

    @Test("Layout is not a layer, so it has no thumbnail")
    func layoutHasNoThumbnail() {
        #expect(IconSettings().isolatingLayer(.badge, .layout) == nil)
    }
}
