// App/PresetIndicator.swift
//
// The two marks a preset tile can carry, and the rule that decides which of them apply.
//
// **A value rather than three computed properties inside the tile**, for the same
// reason `LayerSidebarRow.selected` is a value: the name
// line's glyphs, the tile's tooltip and its accessibility label all describe the same preset,
// and a rule spread across a view's `body` is reachable by no test. Nothing in
// `PresetList` is covered — that is a standing gap — so the part that can be a pure
// function is one, and `PresetIndicatorTests` enumerates it.
//
// **App-target only**, since the tile that draws these is app-only.

import SwiftUI

/// One mark on a preset tile.
struct PresetIndicator: Identifiable, Equatable {
    /// The SF Symbol the tile draws for it.
    let symbolName: String

    /// The fact the glyph stands for, phrased as a clause for the tile's tooltip and its
    /// accessibility label, where it joins a comma-separated list after the preset's
    /// name. The glyph is inline in the name and carries no tooltip of its own.
    let clause: String

    var id: String { symbolName }

    /// A preset the user saved, as opposed to one Mica ships.
    ///
    /// **Identity, not a warning**, so unlike `advancedControls` it is drawn whatever
    /// the preferences say. Built-ins and user presets share one grid inside each
    /// scope, so without this the only thing distinguishing them is that a built-in has
    /// no Delete in its context menu — which the user cannot see without right-clicking.
    static var userPreset: PresetIndicator {
        PresetIndicator(
            symbolName: "person.fill",
            clause: String(localized: "your preset")
        )
    }

    /// Applying this preset turns Show Advanced Controls on.
    ///
    /// **Derived, never authored**: see `MicaPreset.needsAdvancedControls`. It is finer
    /// than "anything fancy" — only a custom two-colour gradient or a non-monochrome
    /// rendering mode qualifies. Corner styles, shadows, symbol weights and the
    /// *derived* gradient are all hidden-but-applied and carry no indicator.
    static var advancedControls: PresetIndicator {
        PresetIndicator(
            symbolName: "slider.horizontal.3",
            clause: String(localized: "turns on advanced controls")
        )
    }

    /// Every indicator that exists.
    ///
    /// Here so the guards on the glyphs and the wording iterate rather than name their
    /// subjects: a third indicator added without a line in `PresetIndicatorTests` would
    /// otherwise ship with an unchecked SF Symbol name, and a misspelled one draws
    /// nothing at all with no error.
    static var all: [PresetIndicator] { [.userPreset, .advancedControls] }

    /// Which indicators a tile draws, in reading order.
    ///
    /// A pure function of three facts rather than a method on `ResolvedPreset`, so the
    /// eight combinations can be enumerated directly and the preference does not have
    /// to be faked to reach them.
    ///
    /// **Identity leads.** Whether a preset is the user's cannot change while the app
    /// is running, while the advanced-controls glyph appears and disappears with the
    /// preference — so putting identity first keeps a tile's leading glyph still when
    /// the preference is toggled.
    ///
    /// - Parameter advancedControlsEnabled: the advanced-controls glyph warns about a
    ///   preference this preset is about to change, so it is **absent once that
    ///   preference is already on**. There is nothing left to warn about, and left in
    ///   it would mark every flagged tile for the rest of the session.
    static func indicators(
        isUserPreset: Bool,
        needsAdvancedControls: Bool,
        advancedControlsEnabled: Bool
    ) -> [PresetIndicator] {
        var found: [PresetIndicator] = []
        if isUserPreset {
            found.append(.userPreset)
        }
        if needsAdvancedControls, !advancedControlsEnabled {
            found.append(.advancedControls)
        }
        return found
    }
}
