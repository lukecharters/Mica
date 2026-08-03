// BadgeActivationTests.swift
// What switches the badge on. Phase 5 of
// docs/plans/visibility-activation-and-imported-backgrounds.md §3.
//
// Three arguments activate the badge — `--badge-fg`, `--badge-bg`,
// `--badge-visibility on` — and nothing else does. The principle behind the set,
// which is why it is a rule rather than a list to maintain: an argument saying what
// the badge *is* activates it; an argument saying how it looks or where it sits does
// not. The modifier sweep below is what keeps that honest.

import Testing
import Foundation

@Suite
@MainActor
struct BadgeActivationTests {

    private func build(_ args: [String]) throws -> IconSettings {
        try IconGenerationRunner().buildTestSettings(from: parseCommand(["star.fill"] + args))
    }

    private func imageFixture() throws -> String {
        try makeTempImageFile().path
    }

    // MARK: - The three activators

    @Test("--badge-fg activates the badge")
    func badgeForegroundActivates() throws {
        #expect(try build(["--badge-fg", "symbol:plus"]).badge.isVisible == true)
    }

    @Test("--badge-bg activates the badge on its own")
    func badgeBackgroundActivates() throws {
        // The case this whole change exists for: artwork with no symbol invented.
        // Before phase 5 you had to write `--badge-fg symbol:plus --badge-bg app.png`
        // and name a symbol you did not want.
        #expect(try build(["--badge-bg", "custom-gradient",
                           "--badge-bg-gradient-colors", "red,orange"]).badge.isVisible == true)
        #expect(try build(["--badge-bg", imageFixture()]).badge.isVisible == true)
    }

    @Test("--badge-visibility on activates the badge on its own")
    func badgeVisibilityOnActivates() throws {
        #expect(try build(["--badge-visibility", "on"]).badge.isVisible == true)
    }

    @Test("An activated badge with no --badge-fg keeps the default symbol")
    func activatedWithoutForeground_keepsTheDefault() throws {
        let settings = try build(["--badge-bg", "standard"])
        #expect(settings.badge.isVisible == true)
        #expect(settings.badge.foreground.symbolName == ForegroundSpec.badgeDefault.symbolName)
    }

    // MARK: - Nothing else activates
    //
    // Each of these used to be silent and inert, and must stay so. `--badge-position`
    // is the one that motivated rejecting the any-badge-argument rule: a *placement*
    // flag conjuring a default gearshape is a flag doing something it does not say.

    @Test("A modifier-only invocation activates nothing", arguments: [
        ["--badge-position", "bottom-left"],
        ["--badge-scale", "1.3"],
        ["--badge-offset-x", "0.2"],
        ["--badge-offset-y=-0.15"],
        ["--badge-symbol-color", "red"],
        ["--badge-symbol-weight", "bold"],
        ["--badge-symbol-rendering", "hierarchical"],
        ["--badge-fg-scale", "1.2"],
        ["--badge-fg-shadow", "off"],
        ["--badge-bg-color", "purple"],
        ["--badge-bg-shadow", "off"],
        ["--badge-bg-scale", "1.1"],
        ["--badge-bg-padding", "on"],
        ["--badge-generation-mode", "system"],
    ])
    func modifiersDoNotActivate(_ args: [String]) throws {
        #expect(try build(args).badge.isVisible == false,
                "\(args.joined(separator: " ")) must not conjure a badge")
    }

    @Test("A layer visibility flag set to on does not activate", arguments: [
        "--badge-fg-visibility", "--badge-bg-visibility",
    ])
    func layerVisibilityOnDoesNotActivate(_ flag: String) throws {
        // The interesting half of the sweep: `on` activates for the *group* flag and
        // must not for the layer flags. They say how an existing badge is composed.
        #expect(try build([flag, "on"]).badge.isVisible == false)
    }

    @Test("--badge-visibility off activates nothing")
    func groupVisibilityOffDoesNotActivate() throws {
        #expect(try build(["--badge-visibility", "off"]).badge.isVisible == false)
    }

    // MARK: - off does not veto activation, it sets the baseline

    @Test("--badge-visibility off starts an activated badge's layers hidden")
    func groupOffHidesAnActivatedBadge() throws {
        #expect(try build(["--badge-fg", "symbol:plus",
                           "--badge-visibility", "off"]).badge.isVisible == false)
    }

    @Test("A layer flag still reveals a layer of a group-hidden badge")
    func layerFlagRevealsThroughGroupOff() throws {
        // Activation and visibility are separate steps. Vetoing activation on an
        // explicit `off` would break the precedence the icon obeys, where
        // `--icon-visibility off --icon-fg-visibility on` is a visible foreground on
        // a hidden background.
        let settings = try build([
            "--badge-fg", "symbol:plus", "--badge-visibility", "off", "--badge-fg-visibility", "on",
        ])
        #expect(settings.badge.foreground.isHidden == false)
        #expect(settings.badge.background.isHidden == true)
        #expect(settings.badge.isVisible == true)
    }

    // MARK: - The badge's foreground rule over imported artwork

    @Test("--badge-bg <art> alone hides the badge foreground")
    func importedBadgeArtworkAlone_hidesTheForeground() throws {
        // Rule 3: a bare import is artwork-only. This is the state
        // `BadgeSpec.applyBackgroundImage` sets and that activation must no longer
        // overwrite.
        let settings = try build(["--badge-bg", imageFixture()])
        #expect(settings.badge.isVisible == true)
        #expect(settings.badge.background.isHidden == false)
        #expect(settings.badge.foreground.isHidden == true)
    }

    @Test("Naming any badge foreground argument keeps the foreground over artwork",
          arguments: [
            ["--badge-fg", "symbol:plus"],
            ["--badge-symbol-color", "red"],
            ["--badge-symbol-weight", "bold"],
            ["--badge-fg-scale", "1.2"],
            ["--badge-fg-shadow", "off"],
          ])
    func foregroundArgumentKeepsTheForeground(_ args: [String]) throws {
        // Rule 2: styling a foreground means you want one.
        let settings = try build(["--badge-bg", imageFixture()] + args)
        #expect(settings.badge.foreground.isHidden == false,
                "\(args.joined(separator: " ")) is a request for a foreground")
    }

    @Test("--badge-fg-visibility is honoured exactly over imported artwork",
          arguments: [("on", false), ("off", true)])
    func explicitLayerVisibilityWinsOverArtwork(_ value: String, _ expectHidden: Bool) throws {
        // Rule 1: an explicit statement always wins — including `off`, which is the
        // one foreground flag that does not imply a wanted foreground.
        let settings = try build(["--badge-bg", imageFixture(), "--badge-fg-visibility", value])
        #expect(settings.badge.foreground.isHidden == expectHidden)
    }
}
