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
        // Naming no foreground at all is how rule 3 is reached. It used to require
        // naming one and having it discounted, because the positional symbol this
        // invocation carried was excluded from rule 2 — `--icon-symbol` is not.
        let settings = try build(["--icon-bg", imageFixture()])
        #expect(settings.icon.background.isHidden == false)
        #expect(settings.icon.foreground.isHidden == true)
    }

    @Test("A generated background does not hide the foreground", arguments: [
        "standard", "custom-gradient",
    ])
    func generatedBackground_leavesTheForegroundAlone(_ kind: String) throws {
        // The rule is conditional on a *freshly imported* background. Nothing else
        // should touch the foreground's visibility.
        var args = ["--icon-symbol", "command", "--icon-bg", kind]
        if kind == "custom-gradient" { args += ["--icon-bg-gradient-colors", "red,orange"] }
        #expect(try build(args).icon.foreground.isHidden == false)
    }

    // MARK: - Rule 2: styling a foreground means you want one

    @Test("Any icon foreground argument keeps the foreground over an import", arguments: [
        ["--icon-fg", "symbol:heart.fill"],
        ["--icon-symbol", "heart.fill"],
        ["--icon-fg-scale", "1.2"],
        ["--icon-symbol-rendering", "hierarchical"],
        ["--icon-symbol-color", "green"],
        ["--icon-symbol-palette", "red,green,blue"],
        ["--icon-symbol-weight", "bold"],
        ["--icon-symbol-gradient", "off"],
        ["--icon-fg-shadow", "off"],
    ])
    func foregroundArgumentKeepsTheForeground(_ args: [String]) throws {
        let settings = try build(["--icon-bg", imageFixture()] + args)
        #expect(settings.icon.foreground.isHidden == false,
                "\(args.joined(separator: " ")) is a request for a foreground")
    }

    // MARK: - Rule 1: an explicit statement always wins

    @Test("--icon-fg-visibility is honoured exactly over an import",
          arguments: [("on", false), ("off", true)])
    func explicitVisibilityWins(_ value: String, _ expectHidden: Bool) throws {
        let settings = try build(["--icon-bg", imageFixture(),
                                  "--icon-fg-visibility", value])
        #expect(settings.icon.foreground.isHidden == expectHidden)
    }

    @Test("--icon-fg-visibility off beats a foreground argument")
    func explicitOffBeatsRuleTwo() throws {
        // Rule 1 outranks rule 2: `off` is the one foreground flag that does not imply
        // a wanted foreground, so it must not be self-defeating.
        let settings = try build(["--icon-bg", imageFixture(),
                                  "--icon-symbol-color", "green",
                                  "--icon-fg-visibility", "off"])
        #expect(settings.icon.foreground.isHidden == true)
    }

    // MARK: - Naming a symbol is what separates rules 2 and 3

    @Test("Naming a symbol is the whole difference between rules 3 and 2")
    func namingASymbolIsTheDifference() throws {
        // The two invocations differ by nothing but the foreground, which is what
        // makes the rule readable. Until `--icon-symbol` replaced the positional
        // these two lines both named a symbol and only one of them counted, and
        // that discrepancy was the surprise `--icon-bg`'s abstract had to document.
        let path = try imageFixture()
        #expect(try build(["--icon-bg", path]).icon.foreground.isHidden == true)
        #expect(try build(["--icon-symbol", "command", "--icon-bg", path])
                    .icon.foreground.isHidden == false)
        // And the long form it abbreviates agrees, or the two are not aliases.
        #expect(try build(["--icon-fg", "symbol:command", "--icon-bg", path])
                    .icon.foreground.isHidden == false)
    }

    @Test("A symbol beside another foreground argument still shows the foreground")
    func symbolPlusForegroundArgument() throws {
        // Two independent reasons for rule 2 to fire; the symbol must still be the
        // one that lands, rather than a default the other argument styles.
        let settings = try build(["--icon-symbol", "heart.fill", "--icon-bg", imageFixture(),
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
        let bare = try build(["--icon-bg", path])
        let explicit = try build(["--icon-bg", path, "--icon-fg-visibility", "off"])
        #expect(bare.icon.foreground.isHidden == explicit.icon.foreground.isHidden)
        #expect(bare.icon.background.isHidden == explicit.icon.background.isHidden)
        #expect(bare.icon.background.cornerRadiusStyle == explicit.icon.background.cornerRadiusStyle)
    }
}
