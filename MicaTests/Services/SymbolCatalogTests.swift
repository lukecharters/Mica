// SymbolCatalogTests.swift
// Tests for which spelling of a symbol SymbolCatalog picks on a given macOS.
//
// Everything runs against the synthetic catalog below, not the shipped one: the shipped
// file is regenerated from Apple's data every release, so a test that named one of its
// symbols would report Apple's renames as defects. The single test over the bundled file
// checks only that it loads.

import Testing
import Foundation
@testable import Mica

@Suite(.tags(.unit))
struct SymbolCatalogTests {

    private static let fixture = """
    {
      "formatVersion": 1,
      "generatedFrom": {"macOS": "27.0 (test)", "sfSymbolsApp": "27.0 (test)"},
      "symbols": [
        {"name": "star", "macOS": "11.0"},
        {"name": "coin.building.classical", "macOS": "27.0",
         "aliases": [{"name": "coin.bank.building", "macOS": "15.0"}]},
        {"name": "trio.new", "macOS": "27.0",
         "aliases": [{"name": "trio.old", "macOS": "11.0"}, {"name": "trio.mid", "macOS": "14.0"}]},
        {"name": "brandnew", "macOS": "27.0"},
        {"name": "ancient", "macOS": "11.0", "aliases": [{"name": "ancient.legacy"}]}
      ],
      "retired": [
        {"name": "gone.symbol", "macOS": "15.0"}
      ]
    }
    """

    private let catalog = try! SymbolCatalog(data: Data(fixture.utf8))

    private let v11 = MacOSVersion(11)
    private let v14 = MacOSVersion(14)
    private let v15 = MacOSVersion(15)
    private let v27 = MacOSVersion(27)

    private func status(_ name: String, on os: MacOSVersion, systemResolves: Bool = false) -> SymbolCatalog.Status {
        catalog.status(of: name, on: os, systemResolves: { _ in systemResolves })
    }

    // MARK: - Render names

    @Test("A name new on 27 is drawn under its old alias on 15")
    func newNameUsesAliasOnOlderOS() {
        #expect(catalog.renderName(for: "coin.building.classical", on: v15) == "coin.bank.building")
    }

    @Test("An old name stays as it is where it still exists")
    func oldNameIsKept() {
        #expect(catalog.renderName(for: "coin.bank.building", on: v27) == "coin.bank.building")
        #expect(catalog.renderName(for: "coin.bank.building", on: v15) == "coin.bank.building")
    }

    @Test("A current name stays current where it exists")
    func currentNameIsKept() {
        #expect(catalog.renderName(for: "coin.building.classical", on: v27) == "coin.building.classical")
        #expect(catalog.renderName(for: "star", on: v15) == "star")
    }

    @Test("The newest alias available on the OS is chosen",
          arguments: [(MacOSVersion(13), "trio.old"), (MacOSVersion(14), "trio.mid"), (MacOSVersion(26, 1), "trio.mid")])
    func newestAvailableAlias(os: MacOSVersion, expected: String) {
        #expect(catalog.renderName(for: "trio.new", on: os) == expected)
    }

    @Test("An alias newer than the OS gives way to an older spelling")
    func aliasNewerThanOSFallsBack() {
        #expect(catalog.renderName(for: "trio.mid", on: MacOSVersion(13)) == "trio.old")
    }

    @Test("An alias with no recorded version is recognised but never chosen")
    func unversionedAlias() {
        #expect(catalog.renderName(for: "ancient.legacy", on: v15) == "ancient")
        #expect(catalog.renderName(for: "ancient", on: v15) == "ancient")
        #expect(status("ancient.legacy", on: v15) == .available(renderName: "ancient"))
    }

    @Test("The drawable name is the render name, or the name unchanged when the catalog has none")
    func drawableName() {
        #expect(catalog.drawableName(for: "coin.building.classical", on: v15) == "coin.bank.building")
        #expect(catalog.drawableName(for: "brandnew", on: v15) == "brandnew")
        #expect(catalog.drawableName(for: "not.in.catalog", on: v15) == "not.in.catalog")
    }

    // MARK: - Status

    @Test("A symbol that exists only on 27 needs 27 on 15")
    func onlyOnNewerOS() {
        #expect(catalog.renderName(for: "brandnew", on: v15) == nil)
        #expect(status("brandnew", on: v15) == .needsNewerMacOS(v27))
    }

