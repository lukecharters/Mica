// AppViewModelTests.swift
// AppViewModel is a thin coordinator hosting IconViewModel.

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
}
