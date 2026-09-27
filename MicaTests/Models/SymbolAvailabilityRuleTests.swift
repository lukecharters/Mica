// SymbolAvailabilityRuleTests.swift
// Which layers the app reports as not drawing, and where it says so.
//
// The name field, the canvas marker, the export panel and the load warnings all read
// `SymbolAvailability`, so these rules are the whole of what decides them. A
// System-mode layer is only ever reported from its own render's result, for the name
// that was rendered — never from NSImage, and never while a render is pending.

import Testing
import Foundation
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct SymbolAvailabilityRuleTests {

    private static let bogus = "zz.not.a.symbol"

    private static let catalog = try! SymbolCatalog(data: Data(#"""
    {"formatVersion": 1, "symbols": [{"name": "fixture.only27", "macOS": "27.0"}]}
    """#.utf8))

    private func settings(icon: String = "circle", badge: String? = nil) -> IconSettings {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = icon
        if let badge {
            settings.badge.isVisible = true
            settings.badge.foreground.symbolName = badge
        } else {
            settings.badge.isVisible = false
        }
        return settings
    }

    // MARK: - Marked layers

    @Test("A Mica-mode symbol nothing knows is marked; a real one is not")
    func micaModeForeground() {
        #expect(SymbolAvailability.markedLayers(settings(icon: Self.bogus), renders: .init()) == [.iconForeground])
        #expect(SymbolAvailability.markedLayers(settings(), renders: .init()).isEmpty)
    }

    @Test("A System-mode name is not marked until its own render says so")
    func systemModeWaitsForTheRender() {
        var s = settings(icon: Self.bogus)
        s.icon.mode = .system
        #expect(SymbolAvailability.markedLayers(s, renders: .init()).isEmpty)
        #expect(SymbolAvailability.markedLayers(s, renders: .init(icon: Self.bogus)) == [.icon])
    }

    @Test("A render of a previous name says nothing about the current one")
    func staleRenderIsIgnored() {
        var s = settings(icon: "circle.fill")
        s.icon.mode = .system
        #expect(SymbolAvailability.markedLayers(s, renders: .init(icon: "circle")).isEmpty)
    }

    @Test("The badge is marked as a foreground in Mica mode and as a whole in System mode")
    func badgeMarking() {
        #expect(SymbolAvailability.markedLayers(settings(badge: Self.bogus), renders: .init()) == [.badgeForeground])

        var system = settings(badge: Self.bogus)
        system.badge.foreground.source = .system
        #expect(SymbolAvailability.markedLayers(system, renders: .init()).isEmpty)
        #expect(SymbolAvailability.markedLayers(system, renders: .init(badge: Self.bogus)) == [.badge])
    }

    @Test("A hidden badge and an image foreground are never marked")
    func notMarked() {
        var hidden = settings()
        hidden.badge.isVisible = false
        hidden.badge.foreground.symbolName = Self.bogus
        #expect(SymbolAvailability.markedLayers(hidden, renders: .init()).isEmpty)

        var image = settings(icon: "stem-of-an-image-file")
        image.icon.foreground.source = .image
        #expect(SymbolAvailability.iconStatus(image, renders: .init()) == nil)
    }

    // MARK: - Messages

    @Test("The problem names the symbol, and the version when it is too new")
    func problemText() throws {
        let unknown = try #require(SymbolAvailability.problem(with: "abc", status: .unknown))
        #expect(unknown.contains("abc"))
        let tooNew = try #require(SymbolAvailability.problem(with: "abc", status: .needsNewerMacOS(MacOSVersion(27))))
        #expect(tooNew.contains("macOS 27.0"))
        #expect(SymbolAvailability.problem(with: "abc", status: .available(renderName: "abc")) == nil)
        #expect(SymbolAvailability.problem(with: "abc", status: nil) == nil)
    }

    @Test("The export panel gets one line per layer that will not draw")
    func exportWarnings() {
        #expect(SymbolAvailability.exportWarnings(settings(icon: Self.bogus, badge: Self.bogus), renders: .init()).count == 2)
        #expect(SymbolAvailability.exportWarnings(settings(badge: "circle"), renders: .init()).isEmpty)
    }

    // MARK: - Load warnings

    private func loadWarnings(_ imported: IconSettings, over current: IconSettings) -> [MicaConfigWarning] {
        SymbolAvailability.loadWarnings(
            importing: imported, over: current,
            catalog: Self.catalog, os: MacOSVersion(15), systemResolves: { $0 == "circle" }
        )
    }

    @Test("A configuration that brings in an unknown or too-new symbol warns under its key")
    func loadWarnsOnNewNames() {
        #expect(loadWarnings(settings(icon: Self.bogus), over: settings()).map(\.key) == ["icon-fg"])
        #expect(loadWarnings(settings(badge: "fixture.only27"), over: settings()).map(\.key) == ["badge-fg"])
        #expect(loadWarnings(settings(badge: "fixture.only27"), over: settings()).first?.message.contains("macOS 27.0") == true)
    }

    @Test("A name that was already there, or a System-mode layer, does not warn on load")
    func loadIsQuietOtherwise() {
        let bad = settings(icon: Self.bogus)
        #expect(loadWarnings(bad, over: bad).isEmpty)

        var system = settings(icon: Self.bogus)
        system.icon.mode = .system
        #expect(loadWarnings(system, over: settings()).isEmpty)

        #expect(loadWarnings(settings(), over: settings(icon: Self.bogus)).isEmpty)
    }
}
