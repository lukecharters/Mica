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
        #expect(vm.generationMode == .swiftUI)
        #expect(vm.appexEnclosureColor == .blue)
        #expect(vm.appexSymbolColor == .white)
        #expect(vm.badgeAppexEnclosureColor == .blue)
        #expect(vm.badgeAppexSymbolColor == .white)
        #expect(vm.showExportDialog == false)
        #expect(vm.exportPath == nil)
        #expect(vm.testingMode == false)
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
        #expect(key.badgeIconSource == .customImage)
        #expect(key.symbolName == "plus.circle")
        #expect(key.enclosureColor == .red)
        #expect(key.symbolColor == .black)
    }

    @Test("BadgeAppexGenerationKey: identical inputs produce equal keys")
    func badgeAppexGenerationKey_equal_whenIdentical() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .sfSymbol,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .sfSymbol,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        #expect(a == b)
    }

    @Test("BadgeAppexGenerationKey: differing showBadge breaks equality")
    func badgeAppexGenerationKey_inequal_differentShowBadge() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .sfSymbol,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: false, badgeIconSource: .sfSymbol,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        #expect(a != b)
    }

    @Test("BadgeAppexGenerationKey: differing badge icon source breaks equality")
    func badgeAppexGenerationKey_inequal_differentBadgeIconSource() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .sfSymbol,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .customImage,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        #expect(a != b)
    }

    @Test("BadgeAppexGenerationKey: differing symbol name breaks equality")
    func badgeAppexGenerationKey_inequal_differentSymbolName() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .sfSymbol,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .sfSymbol,
            symbolName: "bell.fill", enclosureColor: .blue, symbolColor: .white)
        #expect(a != b)
    }

    @Test("BadgeAppexGenerationKey: differing enclosure color breaks equality")
    func badgeAppexGenerationKey_inequal_differentEnclosureColor() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .sfSymbol,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .sfSymbol,
            symbolName: "gearshape.fill", enclosureColor: .green, symbolColor: .white)
        #expect(a != b)
    }

    @Test("BadgeAppexGenerationKey: differing symbol color breaks equality")
    func badgeAppexGenerationKey_inequal_differentSymbolColor() {
        let a = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .sfSymbol,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .white)
        let b = IconViewModel.BadgeAppexGenerationKey(
            showBadge: true, badgeIconSource: .sfSymbol,
            symbolName: "gearshape.fill", enclosureColor: .blue, symbolColor: .yellow)
        #expect(a != b)
    }

    // MARK: - Preset color selectors

    @Test("selectPresetColor with a valid index writes to iconSettings.baseColor")
    func selectPresetColor_valid_writes() {
        let vm = IconViewModel()
        let options: [(name: String, color: Color)] = [
            ("blue", .blue),
            ("green", .green),
            ("red", .red)
        ]
        vm.selectPresetColor(index: 1, options: options)
        #expect(vm.iconSettings.baseColor == .green)
    }

    @Test("selectPresetColor out-of-range index is a no-op",
          arguments: [-1, 3, 99, Int.max])
    func selectPresetColor_outOfRange_noop(_ index: Int) {
        let vm = IconViewModel()
        let original = vm.iconSettings.baseColor
        let options: [(name: String, color: Color)] = [("a", .red)]
        vm.selectPresetColor(index: index, options: options)
        #expect(vm.iconSettings.baseColor == original,
                "Out-of-range index (\(index)) must not mutate baseColor")
    }

    @Test("selectPresetColor with an empty options array is a no-op at any index")
    func selectPresetColor_emptyOptions_noop() {
        let vm = IconViewModel()
        let original = vm.iconSettings.baseColor
        vm.selectPresetColor(index: 0, options: [])
        #expect(vm.iconSettings.baseColor == original)
    }

    @Test("selectBadgePresetColor with a valid index writes to iconSettings.badgeBaseColor")
    func selectBadgePresetColor_valid_writes() {
        let vm = IconViewModel()
        let options: [(name: String, color: Color)] = [
            ("blue", .blue),
            ("purple", .purple)
        ]
        vm.selectBadgePresetColor(index: 0, options: options)
        #expect(vm.iconSettings.badgeBaseColor == .blue)
    }

    @Test("selectBadgePresetColor out-of-range index is a no-op",
          arguments: [-1, 2, 99])
    func selectBadgePresetColor_outOfRange_noop(_ index: Int) {
        let vm = IconViewModel()
        let original = vm.iconSettings.badgeBaseColor
        let options: [(name: String, color: Color)] = [("only", .gray)]
        vm.selectBadgePresetColor(index: index, options: options)
        #expect(vm.iconSettings.badgeBaseColor == original,
                "Out-of-range index (\(index)) must not mutate badgeBaseColor")
    }
}
