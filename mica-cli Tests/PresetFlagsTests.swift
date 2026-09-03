// PresetFlagsTests.swift
//
// `--icon-preset` and `--badge-preset`: the flags themselves, the precedence rule
// that makes them useful, and the two ways they are allowed to change validation.
//
// **The precedence rule is the feature.** A preset applies *before* the flags, so an
// explicit flag overrides it — which is also how the CLI gets style-only presets for
// free: `--icon-preset <name> --icon-symbol hammer.fill` is that preset applied to a
// different glyph, so the CLI never has to know that the GUI considered a style-only
// preset kind and declined it.
//
// **No preset is named by a literal in this file.** Names and glyphs both come out of
// `PresetCatalog`, which is curated for taste and churns often. Everything asserted here
// is true of *any* preset the catalogue holds — resolution, precedence, validation,
// output naming — so a curation pass that renames or drops one must not turn this suite
// red. `anyIcon`/`anyBadge` are how a test gets a subject.
//
// The subtler test here is `badgePresetDoesNotExcuseAMissingIconForeground`. Presets
// produce a base where there was none, and `context.base == nil` used to be how the
// CLI asked "is an icon foreground compulsory?" — so a badge-only preset would have
// silently rendered the default `command` glyph. A surprising success is worse than
// the error it replaced.

import Testing
import Foundation
import SwiftUI
import ArgumentParser

@Suite
@MainActor
struct PresetFlagsTests {

    // MARK: - Helpers

    private func context(icon: String? = nil, badge: String? = nil) throws -> GenerationContext {
        try GenerationContext.load(configPath: nil, iconPreset: icon, badgePreset: badge)
    }

    /// Some built-in of `scope`, chosen by the catalogue. Loud rather than neutral if the
    /// catalogue is empty: a helper returning a placeholder name would make every test
    /// using it pass against a preset that does not exist.
    private func anyPreset(_ scope: PresetScope) throws -> MicaPreset {
        try #require(PresetCatalog.builtIn(scope).first, "the catalogue holds no \(scope) preset")
    }

    private func anyIcon() throws -> String { try anyPreset(.icon).name }
    private func anyBadge() throws -> String { try anyPreset(.badge).name }

    private func settings(_ args: [String], icon: String? = nil, badge: String? = nil) throws -> IconSettings {
        let command = try parseCommand(args)
        let context = try self.context(icon: icon, badge: badge)
        guard let base = context.base else {
            return try IconGenerationRunner().buildTestSettings(from: command)
        }
        return try IconGenerationRunner().buildTestSettings(from: command, onto: base)
    }

    // MARK: - The flags parse

    @Test("Both preset flags parse")
    func flagsParse() throws {
        // Any two strings would do — the parser does not resolve them — but using real
        // names keeps the invocation one a user could type.
        let icon = try anyIcon()
        let badge = try anyBadge()
        let command = try parseCommand(["--icon-preset", icon, "--badge-preset", badge])
        #expect(command.iconPreset == icon)
        #expect(command.badgePreset == badge)
    }

    @Test("Neither flag is a configuration key")
    func presetFlagsAreNotKeys() {
        // A configuration naming a preset instead of carrying its values would not be
        // self-contained, which is the format's central promise: a file has to render
        // the same icon on a machine that has never seen the preset.
        for flag in MicaConfigKey.presetFlagNames {
            #expect(MicaConfigKey(rawValue: flag) == nil, "'\(flag)' became a configuration key")
        }
        #expect(MicaConfigKey.presetFlagNames == ["icon-preset", "badge-preset"])
    }

    // MARK: - Resolution

    @Test("A built-in resolves, case-insensitively")
    func resolvesBuiltIn() throws {
        // A preset name is a display name rather than an identifier, and a lowercased
        // name is what anyone would type.
        let name = try anyIcon()
        let exact = try GenerationContext.resolvePreset(named: name, scope: .icon)
        let lower = try GenerationContext.resolvePreset(named: name.lowercased(), scope: .icon)
        #expect(exact == lower)
        #expect(exact.isBuiltIn)
    }

