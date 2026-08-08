// SymbolFlagTests.swift
// `--icon-symbol` / `--badge-symbol`: the prefix-free way to name an SF Symbol.
//
// They are shorthand for `--icon-fg symbol:<name>`, and "shorthand" is the whole
// claim under test here — not just that they parse, but that they reach every
// decision the flag they stand in for reaches. Three of those are load-bearing and
// would each fail quietly:
//
//   * `badgeIsActive` — a --badge-symbol that missed it renders no badge at all.
//   * `foregroundArgumentGiven` — rule 2 of the imported-background foreground rule.
//   * the output basename — which names the file when there is no -o.
//
// The merge is a computed `foreground` inside each options struct, so all three
// hold by construction. These tests are what says so, and what would catch someone
// "simplifying" it into a second stored property.

import Testing
import Foundation
import ArgumentParser

@Suite
@MainActor
struct SymbolFlagTests {

    private func build(_ args: [String]) throws -> IconSettings {
        try IconGenerationRunner().buildTestSettings(from: parseCommand(args))
    }

    private func imageFixture() throws -> String {
        try makeTempImageFile().path
    }

    // MARK: - The shorthand claim

    @Test("--icon-symbol resolves to the same foreground as --icon-fg symbol:")
    func iconSymbolMatchesTheLongForm() throws {
        let short = try parseCommand(["--icon-symbol", "star.fill"]).resolvedForeground()
        let long = try parseCommand(["--icon-fg", "symbol:star.fill"]).resolvedForeground()
        #expect(short == long)
        #expect(short == .symbol("star.fill"))
    }

    @Test("--badge-symbol resolves to the same foreground as --badge-fg symbol:")
    func badgeSymbolMatchesTheLongForm() throws {
        let short = try parseCommand(["--icon-symbol", "star.fill", "--badge-symbol", "plus.circle"])
            .resolvedBadgeForeground()
        let long = try parseCommand(["--icon-symbol", "star.fill", "--badge-fg", "symbol:plus.circle"])
            .resolvedBadgeForeground()
        #expect(short == long)
        #expect(short == .symbol("plus.circle"))
    }

    @Test("A bare name is not read as an image path")
    func bareNameIsNotAPath() throws {
        // The failure this guards is silent: `ForegroundValue(parsing:)` treats
        // anything without the prefix as a path, so a --icon-symbol that forgot to
        // add it would resolve to `.image("star.fill")` and fail much later, as a
        // missing file rather than as a bad flag.
        #expect(try parseCommand(["--icon-symbol", "star.fill"]).resolvedForeground() == .symbol("star.fill"))
    }

    // MARK: - Reaching the decisions the long form reaches

    @Test("--badge-symbol activates the badge")
    func badgeSymbolActivatesTheBadge() throws {
        // `badgeIsActive` reads the merged `foreground`. A second stored property
        // would leave this false and render the icon with no badge and no error.
        let settings = try build(["--icon-symbol", "star.fill", "--badge-symbol", "plus.circle"])
        #expect(settings.badge.isVisible)
        #expect(settings.badge.foreground.symbolName == "plus.circle")
    }

    @Test("--icon-symbol counts as an icon foreground argument")
    func iconSymbolCountsAsAForegroundArgument() throws {
        // Rule 2: naming a foreground over imported artwork means you want one.
        // This is the deliberate difference from the positional it replaced, which
        // was boilerplate and did not count.
        let settings = try build(["--icon-symbol", "command", "--icon-bg", imageFixture()])
        #expect(settings.icon.foreground.isHidden == false)
        #expect(settings.icon.foreground.symbolName == "command")
    }

    @Test("--badge-symbol counts as a badge foreground argument")
    func badgeSymbolCountsAsAForegroundArgument() throws {
        let settings = try build([
            "--icon-symbol", "star.fill",
            "--badge-symbol", "plus.circle", "--badge-bg", imageFixture(),
        ])
        #expect(settings.badge.foreground.isHidden == false)
    }

    @Test("--icon-symbol names the output file")
    func iconSymbolNamesTheOutputFile() throws {
        #expect(try parseCommand(["--icon-symbol", "gear.badge"]).defaultOutputBasename() == "gear.badge")
    }

    // MARK: - The prefix is refused, not tolerated

