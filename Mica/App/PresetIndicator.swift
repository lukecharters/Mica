// App/PresetIndicator.swift
//
// The small glyphs a preset tile carries beneath its name, and the rule that decides
// which of them apply.
//
// **A value rather than three computed properties inside the tile**, for the same
// reason `SidebarPresentation` and `LayerSidebarRow.selected` are values: the glyph
// row, the tile's tooltip and its accessibility label all describe the same preset,
// and a rule spread across a view's `body` is reachable by no test. Nothing in
// `PresetList` is covered — that is a standing gap — so the part that can be a pure
// function is one, and `PresetIndicatorTests` enumerates it.
//
// **Nothing here may be drawn on top of a thumbnail.** A marker over one has to separate
// itself from a rendered icon, and a rendered icon is a coloured chiclet in any colour
// the app can produce: a tint merges into the blue icons, and a material resolves to
// something close to the white and grey ones. The artwork owns the whole palette, so no
// fill wins — the constraint is the placement, not the fill. Outside the thumbnail the
// sidebar material is the ground and `.secondary` reads as chrome, so the glyphs need no
// fill at all. `presets.md` carries the measurements.
//
// **App-target only**, since the tile that draws these is app-only.

import SwiftUI

/// One glyph in a preset tile's metadata row.
struct PresetIndicator: Identifiable, Equatable {
    /// The SF Symbol drawn in the row.
    let symbolName: String

    /// The glyph's own tooltip, phrased as a standalone sentence because it is read on
    /// its own when the pointer stops over the glyph.
    let help: LocalizedStringKey

    /// The same fact phrased as a clause, for the tile's tooltip and its accessibility
    /// label, where it joins a comma-separated list after the preset's name.
    ///
    /// Two spellings of one fact. They are side by side here so they cannot drift into
    /// saying different things, which is what happens when a tooltip is written at the
    /// glyph and a VoiceOver label is assembled somewhere else.
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
            help: "A preset you saved",
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
            help: "Turns on Show Advanced Controls",
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
