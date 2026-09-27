// SymbolAvailabilityTests.swift
// Which symbol names `generate` refuses before rendering, and with what message.
//
// A Mica-mode layer is decided up front, by the catalog and then NSImage. A
// System-mode layer is refused up front only when the catalog knows the symbol and
// this macOS has no spelling of it; anything else is left to the render, which is
// the only thing that can tell whether IconServices resolves a name. That half runs
// in the smoke test, against the shipped binary.

import Testing
import Foundation

@Suite
@MainActor
struct SymbolAvailabilityTests {

    private static let catalog = try! SymbolCatalog(data: Data(#"""
    {"formatVersion": 1, "symbols": [
      {"name": "fixture.new", "macOS": "27.0", "aliases": [{"name": "fixture.old", "macOS": "15.0"}]},
      {"name": "fixture.only27", "macOS": "27.0"}
    ]}
    """#.utf8))

    private let v15 = MacOSVersion(15, 4)
    private let v27 = MacOSVersion(27)

    private func validate(_ settings: IconSettings, on os: MacOSVersion) throws {
        try IconGenerationRunner().validateResolvedSymbols(settings, catalog: Self.catalog, os: os)
    }

    private func icon(_ name: String, system: Bool = false) -> IconSettings {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = name
        if system { settings.icon.mode = .system }
        return settings
    }

    private func message(_ body: () throws -> Void) -> String? {
        do {
            try body()
            return nil
        } catch let error as CLIError {
            return error.errorDescription
        } catch {
            return "unexpected \(error)"
        }
    }

    @Test("A name nothing knows is refused, naming the macOS it was checked against")
    func unknownNameIsRefused() {
        let text = message { try validate(icon("zz.not.a.symbol"), on: v27) }
        #expect(text == IconGenerationRunner.unknownSymbolMessage("zz.not.a.symbol", os: v27))
        #expect(text?.contains("macOS 27.0") == true)
    }

    @Test("A symbol with no spelling on this macOS names the version it needs")
    func needsNewerMacOS() {
        let text = message { try validate(icon("fixture.only27"), on: v15) }
        #expect(text == "SF Symbol 'fixture.only27' requires macOS 27.0 or later; this Mac is running macOS 15.4.")
    }

    @Test("A new name passes on an older macOS that has its old spelling")
    func renamedSymbolPasses() throws {
        try validate(icon("fixture.new"), on: v15)
        try validate(icon("fixture.old"), on: v27)
    }

    @Test("A name the catalog lacks passes when the system resolves it")
    func systemResolvedNamePasses() throws {
        try validate(icon("circle"), on: v27)
    }

    @Test("System mode leaves a name the catalog lacks to the render")
    func systemModeDefersToTheRender() throws {
        try validate(icon("zz.not.a.symbol", system: true), on: v27)

        var settings = IconSettings()
        settings.badge.isVisible = true
        settings.badge.foreground.source = .system
        settings.badge.foreground.symbolName = "zz.not.a.symbol"
        try validate(settings, on: v27)
    }

    @Test("System mode still refuses a catalog symbol this macOS cannot draw")
    func systemModeRefusesTooNew() {
        let text = message { try validate(icon("fixture.only27", system: true), on: v15) }
        #expect(text?.contains("requires macOS 27.0") == true)
    }

    @Test("A Mica-mode badge is checked like the icon")
    func badgeIsChecked() {
        var settings = IconSettings()
        settings.badge.isVisible = true
        settings.badge.foreground.symbolName = "zz.not.a.symbol"
        #expect(message { try validate(settings, on: v27) } != nil)
    }

    @Test("A hidden badge and an image foreground are not looked up")
    func notLookedUp() throws {
        var settings = IconSettings()
        settings.badge.isVisible = false
        settings.badge.foreground.symbolName = "zz.not.a.symbol"
        try validate(settings, on: v27)

        var image = icon("an-image-file-stem")
        image.icon.foreground.source = .image
        try validate(image, on: v27)
    }

    @Test("The error text is the message alone, without a repeated prefix")
    func noRepeatedPrefix() {
        #expect(CLIError.invalidSymbol("SF Symbol 'x' isn't available.").errorDescription == "SF Symbol 'x' isn't available.")
    }
}
