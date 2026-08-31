// Services/PresetCatalog.swift
//
// The built-in presets: ten, five per scope.
//
// **This is a coverage set, not a catalogue.** The selection rule is "what exercises
// a code path", not "what a Mac admin needs" — the real catalogue is curated later,
// and the names here are placeholders that lean purpose-flavoured because that is
// the axis currently favoured for it. What ships first is the smallest number of
// presets that reaches every major option, so the plumbing is proven and the pane
// has something in it.
//
// Between them the icon presets cover: flat and gradient backgrounds, both gradient
// kinds, monochrome and hierarchical rendering, white and coloured symbols, all
// three corner styles, shadow on and off, and a non-auto weight. The badge presets
// cover three of the four corners, a non-default scale, non-zero offsets, and both
// background kinds. `PresetCatalogTests` pins the coverage rather than the taste,
// so re-curating the names later breaks nothing.
//
// ## Swift literals, not bundled JSON
//
// Deliberate, and it is the one structural decision in this file. `mica-cli` reaches
// its bundled resources through `Bundle.main`, and `symbol-calibration.json` is
// already the last thing standing between it and running as a standalone binary. A
// bundled `presets.json` would be a second — and its failure mode is the same silent
// one: the lookup fails without a word and the CLI's `--icon-preset` stops matching
// the GUI's. As literals the built-ins compile into both targets and cannot diverge.
// User presets are a different question and are files, because they have to be.
//
// ## No System-mode presets
//
// A Security (icon) and a System Badge preset were drafted and cut. They were the
// only entries whose thumbnails could not use the cheap `IconContentView` path — an
// appex icon needs an async raster per thumbnail via `AppexReferenceService` — so
// **every thumbnail in the pane is now a synchronous SwiftUI view and the pane needs
// no loading state and no thumbnail cache.** Don't build either speculatively; both
// become necessary the moment a System-mode preset is added, and that is the right
// time to add them.
//
// `icon-generation-mode` and `badge-generation-mode` are still in scope under
// scope-complete, so every preset here carries `mica` for its group and applying one
// to a System-mode group still switches it back. The gap is the other direction —
// nothing here switches a group *into* System mode — which `PresetApplicationTests`
// covers on the apply path rather than by reinstating a preset.
//
// Shared with `mica-cli`, so this is one of the paths named in both
// `membershipExceptions` lists.

import Foundation

enum PresetCatalog {

    // MARK: - Icon presets

    /// Five icon presets. Two carry the advanced-controls indicator (Media's custom
    /// gradient, Developer's hierarchical rendering); three do not.
    static let builtInIcon: [MicaPreset] = [
        // The baseline path: flat colour, white glyph.
        //
        // `icon-bg-gradient: false` is explicit and has to be.
        // `IconBackgroundSpec().usesGradient` is `true`, so under scope-complete an
        // omitted key means the default — which is *on*. A preset that means flat
        // must say so.
        MicaPreset(
            name: "Installer",
            scope: .icon,
            keys: [
                "icon-bg": .string("standard"),
                "icon-bg-color": .string("blue"),
                "icon-bg-gradient": .bool(false),
                "icon-fg": .string("symbol:arrow.down.app"),
                "icon-symbol-color": .string("white"),
            ],
            isBuiltIn: true
        ),

        // A symbol colour that is not white, over a light background — the pair the
        // simple pane's two colour rows exist for.
        MicaPreset(
            name: "Software Update 1",
            scope: .icon,
            keys: [
                "icon-bg-color": .string("grey"),
                "icon-symbol-color": .string("white"),
                "icon-fg": .string("symbol:gear.badge"),
            ],
            isBuiltIn: true
        ),
        MicaPreset(
            name: "Software Update 2",
            scope: .icon,
            keys: [
                "icon-bg-color": .string("grey"),
                "icon-symbol-rendering": .string("multicolor"),
                "icon-symbol-color": .string("white"),
                "icon-fg": .string("symbol:gear.badge"),
            ],
            isBuiltIn: true
        ),

        // A custom two-colour gradient — the list-encoded form, and the *other*
        // gradient kind from `icon-bg-gradient`. Carries the indicator:
        // `resetToSimpleControls()` clears `usesCustomGradient`.
        MicaPreset(
            name: "Media",
            scope: .icon,
            keys: [
                "icon-bg": .string("custom-gradient"),
                "icon-bg-gradient-colors": .strings(["orange", "pink"]),
                "icon-symbol-color": .string("white"),
                "icon-fg": .string("symbol:play.fill"),
            ],
            isBuiltIn: true
        ),

        MicaPreset(
            name: "Developer",
            scope: .icon,
            keys: [
                "icon-symbol-color": .string("white"),
                "icon-bg-color": .string("blue"),
                "icon-fg": .string("symbol:chevron.left.forwardslash.chevron.right"),
            ],
            isBuiltIn: true
        ),
        
        MicaPreset(
            name: "Success",
            scope: .icon,
            keys: [
                "icon-symbol-color": .string("white"),
                "icon-bg-color": .string("green"),
                "icon-fg": .string("symbol:checkmark"),
                "icon-symbol-weight": .string("bold"),
            ],
            isBuiltIn: true
        ),
        
        MicaPreset(
            name: "Check Engine",
            scope: .icon,
            keys: [
                "icon-symbol-color": .string("orange"),
                "icon-bg-color": .string("black"),
                "icon-fg": .string("symbol:engine.combustion"),
//                "icon-symbol-weight": .string("bold"),
            ],
            isBuiltIn: true
        ),

        // The three "hidden but applied" axes at once — corner radius off, shadow
        // off, a non-auto weight. **No indicator**, and that is the point of this
        // entry: `resetToSimpleControls()` folds none of these, so they survive the
        // simple pane untouched and unrepresented.
        MicaPreset(
            name: "Documentation",
            scope: .icon,
            keys: [
                "icon-bg-corner-radius": .string("off"),
                "icon-bg-shadow": .string("off"),
                "icon-symbol-weight": .string("bold"),
                "icon-bg-color": .string("gray"),
                "icon-fg": .string("symbol:doc.text.fill"),
            ],
            isBuiltIn: true
        ),
    ]

