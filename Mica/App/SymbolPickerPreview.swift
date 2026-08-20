// App/SymbolPickerPreview.swift
import SwiftUI

/// How the symbol browser's grid draws a symbol.
///
/// **Preview only.** The picker chooses a *name* and nothing else — it writes one
/// `String` back through its binding — so the rendering mode picked here reaches
/// no `IconSettings` and no export. It exists because a symbol's hierarchical and
/// multicolour renderings are the whole reason to prefer one symbol over another,
/// and until now the browser drew all 6000 of them flat.
///
/// The colours are therefore **fixed rather than editable**: a colour well here
/// would look like it was setting the icon's colour, which is the one thing this
/// sheet must not do. `Color.primary` matches the browser's own labels, so a
/// symbol reads as list content rather than as a preview of the icon.
enum SymbolPickerPreview {
    /// Where the browser's rendering mode is stored. Its own key rather than one of
    /// `InspectorPreferences`': the browser is a sheet the inspector happens to open,
    /// and this preference is about reading a list of 6000 symbols, not about the
    /// inspector's shape.
    static let renderingStyleKey = "symbolPicker.renderingStyle"

    /// The base level of every mode. Hierarchical derives its lower levels from
    /// it, and multicolour falls back to it for a symbol with no colours of its
    /// own.
    static let symbolColor: Color = .primary

    /// Palette mode's three levels. Deliberately led by the same `primary`, so
    /// switching into palette re-tints the *secondary* and *tertiary* levels and
    /// leaves the symbol recognisable — a fully coloured triple would read as a
    /// different symbol rather than as the same one shown a second way.
    static let paletteColors: [Color] = [.primary, .blue, .red]

    /// The foreground styles a cell applies, in `foregroundStyle` order: three for
    /// palette, one for everything else.
    static func colors(for style: SymbolRenderingStyle) -> [Color] {
        style == .palette ? paletteColors : [symbolColor]
    }
}
