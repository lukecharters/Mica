// IconForegroundRuleTests.swift
// Whether the icon's foreground draws over an imported background. Phase 6 of
// docs/plans/visibility-activation-and-imported-backgrounds.md.
//
// Three branches, in order:
//
//   1. `--icon-fg-visibility` given → honour it exactly, `off` included.
//   2. Else any other icon foreground argument given → visible.
//   3. Else → hidden.
//
// The badge's mirror of this lives in BadgeActivationTests, because activation is
// what made it reachable there.

import Testing
import Foundation

@Suite
@MainActor
struct IconForegroundRuleTests {

    private func build(_ args: [String]) throws -> IconSettings {
        try IconGenerationRunner().buildTestSettings(from: parseCommand(args))
    }

    private func imageFixture() throws -> String {
        try makeTempImageFile().path
    }

    // MARK: - Rule 3: the bare import

    @Test("An imported background alone hides the icon foreground")
    func bareImport_hidesTheForeground() throws {
        let settings = try build(["command", "--icon-bg", imageFixture()])
        #expect(settings.icon.background.isHidden == false)
        #expect(settings.icon.foreground.isHidden == true)
    }

    @Test("A generated background does not hide the foreground", arguments: [
        "standard", "custom-gradient",
    ])
    func generatedBackground_leavesTheForegroundAlone(_ kind: String) throws {
        // The rule is conditional on a *freshly imported* background. Nothing else
        // should touch the foreground's visibility.
        var args = ["command", "--icon-bg", kind]
        if kind == "custom-gradient" { args += ["--icon-bg-gradient-colors", "red,orange"] }
        #expect(try build(args).icon.foreground.isHidden == false)
    }

    // MARK: - Rule 2: styling a foreground means you want one

    @Test("Any icon foreground argument keeps the foreground over an import", arguments: [
        ["--icon-fg", "symbol:heart.fill"],
        ["--icon-fg-scale", "1.2"],
        ["--icon-symbol-rendering", "hierarchical"],
        ["--icon-symbol-color", "green"],
        ["--icon-symbol-palette", "red,green,blue"],
        ["--icon-symbol-weight", "bold"],
        ["--icon-symbol-gradient", "off"],
        ["--icon-fg-shadow", "off"],
    ])
    func foregroundArgumentKeepsTheForeground(_ args: [String]) throws {
        let settings = try build(["command", "--icon-bg", imageFixture()] + args)
        #expect(settings.icon.foreground.isHidden == false,
                "\(args.joined(separator: " ")) is a request for a foreground")
    }

    // MARK: - Rule 1: an explicit statement always wins

    @Test("--icon-fg-visibility is honoured exactly over an import",
          arguments: [("on", false), ("off", true)])
    func explicitVisibilityWins(_ value: String, _ expectHidden: Bool) throws {
        let settings = try build(["command", "--icon-bg", imageFixture(),
                                  "--icon-fg-visibility", value])
        #expect(settings.icon.foreground.isHidden == expectHidden)
    }

    @Test("--icon-fg-visibility off beats a foreground argument")
    func explicitOffBeatsRuleTwo() throws {
        // Rule 1 outranks rule 2: `off` is the one foreground flag that does not imply
        // a wanted foreground, so it must not be self-defeating.
        let settings = try build(["command", "--icon-bg", imageFixture(),
                                  "--icon-symbol-color", "green",
                                  "--icon-fg-visibility", "off"])
        #expect(settings.icon.foreground.isHidden == true)
    }

    // MARK: - The positional does not count

    @Test("The positional symbol does not count towards rule 2")
    func positionalDoesNotCount() throws {
        // The one place a user could be surprised, and the reason it is documented in
        // `--icon-bg`'s help abstract. Counting the positional would make rule 3
        // unreachable, since nearly every invocation has one.
        let path = try imageFixture()
        #expect(try build(["command", "--icon-bg", path]).icon.foreground.isHidden == true)
        #expect(try build(["--icon-fg", "symbol:command", "--icon-bg", path])
                    .icon.foreground.isHidden == false)
    }

    @Test("A positional beside a foreground argument still shows the foreground")
    func positionalPlusForegroundArgument() throws {
        // Rule 2 fires on the *other* argument; the positional supplies the symbol.
        let settings = try build(["heart.fill", "--icon-bg", imageFixture(),
                                  "--icon-symbol-color", "green"])
        #expect(settings.icon.foreground.isHidden == false)
        #expect(settings.icon.foreground.symbolName == "heart.fill")
    }

    // MARK: - Compatibility

    @Test("The bare-import render is unchanged from before the rule existed")
    func bareImportMatchesExplicitOff() throws {
        // The guarantee that must not go red: `--icon-bg app.png` renders what it
        // always has. Asserted on the settings here and on the rendered bytes by the
        // smoke test's import section.
        let path = try imageFixture()
        let bare = try build(["command", "--icon-bg", path])
        let explicit = try build(["command", "--icon-bg", path, "--icon-fg-visibility", "off"])
        #expect(bare.icon.foreground.isHidden == explicit.icon.foreground.isHidden)
        #expect(bare.icon.background.isHidden == explicit.icon.background.isHidden)
        #expect(bare.icon.background.cornerRadiusStyle == explicit.icon.background.cornerRadiusStyle)
    }
}
