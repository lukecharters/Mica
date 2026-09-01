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

    static let builtInIcon: [MicaPreset] = [
        
        MicaPreset(
            name: "Attention",
            scope: .icon,
            keys: [
                "icon-symbol-color": .string("white"),
                "icon-bg-color": .string("yellow"),
                "icon-fg": .string("symbol:exclamationmark.triangle.fill"),
            ],
            isBuiltIn: true
        ),
        
        MicaPreset(
            name: "Account",
            scope: .icon,
            keys: [
                "icon-bg-color": .string("blue"),
                "icon-symbol-color": .string("white"),
                "icon-fg": .string("symbol:person.fill"),
                "icon-fg-scale" : .number(1.1),
            ],
            isBuiltIn: true
        ),
        
        
        
        MicaPreset(
            name: "Fail",
            scope: .icon,
            keys: [
                "icon-symbol-color": .string("white"),
                "icon-bg-color": .string("red"),
                "icon-fg": .string("symbol:xmark"),
                "icon-symbol-weight": .string("bold"),
            ],
            isBuiltIn: true
        ),
        
        MicaPreset(
            name: "Settings",
            scope: .icon,
            keys: [
                "icon-bg-color": .string("grey"),
                "icon-symbol-color": .string("white"),
                "icon-fg": .string("symbol:gear"),
            ],
            isBuiltIn: true
        ),
        
        MicaPreset(
            name: "Software Update",
            scope: .icon,
            keys: [
                "icon-bg-color": .string("grey"),
                "icon-symbol-rendering": .string("multicolor"),
                "icon-symbol-color": .string("white"),
                "icon-fg": .string("symbol:gear.badge"),
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
        
    ]

    // MARK: - Badge presets

    /// Five badge presets. One carries the advanced-controls indicator (Attention's
    /// custom gradient).
    ///
    /// Each carries `badge-fg`, which is what switches the badge on — see
    /// `PresetApplication`. The corner is part of every one of them, because the
    /// ghost-corner thumbnail only means something if the preset sets it.
    static let builtInBadge: [MicaPreset] = [
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
            name: "Delete",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:trash.fill"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("medium"),
                "badge-bg-color": .string("red"),
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
            name: "Fail",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:xmark"),
                "badge-bg-color": .string("red"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("bold"),
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
            name: "Notification dot",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:circlebadge.fill"),
                "badge-fg-scale": .number(0.3),
                "badge-symbol-color": .string("white"),
                "badge-bg-color": .string("red"),
                "badge-fg-shadow": .bool(false),
                "badge-bg-gradient": .bool(false),
                "badge-position": .string("top-right"),
            ],
            isBuiltIn: true
        ),
        
        MicaPreset(
            name: "Notification 1",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:1.circle.fill"),
                "badge-fg-scale": .number(1.50),
                "badge-symbol-color": .string("red"),
                "badge-symbol-rendering" : .string("multicolor"),
                "badge-bg-visibility": .bool(false),
                "badge-position": .string("top-right"),
            ],
            isBuiltIn: true
        ),
        
        MicaPreset(
            name: "Privacy",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:hand.raised.fill"),
                "badge-symbol-color": .string("white"),
                "badge-bg-color": .string("blue"),
            ],
            isBuiltIn: true
        ),
        
        MicaPreset(
            name: "Recording",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:record.circle"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("light"),
                "badge-bg-color": .string("red"),
                "badge-fg-shadow": .bool(false),
                "badge-bg-gradient": .bool(false),
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
            name: "Reconfigure",
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
            name: "Repair",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:screwdriver.fill"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("medium"),
                "badge-bg-color": .string("grey"),
                "badge-fg-offset-x": .number(0.03),
                "badge-fg-scale": .number(0.85),
            ],
            isBuiltIn: true
        ),
        
        MicaPreset(
            name: "Reset",
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
            name: "Settings",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:gearshape.fill"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("medium"),
                "badge-bg-color": .string("grey"),
            ],
            isBuiltIn: true
        ),
        
        MicaPreset(
            name: "Success",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:checkmark"),
                "badge-bg-color": .string("green"),
                "badge-symbol-color": .string("white"),
                "badge-symbol-weight": .string("bold"),
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
            name: "Update",
            scope: .badge,
            keys: [
                "badge-fg": .string("symbol:arrowshape.up.fill"),
                "badge-bg-color": .string("green"),
                "badge-symbol-color": .string("white"),
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
