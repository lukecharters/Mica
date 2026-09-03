// MicaTests/Models/PresetsToolbarTests.swift
// The two toolbar buttons that open the preset popovers are told apart by a glyph and
// a title, and both come from `PresetScope`. A misspelled SF Symbol name draws
// nothing, with no error, so the glyphs are resolved here.

import AppKit
import Testing
@testable import Mica

@Suite("Presets toolbar", .tags(.unit))
struct PresetsToolbarTests {

    @Test("Every scope's glyph resolves", arguments: PresetScope.allCases)
    func everyGlyphResolves(scope: PresetScope) {
        #expect(
            NSImage(systemSymbolName: scope.toolbarSymbolName, accessibilityDescription: nil) != nil,
            Comment(rawValue: "\(scope.toolbarSymbolName) is not an SF Symbol")
        )
    }

    @Test("The two scopes do not share a glyph")
    func glyphsAreDistinct() {
        #expect(PresetScope.icon.toolbarSymbolName != PresetScope.badge.toolbarSymbolName)
    }

    @Test("Every scope has a title", arguments: PresetScope.allCases)
    func everyScopeIsTitled(scope: PresetScope) {
        #expect(!scope.libraryTitle.isEmpty)
    }

    @Test("The two titles differ")
    func titlesAreDistinct() {
        #expect(PresetScope.icon.libraryTitle != PresetScope.badge.libraryTitle)
    }
}
