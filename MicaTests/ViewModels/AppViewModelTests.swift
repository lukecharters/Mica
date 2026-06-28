// AppViewModelTests.swift
// AppViewModel is a thin coordinator hosting IconViewModel.

import Testing
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct AppViewModelTests {

    @Test("Fresh AppViewModel exposes a default IconViewModel")
    func fresh_hasDefaultIconVM() {
        let app = AppViewModel()
        #expect(app.iconVM.iconSettings.symbolName == "command")
        #expect(app.iconVM.generationMode == .swiftUI)
        #expect(app.iconVM.appexEnclosureColor == .blue)
        #expect(app.iconVM.appexSymbolColor == .white)
    }
}