    @Test("An unknown preset is fatal, and the error lists what is available")
    func unknownPresetIsFatal() throws {
        // Fatal rather than ignored, on the same terms as an unknown `--config` path:
        // silently rendering without the preset the user asked for is the failure this
        // whole area exists to avoid. Listing the names matters because presets are the
        // one part of the CLI's vocabulary that is not in `--help`.
        #expect(throws: (any Error).self) {
            _ = try GenerationContext.resolvePreset(named: "nosuch", scope: .icon)
        }
        let available = try anyIcon()
        do {
            _ = try GenerationContext.resolvePreset(named: "nosuch", scope: .icon)
        } catch {
            #expect(error.localizedDescription.contains(available))
        }
    }

    @Test("A preset name is looked up in its own scope only")
    func scopesAreSeparate() throws {
        // An icon preset asked for as a badge preset must fail rather than quietly
        // finding the icon one and applying its keys to nothing.
        //
        // The two scopes do share some names, so the subject has to be a name that is
        // an icon preset and *not* a badge one — picked here rather than assumed.
        let badgeNames = Set(PresetCatalog.builtIn(.badge).map { $0.name.lowercased() })
        let iconOnly = try #require(
            PresetCatalog.builtIn(.icon).first { !badgeNames.contains($0.name.lowercased()) },
            "every icon preset shares its name with a badge preset"
        )
        #expect(throws: (any Error).self) {
            _ = try GenerationContext.resolvePreset(named: iconOnly.name, scope: .badge)
        }
    }

    /// The symbol a built-in names in its own `*-fg` key, with the `symbol:` prefix off.
    ///
    /// Tests read the expected glyph from the catalogue rather than repeating it, so that
    /// re-curating `PresetCatalog` — which happens for taste, and often — cannot fail the
    /// CLI suite. It is not tautological: the value still has to survive `MicaConfigCodec`
    /// and the scoped copy to arrive in the base.
    private func declaredSymbol(of preset: MicaPreset) throws -> String {
        let key = preset.scope == .icon ? "icon-fg" : "badge-fg"
        guard case .string(let value)? = preset.keys[key] else {
            throw PresetFixtureError.missingForegroundKey(preset: preset.name, key: key)
        }
        let prefix = "symbol:"
        guard value.hasPrefix(prefix) else {
            throw PresetFixtureError.foregroundIsNotASymbol(preset: preset.name, value: value)
        }
        return String(value.dropFirst(prefix.count))
    }

    // MARK: - The context a preset produces

    @Test("An icon preset produces a base and supplies an icon foreground")
    func iconPresetProducesABase() throws {
        let preset = try anyPreset(.icon)
        let context = try context(icon: preset.name)
        let base = try #require(context.base)
        #expect(context.suppliesIconForeground)
        // The glyph is read from the preset rather than written here: what is worth
        // asserting is that the preset's own `icon-fg` survived the decode and the
        // scoped copy, which is what this compares. It is not tautological — a literal
        // would be both weaker and curation-dependent.
        //
        // Hoisted out of `#expect`: the macro runs its operands in a non-throwing
        // autoclosure, so a `try` call has to be a `let` first.
        let declared = try declaredSymbol(of: preset)
        #expect(base.icon.foreground.symbolName == declared)
    }

    @Test("A badge preset produces a base but supplies no icon foreground")
    func badgePresetProducesABaseWithoutAForeground() throws {
        // The distinction `suppliesIconForeground` exists for. The base is real — it
        // carries the badge — but nothing in it says what the icon should be.
        let context = try context(badge: try anyBadge())
        let base = try #require(context.base)
        #expect(!context.suppliesIconForeground)
        #expect(base.badge.isVisible)
    }

    @Test("A flags-only generate still has no base at all")
    func noPresetNoBase() throws {
        let context = try context()
        #expect(context.base == nil)
        #expect(!context.suppliesIconForeground)
    }

    @Test("Both presets compose without touching each other")
    func bothScopesCompose() throws {
        // Asserted *differentially*, against each preset applied alone, rather than
        // against two literal symbol names. That is both curation-proof and a stronger
        // claim: two literals would still pass if composing quietly changed the glyph to
        // some third value, so long as someone updated the expectations to match.
        let icon = try anyIcon()
        let badge = try anyBadge()
        let both = try #require(try context(icon: icon, badge: badge).base)
        let iconOnly = try #require(try context(icon: icon).base)
        let badgeOnly = try #require(try context(badge: badge).base)

        #expect(both.icon.foreground.symbolName == iconOnly.icon.foreground.symbolName)
        #expect(both.badge.foreground.symbolName == badgeOnly.badge.foreground.symbolName)
        #expect(both.icon.background.color == iconOnly.icon.background.color)
        #expect(both.badge.background.color == badgeOnly.badge.background.color)
        #expect(both.badge.isVisible)
    }

    @Test("A preset produces no warnings")
    func presetsWarnAboutNothing() throws {
        for name in PresetCatalog.builtInIcon.map(\.name) {
            let context = try context(icon: name)
            #expect(context.warnings.isEmpty, "\(name): \(context.warnings.map(\.message).joined(separator: "; "))")
        }
    }

    // MARK: - Precedence

    @Test("An explicit flag overrides the preset")
    func flagOverridesPreset() throws {
        // The whole precedence rule in one assertion.
        // The preset's own background, read from the preset — an unrelated flag must
        // leave it alone.
        let icon = try anyIcon()
        let presetBackground = try settings([], icon: icon).icon.background.color
        let plain = try settings(["--icon-symbol", "x"], icon: icon)
        #expect(plain.icon.background.color == presetBackground)

        // `red` is the *flag's* value, not the catalogue's, so pinning it is safe.
        let overridden = try settings(["--icon-bg-color", "red"], icon: icon)
        #expect(overridden.icon.background.color == .red)
    }

    @Test("Overriding the symbol keeps the preset's styling — style-only, for free")
    func symbolOverrideIsStyleOnly() throws {
        // What §7 of the plan says the CLI gets without a style-only preset kind:
        // the preset's look with a different glyph. Every background axis is compared
        // against the same preset applied alone, so the claim holds whichever kind of
        // background the catalogue's presets happen to use.
        let icon = try anyIcon()
        let base = try settings([], icon: icon)
        let restyled = try settings(["--icon-symbol", "hammer.fill"], icon: icon)

        #expect(restyled.icon.foreground.symbolName == "hammer.fill")
        #expect(restyled.icon.background.color == base.icon.background.color)
        #expect(restyled.icon.background.usesGradient == base.icon.background.usesGradient)
        #expect(restyled.icon.background.usesCustomGradient == base.icon.background.usesCustomGradient)
        #expect(restyled.icon.background.gradientStartColor == base.icon.background.gradientStartColor)
        #expect(restyled.icon.background.gradientEndColor == base.icon.background.gradientEndColor)
    }

    @Test("A badge flag overrides the badge preset without disturbing the icon preset")
    func badgeFlagOverridesBadgePresetOnly() throws {
        let icon = try anyIcon()
        let settings = try settings(["--badge-position", "top-left"], icon: icon, badge: try anyBadge())
        #expect(settings.badge.position == .topLeft)
        // The icon half, compared against the icon preset applied on its own rather than
        // against a literal glyph: what this test is about is the badge flag *not*
        // reaching the icon, which is a relation between two runs.
        let iconOnly = try self.settings([], icon: icon)
        #expect(settings.icon.foreground.symbolName == iconOnly.icon.foreground.symbolName)
    }

    @Test("A preset never touches the export settings")
    func presetsDoNotTouchExport() throws {
        // Falls out of the key namespace rather than from a rule anyone applies, so it
        // is worth an assertion on the surface a user would notice it on.
        let settings = try settings(["--size", "256"], icon: try anyIcon(), badge: try anyBadge())
        #expect(settings.export.size == 256)
    }

    // MARK: - Validation

    @Test("An icon preset excuses a missing icon foreground")
    func iconPresetExcusesTheForeground() throws {
        // The preset carries the symbol, so requiring one on the command line would
        // mean naming a glyph only to have the preset's replace it.
        let command = try parseCommand([])
        let context = try context(icon: try anyIcon())
        #expect(throws: Never.self) {
            try command.performValidationForTesting(in: context)
        }
    }

    @Test("A badge preset does NOT excuse a missing icon foreground")
    func badgePresetDoesNotExcuseAMissingIconForeground() throws {
        // **The regression this pair guards.** `context.base != nil` used to answer
        // "is a foreground compulsory?", and a badge-only preset produces a base — so
        // this invocation would have rendered the default blue `command` icon and
        // reported success. A surprising success is worse than the error it replaced.
        let command = try parseCommand([])
        let context = try context(badge: try anyBadge())
        #expect(throws: (any Error).self) {
            try command.performValidationForTesting(in: context)
        }
    }

    @Test("A badge preset plus an icon symbol validates")
    func badgePresetWithAnIconSymbolIsFine() throws {
        let command = try parseCommand(["--icon-symbol", "star.fill"])
        let context = try context(badge: try anyBadge())
        #expect(throws: Never.self) {
            try command.performValidationForTesting(in: context)
        }
    }

    // MARK: - Output naming

    @Test("With no foreground flag the file is named after the preset's symbol")
    func outputBasenameComesFromThePreset() throws {
        // A preset is not a file and has no stem to borrow, so `outputBasename` is nil
        // for one — without this the file would fall back to the generic "icon".
        let preset = try anyPreset(.icon)
        let command = try parseCommand([])
        let context = try context(icon: preset.name)
        let declared = try declaredSymbol(of: preset)
        #expect(command.defaultOutputBasename(in: context) == declared)
    }

    @Test("An explicit symbol still names the file")
    func explicitSymbolStillNamesTheFile() throws {
        let command = try parseCommand(["--icon-symbol", "hammer.fill"])
        let context = try context(icon: try anyIcon())
        #expect(command.defaultOutputBasename(in: context) == "hammer.fill")
    }
}

/// Failures in this file's own fixtures, kept loud rather than neutral: a helper that
/// returned an empty string on a missing key would make every assertion using it pass.
private enum PresetFixtureError: Error, CustomStringConvertible {
    case missingForegroundKey(preset: String, key: String)
    case foregroundIsNotASymbol(preset: String, value: String)

    var description: String {
        switch self {
        case .missingForegroundKey(let preset, let key):
            return "\(preset) carries no \(key)"
        case .foregroundIsNotASymbol(let preset, let value):
            return "\(preset)'s foreground is \(value), not a symbol: reference"
        }
    }
}
