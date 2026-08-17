// ColorSurfaceAgreementTests.swift
//
// Phase 5 of the colour-resolution plan, and the phase that proves the
// workstream's goal: **a colour means the same thing and is written the same way
// across the GUI, `mica-cli` and a JSON configuration.** Phases 1–4 only made that
// possible — one token table, provenance in the stored value, one grammar, a
// validated appex projection. Nothing so far asserted the surfaces actually agree.
//
// ## What counts as a surface, and why there are only two parsers
//
// The GUI has no colour parser of its own. Its wells produce a `Color` that
// `MicaColorValue(resolving:)` captures, and its preset dropdown writes a token
// directly — neither goes through a string. The only way a *typed* colour reaches
// the GUI is by importing a configuration, so **for colour strings the GUI path is
// the configuration path**, and `MicaConfigCodec.encode` is the direction where the
// GUI writes and the CLI reads. That leaves two string parsers to keep in step:
//
// | Surface | Entry |
// |---|---|
// | `mica-cli generate` flags | `GenerateCommand` → `buildIconSettings` |
// | a JSON configuration, and therefore the GUI | `MicaConfigCodec.decode` |
//
// `ConfigFlagParityTests` already checks those two agree — but along the *key* axis,
// one representative value per key. This suite is the other axis: every colour
// **form**, on every colour-bearing key. A form that parses on one side and not the
// other, or stores a different value, shows up here.
//
// ## Why so little of this renders
//
// There is one rendering engine: both interfaces build an `IconSettings` and hand it
// to `IconRenderer`. So once two paths produce an equal `IconSettings` they render
// identically **by construction**, and a pixel comparison of the two would only be
// asserting that one function is deterministic. The renders below are spent on the
// claims equality cannot make: that two *different* spellings of one colour mean the
// same colour, and that a wide-gamut form survives to a Display P3 export.
// End-to-end agreement of the shipped binary is `cli-smoke-test.sh`'s job, where the
// flag and `--config` invocations are compared as PNGs.

import Testing
import Foundation
import SwiftUI
import AppKit

/// The fixture tables, deliberately **outside** the `@MainActor` suite: `@Test`'s
/// `arguments:` are evaluated before the test body and therefore outside the actor,
/// so an isolated `static let` cannot be a parameter source.
enum ColorFormFixtures {

    // MARK: - The forms

    /// One way of writing a colour, from §4.3's table.
    struct ColorForm: Sendable, CustomStringConvertible {
        let text: String
        /// Whether the text contains a comma, and so cannot be used in the four
        /// options that split their value on commas.
        var hasComma: Bool { text.contains(",") }
        var description: String { text }

        init(_ text: String) { self.text = text }
    }

    /// Every surviving form, at least one per family, including the shapes most
    /// likely to be handled differently by two parsers: a token carrying an alpha
    /// modifier (the value keeps a name *and* a number), the unbounded forms
    /// (components outside 0–1), and `extended-gray:` — two components, and the one
    /// form Mica reads but never writes.
    static let forms: [ColorForm] = [
        // Tokens, including the two surviving aliases and the two semantic colours.
        ColorForm("blue"),
        ColorForm("mint"),
        ColorForm("white"),
        ColorForm("gray"),
        ColorForm("grey"),
        ColorForm("clear"),
        ColorForm("transparent"),
        ColorForm("primary"),
        ColorForm("secondary"),
        // Case is folded on the way in, and the canonical spelling is what is kept.
        ColorForm("BLUE"),
        // Hex, all three widths, with and without the #.
        ColorForm("#0088FF"),
        ColorForm("0088FF"),
        ColorForm("#08F"),
        ColorForm("#0088FFCC"),
        // Functions, with and without the alpha argument.
        ColorForm("rgb(0,136,255)"),
        ColorForm("rgb(0,136,255,0.5)"),
        ColorForm("hsl(209,100%,50%)"),
        ColorForm("hsl(209,100%,50%,0.5)"),
        // Bounded spaces, alpha present and absent.
        ColorForm("srgb:0,0.53,1"),
        ColorForm("srgb:0,0.53,1,0.5"),
        ColorForm("display-p3:0,0.5,1"),
        // Unbounded spaces — wide gamut, and the read-only gray form.
        ColorForm("extended-srgb:0,0.53333,1,1"),
        ColorForm("extended-srgb:1.09300,-0.22670,-0.15010,1.00000"),
        ColorForm("extended-gray:0.5,1"),
        // The opacity suffix, on each family that takes one.
        ColorForm("blue:0.5"),
        ColorForm("primary:0.5"),
        ColorForm("#0088FF:0.5"),
        ColorForm("rgb(0,136,255):0.5"),
    ]

