// ConfigOverrideTests.swift
//
// `--config` end to end, at the seam where the two halves meet:
// `GenerationContext.load` reads the file, and `buildIconSettings(from:onto:)`
// applies the flags to what it found.
//
// `BaseOverrideTests` already defends "an absent flag leaves the base untouched"
// against a hand-built base. This suite asks the question `--config` actually
// poses — that the base a *real configuration file* produces survives the same
// way, and that validation stops demanding what the file already supplies.

import Testing
import Foundation
import SwiftUI

@Suite
@MainActor
struct ConfigOverrideTests {

    // MARK: - Fixture

    /// A configuration that is non-default in every group, so a flag that
    /// overwrites something it should have left alone shows up as a changed field.
    static let distinctiveConfig: [String: Any] = [
        "size": 256,
        "scale": "2x",
        "color-space": "displayP3",

        "icon-fg": "symbol:bolt.fill",
        "icon-fg-scale": 1.4,
        "icon-symbol-rendering": "hierarchical",
        "icon-symbol-color": "orange",
        "icon-symbol-palette": ["red", "green", "blue"],
        "icon-symbol-weight": "bold",
        "icon-fg-shadow": false,

        "icon-bg-color": "teal",
        "icon-bg-gradient": false,
        "icon-bg-corner-radius": "macos11",
        "icon-bg-shadow": "macos11",

        "badge-fg": "symbol:bell.fill",
        "badge-symbol-color": "yellow",
        "badge-bg-color": "purple",
        "badge-position": "top-left",
        "badge-scale": 1.3,
        "badge-offset-x": 0.2,
    ]

    /// Write a configuration to a unique temporary file and return its path. Each
    /// call gets a fresh directory so the suite stays parallel-safe, and so a
    /// relative image path in a future fixture resolves somewhere predictable.
    static func writeConfig(_ object: Any, name: String = "config") throws -> String {
        let directory = URL.temporaryDirectory.appending(path: "cli-config-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(name).json")
        let data: Data
        if let raw = object as? String {
            data = Data(raw.utf8)   // for the deliberately malformed cases
        } else {
            data = try JSONSerialization.data(withJSONObject: object)
        }
        try data.write(to: url)
        return url.path
    }

    static func load(_ object: Any, name: String = "config") throws -> GenerationContext {
        try GenerationContext.load(configPath: writeConfig(object, name: name))
    }

    static func build(_ args: [String], onto context: GenerationContext) throws -> IconSettings {
        try IconGenerationRunner().buildTestSettings(from: parseCommand(args), onto: context.base ?? IconSettings())
    }

    // MARK: - Loading

    @Test("A configuration file loads into a base, the appex colours and a basename")
    func loadingProducesAContext() throws {
        let path = try Self.writeConfig(Self.distinctiveConfig, name: "my-icon")
        let context = try GenerationContext.load(configPath: path)

        #expect(context.base?.icon.foreground.symbolName == "bolt.fill")
        #expect(context.base?.export.size == 256)
        #expect(context.outputBasename == "my-icon")
        #expect(context.warnings.isEmpty)
    }

    @Test("No --config gives the flags-only context")
    func absentConfigGivesNone() throws {
        let context = try GenerationContext.load(configPath: nil)
        #expect(context.base == nil)
        #expect(context.outputBasename == nil)
        #expect(context.appexColors == MicaAppexColors())
    }

