// IconSettingsTests.swift
// Unit tests for the IconSettings struct: defaults, computed properties,
// enum round-trips. Complements IconSettingsValidationTests (which covers
// the size constants and export.isSizeValid).

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct IconSettingsTests {

    // MARK: - Defaults

    @Test("Defaults match the shipped initial configuration")
    func defaults_areStable() {
        let s = IconSettings()
        #expect(s.icon.foreground.symbolName == "command")
        #expect(s.export.size == 512)
        #expect(s.export.isRetina == false)
        #expect(s.icon.foreground.renderingStyle == .monochrome)
        #expect(s.icon.foreground.fillStyle == .flat)
        #expect(s.icon.background.source == .color)
        #expect(s.icon.background.preRenderedColorName == "Blue")
        #expect(s.icon.background.cornerRadiusStyle == .macOS26)
        #expect(s.export.colorSpace == .sRGB)
        #expect(s.icon.background.usesGradient == true)
        #expect(s.icon.background.usesCustomGradient == false)
        #expect(s.badge.isVisible == false)
        #expect(s.badge.position == .bottomRight)
        #expect(s.badge.foreground.symbolName == "gearshape.fill")
        #expect(s.icon.foreground.source == .symbol)
        #expect(s.icon.foreground.image == nil)
        #expect(s.icon.foreground.symbolScale == 1.0)
        #expect(s.badge.offsetX == 0.0)
        #expect(s.badge.offsetY == 0.0)
    }

    // MARK: - export.pixelSize

    @Test("export.pixelSize equals export.size without retina")
    func finalExportSize_nonRetina() {
        var s = IconSettings()
        s.export.size = 256
        s.export.isRetina = false
        #expect(s.export.pixelSize == 256)

        s.export.size = 1024
        #expect(s.export.pixelSize == 1024)
    }

    @Test("export.pixelSize doubles with retina")
    func finalExportSize_retina() {
        var s = IconSettings()
        s.export.size = 256
        s.export.isRetina = true
        #expect(s.export.pixelSize == 512)

        s.export.size = 1024
        #expect(s.export.pixelSize == 2048)
    }

    // MARK: - icon.background.preRenderedAssetName

    @Test("icon.background.preRenderedAssetName composes lowercase color + gradient/solid suffix")
    func preRenderedAssetName_gradientAndSolid() {
        var s = IconSettings()
        s.icon.background.preRenderedColorName = "Blue"
        s.icon.background.usesGradient = true
        #expect(s.icon.background.preRenderedAssetName == "background-blue-gradient")

        s.icon.background.usesGradient = false
        #expect(s.icon.background.preRenderedAssetName == "background-blue-solid")

        s.icon.background.preRenderedColorName = "GraphitE"
        #expect(s.icon.background.preRenderedAssetName == "background-graphite-solid")
    }

    // MARK: - icon.background.gradientColors / badge.background.gradientColors

    @Test("icon.background.gradientColors returns [icon.background.gradientStartColor, icon.background.gradientEndColor]")
    func gradientColors_mirrorsCustomColors() {
        var s = IconSettings()
        s.icon.background.gradientStartColor = .red
        s.icon.background.gradientEndColor = .green
        #expect(s.icon.background.gradientColors == [.red, .green])
    }

    @Test("badge.background.gradientColors returns [badge.background.gradientStartColor, badge.background.gradientEndColor]")
    func badgeGradientColors_mirrorsBadgeCustomColors() {
        var s = IconSettings()
        s.badge.background.gradientStartColor = .white
        s.badge.background.gradientEndColor = .indigo
        #expect(s.badge.background.gradientColors == [.white, .indigo])
    }

    // MARK: - Equatable

    @Test("Two default IconSettings are equal")
    func equatable_defaultsEqual() {
        #expect(IconSettings() == IconSettings())
    }

    @Test("Mutating any tracked field breaks equality")
    func equatable_mutationBreaksEquality() {
        var a = IconSettings()
        var b = IconSettings()
        #expect(a == b)

        b.icon.foreground.symbolName = "star.fill"
        #expect(a != b)

        a = IconSettings()
        b = IconSettings()
        b.export.size = 256  // differ from the default (512) so equality breaks
        #expect(a != b)

        a = IconSettings()
        b = IconSettings()
        b.export.isRetina = true
        #expect(a != b)
    }

    // MARK: - Enum round-trips

    @Test("SymbolRenderingStyle raw-value round-trips", arguments: SymbolRenderingStyle.allCases)
    func symbolRenderingMode_roundTrip(_ mode: SymbolRenderingStyle) throws {
        let rt = try #require(SymbolRenderingStyle(rawValue: mode.rawValue))
        #expect(rt == mode)
        #expect(rt.id == mode.rawValue)
    }

    @Test("ExportColorSpace raw-value round-trips", arguments: ExportColorSpace.allCases)
    func exportColorSpace_roundTrip(_ space: ExportColorSpace) throws {
        let rt = try #require(ExportColorSpace(rawValue: space.rawValue))
        #expect(rt == space)
    }

    @Test("ExportColorSpace nsColorSpace matches expected macOS color space")
    func exportColorSpace_nsColorSpace() {
        #expect(ExportColorSpace.sRGB.nsColorSpace == .sRGB)
        #expect(ExportColorSpace.displayP3.nsColorSpace == .displayP3)
    }

    @Test("BadgePosition raw-value round-trips", arguments: BadgePosition.allCases)
    func badgePosition_roundTrip(_ pos: BadgePosition) throws {
        let rt = try #require(BadgePosition(rawValue: pos.rawValue))
        #expect(rt == pos)
    }

    @Test("IconBackgroundSource raw-value round-trips", arguments: IconBackgroundSource.allCases)
    func backgroundMode_roundTrip(_ mode: IconBackgroundSource) throws {
        let rt = try #require(IconBackgroundSource(rawValue: mode.rawValue))
        #expect(rt == mode)
    }

    @Test("IconCornerRadiusStyle raw-value round-trips", arguments: IconCornerRadiusStyle.allCases)
    func cornerRadiusStyle_roundTrip(_ style: IconCornerRadiusStyle) throws {
        let rt = try #require(IconCornerRadiusStyle(rawValue: style.rawValue))
        #expect(rt == style)
    }

    @Test("BackgroundShadowStyle raw-value round-trips", arguments: BackgroundShadowStyle.allCases)
    func backgroundShadowStyle_roundTrip(_ style: BackgroundShadowStyle) throws {
        let rt = try #require(BackgroundShadowStyle(rawValue: style.rawValue))
        #expect(rt == style)
    }

    @Test("SymbolWeight raw-value round-trips", arguments: SymbolWeight.allCases)
    func symbolWeight_roundTrip(_ w: SymbolWeight) throws {
        let rt = try #require(SymbolWeight(rawValue: w.rawValue))
        #expect(rt == w)
    }

    @Test("SymbolWeight.auto maps to nil fontWeight; others map to a concrete weight")
    func symbolWeight_fontWeightMapping() {
        #expect(SymbolWeight.auto.fontWeight == nil)
        // Non-.auto cases all produce a non-nil Font.Weight.
        for w in SymbolWeight.allCases where w != .auto {
            #expect(w.fontWeight != nil, "Expected non-nil fontWeight for \(w)")
        }
    }
}
