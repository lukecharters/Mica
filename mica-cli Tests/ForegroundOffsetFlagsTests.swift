// ForegroundOffsetFlagsTests.swift
//
// The four foreground-nudge flags: `--icon-fg-offset-x`/`-y` and
// `--badge-fg-offset-x`/`-y`. They join `--badge-offset-x`/`-y` as the only flags
// that take a negative value, and they are the first ones with a *different*
// accepted range — ±0.5 rather than ±1.0, because a foreground starts centred in
// its own frame where a badge starts in a corner. Two ranges validated by one
// function is exactly the arrangement that goes wrong quietly, so both are pinned
// here.

import Testing
import Foundation
import ArgumentParser

@Suite
@MainActor
struct ForegroundOffsetFlagsTests {

    // MARK: - Through to the settings

    @Test("The four offset flags reach their layer's spec")
    func offsetFlagsReachTheSpec() throws {
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand([
            "--icon-symbol", "star.fill",
            "--icon-fg-offset-x=0.2", "--icon-fg-offset-y=-0.1",
            "--badge-symbol", "plus",
            "--badge-fg-offset-x=-0.4", "--badge-fg-offset-y=0.35",
        ]))

        #expect(settings.icon.foreground.offsetX == 0.2)
        #expect(settings.icon.foreground.offsetY == -0.1)
        #expect(settings.badge.foreground.offsetX == -0.4)
        #expect(settings.badge.foreground.offsetY == 0.35)
    }

    @Test("Omitted, they are nil and the spec stays centred")
    func omittedOffsetsLeaveTheDefault() throws {
        let command = try parseCommand(["--icon-symbol", "star.fill", "--badge-symbol", "plus"])
        #expect(command.iconForeground.offsetX == nil)
        #expect(command.iconForeground.offsetY == nil)
        #expect(command.badge.foregroundOffsetX == nil)
        #expect(command.badge.foregroundOffsetY == nil)

        let settings = try IconGenerationRunner().buildTestSettings(from: command)
        #expect(settings.icon.foreground.offsetX == 0)
        #expect(settings.badge.foreground.offsetY == 0)
    }

    /// An imported foreground is nudged by the same pair of values — one stored
    /// offset for both sources, unlike `--icon-fg-scale`, which has to choose
    /// between `symbolScale` and `imageScale`.
    @Test("An imported foreground takes the same offset")
    func imageForegroundTakesTheOffset() throws {
        let image = try makeTempImageFile()
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand([
            "--icon-fg", image.path, "--icon-fg-offset-y=0.3",
        ]))
        #expect(settings.icon.foreground.source == .image)
        #expect(settings.icon.foreground.offsetY == 0.3)
    }

    // MARK: - The range

    @Test("Past ±0.5 is refused, and the message names the bounds it checked",
          arguments: ["--icon-fg-offset-x", "--icon-fg-offset-y",
                      "--badge-fg-offset-x", "--badge-fg-offset-y"])
    func outOfRangeIsRefused(flag: String) throws {
        do {
            _ = try parseCommand(["--icon-symbol", "star.fill", "--badge-symbol", "plus",
                                  "\(flag)=0.6"])
            Issue.record("\(flag)=0.6 was accepted; the foreground range is ±0.5")
        } catch {
            let message = String(describing: error)
            #expect(message.contains("-0.5"), "\(flag) reported: \(message)")
            #expect(message.contains("0.5"), "\(flag) reported: \(message)")
        }
        #expect(throws: Never.self) {
            try parseCommand(["--icon-symbol", "star.fill", "--badge-symbol", "plus",
                              "\(flag)=-0.5"])
        }
    }

    /// The badge's *own* offset keeps the wider range, so generalising
    /// `validateOffset` must not have narrowed it.
    @Test("The badge's own offsets still take the full ±1.0")
    func badgeOffsetKeepsItsWiderRange() throws {
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand([
            "--icon-symbol", "star.fill", "--badge-symbol", "plus",
            "--badge-offset-x=0.9", "--badge-offset-y=-1.0",
        ]))
        #expect(settings.badge.offsetX == 0.9)
        #expect(settings.badge.offsetY == -1.0)
    }

    /// A negative value must be attached with `=`. Given a space, ArgumentParser
    /// reads `-0.2` as another flag and fails before any transform runs, which is
    /// why the `=` hint lives in each flag's abstract.
    @Test("A negative value needs the = form")
    func negativeNeedsTheEqualsForm() throws {
        #expect(throws: Never.self) {
            try parseCommand(["--icon-symbol", "star.fill", "--icon-fg-offset-x=-0.2"])
        }
        #expect(throws: (any Error).self) {
            try parseCommand(["--icon-symbol", "star.fill", "--icon-fg-offset-x", "-0.2"])
        }
    }

    // MARK: - Rule 2 of the foreground rule

    /// Nudging a foreground is styling a foreground, so naming one of these over an
    /// imported background means the import's hide-it default is overruled. The
    /// alternative would be a flag that positions something invisible.
    @Test("An offset flag counts as wanting a foreground over imported artwork")
    func offsetCountsAsAForegroundArgument() throws {
        let artwork = try makeTempImageFile()

        let bare = try parseCommand(["--icon-symbol", "star.fill", "--icon-bg", artwork.path])
        #expect(bare.iconForeground.foregroundArgumentGiven == true)   // --icon-symbol is one

        let noForeground = try parseCommand(["--icon-bg", artwork.path])
        #expect(noForeground.iconForeground.foregroundArgumentGiven == false)
        #expect(try IconGenerationRunner().buildTestSettings(from: noForeground)
                    .icon.foreground.isHidden == true)

        let nudged = try parseCommand(["--icon-bg", artwork.path, "--icon-fg-offset-x=0.1"])
        #expect(nudged.iconForeground.foregroundArgumentGiven == true)
        #expect(try IconGenerationRunner().buildTestSettings(from: nudged)
                    .icon.foreground.isHidden == false)

        // And the badge's counterpart, whose predicate is a separate list.
        let badgeNudged = try parseCommand([
            "--icon-symbol", "star.fill", "--badge-bg", artwork.path, "--badge-fg-offset-y=0.1",
        ])
        #expect(badgeNudged.badge.foregroundArgumentGiven == true)
        #expect(try IconGenerationRunner().buildTestSettings(from: badgeNudged)
                    .badge.foreground.isHidden == false)
    }

    /// Rule 1 still wins: an explicit `off` is honoured exactly, even beside a
    /// nudge. A flag that switches something off must never be what switches it on.
    @Test("An explicit visibility off beats a nudge")
    func explicitVisibilityStillWins() throws {
        let artwork = try makeTempImageFile()
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand([
            "--icon-bg", artwork.path, "--icon-fg-offset-x=0.1", "--icon-fg-visibility", "off",
        ]))
        #expect(settings.icon.foreground.isHidden == true)
        #expect(settings.icon.foreground.offsetX == 0.1)
    }
}
