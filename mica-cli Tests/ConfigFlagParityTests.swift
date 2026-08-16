// ConfigFlagParityTests.swift
//
// The two drift alarms for `--config`.
//
// The configuration format is defined as "the `generate` flags, as JSON", and the
// codec implements that definition a second time — `MicaConfigCodec.decode`
// mirrors `buildIconSettings` rule for rule rather than synthesising an argv. That
// duplication buys the GUI a code path it can use without an ArgumentParser, and
// costs exactly one risk: the two halves drifting apart. Nothing else in either
// test target can see it happen, because every other suite exercises one half.
//
// So there are two tests here, and they are the reason the design is safe:
//
// 1. **Parity of the vocabularies** — every `MicaConfigKey` is a real flag, and
//    every flag is a key, an accepted alias, or a deliberate exemption. Catches a
//    key added to one side only, and a flag renamed on the other.
// 2. **Parity of the semantics** — decoding a configuration produces the same
//    `IconSettings` as passing its keys as flags. Catches the subtler half: both
//    sides accepting `icon-bg-shadow` while disagreeing about what an absent one
//    means. Every fixture below is written once and used for both, so the two can
//    only agree by actually agreeing.

import Testing
import Foundation
import SwiftUI
import ArgumentParser

@Suite
@MainActor
struct ConfigFlagParityTests {

    // MARK: - Fixtures
    //
    // A representative value for every key, as a `switch` with no `default`: a new
    // `MicaConfigKey` fails to compile until someone states what it accepts, which
    // is the same moment they should be checking it is a flag too.

    static func sampleFlagValue(for key: MicaConfigKey) -> String {
        switch key {
        case .size: return "512"
        case .scale: return "2x"
        case .colorSpace: return "displayP3"
        case .iconGenerationMode: return "mica"
        case .badgeGenerationMode: return "mica"
        case .iconVisibility: return "off"
        case .badgeVisibility: return "off"
        case .iconFG: return "symbol:star.fill"
        case .iconFGScale: return "1.2"
        case .iconSymbolRendering: return "hierarchical"
        case .iconSymbolColor: return "red"
        case .iconSymbolPalette: return "red,green,blue"
        case .iconSymbolWeight: return "bold"
        case .iconSymbolGradient: return "on"
        case .iconFGShadow: return "off"
        case .iconFGVisibility: return "off"
        case .iconBG: return "standard"
        case .iconBGColor: return "green"
        case .iconBGGradientColors: return "red,blue"
        case .iconBGGradient: return "off"
        case .iconBGCornerRadius: return "macos15"
        case .iconBGScale: return "1.1"
        case .iconBGShadow: return "off"
        case .iconBGPadding: return "on"
        case .iconBGVisibility: return "off"
        case .badgeFG: return "symbol:plus.circle"
        case .badgeFGScale: return "1.2"
        case .badgeSymbolRendering: return "hierarchical"
        case .badgeSymbolColor: return "red"
        case .badgeSymbolPalette: return "red,green,blue"
        case .badgeSymbolWeight: return "bold"
        case .badgeSymbolGradient: return "on"
        case .badgeFGShadow: return "off"
        case .badgeFGVisibility: return "off"
        case .badgeBG: return "standard"
        case .badgeBGColor: return "green"
        case .badgeBGGradientColors: return "red,blue"
        case .badgeBGGradient: return "off"
        case .badgeBGScale: return "1.1"
        case .badgeBGShadow: return "off"
        case .badgeBGPadding: return "on"
        case .badgeBGVisibility: return "off"
        case .badgePosition: return "bottom-left"
        case .badgeScale: return "1.3"
        case .badgeOffsetX: return "0.2"
        case .badgeOffsetY: return "0.2"
        }
    }

    // MARK: - 1. Every key is a flag

