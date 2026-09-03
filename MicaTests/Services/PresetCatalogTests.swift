// PresetCatalogTests.swift
// Tests for the built-in set, and for the derived advanced-controls indicator.
//
// **Nothing here pins a count or a colour.** The catalogue answers to taste and is
// re-curated freely, so an assertion that there are five icon presets, or that Media is
// orange-to-pink, breaks on a curation pass and teaches nobody anything — it reports a
// decision as a defect. What these assert is what must hold of *any* catalogue: every
// entry is well-formed, decodes cleanly, keeps to its scope, and carries the right
// indicator. The option space the decoder must support moved to `PresetCoverageTests`,
// where synthetic presets exercise it without constraining what ships.
//
// The indicator tests are the finer half. `resetToSimpleControls()` folds **only**
// custom gradients, imported sources and non-monochrome rendering — so the derived
// gradient, corner styles, symbol weights and shadows are all hidden-but-applied and
// must carry *no* indicator. A test that only checked "the fancy ones are flagged"
// would pass while over-flagging everything.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct PresetCatalogTests {

    // MARK: - Well-formedness

    @Test("Every built-in is marked built-in and keeps to its own scope")
    func builtInsAreWellFormed() {
        for preset in PresetCatalog.builtIn {
            #expect(preset.isBuiltIn, "\(preset.name) is not marked built-in")
            #expect(preset.unscopedKeys.isEmpty,
                    "\(preset.name) carries \(preset.unscopedKeys.joined(separator: ", "))")
            #expect(!preset.keys.isEmpty, "\(preset.name) has no keys")
        }
    }

    @Test("Every built-in decodes with no warnings")
    func builtInsDecodeCleanly() throws {
        // A warning from a built-in is a typo in this repository — a colour name that
        // is not a token, a value out of range — and it would reach the user as an
        // alert the moment they clicked the preset.
        for preset in PresetCatalog.builtIn {
            let decoded = try PresetApplication.decode(preset)
            #expect(decoded.warnings.isEmpty,
                    "\(preset.name): \(decoded.warnings.map(\.message).joined(separator: "; "))")
        }
    }

    @Test("Names are unique within a scope")
    func namesAreUniqueWithinScope() {
        for scope in PresetScope.allCases {
            let names = PresetCatalog.builtIn(scope).map { $0.name.lowercased() }
            #expect(Set(names).count == names.count, "\(scope) has a duplicate name")
        }
    }

    @Test("Neither scope's catalogue is empty")
    func catalogueIsPopulated() {
        // Deliberately a floor and not a count. The number of presets is a curation
        // decision, and pinning it reports that decision as a failure. What is worth
        // catching is an *empty* scope: every other test in this file iterates the
        // catalogue, so an empty one passes all of them vacuously, and the pane would
        // ship a blank section with nothing failing.
        #expect(!PresetCatalog.builtInIcon.isEmpty)
        #expect(!PresetCatalog.builtInBadge.isEmpty)
        #expect(PresetCatalog.builtIn.count == PresetCatalog.builtInIcon.count + PresetCatalog.builtInBadge.count)
    }

    @Test("No built-in is a System-mode preset")
    func noSystemModePresets() throws {
        // Deliberate, and it is what lets every thumbnail be a synchronous SwiftUI
        // view: an appex icon needs an async raster per thumbnail via
        // `AppexReferenceService`. Adding one means adding a loading state and a
        // thumbnail cache to the pane — which is fine, but should be a decision rather
        // than a surprise, and this test is where it gets made.
        for preset in PresetCatalog.builtIn {
            let settings = PresetApplication.previewSettings(for: preset)
            switch preset.scope {
            case .icon:  #expect(settings.icon.mode == .mica, "\(preset.name) is a System-mode icon preset")
            case .badge: #expect(settings.badge.mode == .mica, "\(preset.name) is a System-mode badge preset")
            }
        }
    }

    // MARK: - The advanced-controls indicator

    @Test("Exactly the presets that need advanced controls are flagged")
    func indicatorMatchesTheFold() {
        // The predicate restated independently: a preset needs the advanced controls
        // exactly when it lands on a custom gradient or a non-monochrome rendering
        // mode — the only two things `resetToSimpleControls()` folds that a preset can
        // reach. (Imported sources are the third, and a preset cannot carry one.)
        //
        // Written as an independent expectation rather than by calling the same
        // predicate twice, or the test would assert nothing.
        for preset in PresetCatalog.builtIn {
            let settings = PresetApplication.previewSettings(for: preset)
            let expected: Bool
            switch preset.scope {
            case .icon:
                expected = settings.icon.background.usesCustomGradient
                    || settings.icon.foreground.renderingStyle != .monochrome
            case .badge:
                expected = settings.badge.background.usesCustomGradient
                    || settings.badge.foreground.renderingStyle != .monochrome
            }
            #expect(preset.needsAdvancedControls == expected,
                    "\(preset.name): indicator says \(preset.needsAdvancedControls), the fold says \(expected)")
        }
    }

    @Test("The indicator discriminates — some presets carry it, some do not")
    func indicatorDiscriminates() {
        // `indicatorMatchesTheFold` already proves each preset's flag is *correct*, so
        // an exact count adds nothing about correctness — whatever the number is, it is
        // right by construction. What a count weakly stood in for is this: an indicator
        // that flagged everything, or nothing, would still satisfy the fold and would
        // still be useless in the pane. That property survives any curation.
        for scope in PresetScope.allCases {
            let presets = PresetCatalog.builtIn(scope)
            #expect(presets.contains { $0.needsAdvancedControls },
                    "no \(scope) preset carries the indicator")
            #expect(presets.contains { !$0.needsAdvancedControls },
                    "every \(scope) preset carries the indicator")
        }
    }

    @Test("Corner styles, shadows, weights and the derived gradient carry no indicator")
    func indicatorIsNotOverBroad() {
        // The half that would otherwise rot. `resetToSimpleControls()` leaves all four
        // of these alone, so they are hidden-but-applied and must not be flagged —
        // and a naive "is this preset unusual" predicate would flag every one.
        let preset = MicaPreset(
            name: "Hidden But Applied",
            scope: .icon,
            keys: [
                "icon-fg": .string("symbol:doc.text.fill"),
                "icon-bg-corner-radius": .string("off"),
                "icon-bg-shadow": .string("off"),
                "icon-symbol-weight": .string("bold"),
                "icon-bg-gradient": .bool(true),
                "icon-fg-scale": .number(1.4),
            ]
        )
        #expect(!preset.needsAdvancedControls)
    }

    @Test("A custom gradient and a non-monochrome mode each flag on their own")
    func indicatorTriggers() {
        let gradient = MicaPreset(
            name: "Gradient",
            scope: .icon,
            keys: [
                "icon-fg": .string("symbol:star"),
                "icon-bg": .string("custom-gradient"),
                "icon-bg-gradient-colors": .strings(["red", "blue"]),
            ]
        )
        #expect(gradient.needsAdvancedControls)

        let hierarchical = MicaPreset(
            name: "Hierarchical",
            scope: .icon,
            keys: [
                "icon-fg": .string("symbol:star"),
                "icon-symbol-rendering": .string("hierarchical"),
            ]
        )
        #expect(hierarchical.needsAdvancedControls)
    }

    @Test("The indicator is a property of the preset, not of the current icon")
    func indicatorIgnoresCurrentSettings() {
        // A badge preset must not be flagged because the *icon* already has a custom
        // gradient — the badge preset neither caused that nor changes it. Measuring
        // against the current settings instead of against defaults is the mistake this
        // catches, and on screen it would look like every preset needing the advanced
        // controls once the user picked a gradient.
        var dirty = IconSettings()
        dirty.icon.background.usesCustomGradient = true
        dirty.icon.foreground.renderingStyle = .hierarchical

        let plainBadge = MicaPreset(
            name: "Plain Badge",
            scope: .badge,
            keys: ["badge-fg": .string("symbol:plus"), "badge-bg-color": .string("blue")]
        )
        #expect(!plainBadge.needsAdvancedControls)
        // And the apply-path question, which *does* read the current settings, answers
        // differently on the same preset — which is the distinction the two predicates
        // exist to keep.
        #expect(dirty.wouldRevealAdvancedControls(applying: plainBadge))
    }

    @Test("A preset needing advanced controls would also reveal them when applied")
    func indicatorAgreesWithTheReveal() throws {
        // The pane's promise and the apply's behaviour, checked against each other
        // over clean settings — where the only thing that can cause a reveal is the
        // preset itself.
        for preset in PresetCatalog.builtIn where preset.needsAdvancedControls {
            #expect(IconSettings().wouldRevealAdvancedControls(applying: preset),
                    "\(preset.name) shows the indicator but would not reveal the controls")
        }
    }
}