    // MARK: - Badge presets

    /// Five badge presets. One carries the advanced-controls indicator (Attention's
    /// custom gradient).
    ///
    /// Each carries `badge-fg`, which is what switches the badge on — see
    /// `PresetApplication`. The corner is part of every one of them, because the
    /// ghost-corner thumbnail only means something if the preset sets it.
    static let builtInBadge: [MicaPreset] = [
        // The baseline: default corner, default scale.
        MicaPreset(
            name: "Update",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:arrowshape.up.fill"),
                "badge-bg-color": .string("green"),
                "badge-symbol-color": .string("white"),
                "badge-position": .string("bottom-right"),
            ],
            isBuiltIn: true
        ),
        MicaPreset(
            name: "New",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:plus"),
                "badge-symbol-weight": .string("bold"),
                "badge-symbol-color": .string("white"),
                "badge-bg-color": .string("green"),
                "badge-position": .string("top-right"),
            ],
            isBuiltIn: true
        ),
        MicaPreset(
            name: "Locked",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:lock.fill"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("medium"),
                "badge-bg-color": .string("gray"),
                "badge-position": .string("bottom-left"),
            ],
            isBuiltIn: true
        ),
        MicaPreset(
            name: "Attention",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:exclamationmark.triangle.fill"),
//                "badge-fg-offset-x" : .number(0.05),
//                "badge-fg-offset-y" : .number(0.05),
                "badge-fg-scale" : .number(1.45),
                "badge-symbol-color" : .string("white"),
                "badge-symbol-rendering" : .string("multicolor"),
                "badge-symbol-weight" : .string("regular"),
                "badge-bg-visibility": .bool(false),
                
            ],
            isBuiltIn: true
        ),

        MicaPreset(
            name: "Download",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:arrow.down"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("bold"),
                "badge-bg-color": .string("blue"),
            ],
            isBuiltIn: true
        ),
        MicaPreset(
            name: "Refresh",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:arrow.trianglehead.2.clockwise.rotate.90"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("bold"),
                "badge-bg-color": .string("grey"),
            ],
            isBuiltIn: true
        ),
        MicaPreset(
            name: "Reset 1",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:gearshape.arrow.trianglehead.2.clockwise.rotate.90"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("medium"),
                "badge-bg-color": .string("grey"),
            ],
            isBuiltIn: true
        ),
        MicaPreset(
            name: "Reset 2",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:arrow.uturn.backward"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("bold"),
                "badge-bg-color": .string("yellow"),
            ],
            isBuiltIn: true
        ),
        MicaPreset(
            name: "Uninstall",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:xmark"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("bold"),
                "badge-bg-color": .string("black"),
                "badge-position": .string("top-left"),
            ],
            isBuiltIn: true
        ),
        MicaPreset(
            name: "Delete",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:trash"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("bold"),
                "badge-bg-color": .string("red"),
            ],
            isBuiltIn: true
        ),
    ]

    /// Every built-in, icon presets first.
    static var builtIn: [MicaPreset] { builtInIcon + builtInBadge }

    /// The built-ins for one scope.
    static func builtIn(_ scope: PresetScope) -> [MicaPreset] {
        switch scope {
        case .icon:  return builtInIcon
        case .badge: return builtInBadge
        }
    }
}
