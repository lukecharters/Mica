// App/PresetSlugPasteboard.swift
//
// Copy Slug, from a preset tile's context menu: the slug as plain text, ready to
// paste after `--icon-preset` or `--badge-preset`. A function rather than a closure in
// the tile, so a test can point it at a scratch pasteboard instead of the user's.

import AppKit

enum PresetSlugPasteboard {
    /// Replace the pasteboard's contents with the preset's slug.
    @discardableResult
    static func copy(_ preset: MicaPreset, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(preset.slug, forType: .string)
    }
}
