// IconViewModelTests.swift
// Covers the synchronous surface of IconViewModel: defaults, derived
// mirror properties, generation-key roll-ups, and preset color
// selectors. Async generateAppexIcon / generateBadgeAppexIcon are
// deferred to Phase 4+ (they require an AppexReferenceProviding seam).

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct IconViewModelTests {

    // MARK: - Defaults

    @Test("Fresh VM has expected published-property defaults")
    func defaults() {
        let vm = IconViewModel()
        #expect(vm.generationMode == .mica)
        #expect(vm.appexEnclosureColor == .blue)
        #expect(vm.appexSymbolColor == .white)
        #expect(vm.badgeAppexEnclosureColor == .blue)
        #expect(vm.badgeAppexSymbolColor == .white)
        #expect(vm.showExportDialog == false)
        #expect(vm.appexIsGenerating == false)
        #expect(vm.badgeAppexIsGenerating == false)
        #expect(vm.appexError == nil)
        #expect(vm.badgeAppexError == nil)
        #expect(vm.appexRenderedImage == nil)
        #expect(vm.badgeAppexRenderedImage == nil)
    }

    // MARK: - Derived mirror property

    @Test("actualExportSize mirrors iconSettings.finalExportSize without retina")
    func actualExportSize_mirrors_nonRetina() {
        let vm = IconViewModel()
        vm.iconSettings.exportSize = 512
        vm.iconSettings.exportRetinaSize = false
        #expect(vm.actualExportSize == 512)
    }

    @Test("actualExportSize doubles when exportRetinaSize flips on")
    func actualExportSize_mirrors_retina() {
        let vm = IconViewModel()
        vm.iconSettings.exportSize = 512
        vm.iconSettings.exportRetinaSize = true
        #expect(vm.actualExportSize == 1024)
    }

    // MARK: - AppexGenerationKey

    @Test("appexGenerationKey captures symbol name, enclosure color, symbol color")
    func appexGenerationKey_captures_fields() {
        let vm = IconViewModel()
        vm.iconSettings.symbolName = "star.fill"
        vm.appexEnclosureColor = .green
        vm.appexSymbolColor = .yellow

        let key = vm.appexGenerationKey
        #expect(key.symbolName == "star.fill")
        #expect(key.enclosureColor == .green)
        #expect(key.symbolColor == .yellow)
    }

    @Test("AppexGenerationKey: identical inputs produce equal keys")
    func appexGenerationKey_equal_whenIdentical() {
        let a = IconViewModel.AppexGenerationKey(symbolName: "star.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.AppexGenerationKey(symbolName: "star.fill", enclosureColor: .blue, symbolColor: .white)
        #expect(a == b)
    }

    @Test("AppexGenerationKey: differing symbol name breaks equality")
    func appexGenerationKey_inequal_differentSymbol() {
        let a = IconViewModel.AppexGenerationKey(symbolName: "star.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.AppexGenerationKey(symbolName: "heart.fill", enclosureColor: .blue, symbolColor: .white)
        #expect(a != b)
    }

    @Test("AppexGenerationKey: differing enclosure color breaks equality")
    func appexGenerationKey_inequal_differentEnclosure() {
        let a = IconViewModel.AppexGenerationKey(symbolName: "star.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.AppexGenerationKey(symbolName: "star.fill", enclosureColor: .green, symbolColor: .white)
        #expect(a != b)
    }

    @Test("AppexGenerationKey: differing symbol color breaks equality")
    func appexGenerationKey_inequal_differentSymbolColor() {
        let a = IconViewModel.AppexGenerationKey(symbolName: "star.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.AppexGenerationKey(symbolName: "star.fill", enclosureColor: .blue, symbolColor: .yellow)
        #expect(a != b)
    }

    // MARK: - BadgeAppexGenerationKey

    @Test("badgeAppexGenerationKey captures all five fields")
    func badgeAppexGenerationKey_captures_all() {
        let vm = IconViewModel()
        vm.iconSettings.showBadge = true
        vm.iconSettings.badgeIconSource = .customImage
        vm.iconSettings.badgeSymbolName = "plus.circle"
        vm.badgeAppexEnclosureColor = .red
        vm.badgeAppexSymbolColor = .black

        let key = vm.badgeAppexGenerationKey
        #expect(key.showBadge == true)
        #expect(key.badgeGenerationMode == .mica)
        #expect(key.symbolName == "plus.circle")
        #expect(key.enclosureColor == .red)
        #expect(key.symbolColor == .black)
    }

    @Test("BadgeAppexGenerationKey: identical inputs produce equal keys")
    func badgeAppexGenerationKey_equal_whenIdentical() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .mica,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .mica,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        #expect(a == b)
    }

    @Test("BadgeAppexGenerationKey: differing showBadge breaks equality")
    func badgeAppexGenerationKey_inequal_differentShowBadge() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .mica,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: false, badgeGenerationMode: .mica,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        #expect(a != b)
    }

    @Test("BadgeAppexGenerationKey: differing badge mode breaks equality")
    func badgeAppexGenerationKey_inequal_differentBadgeIconSource() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .mica,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .system,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        #expect(a != b)
    }

    @Test("BadgeAppexGenerationKey: differing symbol name breaks equality")
    func badgeAppexGenerationKey_inequal_differentSymbolName() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .mica,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .mica,
            symbolName: "bell.fill", enclosureColor: .blue, symbolColor: .white)
        #expect(a != b)
    }

    @Test("BadgeAppexGenerationKey: differing enclosure color breaks equality")
    func badgeAppexGenerationKey_inequal_differentEnclosureColor() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .mica,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .mica,
            symbolName: "gearshape.fill", enclosureColor: .green, symbolColor: .white)
        #expect(a != b)
    }

    @Test("BadgeAppexGenerationKey: differing symbol color breaks equality")
    func badgeAppexGenerationKey_inequal_differentSymbolColor() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .mica,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeGenerationMode: .mica,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .yellow)
        #expect(a != b)
    }
}
