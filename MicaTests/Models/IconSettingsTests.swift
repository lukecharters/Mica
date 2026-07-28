// IconSettingsTests.swift
// Unit tests for the IconSettings struct: defaults, computed properties,
// enum round-trips. Complements IconSettingsValidationTests (which covers
// the size constants and isExportSizeValid).

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
        #expect(s.symbolName == "command")
        #expect(s.exportSize == 512)
        #expect(s.exportRetinaSize == false)
        #expect(s.symbolRenderingMode == .monochrome)
        #expect(s.symbolColorRenderingMode == .flat)
        #expect(s.backgroundMode == .custom)
        #expect(s.preRenderedColorName == "Blue")
        #expect(s.cornerRadiusStyle == .macOS26)
        #expect(s.exportColorSpace == .sRGB)
        #expect(s.enableBackgroundGradient == true)
        #expect(s.useCustomColors == false)
        #expect(s.showBadge == false)
        #expect(s.badgePosition == .bottomRight)
        #expect(s.badgeSymbolName == "gearshape.fill")
        #expect(s.iconSource == .sfSymbol)
        #expect(s.importedImage == nil)
        #expect(s.manualSymbolScale == 1.0)
        #expect(s.badgeManualOffsetX == 0.0)
        #expect(s.badgeManualOffsetY == 0.0)
    }

    // MARK: - finalExportSize

    @Test("finalExportSize equals exportSize without retina")
    func finalExportSize_nonRetina() {
        var s = IconSettings()
        s.exportSize = 256
        s.exportRetinaSize = false
        #expect(s.finalExportSize == 256)

        s.exportSize = 1024
        #expect(s.finalExportSize == 1024)
    }

    @Test("finalExportSize doubles with retina")
    func finalExportSize_retina() {
        var s = IconSettings()
        s.exportSize = 256
        s.exportRetinaSize = true
        #expect(s.finalExportSize == 512)

        s.exportSize = 1024
        #expect(s.finalExportSize == 2048)
    }

    // MARK: - preRenderedAssetName

    @Test("preRenderedAssetName composes lowercase color + gradient/solid suffix")
    func preRenderedAssetName_gradientAndSolid() {
        var s = IconSettings()
        s.preRenderedColorName = "Blue"
        s.enableBackgroundGradient = true
        #expect(s.preRenderedAssetName == "background-blue-gradient")

        s.enableBackgroundGradient = false
        #expect(s.preRenderedAssetName == "background-blue-solid")

        s.preRenderedColorName = "GraphitE"
        #expect(s.preRenderedAssetName == "background-graphite-solid")
    }

    // MARK: - gradientColors / badgeGradientColors

    @Test("gradientColors returns [customPrimaryColor, customSecondaryColor]")
    func gradientColors_mirrorsCustomColors() {
        var s = IconSettings()
        s.customPrimaryColor = .red
        s.customSecondaryColor = .green
        #expect(s.gradientColors == [.red, .green])
    }

    @Test("badgeGradientColors returns [badgeCustomPrimaryColor, badgeCustomSecondaryColor]")
    func badgeGradientColors_mirrorsBadgeCustomColors() {
        var s = IconSettings()
        s.badgeCustomPrimaryColor = .white
        s.badgeCustomSecondaryColor = .indigo
        #expect(s.badgeGradientColors == [.white, .indigo])
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

        b.symbolName = "star.fill"
        #expect(a != b)

        a = IconSettings()
        b = IconSettings()
        b.exportSize = 256  // differ from the default (512) so equality breaks
        #expect(a != b)

        a = IconSettings()
        b = IconSettings()
        b.exportRetinaSize = true
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

    @Test("BackgroundMode raw-value round-trips", arguments: BackgroundMode.allCases)
    func backgroundMode_roundTrip(_ mode: BackgroundMode) throws {
        let rt = try #require(BackgroundMode(rawValue: mode.rawValue))
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
