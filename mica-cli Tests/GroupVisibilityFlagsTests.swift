// GroupVisibilityFlagsTests.swift
// `--icon-visibility` / `--badge-visibility`: whole-group visibility, matching the
// GUI's sidebar eye. Phase 4 of
// docs/plans/visibility-activation-and-imported-backgrounds.md.
//
// The rule under test throughout is **the group flag applies first and a layer flag
// overrides it**, so a group flag can never win an argument with an explicit layer
// flag, and a layer flag left over in a `--config` file can never survive a group
// flag that did not mention it.

import Testing
import Foundation

@Suite
@MainActor
struct GroupVisibilityFlagsTests {

    private func build(_ args: [String]) throws -> IconSettings {
        try IconGenerationRunner().buildTestSettings(from: parseCommand(args))
    }

    // MARK: - The flags on their own

    @Test("--icon-visibility off hides both icon layers")
    func iconVisibilityOff_hidesBothLayers() throws {
        let settings = try build(["star.fill", "--icon-visibility", "off"])
        #expect(settings.icon.foreground.isHidden == true)
        #expect(settings.icon.background.isHidden == true)
        #expect(settings.icon.isHidden == true)
    }

    @Test("--icon-visibility on leaves both icon layers visible")
    func iconVisibilityOn_showsBothLayers() throws {
        let settings = try build(["star.fill", "--icon-visibility", "on"])
        #expect(settings.icon.foreground.isHidden == false)
        #expect(settings.icon.background.isHidden == false)
    }

    @Test("Omitting the flag changes nothing")
    func absentFlag_leavesTheDefaults() throws {
        let settings = try build(["star.fill"])
        #expect(settings.icon.isHidden == false)
        #expect(settings.badge.isVisible == false)
    }

    @Test("--badge-visibility on turns the badge on without a --badge-fg")
    func badgeVisibilityOn_activatesTheBadge() throws {
        // For the badge, group visibility *is* the activation bit: `isVisible` is
        // `!fg.isHidden || !bg.isHidden`. So this flag necessarily activates, which
        // is also §3's rule arriving for one of its three activators.
        let settings = try build(["star.fill", "--badge-visibility", "on"])
        #expect(settings.badge.isVisible == true)
        #expect(settings.badge.foreground.isHidden == false)
        #expect(settings.badge.background.isHidden == false)
    }

    @Test("--badge-visibility off leaves an unasked-for badge off")
    func badgeVisibilityOff_staysOff() throws {
        let settings = try build(["star.fill", "--badge-visibility", "off"])
        #expect(settings.badge.isVisible == false)
    }

    // MARK: - Precedence: the group applies first, a layer overrides it

    @Test("A layer flag overrides the group flag, in both directions")
    func layerFlagOverridesTheGroup() throws {
        let visibleForeground = try build([
            "star.fill", "--icon-visibility", "off", "--icon-fg-visibility", "on",
        ])
        #expect(visibleForeground.icon.foreground.isHidden == false)
        #expect(visibleForeground.icon.background.isHidden == true,
                "the group flag must still reach the layer the layer flag did not name")

        let hiddenBackground = try build([
            "star.fill", "--icon-visibility", "on", "--icon-bg-visibility", "off",
        ])
        #expect(hiddenBackground.icon.foreground.isHidden == false)
        #expect(hiddenBackground.icon.background.isHidden == true)
    }

    @Test("--badge-visibility off beats --badge-fg activating the badge")
    func badgeGroupOffBeatsActivation() throws {
        // The activation baseline is the group flag when one was given. Without
        // this, activation would write both layers with `?? true` and silently undo
        // the flag the user just passed.
        let settings = try build([
            "star.fill", "--badge-fg", "symbol:plus", "--badge-visibility", "off",
        ])
        #expect(settings.badge.isVisible == false)
    }

    @Test("A badge layer flag still overrides --badge-visibility off")
    func badgeLayerFlagOverridesTheGroup() throws {
        let settings = try build([
            "star.fill", "--badge-fg", "symbol:plus",
            "--badge-visibility", "off", "--badge-fg-visibility", "on",
        ])
        #expect(settings.badge.foreground.isHidden == false)
        #expect(settings.badge.background.isHidden == true)
        #expect(settings.badge.isVisible == true, "one visible layer is a visible badge")
    }

    // MARK: - Showing a group clears a per-layer flag

    @Test("--icon-visibility on clears a per-layer hidden flag from a configuration")
    func groupOn_clearsAPerLayerFlag() throws {
        // The property that makes one flag reliably bring a whole group back, and
        // the reason this writes both layers rather than only the ones it changed.
        let context = try Self.load([
            "icon-fg": "symbol:star.fill",
            "icon-fg-visibility": false,
            "icon-bg-visibility": false,
        ])
        #expect(context.base?.icon.isHidden == true, "the configuration must start hidden")

        let settings = try Self.build(["--icon-visibility", "on"], onto: context)
        #expect(settings.icon.foreground.isHidden == false)
        #expect(settings.icon.background.isHidden == false)
    }

    @Test("--badge-visibility off turns off a badge the configuration supplied")
    func groupOff_turnsOffAConfigurationBadge() throws {
        // The job that earns `--badge-visibility` its place: a configuration is the
        // only way a badge arrives without a flag, so before this there was no way
        // to turn one off from the command line.
        let context = try Self.load([
            "icon-fg": "symbol:star.fill",
            "badge-fg": "symbol:plus",
        ])
        #expect(context.base?.badge.isVisible == true)

        #expect(try Self.build([], onto: context).badge.isVisible == true)
        #expect(try Self.build(["--badge-visibility", "off"], onto: context).badge.isVisible == false)
    }

    // MARK: - Support
    //
    // `buildTestSettings(from:)` does not read `--config` — the file is decoded into
    // a base and the flags are applied onto it, which is what the `onto:` overload
    // exists for. Same shape as ConfigOverrideTests.

    private static func load(_ object: Any) throws -> GenerationContext {
        let directory = URL.temporaryDirectory.appending(path: "group-visibility-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "config.json")
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        return try GenerationContext.load(configPath: url.path)
    }

    private static func build(_ args: [String], onto context: GenerationContext) throws -> IconSettings {
        try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["star.fill"] + args), onto: context.base ?? IconSettings())
    }
}