    @Test("Every configuration key parses as a real generate flag")
    func everyKeyIsAFlag() throws {
        for key in MicaConfigKey.allCases {
            let value = Self.sampleFlagValue(for: key)
            #expect(
                throws: Never.self,
                "'\(key.rawValue)' is a configuration key but not a --\(key.rawValue) flag"
            ) {
                // The `=` form throughout: two of these flags take negatives, and a
                // space would have ArgumentParser read the value as another flag.
                try parseCommand(["--icon-symbol", "star.fill", "--\(key.rawValue)=\(value)"])
            }
        }
    }

    @Test("Every British alias parses as a real generate flag too")
    func everyAliasIsAFlag() throws {
        for (alias, canonical) in MicaConfigKey.britishAliases {
            let value = Self.sampleFlagValue(for: canonical)
            #expect(throws: Never.self, "'\(alias)' is accepted on decode but is not a flag") {
                try parseCommand(["--icon-symbol", "star.fill", "--\(alias)=\(value)"])
            }
        }
    }

    // MARK: - 2. Every flag is a key

    @Test("Every long flag in generate's help is a configuration key, an alias, or exempt")
    func everyFlagIsAKey() throws {
        // Anything a configuration deliberately cannot say. Both sets are the
        // codec's own, so the two halves cannot disagree about which flags describe
        // an invocation rather than an icon, or which abbreviate a key rather than
        // being one. Keeping the alias list in the codec is the point: a flag
        // exempted here and unknown there would decode as "not a configuration key".
        let exempt = MicaConfigKey.processLevelNames
            .union(MicaConfigKey.cliOnlyAliasNames.keys)
            .union(["help", "version"])
        let keys = Set(MicaConfigKey.allCases.map(\.rawValue))
        let aliases = Set(MicaConfigKey.britishAliases.keys)

        // The whole help text, prose included: an example naming a flag that is not
        // a key is just as much a documentation bug as a missing option.
        let help = GenerateCommand.helpMessage(columns: 200)
        let pattern = try NSRegularExpression(pattern: "--[a-z][a-z0-9-]*")
        let matches = pattern.matches(in: help, range: NSRange(help.startIndex..., in: help))

        var unaccounted: Set<String> = []
        for match in matches {
            guard let range = Range(match.range, in: help) else { continue }
            let flag = String(help[range]).dropFirst(2)
            let name = String(flag)
            if keys.contains(name) || aliases.contains(name) || exempt.contains(name) { continue }
            unaccounted.insert(name)
        }

        #expect(unaccounted.isEmpty, "flags with no configuration key: \(unaccounted.sorted().joined(separator: ", "))")
    }

    @Test("The CLI-only shorthands are never written to a configuration")
    func cliOnlyAliasesAreNeverEncoded() throws {
        // The exemption above says these flags need no key. This says the encoder
        // agrees — a written `icon-symbol` would be a key by another name, and the
        // decoder would reject the file it had just produced.
        var settings = IconSettings()
        settings.icon.foreground.source = .symbol
        settings.icon.foreground.symbolName = "star.fill"
        settings.badge.foreground.source = .symbol
        settings.badge.foreground.symbolName = "plus.circle"
        settings.badge.foreground.isHidden = false

        let data = try MicaConfigCodec.encode(settings: settings)
        let written = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        for shorthand in MicaConfigKey.cliOnlyAliasNames.keys {
            #expect(written[shorthand] == nil, "the encoder wrote the CLI shorthand '\(shorthand)'")
        }
        #expect(written["icon-fg"] as? String == "symbol:star.fill")
    }

    @Test("A CLI shorthand in a configuration warns, and names the key to use instead")
    func cliOnlyAliasInAConfigurationNamesTheKey() throws {
        // Reachable by anyone who met the flag first. "not a configuration key" is
        // true and unhelpful; the warning has to carry the translation.
        let json = #"{"icon-symbol": "star.fill"}"#.data(using: .utf8)!
        let decoded = try MicaConfigCodec.decode(json: json, configDirectory: nil)
        let warning = try #require(decoded.warnings.first { $0.key == "icon-symbol" })
        #expect(warning.message.contains("icon-fg"))
    }

    // MARK: - 3. The semantics match
    //
    // Each fixture is a configuration. It is decoded, and its own keys are also
    // handed to the flag parser; the two `IconSettings` must be identical.
    //
    // Deliberately no images: both sides would import the same file, but
    // `ImportedImage` equality is identity-based, so the comparison could not
    // succeed even when the behaviour is right. Image handling is pinned instead by
    // `MicaConfigTests` (codec side) and `ImportedImageDefaultsTests` (flag side).

    /// The same configuration as a command line. Values are rendered exactly as the
    /// flags accept them, which is what makes the comparison meaningful.
    static func argv(for config: [String: Any]) -> [String] {
        config.keys.sorted().map { key in
            let value = config[key]!
            let rendered: String
            switch value {
            case let bool as Bool:
                rendered = ToggleState(bool).rawValue
            case let array as [String]:
                rendered = array.joined(separator: ",")
            case let int as Int:
                rendered = String(int)
            case let double as Double:
                rendered = String(double)
            case let string as String:
                rendered = string
            default:
                rendered = "\(value)"
            }
            // `=` rather than a space: --badge-offset-y=-0.15 is the only form
            // ArgumentParser reads as a value rather than another flag.
            return "--\(key)=\(rendered)"
        }
    }

    /// One configuration, and whether decoding it is expected to say something.
    /// Only one fixture does: the codec tells a config author that badge keys with
    /// no `badge-fg` are inert, where the flag parser leaves the same mistake
    /// silent. That difference is deliberate and does not touch the settings, which
    /// is exactly what the fixture is here to prove.
    struct EquivalenceFixture {
        let name: String
        let config: [String: Any]
        var warns: Bool = false
    }

    static let equivalenceFixtures: [EquivalenceFixture] = [
        .init(name: "empty", config: [:]),

        .init(name: "export", config: [
            "size": 256,
            "scale": "2x",
            "color-space": "displayP3",
        ]),

        .init(name: "icon foreground", config: [
            "icon-fg": "symbol:bolt.fill",
            "icon-fg-scale": 1.4,
            "icon-symbol-rendering": "hierarchical",
            "icon-symbol-color": "orange",
            "icon-symbol-weight": "bold",
            "icon-symbol-gradient": true,
            "icon-fg-shadow": false,
            "icon-fg-visibility": false,
        ]),

        .init(name: "icon palette", config: [
            "icon-fg": "symbol:person.3.sequence.fill",
            "icon-symbol-rendering": "palette",
            "icon-symbol-palette": ["red", "green", "blue"],
        ]),

        .init(name: "icon background", config: [
            "icon-bg-color": "teal",
            "icon-bg-gradient": false,
            "icon-bg-corner-radius": "macos15",
            "icon-bg-shadow": "macos15",
            "icon-bg-visibility": false,
        ]),

        .init(name: "icon custom gradient", config: [
            "icon-bg": "custom-gradient",
            "icon-bg-gradient-colors": ["#FF6B35", "#F7931E"],
        ]),

        .init(name: "badge", config: [
            "badge-fg": "symbol:plus.circle",
            "badge-fg-scale": 1.2,
            "badge-symbol-rendering": "hierarchical",
            "badge-symbol-color": "cyan",
            "badge-symbol-weight": "semibold",
            "badge-symbol-gradient": true,
            "badge-fg-shadow": false,
            "badge-bg-color": "purple",
            "badge-bg-gradient": false,
            "badge-bg-shadow": false,
            "badge-position": "top-left",
            "badge-scale": 1.3,
        ]),

        .init(name: "badge negative offsets", config: [
            "badge-fg": "symbol:bell.fill",
            "badge-offset-x": -0.25,
            "badge-offset-y": -0.15,
        ]),

        .init(name: "badge layer visibility", config: [
            "badge-fg": "symbol:plus",
            "badge-fg-visibility": true,
            "badge-bg-visibility": false,
        ]),

        .init(name: "badge custom gradient", config: [
            "badge-fg": "symbol:gearshape.fill",
            "badge-bg": "custom-gradient",
            "badge-bg-gradient-colors": ["red", "orange"],
        ]),

        // The activation rule from the other side: without `badge-fg` every badge
        // key is inert, and both halves have to be inert in the same way.
        .init(name: "badge keys with no badge-fg", config: [
            "badge-position": "top-left",
            "badge-scale": 1.5,
            "badge-bg-color": "red",
        ], warns: true),

        .init(name: "system icon", config: [
            "icon-generation-mode": "system",
            "icon-fg": "symbol:folder.fill",
            "icon-bg-color": "red",
            "icon-symbol-color": "white",
        ]),

        .init(name: "system badge", config: [
            "badge-generation-mode": "system",
            "badge-fg": "symbol:gear",
            "badge-bg-color": "red",
            "badge-symbol-color": "white",
        ]),
    ]

    // One test over the whole matrix rather than a parameterized one: the fixtures
    // are `[String: Any]`, which is not Sendable, so they cannot cross into the
    // per-case tasks a parameterized `@Test` spawns. `#expect` does not stop the
    // loop, so a drift in three fixtures still reports all three by name.
    @Test("Decoding a configuration equals passing its keys as flags")
    func decodeMatchesTheFlagBuilder() throws {
        for fixture in Self.equivalenceFixtures {
            let json = try JSONSerialization.data(withJSONObject: fixture.config)
            let decoded = try MicaConfigCodec.decode(json: json, configDirectory: nil)
            #expect(decoded.warnings.isEmpty == !fixture.warns,
                    "\(fixture.name): unexpected decode warnings \(decoded.warnings)")

            // `onto: IconSettings()` and not the no-base overload: a configuration
            // is a base, so neither side seeds the CLI's white palette.
            let built = try IconGenerationRunner().buildTestSettings(
                from: parseCommand(Self.argv(for: fixture.config)),
                onto: IconSettings()
            )

            #expect(decoded.settings == built, "\(fixture.name): the codec and the flag builder disagree")
        }
    }

    @Test("The System-mode colours a configuration carries match the flags' own resolution")
    func systemColorsMatchTheFlags() throws {
        let config: [String: Any] = [
            "icon-generation-mode": "system",
            "icon-bg-color": "red",
            "icon-symbol-color": "white",
            "badge-generation-mode": "system",
            "badge-fg": "symbol:gear",
            "badge-bg-color": "green",
            "badge-symbol-color": "black",
        ]
        let json = try JSONSerialization.data(withJSONObject: config)
        let decoded = try MicaConfigCodec.decode(json: json, configDirectory: nil)

        // The flag side resolves these at render time rather than into IconSettings,
        // so they are compared through the command's own resolvers — which is also
        // what proves the fallback chain lands on the configuration's values.
        let command = try parseCommand(["--icon-symbol", "star.fill"])
        let context = GenerationContext(
            base: decoded.settings,
            appexColors: decoded.appexColors,
            outputBasename: nil,
            warnings: []
        )
        #expect(try command.resolvedIconAppexEnclosureColor(in: context).stringValue == "red")
        #expect(try command.resolvedIconAppexSymbolColor(in: context).stringValue == "white")
        #expect(try command.resolvedBadgeAppexEnclosureColor(in: context).stringValue == "green")
        #expect(try command.resolvedBadgeAppexSymbolColor(in: context).stringValue == "black")
    }

    @Test("With no configuration the appex fallbacks are the CLI's own defaults")
    func systemColorsFallBackToTheCLIDefaults() throws {
        let command = try parseCommand(["--icon-symbol", "star.fill"])
        #expect(try command.resolvedIconAppexEnclosureColor(in: .none).stringValue == "blue")
        #expect(try command.resolvedIconAppexSymbolColor(in: .none).stringValue == "white")
        #expect(try command.resolvedBadgeAppexEnclosureColor(in: .none).stringValue == "blue")
        #expect(try command.resolvedBadgeAppexSymbolColor(in: .none).stringValue == "white")
    }

    @Test("A flag still overrides the configuration's appex colour")
    func systemColorFlagsOverrideTheConfiguration() throws {
        let context = GenerationContext(
            base: IconSettings(),
            appexColors: MicaAppexColors(iconEnclosure: .red, iconSymbol: .black,
                                         badgeEnclosure: .green, badgeSymbol: .yellow),
            outputBasename: nil,
            warnings: []
        )
        let command = try parseCommand([
            "--icon-symbol", "star.fill",
            "--icon-bg-color", "purple",
            "--badge-fg", "symbol:gear",
            "--badge-symbol-color", "orange",
        ])
        #expect(try command.resolvedIconAppexEnclosureColor(in: context).stringValue == "purple")
        #expect(try command.resolvedIconAppexSymbolColor(in: context).stringValue == "black", "no flag, so the configuration stands")
        #expect(try command.resolvedBadgeAppexEnclosureColor(in: context).stringValue == "green")
        #expect(try command.resolvedBadgeAppexSymbolColor(in: context).stringValue == "orange")
    }
}