    // MARK: - The keys

    /// One colour-bearing configuration key: the other keys needed to make it
    /// operative, and how to read the colour back out of the built settings.
    ///
    /// Not `Sendable`, because the context is a JSON dictionary — only
    /// `(form, keyName)` is ever parameterised, so it never crosses an isolation
    /// boundary.
    struct ColorKey {
        let key: MicaConfigKey
        /// Keys that must accompany it, or the value is not operative and the
        /// writer's applicability gates drop it.
        let context: [String: Any]
        let read: @Sendable (IconSettings) -> MicaColorValue

        var name: String { key.rawValue }
    }

    /// The four single-colour keys. `icon-symbol-color` is read under the default
    /// monochrome rendering, where it lands on `foreground.color`; its palette and
    /// hierarchical variants are different properties and are covered by
    /// `ColorOpacityFlagsTests`.
    // `nonisolated(unsafe)`: `ColorKey` carries a `[String: Any]` context, so the
    // table is not `Sendable`. It is immutable and only ever read from a test body,
    // and the alternative — a JSON-shaped fixture that *is* Sendable — would mean
    // hand-encoding each context as a string and losing the one-table property this
    // suite depends on.
    nonisolated(unsafe) static let singleColorKeys: [ColorKey] = [
        ColorKey(key: .iconSymbolColor,
                 context: ["icon-fg": "symbol:star.fill"],
                 read: { $0.icon.foreground.color }),
        ColorKey(key: .iconBGColor,
                 context: ["icon-fg": "symbol:star.fill"],
                 read: { $0.icon.background.color }),
        ColorKey(key: .badgeSymbolColor,
                 context: ["icon-fg": "symbol:star.fill", "badge-fg": "symbol:plus.circle"],
                 read: { $0.badge.foreground.color }),
        ColorKey(key: .badgeBGColor,
                 context: ["icon-fg": "symbol:star.fill", "badge-fg": "symbol:plus.circle"],
                 read: { $0.badge.background.color }),
    ]

    /// Flattened for parameterisation, so a failure names the form and the key
    /// rather than an index.
    static let formKeyPairs: [(ColorForm, String)] =
        forms.flatMap { form in singleColorKeys.map { (form, $0.name) } }

    static func key(named name: String) -> ColorKey? {
        singleColorKeys.first { $0.name == name }
    }

    // MARK: - Equivalence groups

    /// Forms that describe one colour and must therefore resolve to one colour.
    /// This is the claim `IconSettings` equality *cannot* make — these values are
    /// deliberately unequal, because they carry different provenance — so it is
    /// checked on the resolved components instead.
    struct EquivalenceGroup: Sendable, CustomStringConvertible {
        let name: String
        let spellings: [String]
        var description: String { name }
    }

    static let equivalenceGroups: [EquivalenceGroup] = [
        EquivalenceGroup(name: "an sRGB colour, four ways", spellings: [
            "#0088FF", "0088FF", "rgb(0,136,255)", "srgb:0,0.53333,1",
        ]),
        EquivalenceGroup(name: "white, five ways", spellings: [
            "white", "#FFFFFF", "rgb(255,255,255)", "srgb:1,1,1", "extended-gray:1,1",
        ]),
        EquivalenceGroup(name: "Display P3 red, two ways", spellings: [
            "display-p3:1,0,0", "extended-srgb:1.09300,-0.22670,-0.15010,1.00000",
        ]),
        EquivalenceGroup(name: "half-opacity white, three ways", spellings: [
            "white:0.5", "#FFFFFF80", "srgb:1,1,1,0.5",
        ]),
    ]
}

@Suite
@MainActor
struct ColorSurfaceAgreementTests {

