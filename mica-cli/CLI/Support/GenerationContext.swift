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
        appexColors: MicaAppexColors(),
        outputBasename: nil,
        warnings: []
    )

    /// Load `--config`. A `nil` path gives `.none`, so callers need no branch.
    ///
    /// Only two things are fatal: a file that cannot be read, and JSON that cannot
    /// be parsed. Everything else the codec reports as a warning, because a
    /// configuration written by a newer build must still open in this one.
    static func load(configPath: String?) throws -> GenerationContext {
        guard let configPath else { return .none }

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

        return GenerationContext(
            base: contents.settings,
            appexColors: contents.appexColors,
            outputBasename: url.deletingPathExtension().lastPathComponent,
            warnings: contents.warnings
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