    @Test("--icon-symbol rejects a symbol: prefix, and the error names the bare form")
    func iconSymbolRejectsThePrefix() throws {
        let error = #expect(throws: ValidationError.self) {
            try parseCommand(["--icon-symbol", "symbol:star.fill"]).performValidationForTesting()
        }
        // Without this the value becomes "symbol:symbol:star.fill", which the
        // character check then rejects as "invalid characters" — true, and useless.
        #expect(error?.description.contains("--icon-symbol star.fill") == true)
    }

    @Test("--badge-symbol rejects a symbol: prefix too")
    func badgeSymbolRejectsThePrefix() throws {
        let error = #expect(throws: ValidationError.self) {
            try parseCommand(["--icon-symbol", "star.fill", "--badge-symbol", "symbol:plus.circle"])
                .performValidationForTesting()
        }
        #expect(error?.description.contains("--badge-symbol plus.circle") == true)
    }

    @Test("An empty symbol name is refused", arguments: [
        ["--icon-symbol", ""],
        ["--icon-symbol", "star.fill", "--badge-symbol", ""],
    ])
    func emptySymbolNameIsRefused(args: [String]) throws {
        #expect(throws: ValidationError.self) {
            try parseCommand(args).performValidationForTesting()
        }
    }

    // MARK: - Conflicts are refused, never resolved

    @Test("Giving both --icon-fg and --icon-symbol is an error")
    func iconForegroundConflict() throws {
        // Deliberately not "one wins". The positional this replaced lost silently to
        // --icon-fg, and ending that was half the case for removing it.
        let error = #expect(throws: ValidationError.self) {
            try parseCommand(["--icon-fg", "symbol:bolt.fill", "--icon-symbol", "star.fill"])
                .performValidationForTesting()
        }
        #expect(error?.description.contains("--icon-fg") == true)
        #expect(error?.description.contains("--icon-symbol") == true)
    }

    @Test("Giving both --badge-fg and --badge-symbol is an error")
    func badgeForegroundConflict() throws {
        let error = #expect(throws: ValidationError.self) {
            try parseCommand([
                "--icon-symbol", "star.fill",
                "--badge-fg", "symbol:bolt.fill", "--badge-symbol", "plus.circle",
            ]).performValidationForTesting()
        }
        #expect(error?.description.contains("--badge-fg") == true)
        #expect(error?.description.contains("--badge-symbol") == true)
    }

    @Test("A conflict on an image path is refused as a conflict")
    func conflictOnAnImagePathIsStillAConflict() throws {
        // The one case where the merged value would otherwise be perfectly valid,
        // so only the explicit check catches it.
        let path = try imageFixture()
        #expect(throws: ValidationError.self) {
            try parseCommand(["--icon-fg", path, "--icon-symbol", "star.fill"])
                .performValidationForTesting()
        }
    }

    // MARK: - No collision with the --icon-symbol-* family

    @Test("--icon-symbol does not shadow the flags that share its prefix", arguments: [
        ("--icon-symbol-color", "blue"),
        ("--icon-symbol-rendering", "hierarchical"),
        ("--icon-symbol-weight", "bold"),
        ("--icon-symbol-gradient", "on"),
        ("--icon-symbol-palette", "red,green,blue"),
    ])
    func noPrefixCollisionWithTheFamily(flag: String, value: String) throws {
        // ArgumentParser matches long names exactly rather than by unambiguous
        // prefix, so `--icon-symbol-color=blue` cannot be read as `--icon-symbol`
        // with the value `-color=blue`. Six flags share the prefix; that is worth a
        // test rather than an assumption.
        let command = try parseCommand(["--icon-symbol", "star.fill", flag, value])
        #expect(command.iconForeground.symbol == "star.fill")
        #expect(try command.resolvedForeground() == .symbol("star.fill"))

        // And the same in the `=` form, which is where a prefix parser would break.
        let equalsForm = try parseCommand(["--icon-symbol=star.fill", "\(flag)=\(value)"])
        #expect(equalsForm.iconForeground.symbol == "star.fill")
    }

    // MARK: - Imported artwork alone needs no foreground

    @Test("An icon background image alone is a complete invocation")
    func importedBackgroundNeedsNoForeground() throws {
        // Rule 3 hides the foreground over imported artwork, so requiring one here
        // would mean naming a symbol solely to have it hidden. Before the positional
        // was removed this could not arise: the positional always supplied one.
        let path = try imageFixture()
        #expect(throws: Never.self) {
            try parseCommand(["--icon-bg", path]).performValidationForTesting()
        }
        let settings = try build(["--icon-bg", path])
        #expect(settings.icon.foreground.isHidden == true)
        #expect(settings.icon.background.isHidden == false)
    }

    @Test("Imported artwork names the output file when nothing else can")
    func importedBackgroundNamesTheOutputFile() throws {
        let path = try imageFixture()
        let expected = (path as NSString).lastPathComponent as NSString
        #expect(
            try parseCommand(["--icon-bg", path]).defaultOutputBasename()
                == expected.deletingPathExtension
        )
    }

    @Test("A generated background still requires a foreground", arguments: [
        ["--icon-bg", "standard"],
        ["--icon-bg-color", "blue"],
        ["--icon-bg", "prerendered-liquid-glass"],
    ])
    func generatedBackgroundStillRequiresAForeground(args: [String]) throws {
        // The relaxation is for imported artwork only. Widening it would have
        // `--icon-bg-color blue` quietly render whatever ForegroundSpec.iconDefault
        // happens to name.
        #expect(throws: ValidationError.self) {
            try parseCommand(args).performValidationForTesting()
        }
    }
}
