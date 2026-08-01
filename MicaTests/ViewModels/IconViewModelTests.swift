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

    @Test("actualExportSize mirrors iconSettings.export.pixelSize without retina")
    func actualExportSize_mirrors_nonRetina() {
        let vm = IconViewModel()
        vm.iconSettings.export.size = 512
        vm.iconSettings.export.isRetina = false
        #expect(vm.actualExportSize == 512)
    }

    @Test("actualExportSize doubles when export.isRetina flips on")
    func actualExportSize_mirrors_retina() {
        let vm = IconViewModel()
        vm.iconSettings.export.size = 512
        vm.iconSettings.export.isRetina = true
        #expect(vm.actualExportSize == 1024)
    }

    // MARK: - AppexGenerationKey

    @Test("appexGenerationKey captures symbol name, enclosure color, symbol color")
    func appexGenerationKey_captures_fields() {
        let vm = IconViewModel()
        vm.iconSettings.icon.foreground.symbolName = "star.fill"
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
        vm.iconSettings.badge.isVisible = true
        vm.iconSettings.badge.foreground.source = .image
        vm.iconSettings.badge.foreground.symbolName = "plus.circle"
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

    // MARK: - Export readiness
    //
    // `canExport` gates both the inspector's Export button and File ▸ Export as PNG…
    // (Cmd-Shift-E), which reaches it through the `exportPNG` focused value. A
    // System-mode layer exports its appex-rendered image, so exporting before that
    // image arrives writes a PNG with the layer missing — silently, since the file
    // still appears. The icon and the badge can be in System mode independently, so
    // the cases below pin that *either* one pending is enough to block.

    private func stubImage() -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16))
    }

    @Test("canExport: a fresh Mica-mode icon with no badge is ready")
    func canExport_micaIcon_isReady() {
        let vm = IconViewModel()
        #expect(vm.canExport)
    }

    @Test("canExport: a Mica-mode icon does not wait on an appex image it never uses")
    func canExport_micaIcon_ignoresMissingAppexImage() {
        let vm = IconViewModel()
        vm.iconSettings.icon.mode = .mica
        vm.appexRenderedImage = nil
        #expect(vm.canExport)
    }

    @Test("canExport: a System-mode icon blocks until its appex image arrives")
    func canExport_systemIcon_blocksWithoutImage() {
        let vm = IconViewModel()
        vm.iconSettings.icon.mode = .system
        vm.appexRenderedImage = nil
        #expect(!vm.canExport)
    }

    @Test("canExport: a System-mode icon is ready once its appex image arrives")
    func canExport_systemIcon_readyWithImage() {
        let vm = IconViewModel()
        vm.iconSettings.icon.mode = .system
        vm.appexRenderedImage = stubImage()
        #expect(vm.canExport)
    }

    @Test("canExport: a visible System-mode badge blocks until its appex image arrives")
    func canExport_systemBadge_blocksWithoutImage() {
        let vm = IconViewModel()
        vm.iconSettings.badge.isVisible = true
        vm.iconSettings.badge.foreground.source = .system
        vm.badgeAppexRenderedImage = nil
        #expect(!vm.canExport)
    }

    @Test("canExport: a visible System-mode badge is ready once its appex image arrives")
    func canExport_systemBadge_readyWithImage() {
        let vm = IconViewModel()
        vm.iconSettings.badge.isVisible = true
        vm.iconSettings.badge.foreground.source = .system
        vm.badgeAppexRenderedImage = stubImage()
        #expect(vm.canExport)
    }

    @Test("canExport: a hidden System-mode badge does not block — it is not being drawn")
    func canExport_hiddenSystemBadge_doesNotBlock() {
        let vm = IconViewModel()
        vm.iconSettings.badge.foreground.source = .system
        vm.iconSettings.badge.isVisible = false
        vm.badgeAppexRenderedImage = nil
        #expect(vm.canExport)
    }

    @Test("canExport: with both layers in System mode, a rendered icon alone is not enough")
    func canExport_bothSystem_pendingBadgeStillBlocks() {
        let vm = IconViewModel()
        vm.iconSettings.icon.mode = .system
        vm.iconSettings.badge.isVisible = true
        vm.iconSettings.badge.foreground.source = .system
        vm.appexRenderedImage = stubImage()
        vm.badgeAppexRenderedImage = nil
        #expect(!vm.canExport)
    }

    @Test("canExport: with both layers in System mode, both images make it ready")
    func canExport_bothSystem_readyWhenBothRendered() {
        let vm = IconViewModel()
        vm.iconSettings.icon.mode = .system
        vm.iconSettings.badge.isVisible = true
        vm.iconSettings.badge.foreground.source = .system
        vm.appexRenderedImage = stubImage()
        vm.badgeAppexRenderedImage = stubImage()
        #expect(vm.canExport)
    }
}
