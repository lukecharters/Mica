// App/OptionsCatalog.swift
// Centralized catalog for preset options; tuple element types preserved
import SwiftUI

struct OptionsCatalog {
    /// The preset colour swatches offered in the inspector — a **derived view of
    /// `ColorTokenTable`**, not a list of its own. It was a hand-written array of
    /// 15 Title-Case names until 2026-08-02; the display names are now derived
    /// from the tokens so the GUI list and the parser's vocabulary cannot drift.
    ///
    /// Alphabetical by display name, which is the order this has always shown.
    static let colorOptions: [(name: String, color: Color)] =
        ColorTokenTable.presentable.map { (name: $0.displayName, color: $0.color) }

    /// Look up a preset by its display name. Deliberately scoped to the presets
    /// rather than the whole token table — this backs the pre-rendered background
    /// picker, where a name that has no `background-<name>-solid` asset would
    /// render nothing.
    static func color(named name: String) -> Color {
        colorOptions.first { $0.name == name }?.color ?? .blue
    }
}