    @Test("A missing configuration file is a file-system error")
    func missingFileThrows() throws {
        #expect(throws: CLIError.self) {
            try GenerationContext.load(configPath: "/nonexistent/nowhere/config.json")
        }
    }

    @Test("Malformed JSON is fatal")
    func malformedJSONThrows() throws {
        #expect(throws: CLIError.self) {
            _ = try Self.load("{ \"size\": 512")
        }
    }

    @Test("A JSON array at the top level is fatal — a configuration is an object")
    func nonObjectJSONThrows() throws {
        #expect(throws: CLIError.self) {
            _ = try Self.load(["size", 512] as [Any])
        }
    }

    @Test("An unknown key is a warning, and the rest of the file still loads")
    func unknownKeyWarnsAndLoads() throws {
        let context = try Self.load([
            "icon-fg": "symbol:heart.fill",
            "icon-bg-tint": "red",
        ])

        #expect(context.base?.icon.foreground.symbolName == "heart.fill")
        #expect(context.warnings.count == 1)
        #expect(context.warnings.first?.key == "icon-bg-tint")
    }

    @Test("A process-level flag used as a key is a warning that says so")
    func processLevelKeyWarns() throws {
        let context = try Self.load(["icon-fg": "symbol:heart.fill", "output": "/tmp/x.png"])
        #expect(context.warnings.first?.key == "output")
        #expect(context.warnings.first?.message.contains("command line") == true)
    }

    // MARK: - The core contract: flags over a real configuration

    @Test("No flags at all leaves the configuration exactly as decoded")
    func noFlags_leaveTheConfigurationUntouched() throws {
        let context = try Self.load(Self.distinctiveConfig)
        let result = try Self.build([], onto: context)
        #expect(result == context.base)
    }

    @Test("A single flag changes only its own field")
    func oneFlag_changesOnlyItsOwnField() throws {
        let context = try Self.load(Self.distinctiveConfig)
        let result = try Self.build(["--size", "1024"], onto: context)

        var expected = try #require(context.base)
        expected.export.size = 1024
        #expect(result == expected)
    }

    @Test("Flags across every group override the configuration")
    func flagsOverrideTheConfiguration() throws {
        let context = try Self.load(Self.distinctiveConfig)
        let result = try Self.build(
            [
                "--icon-fg", "symbol:heart.fill",
                "--icon-symbol-color", "white",
                "--icon-bg-color", "green",
                "--badge-position", "bottom-right",
                "--badge-offset-y=-0.1",
                "--color-space", "sRGB",
            ],
            onto: context
        )

        #expect(result.icon.foreground.symbolName == "heart.fill")
        #expect(result.icon.foreground.color == .white)
        #expect(result.icon.background.color == .green)
        #expect(result.badge.position == .bottomRight)
        #expect(result.badge.offsetY == -0.1)
        #expect(result.export.colorSpace == .sRGB)

        // …and everything they did not name still comes from the file.
        #expect(result.export.size == 256)
        #expect(result.icon.foreground.symbolWeight == .bold)
        #expect(result.icon.background.cornerRadiusStyle == .macOS11)
        #expect(result.badge.scale == 1.3)
        #expect(result.badge.offsetX == 0.2)
    }

    @Test("A configuration's palette survives an absent --icon-symbol-palette")
    func configurationPaletteIsNotOverwritten() throws {
        // The sharpest case, as in BaseOverrideTests: the CLI's own default palette
        // is three tints of white, so an eager seed here would be visible.
        let context = try Self.load(Self.distinctiveConfig)
        let result = try Self.build([], onto: context)

        #expect(result.icon.foreground.palettePrimaryColor == .red)
        #expect(result.icon.foreground.paletteSecondaryColor == .green)
        #expect(result.icon.foreground.paletteTertiaryColor == .blue)
    }

    @Test("Badge flags apply to the configuration's badge with no --badge-fg")
    func badgeFlagsApplyToTheConfigurationsBadge() throws {
        let context = try Self.load(Self.distinctiveConfig)
        let result = try Self.build(["--badge-scale", "1.75"], onto: context)

        #expect(result.badge.scale == 1.75)
        #expect(result.badge.foreground.symbolName == "bell.fill", "the file's badge foreground survives")
    }

    // MARK: - Validation changes
    //
    // Three checks stop applying once a configuration is supplying the answer.
    // Each has its without-a-configuration half here too: relaxing them for
    // `--config` must not relax them for `generate`.

    @Test("A foreground is not required when a configuration supplies one")
    func foregroundIsOptionalWithAConfiguration() throws {
        let context = try Self.load(Self.distinctiveConfig)
        let command = try parseCommand(["--config", "unused-in-this-call.json"])
        #expect(throws: Never.self) { try command.performValidationForTesting(in: context) }
    }

    @Test("A foreground is still required without one")
    func foregroundIsStillRequiredWithoutAConfiguration() throws {
        #expect(throws: (any Error).self) {
            try parseCommand([]).performValidationForTesting()
        }
    }

    @Test("--icon-bg custom-gradient alone is legal against a configuration")
    func customGradientNeedsNoColorsWithAConfiguration() throws {
        let context = try Self.load([
            "icon-bg": "custom-gradient",
            "icon-bg-gradient-colors": ["pink", "brown"],
        ])
        let command = try parseCommand(["--icon-bg", "custom-gradient"])
        #expect(throws: Never.self) { try command.performValidationForTesting(in: context) }

        // And the configuration's colours are what it renders with.
        let result = try Self.build(["--icon-bg", "custom-gradient"], onto: context)
        #expect(result.icon.background.gradientStartColor == .pink)
        #expect(result.icon.background.gradientEndColor == .brown)
    }

    @Test("--icon-bg custom-gradient still requires colours without a configuration")
    func customGradientStillNeedsColorsWithoutAConfiguration() throws {
        #expect(throws: (any Error).self) {
            try parseCommand(["star.fill", "--icon-bg", "custom-gradient"]).performValidationForTesting()
        }
    }

    @Test("A configuration in System mode validates its colour flags as appex tokens")
    func systemModeFromTheConfigurationDrivesColorValidation() throws {
        // Both modes reject a nonsense colour — the appex resolver accepts a strict
        // superset of the forms `ColorParser` does, so there is no value one takes
        // and the other refuses. What differs is *which* branch answers, and that
        // is visible in the wording: the appex branch offers the named tokens,
        // because in System mode a bare token is the thing worth reaching for.
        // Whether the context reaches validation at all is exactly what this pins.
        let context = try Self.load(["icon-generation-mode": "system", "icon-fg": "symbol:star.fill"])

        let systemMessage = Self.validationMessage(
            try parseCommand(["--icon-bg-color", "not-a-color"]), in: context
        )
        #expect(systemMessage?.contains("Use a named color") == true, "got: \(systemMessage ?? "no error")")

        let micaMessage = Self.validationMessage(
            try parseCommand(["star.fill", "--icon-bg-color", "not-a-color"]), in: .none
        )
        #expect(micaMessage?.contains("Invalid color format for --icon-bg-color") == true,
                "got: \(micaMessage ?? "no error")")
    }

    /// The text a validation failure produced, or nil if it did not fail.
    static func validationMessage(_ command: GenerateCommand, in context: GenerationContext) -> String? {
        do {
            try command.performValidationForTesting(in: context)
            return nil
        } catch {
            return "\(error)"
        }
    }

    @Test("A badge that came from the configuration still has its flags validated")
    func configurationBadgeFlagsAreValidated() throws {
        let context = try Self.load(Self.distinctiveConfig)
        let command = try parseCommand(["--badge-symbol-rendering", "palette", "--badge-symbol-palette", "red,green"])
        #expect(throws: (any Error).self, "two colours is not a palette") {
            try command.performValidationForTesting(in: context)
        }
    }

    // MARK: - Output naming

    @Test("The output file is named after the configuration when no flag names it")
    func outputBasenameComesFromTheConfiguration() throws {
        let context = try GenerationContext.load(configPath: Self.writeConfig(Self.distinctiveConfig, name: "my-icon"))
        let command = try parseCommand([])
        #expect(command.defaultOutputBasename(in: context) == "my-icon")
    }

    @Test("A positional symbol name still names the output")
    func positionalNameWinsOverTheConfiguration() throws {
        let context = try GenerationContext.load(configPath: Self.writeConfig(Self.distinctiveConfig, name: "my-icon"))
        let command = try parseCommand(["star.fill"])
        #expect(command.defaultOutputBasename(in: context) == "star.fill")
    }

    @Test("--icon-fg names the output ahead of the configuration")
    func foregroundFlagWinsOverTheConfiguration() throws {
        let context = try GenerationContext.load(configPath: Self.writeConfig(Self.distinctiveConfig, name: "my-icon"))
        let command = try parseCommand(["--icon-fg", "symbol:heart.fill"])
        #expect(command.defaultOutputBasename(in: context) == "heart.fill")
    }

    @Test("Without a configuration the basename is unchanged")
    func basenameWithoutAConfigurationIsUnchanged() throws {
        let command = try parseCommand(["star.fill"])
        #expect(command.defaultOutputBasename(in: .none) == command.defaultOutputBasename())
    }

    // MARK: - Relative image paths

    @Test("A relative image path resolves against the configuration's own directory")
    func relativeImagePathResolvesAgainstTheConfiguration() throws {
        let directory = URL.temporaryDirectory.appending(path: "cli-config-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let image = try makeTempImageFile()
        let sidecar = directory.appending(path: "art.png")
        try FileManager.default.copyItem(at: image, to: sidecar)

        let url = directory.appending(path: "config.json")
        try JSONSerialization.data(withJSONObject: ["icon-fg": "art.png"]).write(to: url)

        let context = try GenerationContext.load(configPath: url.path)
        #expect(context.warnings.isEmpty, "the sidecar is right there beside the file")
        #expect(context.base?.icon.foreground.source == .image)
        #expect(context.base?.icon.foreground.image != nil)
    }

    @Test("A missing image is a warning, and the layer opens without it")
    func missingImageWarnsAndLoads() throws {
        let context = try Self.load(["icon-fg": "not-here.png"])
        #expect(context.base?.icon.foreground.source == .image)
        #expect(context.base?.icon.foreground.image == nil)
        #expect(context.warnings.first?.key == "icon-fg")
    }
}