    typealias ColorForm = ColorFormFixtures.ColorForm
    typealias EquivalenceGroup = ColorFormFixtures.EquivalenceGroup

    // MARK: - 1. The two parsers agree

    /// The claim: writing a colour as a flag and writing it as a configuration key
    /// produce **the same stored value** — not merely the same rendered colour. It
    /// has to be the stored value, because that is what carries provenance. A path
    /// that resolved `blue` to components would render identically today and then
    /// diverge on the next OS or the next appearance change, and no pixel comparison
    /// could see it coming.
    @Test("every colour form stores the same value from a flag and from a configuration",
          arguments: ColorFormFixtures.formKeyPairs.map { ($0.0, $0.1) })
    func flagAndConfigurationAgree(_ form: ColorForm, _ keyName: String) throws {
        let key = try #require(ColorFormFixtures.key(named: keyName))
        var config = key.context
        config[key.name] = form.text

        let decoded = try Self.decode(config)
        #expect(decoded.warnings.isEmpty,
                "\(keyName)=\(form): the configuration reader complained: \(decoded.warnings)")

        // `onto: IconSettings()` and not the no-base overload, matching
        // `ConfigFlagParityTests`: a configuration is a base, so neither side seeds
        // the CLI's own white palette.
        let built = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(ConfigFlagParityTests.argv(for: config)),
            onto: IconSettings()
        )

        let fromConfig = key.read(decoded.settings)
        let fromFlag = key.read(built)
        #expect(fromConfig == fromFlag,
                "\(keyName)=\(form): flag stored \(fromFlag.stringValue), configuration stored \(fromConfig.stringValue)")
    }

    // MARK: - 2. A configuration round-trips

    /// The GUI writes a configuration and the CLI reads it, so a colour has to
    /// survive `encode` → `decode` unchanged.
    ///
    /// Asserted on the **value**, not the string, because some forms deliberately
    /// re-spell themselves: the writer only ever emits a token or `extended-srgb:`,
    /// so `#0088FF` comes back as components and `extended-gray:0.5,1` comes back in
    /// sRGB. Same colour, which is the contract — identical text is not.
    @Test("every colour form survives a configuration round trip",
          arguments: ColorFormFixtures.formKeyPairs.map { ($0.0, $0.1) })
    func roundTripPreservesTheColour(_ form: ColorForm, _ keyName: String) throws {
        let key = try #require(ColorFormFixtures.key(named: keyName))
        var config = key.context
        config[key.name] = form.text

        let first = try Self.decode(config).settings
        let reencoded = try MicaConfigCodec.encode(settings: first)
        let second = try MicaConfigCodec.decode(json: reencoded, configDirectory: nil)

        #expect(second.warnings.isEmpty,
                "\(keyName)=\(form): re-reading Mica's own output complained: \(second.warnings)")
        let before = key.read(first)
        let after = key.read(second.settings)
        #expect(before == after,
                "\(keyName)=\(form): \(before.stringValue) became \(after.stringValue)")
    }

    /// And the second cycle is byte-stable, which is the stronger claim: a format
    /// that merely preserved the colour could still rewrite the file every time it
    /// was opened and saved.
    @Test("a re-encoded configuration is byte-identical on the next cycle",
          arguments: ColorFormFixtures.forms)
    func reEncodingIsStable(_ form: ColorForm) throws {
        let config: [String: Any] = ["icon-fg": "symbol:star.fill", "icon-bg-color": form.text]
        let once = try MicaConfigCodec.encode(settings: try Self.decode(config).settings)
        let twice = try MicaConfigCodec.encode(
            settings: try MicaConfigCodec.decode(json: once, configDirectory: nil).settings
        )
        #expect(once == twice, "\(form) is not stable across two encode cycles")
    }

    // MARK: - 3. Equivalent spellings mean the same colour

    @Test("spellings of one colour resolve to one colour",
          arguments: ColorFormFixtures.equivalenceGroups)
    func equivalentSpellingsAgree(_ group: EquivalenceGroup) throws {
        var resolved: [(String, [Double])] = []
        for spelling in group.spellings {
            let value = try MicaColorValue(strictlyParsing: spelling)
            resolved.append((spelling, try Self.extendedComponents(of: value)))
        }
        let (firstName, first) = try #require(resolved.first)
        for (name, components) in resolved.dropFirst() {
            for (index, channel) in components.enumerated() {
                // 8-bit-per-channel tolerance: `#FFFFFF80` can only express alpha as
                // 128/255, and `rgb()` quantises to 1/255.
                #expect(abs(channel - first[index]) <= 0.004,
                        "\(group.name): \(name) channel \(index) is \(channel), \(firstName) has \(first[index])")
            }
        }
    }

    /// A token and its own resolved components must agree — the one equivalence that
    /// cannot be written as a literal, because the components move with the OS and
    /// pinning them is what `AppleColorTokenOracle` exists to contain.
    @Test("a token agrees with the srgb: spelling of its own components",
          arguments: ["blue", "red", "mint", "white"])
    func tokenAgreesWithItsComponents(_ token: String) throws {
        let asToken = try MicaColorValue(strictlyParsing: token)
        let asComponents = try MicaColorValue(strictlyParsing: "srgb:\(Self.resolvedSRGBText(of: token))")
        let a = try Self.extendedComponents(of: asToken)
        let b = try Self.extendedComponents(of: asComponents)
        for index in 0..<4 {
            #expect(abs(a[index] - b[index]) <= 0.0001,
                    "\(token) channel \(index): token \(a[index]) vs components \(b[index])")
        }
        // But they are *not* the same stored value, and that is the point of Phase 2.
        #expect(asToken != asComponents, "a token must not collapse into its components")
        #expect(asToken.tokenName == token)
        #expect(asComponents.tokenName == nil)
    }

    // MARK: - 4. It reaches the pixels, in both colour spaces

    /// Both renders use a flat fill with the foreground hidden, because the default
    /// chiclet gradient shifts a sample enough to muddy the comparison — the same
    /// reason §1.2's measurements were taken with `--icon-bg-gradient off`.
    @Test("equivalent spellings render to the same pixels, in both colour spaces",
          arguments: [ExportColorSpace.sRGB, .displayP3])
    func equivalentSpellingsRenderIdentically(_ colorSpace: ExportColorSpace) throws {
        // An in-gamut group, so both colour spaces can carry it exactly.
        let spellings = ["#0088FF", "rgb(0,136,255)", "srgb:0,0.53333,1"]
        var samples: [(String, NSColor)] = []
        for spelling in spellings {
            samples.append((spelling, try #require(try Self.centreColour(of: spelling, in: colorSpace))))
        }
        let (firstName, first) = try #require(samples.first)
        for (name, colour) in samples.dropFirst() {
            for channel in [\NSColor.redComponent, \NSColor.greenComponent, \NSColor.blueComponent] {
                #expect(abs(colour[keyPath: channel] - first[keyPath: channel]) <= 0.006,
                        "\(colorSpace.rawValue): \(name) differs from \(firstName) — \(colour) vs \(first)")
            }
        }
    }

    /// §7's regression, reached through the *new* spelling: a wide-gamut colour must
    /// survive to a Display P3 export and clip for an sRGB one. If this stops
    /// holding, `display-p3:` has become decorative.
    @Test("a wide-gamut colour reaches a Display P3 export and clips for sRGB")
    func wideGamutSurvivesToP3() throws {
        let p3 = try #require(try Self.centreColour(of: "display-p3:1,0,0", in: .displayP3))
        let srgb = try #require(try Self.centreColour(of: "display-p3:1,0,0", in: .sRGB))

        // In a Display P3 file the P3 primary saturates the encoding.
        #expect(p3.redComponent > 0.99, "P3 red should saturate the P3 encoding: \(p3)")
        #expect(p3.greenComponent < 0.02 && p3.blueComponent < 0.02, "\(p3)")

        // Converted into sRGB the same colour is out of gamut, so it clips to sRGB
        // red — a different stored value for the same request, which is exactly why
        // the colour space belongs to an export and not to a colour.
        #expect(srgb.redComponent > 0.99, "\(srgb)")
        #expect(srgb.greenComponent < 0.06 && srgb.blueComponent < 0.06, "\(srgb)")
    }

    // MARK: - 5. The comma-splitting asymmetry, stated as a test

    /// The four multi-colour options split their value on `,`, so a comma-containing
    /// form cannot be written as a flag at all. A configuration **can** carry one, as
    /// a JSON array. That asymmetry is deliberate and documented, and it is the only
    /// place a colour is expressible on one surface and not the other — so it is
    /// pinned here rather than left to be discovered.
    @Test("a comma-containing form works in a configuration array and not as a flag")
    func commaFormsAreArrayOnly() throws {
        let arrayConfig: [String: Any] = [
            "icon-fg": "symbol:star.fill",
            "icon-bg": "custom-gradient",
            "icon-bg-gradient-colors": ["display-p3:1,0.2,0", "srgb:0,0.53,1"],
        ]
        let decoded = try Self.decode(arrayConfig)
        #expect(decoded.warnings.isEmpty, "\(decoded.warnings)")
        #expect(decoded.settings.icon.background.gradientStartColor
            != decoded.settings.icon.background.gradientEndColor,
                "both gradient stops resolved alike, so neither actually parsed")

        // The same value as a flag cannot work: the comma is the separator.
        #expect(throws: (any Error).self) {
            let command = try parseCommand([
                "--icon-symbol", "star.fill", "--icon-bg", "custom-gradient",
                "--icon-bg-gradient-colors", "display-p3:1,0.2,0",
            ])
            try command.performValidationForTesting()
        }
    }

    /// Comma-free forms must agree across both surfaces in those options too — that
    /// is the majority of real use and has no excuse to differ.
    @Test("comma-free forms agree in the gradient options",
          arguments: ColorFormFixtures.forms.filter { !$0.hasComma })
    func commaFreeFormsAgreeInGradients(_ form: ColorForm) throws {
        let config: [String: Any] = [
            "icon-fg": "symbol:star.fill",
            "icon-bg": "custom-gradient",
            "icon-bg-gradient-colors": [form.text, "white"],
        ]
        let decoded = try Self.decode(config)
        let built = try IconGenerationRunner().buildTestSettings(
            from: parseCommand([
                "--icon-symbol", "star.fill", "--icon-bg", "custom-gradient",
                "--icon-bg-gradient-colors", "\(form.text),white",
            ]),
            onto: IconSettings()
        )
        let fromConfig = decoded.settings.icon.background.gradientStartColor
        let fromFlag = built.icon.background.gradientStartColor
        #expect(fromConfig == fromFlag,
                "\(form): configuration stored \(fromConfig.stringValue), flag stored \(fromFlag.stringValue)")
    }

    // MARK: - Helpers

    private static func decode(_ config: [String: Any]) throws -> MicaConfigContents {
        try MicaConfigCodec.decode(
            json: try JSONSerialization.data(withJSONObject: config),
            configDirectory: nil
        )
    }

    /// Resolved extended-sRGB channels — where two spellings of one colour can be
    /// compared without pinning an OS-dependent value to a literal.
    private static func extendedComponents(of value: MicaColorValue) throws -> [Double] {
        let ns = ColorParser.nsColor(from: value.resolved)
        let extended = try #require(ns.usingColorSpace(.extendedSRGB))
        return [
            Double(extended.redComponent), Double(extended.greenComponent),
            Double(extended.blueComponent), Double(extended.alphaComponent),
        ]
    }

    /// `srgb:` text for a token's resolved components.
    private static func resolvedSRGBText(of token: String) -> String {
        let ns = ColorParser.nsColor(from: MicaColorValue.token(token).resolved)
        guard let srgb = ns.usingColorSpace(.sRGB) else { return "0,0,0" }
        return [srgb.redComponent, srgb.greenComponent, srgb.blueComponent]
            .map { String(format: "%.5f", $0) }
            .joined(separator: ",")
    }

    /// Render a flat fill of `spelling` and read the middle pixel.
    private static func centreColour(of spelling: String, in colorSpace: ExportColorSpace) throws -> NSColor? {
        var settings = IconSettings()
        settings.export.size = 128
        settings.export.colorSpace = colorSpace
        settings.icon.foreground.isHidden = true
        settings.icon.background.usesGradient = false
        settings.icon.background.shadowStyle = .off
        settings.icon.background.color = try MicaColorValue(strictlyParsing: spelling)

        let image = IconRenderer.renderIconSafely(settings: settings)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)
    }
}
