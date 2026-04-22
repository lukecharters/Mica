// AppViewModelTests.swift
// AppViewModel is a thin coordinator hosting IconViewModel plus a dry-run
// renderer hook. These tests verify default construction and that
// runExportDryRun() invokes IconRenderer without mutating ViewModel state.

import Testing
@testable import macOS_Icon_Generator_App

@Suite(.tags(.unit))
@MainActor
struct AppViewModelTests {

    @Test("Fresh AppViewModel exposes a default IconViewModel")
    func fresh_hasDefaultIconVM() {
        let app = AppViewModel()
        #expect(app.iconVM.iconSettings.symbolName == "folder.fill.badge.plus")
        #expect(app.iconVM.generationMode == .swiftUI)
        #expect(app.iconVM.appexEnclosureColor == .blue)
        #expect(app.iconVM.appexSymbolColor == .white)
    }

    @Test("runExportDryRun does not mutate settings or generation mode")
    func runExportDryRun_doesNotMutate() {
        let app = AppViewModel()
        let settingsBefore = app.iconVM.iconSettings
        let modeBefore = app.iconVM.generationMode

        app.runExportDryRun()

        #expect(app.iconVM.iconSettings == settingsBefore,
                "runExportDryRun must be read-only — result is discarded")
        #expect(app.iconVM.generationMode == modeBefore)
    }
}
