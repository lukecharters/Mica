// PresetSlugPasteboardTests.swift
//
// Copy Slug writes the slug, as plain text, and nothing else. Every test uses a
// uniquely-named pasteboard, never `.general`, for the reasons in `IconPasteboardTests`.

import Testing
import AppKit
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct PresetSlugPasteboardTests {

    private static func scratchPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("mica.tests.\(UUID().uuidString)"))
    }

    @Test("Copy Slug puts the slug on the pasteboard as plain text")
    func copiesTheSlug() {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let preset = MicaPreset(name: "Restart, Required!", scope: .icon, keys: [:])

        #expect(PresetSlugPasteboard.copy(preset, to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "restart-required")
    }

    @Test("Copy Slug replaces what was there rather than adding to it")
    func replacesTheContents() {
        let pasteboard = Self.scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setData(Data([0x89]), forType: .png)

        PresetSlugPasteboard.copy(MicaPreset(name: "Taken", scope: .badge, keys: [:]), to: pasteboard)
        // Not `types == [.string]`: AppKit adds the legacy `NSStringPboardType` alias
        // beside the plain-text type, so the exact list is AppKit's to choose.
        #expect(pasteboard.types?.contains(.png) == false)
        #expect(pasteboard.string(forType: .string) == "taken")
    }
}
