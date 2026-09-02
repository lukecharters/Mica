// App/PresetScope+Toolbar.swift
//
// How each scope is named and drawn where the library is reached from: the two
// toolbar buttons, their popovers' title rows, and the Presets window's selector.

import Foundation

extension PresetScope {
    /// The library's name for this scope — the popover's title, the toolbar button's
    /// label and tooltip, and the window's segment.
    ///
    /// Through `String(localized:)` rather than a bare literal so that it is one string
    /// wherever it is shown; `PresetsToolbarTests` checks the two are distinct.
    var libraryTitle: String {
        switch self {
        case .icon:  String(localized: "Icon Presets")
        case .badge: String(localized: "Badge Presets")
        }
    }

    /// The scope's name in the Presets window's selector, where the window's own title
    /// already says "Presets".
    var segmentTitle: String {
        switch self {
        case .icon:  String(localized: "Icon")
        case .badge: String(localized: "Badge")
        }
    }

    /// The toolbar button's glyph.
    ///
    /// **A misspelled name draws nothing at all, with no error**, so
    /// `PresetsToolbarTests` resolves both through `NSImage`.
    var toolbarSymbolName: String {
        switch self {
        case .icon:  "square.on.circle"
        case .badge: "app.badge"
        }
    }
}
