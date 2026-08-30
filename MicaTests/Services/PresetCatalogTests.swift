// PresetCatalogTests.swift
// Tests for the built-in set, and for the derived advanced-controls indicator.
//
// **What is pinned is the coverage, not the taste.** The names, colours and symbols
// in `PresetCatalog` are placeholders — the real catalogue is curated later — so a
// test asserting that Media is orange-to-pink would break on the first curation pass
// and teach nobody anything. What these assert instead is that the set still reaches
// every major option, which is the reason it exists: flat and gradient backgrounds,
// both gradient kinds, monochrome and hierarchical rendering, three corners, a
// non-default scale, non-zero offsets.
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

    @Test("Five presets per scope, ten in all")
    func catalogueSize() {
        #expect(PresetCatalog.builtInIcon.count == 5)
        #expect(PresetCatalog.builtInBadge.count == 5)
        #expect(PresetCatalog.builtIn.count == 10)
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

    // MARK: - Coverage

    @Test("The icon set reaches both gradient kinds and a genuinely flat background")
    func iconCoverage_backgrounds() {
        let settings = PresetCatalog.builtInIcon.map(PresetApplication.previewSettings(for:))

        // A custom two-colour gradient — the list-encoded form.
        #expect(settings.contains { $0.icon.background.usesCustomGradient })
        // The derived gradient, which is a different thing and is the default.
        #expect(settings.contains { $0.icon.background.usesGradient && !$0.icon.background.usesCustomGradient })
        // **Flat**, which needs `icon-bg-gradient: false` spelled out:
        // `IconBackgroundSpec().usesGradient` is `true`, so under scope-completeness an
        // omitted key means the default, which is *on*. This is the assertion that
        // catches someone "tidying away" that explicit false.
        #expect(settings.contains { !$0.icon.background.usesGradient })
    }

    @Test("The icon set reaches monochrome and a non-monochrome rendering mode")
    func iconCoverage_rendering() {
        let styles = Set(PresetCatalog.builtInIcon.map {
            PresetApplication.previewSettings(for: $0).icon.foreground.renderingStyle
        })
        #expect(styles.contains(.monochrome))
        #expect(styles.contains { $0 != .monochrome })
    }

    @Test("The icon set reaches a non-default corner style, shadow and weight")
    func iconCoverage_hiddenButApplied() {
        // The three axes `resetToSimpleControls()` does *not* fold. They matter
        // because they are the ones that survive the simple pane unrepresented, and
        // because the set has to prove they carry no indicator.
        let settings = PresetCatalog.builtInIcon.map(PresetApplication.previewSettings(for:))
        #expect(settings.contains { $0.icon.background.cornerRadiusStyle != IconBackgroundSpec().cornerRadiusStyle })
        #expect(settings.contains { $0.icon.background.shadowStyle != IconBackgroundSpec().shadowStyle })
        #expect(settings.contains { $0.icon.foreground.symbolWeight != .auto })
    }

    @Test("The icon set reaches a white symbol and a coloured one")
    func iconCoverage_symbolColours() {
        let colours = PresetCatalog.builtInIcon.map {
            PresetApplication.previewSettings(for: $0).icon.foreground.color
        }
        #expect(colours.contains(.white))
        #expect(colours.contains { $0 != .white })
    }

    @Test("The badge set reaches three corners")
    func badgeCoverage_corners() {
        // Three, not four: the fourth adds a file and covers no code path the other
        // three do not. What the corners are for is the ghost-corner thumbnail, and
        // three of them prove the crop follows the preset rather than being fixed.
        let corners = Set(PresetCatalog.builtInBadge.map {
            PresetApplication.previewSettings(for: $0).badge.position
        })
        #expect(corners.count >= 3, "the badge set covers only \(corners.count) corner(s)")
    }

    @Test("The badge set reaches a non-default scale and non-zero offsets")
    func badgeCoverage_layout() {
        let settings = PresetCatalog.builtInBadge.map(PresetApplication.previewSettings(for:))
        #expect(settings.contains { $0.badge.scale != BadgeSpec().scale })
        #expect(settings.contains { $0.badge.offsetX != 0 || $0.badge.offsetY != 0 })
    }

    @Test("The badge set reaches both background kinds")
    func badgeCoverage_backgrounds() {
        let settings = PresetCatalog.builtInBadge.map(PresetApplication.previewSettings(for:))
        #expect(settings.contains { $0.badge.background.usesCustomGradient })
        #expect(settings.contains { !$0.badge.background.usesCustomGradient })
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

    @Test("Two icon presets and one badge preset carry the indicator")
    func indicatorCount() {
        // The count from the plan, pinned so re-curating the catalogue is a decision
        // rather than a drift. If this moves, check it moved for a reason.
        #expect(PresetCatalog.builtInIcon.filter(\.needsAdvancedControls).count == 2)
        #expect(PresetCatalog.builtInBadge.filter(\.needsAdvancedControls).count == 1)
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
