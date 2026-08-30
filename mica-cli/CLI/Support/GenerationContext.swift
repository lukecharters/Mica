// CLI/Support/GenerationContext.swift
//
// What a generation starts from, before a single flag is applied.
//
// A flags-only `generate` uses `.none`: no base, the default System-mode colours,
// no fallback basename — which is exactly the shape the CLI had before `--config`
// existed. `--config` loads one from a JSON configuration, and the flags are then
// applied *onto* it by `IconGenerationRunner.buildIconSettings(from:onto:)`.
//
// The three things that travel together here are the three a configuration can
// supply and `IconSettings` alone cannot: the settings, the four System-mode
// colours beside them, and a name for the output file when no flag named one.

import Foundation

struct GenerationContext {
    /// The configuration's settings, or `nil` for a flags-only `generate`.
    ///
    /// Nil is load-bearing rather than merely absent: it is what tells the builder
    /// to seed the CLI's own defaults (the white palette), and what makes an icon
    /// foreground compulsory on the command line.
    let base: IconSettings?

    /// True when the base actually names an icon foreground.
    ///
    /// **`base != nil` used to answer this, and presets are why it no longer can.**
    /// A `--config` base always carries a foreground, so the two were the same
    /// question. `--badge-preset update` alone also produces a base — the preset's
    /// badge over defaults — but nothing in it says what the *icon* should be, so
    /// treating that base as an answer would let a bare `mica-cli --badge-preset
    /// update` silently render the default blue `command` icon. That is a surprising
    /// success, which is worse than the error it replaced.
    ///
    /// Only `validateForeground` reads this. The gradient checks still key on
    /// `base == nil`, correctly: a badge-only preset base does carry icon gradient
    /// colours to fall back on, so `--icon-bg custom-gradient` alone is legitimate
    /// there in exactly the way it is with a minimal `--config` file.
    let suppliesIconForeground: Bool

    /// The System-mode colours, which `IconSettings` does not hold. The defaults
    /// here reproduce the CLI's own `white` symbol / `blue` enclosure, so the
    /// no-configuration case needs no special-casing at the call sites.
    let appexColors: MicaAppexColors

    /// The configuration file's stem. Used to name the output file when no icon
    /// foreground argument gave anything to name it after.
    let outputBasename: String?

    /// Anything the configuration said that this build could not honour. Never
    /// fatal — the caller prints these and carries on.
    let warnings: [MicaConfigWarning]

    /// A flags-only `generate`.
    static let none = GenerationContext(
        base: nil,
        suppliesIconForeground: false,
        appexColors: MicaAppexColors(),
        outputBasename: nil,
        warnings: []
    )

    /// Load `--config` and the two `--*-preset` flags into one base.
    ///
    /// **The order is configuration, then presets, then flags**, most specific last.
    /// The configuration is the broadest statement — a whole icon — so it is the base;
    /// a preset replaces one half of it; and the flags override individual keys of
    /// whatever results, which is `IconGenerationRunner.buildIconSettings(from:onto:)`
    /// applying them afterwards. All three are optional and any combination is legal.
    ///
    /// That precedence is also why the CLI never needs a "style-only preset": because
    /// a preset applies before the flags override it, `--icon-preset media
    /// --icon-symbol hammer.fill` already *is* `media` applied to a different glyph.
    ///
    /// Only two things are fatal: a file that cannot be read, and JSON that cannot
    /// be parsed. Everything else the codec reports as a warning, because a
    /// configuration written by a newer build must still open in this one. A preset
    /// **name** that does not exist is fatal too, and deliberately: an unknown
    /// `--config` path already is, and silently rendering without the preset the user
    /// asked for is the failure mode this whole file exists to avoid.
    static func load(
        configPath: String?,
        iconPreset: String? = nil,
        badgePreset: String? = nil
    ) throws -> GenerationContext {
        var base: IconSettings? = nil
        var appexColors = MicaAppexColors()
        var outputBasename: String? = nil
        var warnings: [MicaConfigWarning] = []
        var suppliesIconForeground = false

        if let configPath {
            let url = URL(fileURLWithPath: (configPath as NSString).expandingTildeInPath)

            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw CLIError.fileSystem("Cannot read configuration \(url.path): \(error.localizedDescription)")
            }

            let contents: MicaConfigContents
            do {
                // The directory anchors the configuration's relative image paths.
                contents = try MicaConfigCodec.decode(json: data, configDirectory: url.deletingLastPathComponent())
            } catch {
                throw CLIError.configurationError(error.localizedDescription)
            }

            base = contents.settings
            appexColors = contents.appexColors
            outputBasename = url.deletingPathExtension().lastPathComponent
            warnings = contents.warnings
            // A decoded configuration always names an icon foreground, if only the
            // default one — the codec writes `icon-fg` into the identity set.
            suppliesIconForeground = true
        }

        for (name, scope) in [(iconPreset, PresetScope.icon), (badgePreset, PresetScope.badge)] {
            guard let name else { continue }
            let preset = try resolvePreset(named: name, scope: scope)

            // Seeded from defaults on the first preset with no `--config`, which is
            // what makes a preset a base in its own right.
            var settings = base ?? IconSettings()
            warnings += try PresetApplication.apply(preset, to: &settings, appexColors: &appexColors)
            base = settings
            if scope == .icon { suppliesIconForeground = true }
        }

        return GenerationContext(
            base: base,
            suppliesIconForeground: suppliesIconForeground,
            appexColors: appexColors,
            outputBasename: outputBasename,
            warnings: warnings
        )
    }

    /// Find a preset by name within its scope: built-ins first, then the user's.
    ///
    /// Matched case-insensitively, because a preset name is a display name rather
    /// than an identifier and `--icon-preset installer` is what anyone would type.
    /// A built-in wins a tie, which is the same rule the pane's name-uniquing
    /// enforces on the way in — so the tie should not arise.
    ///
    /// The error lists what *is* available. A bare "unknown preset" leaves the user
    /// with no way to find out but to read the source, since presets are the one part
    /// of the CLI's vocabulary that is not in `--help`.
    static func resolvePreset(named name: String, scope: PresetScope) throws -> MicaPreset {
        let available = PresetCatalog.builtIn(scope) + UserPresetStore.load(scope)
        if let match = available.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return match
        }
        let flag = scope == .icon ? "--icon-preset" : "--badge-preset"
        let names = available.map(\.name).joined(separator: ", ")
        throw CLIError.configurationError(
            "\(flag): no \(scope.rawValue) preset named \"\(name)\". Available: \(names)"
        )
    }

    // MARK: - Effective generation modes
    //
    // The mode decides how the four colour flags are read (mica → ColorParser,
    // system → appex tokens), so it has to account for the configuration as well
    // as the flag. `GenerationOptions.effectiveIconMode` cannot: it sees only the
    // flag, and would read a System-mode configuration as mica whenever
    // `--icon-generation-mode` was absent — silently validating and resolving
    // every colour the wrong way.

    /// The icon's effective mode: the flag, else the configuration's, else the default.
    func effectiveIconMode(_ flag: GenerationMode?) -> GenerationMode {
        flag ?? base?.icon.mode ?? IconSpec().mode
    }

    /// The badge's effective mode: the flag, else the configuration's, else the default.
    func effectiveBadgeMode(_ flag: GenerationMode?) -> GenerationMode {
        flag ?? base?.badge.mode ?? BadgeSpec().mode
    }
}