    @Test("The version named is the earliest spelling's, not the current name's")
    func needsTheEarliestSpelling() {
        #expect(status("coin.building.classical", on: v14) == .needsNewerMacOS(v15))
        #expect(status("coin.bank.building", on: v14) == .needsNewerMacOS(v15))
    }

    @Test("A retired symbol is available but left out of the gallery")
    func retiredSymbol() {
        #expect(status("gone.symbol", on: v27) == .available(renderName: "gone.symbol"))
        #expect(!catalog.galleryNames(on: v27).contains("gone.symbol"))
    }

    @Test("A name the catalog does not know is put to the system")
    func unknownToCatalogAsksTheSystem() {
        #expect(status("star.ar", on: v27, systemResolves: true) == .available(renderName: "star.ar"))
        #expect(status("star.ar", on: v27, systemResolves: false) == .unknown)
    }

    @Test("A name the catalog knows is not put to the system")
    func knownNameSkipsTheSystem() {
        var asked: [String] = []
        let result = catalog.status(of: "star", on: v15, systemResolves: { asked.append($0); return false })
        #expect(result == .available(renderName: "star"))
        #expect(asked.isEmpty)
    }

    @Test("Names are case-sensitive")
    func caseSensitive() {
        #expect(catalog.renderName(for: "Star", on: v27) == nil)
        #expect(status("Star", on: v27) == .unknown)
    }

    @Test("The default system check resolves a real symbol and refuses nonsense")
    func defaultSystemCheck() {
        #expect(catalog.status(of: "circle", on: v27) == .available(renderName: "circle"))
        #expect(catalog.status(of: "zz.not.a.symbol", on: v27) == .unknown)
    }

    // MARK: - Gallery and lookup

    @Test("The gallery keeps its order and shows each symbol under the spelling that works")
    func galleryOnOlderOS() {
        #expect(catalog.galleryNames(on: v15) == ["star", "coin.bank.building", "trio.mid", "ancient"])
        #expect(catalog.galleryNames(on: v27) == ["star", "coin.building.classical", "trio.new", "brandnew", "ancient"])
    }

    @Test("Current name and aliases are found from any spelling")
    func lookup() {
        #expect(catalog.currentName(for: "trio.old") == "trio.new")
        #expect(catalog.currentName(for: "trio.new") == "trio.new")
        #expect(catalog.currentName(for: "missing") == nil)
        #expect(catalog.aliases(of: "trio.mid") == ["trio.old", "trio.mid"])
        #expect(catalog.aliases(of: "star").isEmpty)
    }

    // MARK: - Loading

    @Test("An unsupported format version is refused")
    func unsupportedFormat() {
        let data = Data(#"{"formatVersion": 2, "symbols": []}"#.utf8)
        #expect(throws: SymbolCatalog.LoadError.unsupportedFormat(2)) { try SymbolCatalog(data: data) }
    }

    @Test("A name listed twice is refused")
    func duplicateName() {
        let data = Data(#"""
        {"formatVersion": 1, "symbols": [
          {"name": "a", "macOS": "11.0", "aliases": [{"name": "b", "macOS": "11.0"}]},
          {"name": "b", "macOS": "12.0"}
        ]}
        """#.utf8)
        #expect(throws: SymbolCatalog.LoadError.duplicateName("b")) { try SymbolCatalog(data: data) }
    }

    @Test("A malformed version is refused", arguments: ["", "27.", "27.0.1", "x.0", "27.-1"])
    func malformedVersion(text: String) {
        let data = Data(#"{"formatVersion": 1, "symbols": [{"name": "a", "macOS": "\#(text)"}]}"#.utf8)
        #expect((try? SymbolCatalog(data: data)) == nil)
    }

    @Test("Versions compare numerically, not as text")
    func versionOrdering() {
        #expect(MacOSVersion("15.10")! > MacOSVersion("15.9")!)
        #expect(MacOSVersion("27")! == MacOSVersion(27, 0))
        #expect(MacOSVersion(26, 1).description == "26.1")
    }

    @Test("The bundled catalog loads")
    func bundledLoads() {
        #expect(!SymbolCatalog.bundled.symbols.isEmpty)
    }
}
