import ArgumentParser
import Foundation

// MARK: - Shared Validation Helpers

// The token vocabularies live in Services/SettingsTokens.swift, shared with the
// configuration codec so the flag transforms and the config keys cannot drift.

/// Resolve an appex colour argument to the value written to the plist.
///
/// System mode accepts the same colour grammar as everything else — see COLOR
/// FORMATS in `generate --help`. Only the *first* branch is special: one of
/// Apple's own tokens keeps its curated rendering instead of resolving to
/// components.
///
/// Both stages throw, and the two failures read differently on purpose:
///
/// - **The grammar** — `not-a-color` — gets the flag name and the list of forms.
/// - **The projection** (`AppexPlistColor`) — a colour outside sRGB, or a
///   translucent background — already explains its own limit and the way out, so
///   its message is passed through with only the flag name prefixed. Rewriting it
///   here would lose the nearest-sRGB suggestion it computed.
///
/// Every caller is behind a System-mode check in `validate()`, so this runs before
/// any rendering and a rejection costs the user nothing (decision D2).
private func resolveAppexColorArg(
    _ input: String,
    role: String,
    key: AppexPlistColor.Role
) throws -> AppexPlistColor {
    let color: AppexColor
    do {
        color = try AppexColor.parsing(cliString: input)
    } catch {
        let tokens = AppexNamedColor.allCases.map(\.rawValue).joined(separator: ", ")
        throw ValidationError("\(role) is invalid: '\(input)'. Use a named color (\(tokens)), a hex color (e.g. #FF1736), or components in a named space (e.g. srgb:1,0.0902,0.2118). See COLOR FORMATS in 'mica-cli generate --help'.")
    }
    do {
        return try AppexPlistColor(projecting: color, role: key)
    } catch {
        throw ValidationError("\(role): \(error.localizedDescription)")
    }
}

private func validateScale(_ scale: String, name: String) throws -> Double {
    guard let value = Double(scale) else {
        throw ValidationError("\(name) must be a number.")
    }
    guard ForegroundSpec.symbolScaleRange.contains(value) else {
        throw ValidationError("\(name) must be between 0.3 and 2.0. You provided: \(scale)")
    }
    return value
}

private func validateOffset(_ offset: String, name: String) throws -> Double {
    guard let value = Double(offset) else {
        throw ValidationError("\(name) must be a number.")
    }
    guard BadgeSpec.offsetRange.contains(value) else {
        throw ValidationError("\(name) must be between -1.0 and 1.0. You provided: \(offset)")
    }
    return value
}

// MARK: - Documenting the default of an Optional-typed flag

/// Formats the `(default: …)` suffix for a flag whose property is Optional.
///
/// ArgumentParser writes that suffix itself, but only from a property's default
/// *value* (`ArgumentDefinition.defaultValueDescription`, derived from the
/// initial value). A flag that must distinguish "not passed" from "passed the
/// default" — which `--config` requires — therefore cannot have one, and loses
/// the annotation. This puts it back, reading the same constant the fallback in
/// `buildIconSettings` uses, so help text cannot drift from behaviour.
///
/// Pass the *settings* default, never a literal: `defaultNote(ExportSpec.defaultSize)`.
func defaultNote(_ value: some CustomStringConvertible) -> String {
    "(default: \(value))"
}

/// `defaultNote` for an on|off flag, taking the settings `Bool` the flag drives
/// so the documented default is derived rather than restated. Note the sense
/// often inverts: a visibility flag is `on` when the spec's `isHidden` is false.
func defaultNote(toggle isOn: Bool) -> String {
    defaultNote(ToggleState(isOn).rawValue)
}

// MARK: - Export Options

// Export flags are Optional-typed with no default value, so that a nil reads as
// "the user did not pass this" — which `--config` needs in order to leave a
// configuration's stored value alone. Defaults therefore live in exactly one place,
// `ExportSpec`, `buildIconSettings` assigns only what was passed, and each
// abstract documents its default via `defaultNote` from that same constant.
struct ExportOptions: ParsableArguments {
    @Option(
        name: [.customLong("output"), .customShort("o")],
        help: ArgumentHelp(
            "Output file path",
            discussion: "If not specified, saves to current directory as '{symbol-name}.png'",
            valueName: "path"
        )
    )
    var outputPath: String?

    @Option(
        name: [.customLong("size"), .customShort("s")],
        help: ArgumentHelp(
            "Export size in pixels (16-1024) \(defaultNote(Int(ExportSpec.defaultSize)))",
            discussion: "Common sizes: 128, 256, 512, 1024.",
            valueName: "pixels"
        ),
        transform: { size in
            guard let intSize = Int(size) else {
                throw ValidationError("Size must be a whole number (no decimals).")
            }
            let minSize = Int(ExportSpec.minSize)
            let maxSize = Int(ExportSpec.maxSize)
            guard (minSize...maxSize).contains(intSize) else {
                throw ValidationError("Size must be between \(minSize) and \(maxSize) pixels. You provided: \(intSize)")
            }
            return intSize
        }
    )
    var size: Int?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Output resolution: 1x or 2x (retina) \(defaultNote(ExportScale.settingsDefault.rawValue))",
            valueName: "scale"
        )
    )
    var scale: ExportScale?

    @Option(
        name: [.customLong("color-space"), .customLong("colour-space")],
        help: ArgumentHelp(
            "Color space: sRGB or displayP3 \(defaultNote(ExportSpec().colorSpace.rawValue))",
            valueName: "space"
        )
    )
    var colorSpace: ExportColorSpace?
}

// MARK: - Generation Options

struct GenerationOptions: ParsableArguments {
    // The user-facing `mica`/`system` tokens ARE GenerationMode's raw values,
    // so the shared model type is stored directly — no parallel string
    // vocabulary between the flag and the settings builder.
    @Option(
        name: .customLong("icon-generation-mode"),
        help: ArgumentHelp(
            "How the icon is rendered: mica (SwiftUI, default) or system (Apple appex rendering)",
            valueName: "mica|system"
        ),
        transform: { try parseGenerationMode($0, role: "Icon") }
    )
    var iconGenerationMode: GenerationMode?

    @Option(
        name: .customLong("badge-generation-mode"),
        help: ArgumentHelp(
            "How the badge is rendered: mica (SwiftUI, default) or system (Apple appex rendering)",
            valueName: "mica|system"
        ),
        transform: { try parseGenerationMode($0, role: "Badge") }
    )
    var badgeGenerationMode: GenerationMode?

    // Both modes are read in a dozen places — two settings builders, four
    // validators and the appex render path — so the nil fallback is resolved
    // here once rather than repeated at each site. Read these, not the stored
    // properties, everywhere except where "was it passed?" is the question.
    // The defaults come from the specs, so there is no literal `mica` to drift.

    /// The icon's effective generation mode: the flag when passed, else the default.
    var effectiveIconMode: GenerationMode { iconGenerationMode ?? IconSpec().mode }

    /// The badge's effective generation mode: the flag when passed, else the default.
    var effectiveBadgeMode: GenerationMode { badgeGenerationMode ?? BadgeSpec().mode }
}

private func parseGenerationMode(_ mode: String, role: String) throws -> GenerationMode {
    guard let parsed = GenerationMode(rawValue: mode.lowercased()) else {
        throw ValidationError("\(role) generation mode must be 'mica' or 'system'.")
    }
    return parsed
}


// MARK: - Group Visibility Options

/// Whole-group visibility, matching the GUI's sidebar eye. Neither flag belongs to
/// a layer's option group, because each writes *both* layers of its group — that is
/// the whole point of them, and it is why they route through
/// `IconSettings.setGroupVisible(_:for:)`, which clears a per-layer hidden flag
/// rather than leaving one behind.
///
/// **The group flag applies first and a layer flag overrides it**, so
/// `--icon-visibility off --icon-fg-visibility on` is a visible foreground on a
/// hidden background. That matches the GUI, where the group eye sets both and you
/// then flip one.
struct GroupVisibilityOptions: ParsableArguments {
    @Option(
        name: .customLong("icon-visibility"),
        help: ArgumentHelp(
            "Icon visibility: on, or off to hide both icon layers. A per-layer flag overrides it.",
            valueName: "on|off"
        )
    )
    var icon: ToggleState?

    // No `defaultNote`: for the badge this flag *is* the activation bit, so its
    // default is not a spec default to quote — a badge is off until something asks
    // for one.
    @Option(
        name: .customLong("badge-visibility"),
        help: ArgumentHelp(
            "Badge visibility: on, or off to hide both badge layers. A per-layer flag overrides it.",
            valueName: "on|off"
        )
    )
    var badge: ToggleState?
}


// MARK: - Icon Foreground Options

struct IconForegroundOptions: ParsableArguments {
    // Folds the old --icon-source + --imported-image. `symbol:<name>` selects an
    // SF Symbol; anything else is treated as an image file path.
    //
    // Read `foreground` below, never this — `--icon-symbol` supplies the same value.
    @Option(
        name: .customLong("icon-fg"),
        help: ArgumentHelp(
            "Icon foreground source",
            discussion: "Either 'symbol:<name>' for an SF Symbol (e.g. symbol:star.fill) or a path to an image file. For a symbol, --icon-symbol says the same thing without the prefix.",
            valueName: "symbol:NAME|path"
        )
    )
    var foregroundFlag: String?

    // The head of the --icon-symbol-* family, which styles the symbol this names.
    // Before it existed the family had no head: you wrote `--icon-fg symbol:star.fill
    // --icon-symbol-color blue` and named one layer two ways in one invocation.
    @Option(
        name: .customLong("icon-symbol"),
        help: ArgumentHelp(
            "Icon SF Symbol name, with no 'symbol:' prefix",
            discussion: "Shorthand for --icon-fg symbol:<name>, e.g. --icon-symbol star.fill. Use --icon-fg for an image file; giving both is an error.",
            valueName: "name"
        )
    )
    var symbol: String?

    /// The foreground as `--icon-fg` spells it, whichever flag supplied it.
    ///
    /// **Normalising here is the point.** Every reader above this struct —
    /// `resolvedForeground()`, `providedForeground()`, `foregroundArgumentGiven`,
    /// the output basename — sees one value and needs no knowledge of the alias, so
    /// there is no list of sites to keep in step. The badge's identical property
    /// also feeds `badgeIsActive`, where forgetting the alias would not fail loudly:
    /// it would render the icon with no badge at all.
    ///
    /// The conflict is caught in `validateForeground`, not resolved here, so this
    /// stays total and the error can name both flags.
    var foreground: String? {
        if let symbol { return "\(ForegroundValue.symbolPrefix)\(symbol)" }
        return foregroundFlag
    }

    /// The three ways the two foreground flags can be asked for something they do
    /// not mean. All refuse; none guesses.
    ///
    /// The conflict in particular is why `foreground` above does not simply pick a
    /// winner. The positional this alias replaces let `--icon-fg` beat it silently,
    /// and half the case for removing the positional was ending that — reinstating
    /// it one flag over would be a poor trade.
    func validateFlags() throws {
        if foregroundFlag != nil, symbol != nil {
            throw ValidationError(
                "Pass --icon-fg or --icon-symbol, not both — --icon-symbol <name> is shorthand for --icon-fg symbol:<name>."
            )
        }
        guard let symbol else { return }
        if symbol.isEmpty {
            throw ValidationError("--icon-symbol requires a symbol name, e.g. --icon-symbol star.fill")
        }
        if ForegroundValue.hasSymbolPrefix(symbol) {
            let bare = String(symbol.dropFirst(ForegroundValue.symbolPrefix.count))
            throw ValidationError(
                "--icon-symbol takes a bare symbol name, so drop the 'symbol:' prefix: --icon-symbol \(bare.isEmpty ? "star.fill" : bare)"
            )
        }
    }

    // Folds --symbol-scale + --imported-image-scale into one flag that drives
    // whichever source (symbol or image) is active.
    @Option(
        name: .customLong("icon-fg-scale"),
        help: ArgumentHelp("Foreground scale multiplier (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Icon foreground scale") }
    )
    var scale: Double?

    @Option(
        name: .customLong("icon-symbol-rendering"),
        help: ArgumentHelp(
            "Symbol rendering mode",
            discussion: "monochrome (default), hierarchical, multicolor, or palette",
            valueName: "mode"
        ),
        transform: { mode in
            let normalized = normalizeBritishSpelling(mode)
            guard SymbolRenderingStyle.from(cliToken: normalized) != nil else {
                throw ValidationError("Symbol rendering mode must be one of: \(SymbolRenderingStyle.allCLITokens.joined(separator: ", "))")
            }
            return normalized
        }
    )
    var symbolRendering: String?

    // Folds --symbol-color + --hierarchical-color + --appex-symbol-color into a
    // single colour. Stored RAW; resolved in the settings builder by generation
    // mode (mica → ColorParser, system → AppexColor.plistValue) since the
    // transform can't see the chosen mode. nil → mode-appropriate default.
    @Option(
        name: [.customLong("icon-symbol-color"), .customLong("icon-symbol-colour")],
        help: ArgumentHelp(
            "Symbol color (monochrome, hierarchical, and multicolor modes)",
            discussion: "See COLOR FORMATS in `mica-cli generate --help`. For system mode, a named appex token keeps Apple's curated rendering; anything else resolves to custom components. Default: white.",
            valueName: "color"
        )
    )
    var symbolColor: String?

    // Folds --palette-primary/secondary/tertiary. Comma-separated `c1,c2,c3`,
    // all three slots accepting the same forms. Validated/parsed in the builder.
    @Option(
        name: .customLong("icon-symbol-palette"),
        help: ArgumentHelp(
            "Palette colors for palette rendering",
            discussion: "Three comma-separated colors 'c1,c2,c3', each taking any single-colour form that contains no comma (e.g. 'blue,white:0.5,white:0.26'). Default: white,white:0.5,white:0.26.",
            valueName: "c1,c2,c3"
        )
    )
    var symbolPalette: String?

    @Option(
        name: .customLong("icon-symbol-weight"),
        help: ArgumentHelp("Symbol weight: auto, ultralight, thin, light, regular, medium, semibold, bold, heavy, black", valueName: "weight"),
        transform: { weight in
            guard SymbolWeight.from(cliToken: weight) != nil else {
                throw ValidationError("Symbol weight must be one of: \(SymbolWeight.allCLITokens.joined(separator: ", "))")
            }
            return weight.lowercased()
        }
    )
    var symbolWeight: String?

    // Was --symbol-color-rendering flat|gradient.
    @Option(
        name: .customLong("icon-symbol-gradient"),
        help: ArgumentHelp(
            "Symbol gradient fill: on or off; gradient requires macOS 26+ \(defaultNote(toggle: ForegroundSpec.iconDefault.fillStyle == .gradient))",
            valueName: "on|off"
        )
    )
    var symbolGradient: ToggleState?

    // nil = unspecified, so the effective value can default based on the source
    // (off for imported images, on for SF Symbols).
    @Option(
        name: .customLong("icon-fg-shadow"),
        help: ArgumentHelp("Foreground shadow: on or off (default: off for images, on for SF Symbols)", valueName: "on|off")
    )
    var shadow: ToggleState?

    @Option(
        name: .customLong("icon-fg-visibility"),
        help: ArgumentHelp(
            "Foreground visibility: on, or off to hide the foreground \(defaultNote(toggle: !ForegroundSpec.iconDefault.isHidden))",
            valueName: "on|off"
        )
    )
    var visibility: ToggleState?

    /// True when any argument styling the icon *foreground* was given.
    ///
    /// Rule 2 of the foreground rule: naming one of these over an imported background
    /// means you want a foreground, so importing artwork does not hide it. The badge's
    /// counterpart is `BadgeOptions.foregroundArgumentGiven`.
    ///
    /// **The positional symbol is excluded structurally**, not by a special case: it
    /// lives on `GenerateCommand`, not in here. That is the point — the positional is
    /// present in nearly every invocation and carries no intent about the foreground,
    /// so counting it would make rule 3 unreachable.
    ///
    /// **`--icon-symbol` is included structurally**, by the same mechanism read the
    /// other way: it lives in here, and `foreground` merges it. That is the honest
    /// reading — a flag typed deliberately does carry intent, where the positional
    /// was boilerplate — and it is why the alias needs no clause of its own.
    ///
    /// **`visibility` is excluded deliberately.** It is rule 1, honoured exactly, and
    /// counting it would make `--icon-fg-visibility off` imply a wanted foreground
    /// while asking to hide one.
    var foregroundArgumentGiven: Bool {
        foreground != nil
            || scale != nil
            || symbolRendering != nil
            || symbolColor != nil
            || symbolPalette != nil
            || symbolWeight != nil
            || symbolGradient != nil
            || shadow != nil
    }
}

// MARK: - Icon Background Options

// `validPreRenderedColors` lives in Services/SettingsTokens.swift, shared with
// the configuration codec.

struct IconBackgroundOptions: ParsableArguments {
    // Folds the old --background-mode + --imported-background. Recognised
    // keywords select a generated background; any other value is an image path.
    @Option(
        name: .customLong("icon-bg"),
        help: ArgumentHelp(
            // The abstract, not the discussion: an image path hiding the symbol is the
            // one surprising consequence of the foreground rule, and the abstract is
            // what a reader sees first. The positional not counting is the whole reason
            // it can surprise — `generate command --icon-bg art.png` hides the symbol
            // while `generate --icon-fg symbol:command --icon-bg art.png` keeps it.
            "Icon background; an image path hides the symbol unless another icon foreground argument names one",
            discussion: """
                standard (color/gradient, default), custom-gradient (two-color gradient), \
                prerendered-liquid-glass (Liquid Glass asset), or a path to an image file.

                An imported background hides this group's foreground by default, because \
                most such imports are a finished icon. Any other argument in the icon \
                foreground or symbol namespace brings it back, and --icon-fg-visibility on \
                forces it. The positional symbol does not count: it is present in nearly \
                every invocation and says nothing about whether you want a foreground.
                """,
            valueName: "standard|custom-gradient|prerendered-liquid-glass|path"
        )
    )
    var selection: String?

    // Folds --base-color + --appex-enclosure-color. Stored RAW; resolved in the
    // builder by generation mode + background kind. nil → blue.
    @Option(
        name: [.customLong("icon-bg-color"), .customLong("icon-bg-colour")],
        help: ArgumentHelp(
            "Background color",
            discussion: "standard: base color (mica) or appex enclosure color (system). prerendered-liquid-glass: one of \(validPreRenderedColors.joined(separator: ", ")). Default: blue.",
            valueName: "color"
        )
    )
    var color: String?

    // Folds --use-custom-colors + --custom-primary + --custom-secondary.
    @Option(
        name: [.customLong("icon-bg-gradient-colors"), .customLong("icon-bg-gradient-colours")],
        help: ArgumentHelp(
            "Two gradient colors for custom-gradient backgrounds",
            discussion: "Comma-separated 'c1,c2' (top,bottom).",
            valueName: "c1,c2"
        )
    )
    var gradientColors: String?

    // Was --no-gradient. standard: flat vs derived gradient; prerendered: picks
    // the -solid vs -gradient asset.
    @Option(
        name: .customLong("icon-bg-gradient"),
        help: ArgumentHelp(
            "Background gradient: on or off \(defaultNote(toggle: IconBackgroundSpec().usesGradient))",
            valueName: "on|off"
        )
    )
    var gradient: ToggleState?

    @Option(
        name: .customLong("icon-bg-corner-radius"),
        help: ArgumentHelp("Corner radius: off, macos15, or macos26 (default)", valueName: "style"),
        transform: { style in
            guard IconCornerRadiusStyle.from(cliToken: style) != nil else {
                throw ValidationError("Corner radius must be 'off', 'macos15', or 'macos26'")
            }
            return style.lowercased()
        }
    )
    var cornerRadius: String?

    @Option(
        name: .customLong("icon-bg-scale"),
        help: ArgumentHelp("Scale for an imported background image (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Icon background scale") }
    )
    var scale: Double?

    // nil = unspecified, so image backgrounds default to no shadow and generated
    // backgrounds to macOS 26.
    @Option(
        name: .customLong("icon-bg-shadow"),
        help: ArgumentHelp("Background shadow: off, macos15, or macos26 (default: off for image backgrounds, macos26 otherwise)", valueName: "style"),
        transform: { style in
            guard BackgroundShadowStyle.from(cliToken: style) != nil else {
                throw ValidationError("Background shadow must be 'off', 'macos15', or 'macos26'")
            }
            return style.lowercased()
        }
    )
    var shadow: String?

    // nil = unspecified → fill the frame (padding off).
    @Option(
        name: .customLong("icon-bg-padding"),
        help: ArgumentHelp("Keep an imported background's padding: on, or off to fill the frame (default)", valueName: "on|off")
    )
    var padding: ToggleState?

    @Option(
        name: .customLong("icon-bg-visibility"),
        help: ArgumentHelp(
            "Background visibility: on, or off to hide the background \(defaultNote(toggle: !IconBackgroundSpec().isHidden))",
            valueName: "on|off"
        )
    )
    var visibility: ToggleState?

    /// True when `--icon-bg` is a file path rather than a generated-background
    /// keyword. An absent flag is not an image background — the default source is
    /// `.color`, so the generated-background defaults below apply.
    var isImageBackground: Bool {
        guard let selection else { return false }
        return !IconBackgroundValue.keywords.contains(selection.lowercased())
    }

    /// Resolved background shadow style: an explicit `--icon-bg-shadow` wins;
    /// otherwise image backgrounds default to no shadow and everything else to
    /// macOS 26.
    var effectiveShadowStyle: String {
        if let shadow { return shadow }
        return isImageBackground ? "off" : "macos26"
    }

    /// Resolved padding compensation. The user-facing `--icon-bg-padding` flag
    /// mirrors the GUI "Icon Padding" toggle: `on` keeps the image's padding
    /// (compensation off), `off` fills the frame (compensation on). Unspecified
    /// fills the frame, matching the GUI's image-import default.
    var effectivePaddingCompensation: Bool {
        guard let padding else { return true }
        return !padding.isOn
    }
}

// MARK: - Badge Options

struct BadgeOptions: ParsableArguments {

    // MARK: Foreground

    // Presence of --badge-fg activates the badge (replaces the old --badge).
    // `symbol:<name>` selects an SF Symbol; anything else is treated as an image
    // file path.
    //
    // Read `foreground` below, never this — `--badge-symbol` supplies the same
    // value, and `badgeIsActive` is one of the readers that must see it.
    @Option(
        name: .customLong("badge-fg"),
        help: ArgumentHelp(
            "Badge foreground source (supplying this activates the badge)",
            discussion: "Either 'symbol:<name>' for an SF Symbol (e.g. symbol:plus.circle) or a path to an image file. For a symbol, --badge-symbol says the same thing without the prefix.",
            valueName: "symbol:NAME|path"
        )
    )
    var foregroundFlag: String?

    // The head of the --badge-symbol-* family, and an activation flag like --badge-fg.
    @Option(
        name: .customLong("badge-symbol"),
        help: ArgumentHelp(
            "Badge SF Symbol name, with no 'symbol:' prefix (supplying this activates the badge)",
            discussion: "Shorthand for --badge-fg symbol:<name>, e.g. --badge-symbol plus.circle. Use --badge-fg for an image file; giving both is an error.",
            valueName: "name"
        )
    )
    var symbol: String?

    /// The foreground as `--badge-fg` spells it, whichever flag supplied it.
    ///
    /// See `IconForegroundOptions.foreground` for why the merge lives here. The
    /// badge raises the stakes: `badgeIsActive` reads this, so a `--badge-symbol`
    /// that bypassed it would render the icon with no badge and no diagnostic.
    var foreground: String? {
        if let symbol { return "\(ForegroundValue.symbolPrefix)\(symbol)" }
        return foregroundFlag
    }

    /// The badge's half of `IconForegroundOptions.validateFlags()`; see there for why
    /// each of the three refuses rather than guessing.
    func validateFlags() throws {
        if foregroundFlag != nil, symbol != nil {
            throw ValidationError(
                "Pass --badge-fg or --badge-symbol, not both — --badge-symbol <name> is shorthand for --badge-fg symbol:<name>."
            )
        }
        guard let symbol else { return }
        if symbol.isEmpty {
            throw ValidationError("--badge-symbol requires a symbol name, e.g. --badge-symbol plus.circle")
        }
        if ForegroundValue.hasSymbolPrefix(symbol) {
            let bare = String(symbol.dropFirst(ForegroundValue.symbolPrefix.count))
            throw ValidationError(
                "--badge-symbol takes a bare symbol name, so drop the 'symbol:' prefix: --badge-symbol \(bare.isEmpty ? "plus.circle" : bare)"
            )
        }
    }

    // Folds the old --badge-symbol-scale + --badge-imported-image-scale into one
    // flag that drives whichever source (symbol or image) is active.
    @Option(
        name: .customLong("badge-fg-scale"),
        help: ArgumentHelp("Badge foreground scale multiplier (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Badge foreground scale") }
    )
    var foregroundScale: Double?

    @Option(
        name: .customLong("badge-symbol-rendering"),
        help: ArgumentHelp(
            "Badge symbol rendering mode",
            discussion: "monochrome (default), hierarchical, multicolor, or palette",
            valueName: "mode"
        ),
        transform: { mode in
            let normalized = normalizeBritishSpelling(mode)
            guard SymbolRenderingStyle.from(cliToken: normalized) != nil else {
                throw ValidationError("Badge symbol rendering mode must be one of: \(SymbolRenderingStyle.allCLITokens.joined(separator: ", "))")
            }
            return normalized
        }
    )
    var symbolRendering: String?

    // Folds --badge-symbol-color + --badge-hierarchical-color + --badge-appex-symbol-color
    // into one colour. Stored RAW; resolved in the settings builder by generation
    // mode (mica → ColorParser, system → AppexColor.plistValue). nil → white.
    @Option(
        name: [.customLong("badge-symbol-color"), .customLong("badge-symbol-colour")],
        help: ArgumentHelp(
            "Badge symbol color (monochrome, hierarchical, and multicolor modes)",
            discussion: "See COLOR FORMATS in `mica-cli generate --help`. For system mode, a named appex token keeps Apple's curated rendering; anything else resolves to custom components. Default: white.",
            valueName: "color"
        )
    )
    var symbolColor: String?

    // Folds --badge-palette-primary/secondary/tertiary. Comma-separated `c1,c2,c3`,
    // all three slots accepting the same forms. Validated/parsed in the builder.
    @Option(
        name: .customLong("badge-symbol-palette"),
        help: ArgumentHelp(
            "Palette colors for badge palette rendering",
            discussion: "Three comma-separated colors 'c1,c2,c3', each taking any single-colour form that contains no comma. Default: white,white:0.5,white:0.26.",
            valueName: "c1,c2,c3"
        )
    )
    var symbolPalette: String?

    @Option(
        name: .customLong("badge-symbol-weight"),
        help: ArgumentHelp("Badge symbol weight: auto, ultralight, thin, light, regular, medium, semibold, bold, heavy, black", valueName: "weight"),
        transform: { weight in
            guard SymbolWeight.from(cliToken: weight) != nil else {
                throw ValidationError("Badge symbol weight must be one of: \(SymbolWeight.allCLITokens.joined(separator: ", "))")
            }
            return weight.lowercased()
        }
    )
    var symbolWeight: String?

    // Was --badge-symbol-color-rendering flat|gradient.
    @Option(
        name: .customLong("badge-symbol-gradient"),
        help: ArgumentHelp(
            "Badge symbol gradient fill: on or off; gradient requires macOS 26+ \(defaultNote(toggle: ForegroundSpec.badgeDefault.fillStyle == .gradient))",
            valueName: "on|off"
        )
    )
    var symbolGradient: ToggleState?

    // nil = unspecified, so the effective value can default based on the source
    // (off for imported images, on for SF Symbols).
    @Option(
        name: .customLong("badge-fg-shadow"),
        help: ArgumentHelp("Badge foreground shadow: on or off (default: off for images, on for SF Symbols)", valueName: "on|off")
    )
    var foregroundShadow: ToggleState?

    // No `defaultNote` on either badge visibility flag: their default is not a
    // spec value but the *activation* rule — supplying --badge-fg means "show the
    // badge", so an active badge is visible unless told otherwise, while the
    // specs default both layers to hidden. The prose says so more precisely than
    // "(default: on)" could. `buildIconSettings` resolves it with `?? true`.
    @Option(
        name: .customLong("badge-fg-visibility"),
        help: ArgumentHelp("Badge foreground visibility: on (default when the badge is active) or off", valueName: "on|off")
    )
    var foregroundVisibility: ToggleState?

    // MARK: Background

    // Folds the old --badge-imported-background. `standard`/`custom-gradient`
    // keywords select a generated background; any other value is an image path.
    // The badge gets no Liquid Glass.
    @Option(
        name: .customLong("badge-bg"),
        help: ArgumentHelp(
            "Badge background; activates the badge, and an image path hides the badge symbol",
            discussion: """
                standard (color/gradient, default), custom-gradient (two-color gradient), \
                or a path to an image file.

                This flag activates the badge on its own, so badge artwork needs no \
                --badge-fg. An imported background hides the badge symbol by default; \
                any other argument in the badge foreground or symbol namespace brings it \
                back, and --badge-fg-visibility on forces it.
                """,
            valueName: "standard|custom-gradient|path"
        )
    )
    var background: String?

    // Folds --badge-color + --badge-appex-enclosure-color. Stored RAW; resolved in
    // the builder by generation mode. nil → gray (mica) / blue (system).
    @Option(
        name: [.customLong("badge-bg-color"), .customLong("badge-bg-colour")],
        help: ArgumentHelp(
            "Badge background color",
            discussion: "standard: base color (mica) or appex enclosure color (system). Default: gray (mica) / blue (system).",
            valueName: "color"
        )
    )
    var backgroundColor: String?

    // Folds --badge-use-custom + --badge-primary + --badge-secondary.
    @Option(
        name: [.customLong("badge-bg-gradient-colors"), .customLong("badge-bg-gradient-colours")],
        help: ArgumentHelp(
            "Two gradient colors for custom-gradient badge backgrounds",
            discussion: "Comma-separated 'c1,c2' (top,bottom).",
            valueName: "c1,c2"
        )
    )
    var backgroundGradientColors: String?

    // Was --badge-no-gradient.
    @Option(
        name: .customLong("badge-bg-gradient"),
        help: ArgumentHelp(
            "Badge background gradient: on or off \(defaultNote(toggle: BadgeBackgroundSpec().usesGradient))",
            valueName: "on|off"
        )
    )
    var backgroundGradient: ToggleState?

    @Option(
        name: .customLong("badge-bg-scale"),
        help: ArgumentHelp("Scale for an imported badge background image (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Badge background scale") }
    )
    var backgroundScale: Double?

    // nil = unspecified → off for image backgrounds, on otherwise. Unlike the icon
    // background, badge background shadow is a plain on|off (no era styles).
    @Option(
        name: .customLong("badge-bg-shadow"),
        help: ArgumentHelp("Badge background shadow: on or off (default: off for image backgrounds, on otherwise)", valueName: "on|off")
    )
    var backgroundShadow: ToggleState?

    // nil = unspecified → fill the frame (padding off).
    @Option(
        name: .customLong("badge-bg-padding"),
        help: ArgumentHelp("Keep an imported badge background's padding: on, or off to fill the frame (default)", valueName: "on|off")
    )
    var backgroundPadding: ToggleState?

    @Option(
        name: .customLong("badge-bg-visibility"),
        help: ArgumentHelp("Badge background visibility: on (default when the badge is active) or off", valueName: "on|off")
    )
    var backgroundVisibility: ToggleState?

    // MARK: Layout (unchanged)

    @Option(
        name: .customLong("badge-position"),
        help: ArgumentHelp("Badge position: top-left, top-right, bottom-left, bottom-right", valueName: "position"),
        transform: { pos in
            guard BadgePosition.from(cliToken: pos) != nil else {
                throw ValidationError("Badge position must be one of: \(BadgePosition.allCLITokens.joined(separator: ", "))")
            }
            return pos.lowercased()
        }
    )
    var position: String?

    @Option(
        name: .customLong("badge-scale"),
        help: ArgumentHelp("Overall badge scale (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Badge scale") }
    )
    var scale: Double?

    // These are the only two flags that take a negative value, and a negative
    // value must be attached with `=`. Given a space, ArgumentParser reads the
    // leading dash and treats `-0.2` as another flag, so parsing fails before
    // the transform below ever runs — the hint cannot live in a ValidationError.
    //
    // It goes in the *abstract*, not the discussion: the resulting "Missing
    // value for '--badge-offset-x <offset>'" error prints the abstract only
    // (ArgumentParser's `missingValueForOptionHelpMessage`), and that error is
    // the exact moment the hint is needed. The discussion carries the reason,
    // which only `--help` readers need.
    @Option(
        name: .customLong("badge-offset-x"),
        help: ArgumentHelp(
            "Badge horizontal offset (-1.0 to 1.0). Write negative values as --badge-offset-x=-0.2",
            discussion: "Written with a space, -0.2 is read as another flag rather than a value.",
            valueName: "offset"
        ),
        transform: { try validateOffset($0, name: "Badge offset X") }
    )
    var offsetX: Double?

    @Option(
        name: .customLong("badge-offset-y"),
        help: ArgumentHelp(
            "Badge vertical offset (-1.0 to 1.0). Write negative values as --badge-offset-y=-0.2",
            discussion: "Written with a space, -0.2 is read as another flag rather than a value.",
            valueName: "offset"
        ),
        transform: { try validateOffset($0, name: "Badge offset Y") }
    )
    var offsetY: Double?

    // MARK: Derived

    /// True when `--badge-bg` is a file path rather than a generated-background
    /// keyword. An absent flag is not an image background — see the icon's.
    var isImageBackground: Bool {
        guard let background else { return false }
        return !BadgeBackgroundValue.keywords.contains(background.lowercased())
    }

    /// Resolved padding compensation for an imported badge background. Mirrors the
    /// GUI "Icon Padding" toggle: `on` keeps the image's padding (compensation off),
    /// `off` fills the frame (compensation on). Unspecified fills the frame.
    var effectiveBackgroundPaddingCompensation: Bool {
        guard let backgroundPadding else { return true }
        return !backgroundPadding.isOn
    }

    /// True when any argument styling the badge *foreground* was given.
    ///
    /// Rule 2 of the foreground rule: naming one of these over an imported
    /// background means you want a foreground, so importing artwork does not hide
    /// it. Every property here is already `Optional` — they were made Optional for
    /// `--config` — so "was this given?" costs nothing.
    ///
    /// **`foregroundVisibility` is deliberately excluded.** It is rule 1, honoured
    /// exactly rather than read as an implication, and counting it would make
    /// `--badge-fg-visibility off` imply a wanted foreground while asking to hide
    /// one. A key that switches something off must never be what switches it on.
    ///
    /// `--badge-symbol` needs no clause: `foreground` already merges it, the same
    /// way it reaches `badgeIsActive`.
    var foregroundArgumentGiven: Bool {
        foreground != nil
            || foregroundScale != nil
            || symbolRendering != nil
            || symbolColor != nil
            || symbolPalette != nil
            || symbolWeight != nil
            || symbolGradient != nil
            || foregroundShadow != nil
    }
}

// MARK: - Main Command

// The resolved-source value types (`ForegroundValue`, `IconBackgroundValue`,
// `BadgeBackgroundValue`) live in Services/SettingsTokens.swift, shared with
// the configuration codec so both interpret `symbol:` prefixes and background
// keywords with the same code.

struct GenerateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate customized macOS app icons using SF Symbols",
        usage: """
            mica-cli [generate] <symbol-name> [<options>]
            mica-cli star.fill -o ~/Desktop/my-icon.png
            mica-cli generate folder.fill --size 512 --icon-bg-color red
            mica-cli --config icon.json [<options>]
            """,
        discussion: """
            EXAMPLES (the `generate` subcommand name is optional — it is the default):

            Basic usage:
              mica-cli star.fill
              mica-cli folder.fill -o ~/Desktop/folder-icon.png

            Symbol color and rendering:
              mica-cli shield.fill --icon-symbol-rendering hierarchical --icon-symbol-color white
              mica-cli gear --icon-symbol-rendering palette --icon-symbol-palette "blue,white:0.5,white:0.26"

            Symbol adjustments:
              mica-cli star.fill --icon-symbol-weight bold --icon-fg-scale 1.3
              mica-cli star.fill --icon-symbol-gradient on --icon-fg-shadow off

            Backgrounds:
              mica-cli star.fill --icon-bg-color red --icon-bg-gradient on
              mica-cli star.fill --icon-bg custom-gradient --icon-bg-gradient-colors "#FF6B35,#F7931E"
              mica-cli star.fill --icon-bg prerendered-liquid-glass --icon-bg-color blue
              mica-cli star.fill --icon-bg ~/bg.png --icon-bg-scale 0.9

            System (Apple) generation mode:
              mica-cli star.fill --icon-generation-mode system \\
                --icon-bg-color blue --icon-symbol-color white

            Imported image foreground:
              mica-cli --icon-fg ~/my-icon.png --icon-fg-scale 0.9

            Badges (supplying --badge-fg turns the badge on):
              mica-cli star.fill --badge-fg symbol:plus.circle.fill --badge-position bottom-right
              mica-cli folder.fill --badge-fg symbol:gearshape.fill \\
                --badge-bg custom-gradient --badge-bg-gradient-colors "red,orange"
              mica-cli star.fill --badge-fg ~/overlay.png --badge-scale 1.2 --badge-offset-x 0.1
              # attach a negative offset with =, or -0.15 is read as another flag
              mica-cli star.fill --badge-fg symbol:plus --badge-offset-y=-0.15

            High-resolution export:
              mica-cli app.fill --size 1024 --scale 2x --color-space displayP3

            Output modes:
              mica-cli star.fill --json            # JSON result to stdout
              mica-cli star.fill --quiet           # only the path on stdout
              mica-cli star.fill --verbose         # per-phase progress on stderr

            Configuration files (what Mica.app's Export Configuration writes):
              mica-cli --config icon.json
              mica-cli --config icon.json --size 1024   # the flag wins

            CONFIG FORMAT — a flat JSON object whose keys are the long flag names
            above, without the leading '--':

              {
                "icon-fg": "symbol:star.fill",
                "icon-bg-color": "blue",
                "icon-symbol-palette": ["blue", "white:0.5", "white:0.26"],
                "size": 512
              }

            An on|off option takes true/false or "on"/"off"; a numeric one takes a
            number or a numeric string. The four options taking several colors at
            once also take a JSON array, which is the only way to pass a color
            containing a comma (the space-prefixed forms below). Image slots are
            paths, and a relative one resolves against the JSON file's own
            directory.

            The positional symbol name has no key — write "icon-fg":
            "symbol:NAME". Nor do --output/-o, --json, --quiet and --verbose: they
            describe an invocation rather than an icon, so they stay on the command
            line. An unknown key or an unusable value is a warning on stderr and
            the rest of the file still loads; only malformed JSON stops the run.

            Every flag is optional with --config, and an absent one leaves the
            configuration's value alone. The output file is named after the
            configuration unless a symbol name, --icon-fg or -o says otherwise.

            COLOR FORMATS — every option taking a color accepts all of these:
              blue, system.blue, label        named and system tokens
              "#0088FF", "#0088FFCC"         hex, 3/6/8 digits
              "rgb(0,136,255)"               rgb() takes 0-255, hsl() degrees
              "hsl(209,100%,50%)"            and percentages; a 4th value in
                                             either one is the alpha
              srgb:0,0.53,1                  components in a named space, 0-1,
              display-p3:0,0.5,1             with the alpha optional
              extended-srgb:0,0.53333,1,1    a configuration's stored form, so a
              extended-gray:1,1              colour can be copied from a config
                                             file onto the command line

            All but the space-prefixed forms may carry a ':opacity' suffix —
            white:0.5, "#0088FF:0.5", "rgb(0,136,255):0.5". The prefixed forms
            already end in an alpha component, so they take no suffix. The suffix
            scales the colour's own alpha rather than replacing it, so 'label:0.5'
            is ~42% (labelColor is only ~85% opaque to begin with), while
            'white:0.5' is 50%.

            In system mode a bare token keeps Apple's curated rendering, so 'white'
            and 'white:0.5' differ: the second is a custom colour. Two limits there,
            both refused rather than quietly changed — the pipeline cannot show a
            colour outside sRGB, and it ignores a *background* colour's opacity, so
            --icon-bg-color and --badge-bg-color take no ':opacity' suffix in system
            mode. The symbol colours do.

            srgb: and display-p3: name bounded spaces, so a component outside 0-1
            is an error rather than a silent clamp. The extended- forms are
            unbounded, which is how a wide-gamut colour is carried: Display P3 red
            is extended-srgb:1.09300,-0.22670,-0.15010,1.00000, and
            display-p3:1,0,0 is the readable way to write the same colour.

            Not accepted, deliberately. Each of these was a second way to say
            something already sayable, and two of them guessed:
              "0,136,255"        bare components read as 0-1 unless one exceeded
                                 1 and then as 0-255, so 1,1,1 was white and
                                 2,2,2 dark gray — write srgb:0,0.53,1
              crimson, khaki,    18 names in no other part of Mica — use hex
              orchid, gold, …
              "rgb(50%,20%,0%)"  percentages in rgb() — use srgb:0.5,0.2,0
              "0.5" or "128"     a lone number for gray — use srgb:0.5,0.5,0.5
              systemblue         missing its dot — use system.blue
              "rgba(…)"/"hsla(…)"  put the alpha in rgb()/hsl() instead

            The options taking several colors at once — --icon-bg-gradient-colors,
            --badge-bg-gradient-colors, --icon-symbol-palette and
            --badge-symbol-palette — split their value on commas, so only the
            comma-free forms above work there: a name, hex, or either with an
            opacity suffix. Neither srgb: nor the extended- forms can be used
            inside them. That is why the default palette reads
            'white,white:0.5,white:0.26'.

            The output file path is written to stdout; diagnostics go to stderr,
            so `mica-cli star.fill -o icon.png` pipes cleanly.
            """
    )

    // Optional: the positional name is shorthand for `--icon-fg symbol:<name>`.
    // Either the positional name or an explicit `--icon-fg` must be supplied.
    @Argument(
        help: ArgumentHelp(
            "The SF Symbol name to render (shorthand for --icon-fg symbol:<name>)",
            discussion: "Use any valid SF Symbol name (e.g., 'star.fill', 'folder.badge.plus'). Optional when --icon-fg is given; --icon-fg wins if both are present.",
            valueName: "symbol-name"
        )
    )
    var symbolName: String?

    // Deliberately not in an OptionGroup: every other flag *is* a setting, while
    // this one says where the settings come from. It is also the reason all of
    // them are Optional — a flag has to be able to read as "not passed" so that a
    // configuration's value survives it.
    @Option(
        name: .customLong("config"),
        help: ArgumentHelp(
            "Start from a JSON configuration file; any flag given overrides it",
            discussion: "Keys are the long flag names without their leading '--'. See CONFIG FORMAT in `mica-cli generate --help`. With --config the positional symbol name is optional.",
            valueName: "path"
        )
    )
    var configPath: String?

    @OptionGroup(title: "Generation")
    var generation: GenerationOptions
    
    @OptionGroup(title: "Icon Foreground")
    var iconForeground: IconForegroundOptions

    @OptionGroup(title: "Background")
    var background: IconBackgroundOptions

    @OptionGroup(title: "Badge")
    var badge: BadgeOptions

    @OptionGroup(title: "Group Visibility")
    var groupVisibility: GroupVisibilityOptions

    @OptionGroup(title: "Export")
    var export: ExportOptions

    @OptionGroup(title: "Output")
    var output: OutputOptions

    // MARK: - Foreground Resolution

    /// Resolve the icon foreground. An explicit `--icon-fg` wins over the
    /// positional symbol-name shorthand. A `symbol:` prefix selects an SF
    /// Symbol; any other value is treated as an image file path.
    func resolvedForeground() throws -> ForegroundValue {
        let raw: String
        if let foreground = iconForeground.foreground {
            raw = foreground
        } else if let symbolName {
            raw = "symbol:\(symbolName)"
        } else {
            throw ValidationError("Provide an icon foreground: a positional SF Symbol name, or --icon-fg <symbol:NAME|path>.")
        }

        guard let value = ForegroundValue(parsing: raw) else {
            throw ValidationError("--icon-fg 'symbol:' requires a symbol name, e.g. symbol:star.fill")
        }
        return value
    }

    /// The icon foreground the command *supplied*, or `nil` when neither the
    /// positional name nor `--icon-fg` was given.
    ///
    /// A flags-only `generate` requires a foreground, so it goes through
    /// `resolvedForeground()` and lets the throw stand. `--config` does not: the
    /// configuration already carries one, and an absent flag there means "keep it"
    /// rather than "error". Only the settings builder uses this — validation still
    /// uses the throwing form, which is what preserves the "provide an icon
    /// foreground" error.
    func providedForeground() throws -> ForegroundValue? {
        guard iconForeground.foreground != nil || symbolName != nil else { return nil }
        return try resolvedForeground()
    }

    /// Resolve the icon background from `--icon-bg`. Recognised keywords select a
    /// generated background; any other value is treated as an image file path.
    func resolvedBackground() -> IconBackgroundValue {
        // Absent means the default generated background, not an image path.
        guard let selection = background.selection else { return .standard }
        return IconBackgroundValue(parsing: selection)
    }

    // MARK: - Badge Resolution

    /// True when an argument asked for a badge.
    ///
    /// **Three arguments activate the badge and nothing else does**: `--badge-fg`
    /// and `--badge-bg`, which name what the badge *is*, and `--badge-visibility on`,
    /// which asks for one directly. Everything else in the namespace — position,
    /// scale, offsets, every `--badge-symbol-*`, every `--badge-bg-*` appearance key,
    /// both layer visibility flags and `--badge-generation-mode` — says how a badge
    /// looks or where it sits, not that there should be one, and stays
    /// inert-and-warn.
    ///
    /// `--badge-visibility off` is not in the set by construction, because only `on`
    /// counts — a key that switches something off must never be what switches it on.
    /// It does **not** veto the other two: activation and visibility are separate
    /// steps, so `--badge-fg symbol:x --badge-visibility off` activates a badge whose
    /// layers then start hidden, and `--badge-fg-visibility on` can still reveal one.
    /// Vetoing here instead would break the precedence rule the icon obeys, where
    /// `--icon-visibility off --icon-fg-visibility on` is a visible foreground on a
    /// hidden background.
    ///
    /// This is *not* `MicaConfigKey.isBadgeKey`. That predicate is the namespace,
    /// and promoting it to the activation rule is the mistake to avoid — it would
    /// make `--badge-position bottom-left` conjure a default gearshape nobody named.
    /// See §3 of docs/plans/visibility-activation-and-imported-backgrounds.md.
    var badgeIsActive: Bool {
        badge.foreground != nil
            || badge.background != nil
            || groupVisibility.badge?.isOn == true
    }

    /// True when the badge is active *at all*: an argument asked for one, or the
    /// configuration already carries a visible one. This is the form every
    /// badge-flag decision wants — gating on the flags alone would leave a
    /// configuration's badge unvalidated and unmentioned.
    ///
    /// An explicit `--badge-visibility off` wins over **the base**, which is the only
    /// way to turn off a badge a `--config` file supplied. Without that clause the
    /// flag would work on a bare invocation and quietly fail with `--config` — the
    /// one case it exists for. It does not override a flag that asked for a badge;
    /// see `badgeIsActive`.
    func badgeIsActive(in context: GenerationContext) -> Bool {
        if badgeIsActive { return true }
        if groupVisibility.badge?.isOn == false { return false }
        return context.base?.badge.isVisible == true
    }

    /// Resolve the badge foreground. Returns `nil` when `--badge-fg` is absent
    /// (the badge is inactive). A `symbol:` prefix selects an SF Symbol; any
    /// other value is treated as an image file path.
    func resolvedBadgeForeground() throws -> ForegroundValue? {
        guard let raw = badge.foreground else { return nil }
        guard let value = ForegroundValue(parsing: raw) else {
            throw ValidationError("--badge-fg 'symbol:' requires a symbol name, e.g. symbol:plus.circle")
        }
        return value
    }

    /// Resolve the badge background from `--badge-bg`. Recognised keywords select
    /// a generated background; any other value is treated as an image file path.
    func resolvedBadgeBackground() -> BadgeBackgroundValue {
        // Absent means the default generated background, not an image path.
        guard let background = badge.background else { return .standard }
        return BadgeBackgroundValue(parsing: background)
    }

    // The four System-mode colours resolve the same way: the flag when passed,
    // otherwise the configuration's — whose own defaults are the `white` symbol /
    // `blue` enclosure the CLI has always used, so a flags-only `generate` lands
    // on exactly the values the old `?? "blue"` literals produced.

    /// Icon appex enclosure colour (system icon mode), from `--icon-bg-color`.
    func resolvedIconAppexEnclosureColor(in context: GenerationContext) throws -> AppexPlistColor {
        guard let raw = background.color else {
            return try AppexPlistColor(projecting: context.appexColors.iconEnclosure, role: .enclosure)
        }
        return try resolveAppexColorArg(raw, role: "--icon-bg-color", key: .enclosure)
    }

    /// Icon appex symbol colour (system icon mode), from `--icon-symbol-color`.
    func resolvedIconAppexSymbolColor(in context: GenerationContext) throws -> AppexPlistColor {
        guard let raw = iconForeground.symbolColor else {
            return try AppexPlistColor(projecting: context.appexColors.iconSymbol, role: .symbol)
        }
        return try resolveAppexColorArg(raw, role: "--icon-symbol-color", key: .symbol)
    }

    /// Badge appex enclosure colour (system badge mode), from `--badge-bg-color`.
    func resolvedBadgeAppexEnclosureColor(in context: GenerationContext) throws -> AppexPlistColor {
        guard let raw = badge.backgroundColor else {
            return try AppexPlistColor(projecting: context.appexColors.badgeEnclosure, role: .enclosure)
        }
        return try resolveAppexColorArg(raw, role: "--badge-bg-color", key: .enclosure)
    }

    /// Badge appex symbol colour (system badge mode), from `--badge-symbol-color`.
    func resolvedBadgeAppexSymbolColor(in context: GenerationContext) throws -> AppexPlistColor {
        guard let raw = badge.symbolColor else {
            return try AppexPlistColor(projecting: context.appexColors.badgeSymbol, role: .symbol)
        }
        return try resolveAppexColorArg(raw, role: "--badge-symbol-color", key: .symbol)
    }

    /// Default output basename (no extension) derived from the resolved
    /// foreground: the symbol name, or the image file's basename.
    func defaultOutputBasename() -> String {
        switch try? resolvedForeground() {
        case .symbol(let name):
            return name
        case .image(let path):
            return Self.basename(ofPath: path)
        case .none:
            // No foreground at all is legal for imported artwork, which is then the
            // only thing naming the icon — the same courtesy a foreground image gets.
            if let symbolName { return symbolName }
            if case .image(let path) = resolvedBackground() { return Self.basename(ofPath: path) }
            return "icon"
        }
    }

    private static func basename(ofPath path: String) -> String {
        ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    }

    /// Default output basename accounting for `--config`: with no foreground on
    /// the command line there is no symbol or image to name the file after, so the
    /// configuration's own filename stands in — `icon.json` renders `icon.png`.
    func defaultOutputBasename(in context: GenerationContext) -> String {
        if iconForeground.foreground == nil, symbolName == nil, let configBasename = context.outputBasename {
            return configBasename
        }
        return defaultOutputBasename()
    }

    // MARK: - Command Execution

    func run() async throws {
        let reporter = output.reporter

        // The configuration loads *before* validation, not after: it decides
        // whether an icon foreground is required on the command line at all, and
        // which generation mode the colour flags are validated against.
        let context: GenerationContext
        do {
            context = try GenerationContext.load(configPath: configPath)
        } catch let error as CLIError {
            try reportFailure(reporter, kind: error.kind, message: error.localizedDescription, exit: .failure)
        }

        // Printed before any work, and in every output mode — see
        // `OutputReporter.warning`.
        for warning in context.warnings {
            reporter.warning("Warning: \(warning.key): \(warning.message)")
        }

        try performValidation(in: context)

        let generator = IconGenerationRunner()

        do {
            let result = try await generator.generateIcon(from: self, context: context, reporter: reporter)

            // stdout = the machine result; stderr = a concise human summary.
            reporter.path(result.path)
            var summary = "Generated \(result.width)×\(result.height) icon (\(humanByteCount(result.bytes)))"
            if context.effectiveIconMode(generation.iconGenerationMode) == .system {
                summary += " in system mode"
            }
            if badgeIsActive(in: context) {
                summary += "; badge included"
            }
            reporter.status(summary)

            if output.json {
                print(encodeJSON(CommandResultJSON(command: "generate", outputs: [result])))
            }
        } catch let error as ColorParseError {
            try reportFailure(reporter, kind: "color", message: error.localizedDescription, exit: .validationFailure)
        } catch let error as CLIError {
            try reportFailure(reporter, kind: error.kind, message: error.localizedDescription, exit: .failure)
        } catch {
            try reportFailure(reporter, kind: "unexpected", message: error.localizedDescription, exit: .failure)
        }
    }

    /// Emit a failure (human text to stderr, or a JSON error object to stdout)
    /// and throw the corresponding exit code. Never returns normally.
    private func reportFailure(_ reporter: OutputReporter, kind: String, message: String, exit code: ExitCode) throws -> Never {
        if output.json {
            print(encodeJSON(CommandErrorJSON(command: "generate", kind: kind, message: message)))
        } else {
            reporter.failure("Error: \(message)")
        }
        throw code
    }

    // MARK: - Testing Support

    /// Expose the private validation chain for unit tests. Mirrors the
    /// `IconGenerationRunner.buildTestSettings(from:)` pattern. The no-argument
    /// form is a flags-only `generate`; pass a context to test `--config`.
    func performValidationForTesting(in context: GenerationContext = .none) throws {
        try performValidation(in: context)
    }

    // MARK: - Validation
    //
    // Every check that can be answered by a configuration takes the context rather
    // than the flags alone. Three of them change answer: a foreground is only
    // compulsory without one, gradient colours are only compulsory without one,
    // and the generation modes — which decide how a colour string is read — come
    // from the configuration when no flag overrides them.

    private func performValidation(in context: GenerationContext) throws {
        // Ahead of everything: these two decide whether the group's foreground can
        // be read at all, so a conflict must be reported as a conflict rather than
        // as whatever the merged value then fails to be.
        try iconForeground.validateFlags()
        try badge.validateFlags()

        try validateForeground(in: context)
        try validateColorDependencies(in: context)
        try validateBadgeDependencies(in: context)
        try validateImagePaths()
        try validateOutputPath()
        try validateColorFormats(in: context)
    }

    /// True when the icon's background is imported artwork, which is the one case
    /// that excuses a missing foreground — see `validateForeground`.
    private var iconBackgroundIsImage: Bool {
        if case .image = resolvedBackground() { return true }
        return false
    }

    private func validateForeground(in context: GenerationContext) throws {
        // Without a configuration the throwing form runs, and its throw is what
        // produces the "provide an icon foreground" error. With one, an absent
        // flag means "keep the configuration's", so only what was passed is checked.
        //
        // Imported artwork is the third case, and it is not a relaxation for its own
        // sake: the foreground rule *hides* the foreground over an imported
        // background unless one was asked for, so demanding one here would require
        // naming a symbol solely to have it hidden. Every other background still
        // requires a foreground, or `--icon-bg-color blue` alone would quietly
        // render whatever `ForegroundSpec.iconDefault` happens to name.
        let foreground: ForegroundValue?
        if context.base == nil, !iconBackgroundIsImage {
            foreground = try resolvedForeground()
        } else {
            foreground = try providedForeground()
        }

        if case .symbol(let name)? = foreground {
            guard name.allSatisfy({ $0.isLetter || $0.isNumber || ".-_".contains($0) }) else {
                throw ValidationError("Symbol name contains invalid characters. Use only letters, numbers, dots, dashes, and underscores.")
            }
        }
    }

    private func validateColorDependencies(in context: GenerationContext) throws {
        // Only a flags-only `generate` has to be given the gradient colours: a
        // configuration already carries a pair, so `--icon-bg custom-gradient`
        // alone legitimately means "use those".
        if context.base == nil, case .customGradient = resolvedBackground(), background.gradientColors == nil {
            throw ValidationError("--icon-bg custom-gradient requires --icon-bg-gradient-colors <c1,c2>.")
        }
        if iconForeground.symbolRendering == "palette", let palette = iconForeground.symbolPalette {
            // Validate the count up front; format is checked in validateColorFormats.
            _ = try splitPalette(palette, role: "--icon-symbol-palette")
        }
    }

    private func validateBadgeDependencies(in context: GenerationContext) throws {
        // Resolves and surfaces any empty-symbol error; nil → badge inactive.
        guard let badgeForeground = try resolvedBadgeForeground() else {
            // A configuration's badge still takes flags, so its dependencies are
            // checked too — minus the foreground ones, which it already satisfies.
            if context.base?.badge.isVisible == true {
                try validateBadgeBackgroundDependencies(in: context)
            }
            return
        }

        if case .symbol(let name) = badgeForeground {
            guard name.allSatisfy({ $0.isLetter || $0.isNumber || ".-_".contains($0) }) else {
                throw ValidationError("Badge symbol name contains invalid characters. Use only letters, numbers, dots, dashes, and underscores.")
            }
        }

        // System badge mode renders via the appex pipeline, which needs an SF Symbol.
        if context.effectiveBadgeMode(generation.badgeGenerationMode) == .system, case .image = badgeForeground {
            throw ValidationError("--badge-generation-mode system requires an SF Symbol badge foreground (--badge-fg symbol:NAME); image foregrounds are only supported in mica mode.")
        }

        try validateBadgeBackgroundDependencies(in: context)
    }

    /// The badge dependencies that hold whether the badge came from `--badge-fg`
    /// or from a configuration.
    private func validateBadgeBackgroundDependencies(in context: GenerationContext) throws {
        // As with the icon: a configuration already carries a gradient pair.
        if context.base == nil, case .customGradient = resolvedBadgeBackground(), badge.backgroundGradientColors == nil {
            throw ValidationError("--badge-bg custom-gradient requires --badge-bg-gradient-colors <c1,c2>.")
        }

        if badge.symbolRendering == "palette", let palette = badge.symbolPalette {
            // Validate the count up front; format is checked in validateColorFormats.
            _ = try splitPalette(palette, role: "--badge-symbol-palette")
        }
    }

    private func validateImagePaths() throws {
        // An image foreground (`--icon-fg <path>`) must point at an existing file.
        // The *provided* form: with --config there may be no foreground flag at
        // all, and a configuration's own images are the codec's to report on.
        var foregroundImagePath: String?
        if case .image(let path)? = try providedForeground() {
            foregroundImagePath = path
        }

        // An image background (`--icon-bg <path>`) must point at an existing file.
        var backgroundImagePath: String?
        if case .image(let path) = resolvedBackground() {
            backgroundImagePath = path
        }

        // Badge image foreground/background (only when the badge is active).
        var badgeForegroundImagePath: String?
        if case .image(let path)? = try resolvedBadgeForeground() {
            badgeForegroundImagePath = path
        }
        var badgeBackgroundImagePath: String?
        if badgeIsActive, case .image(let path) = resolvedBadgeBackground() {
            badgeBackgroundImagePath = path
        }

        let paths: [(String?, String)] = [
            (foregroundImagePath, "--icon-fg"),
            (backgroundImagePath, "--icon-bg"),
            (badgeForegroundImagePath, "--badge-fg"),
            (badgeBackgroundImagePath, "--badge-bg"),
        ]
        for (path, name) in paths {
            guard let path = path else { continue }
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ValidationError("File not found for \(name): \(path)")
            }
        }
    }

    private func validateOutputPath() throws {
        if let path = export.outputPath {
            // Expand ~ like the generator's resolveOutputPath does — otherwise
            // this creates a literal ./~ parent directory at validation time.
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let parentDir = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                do {
                    try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                } catch {
                    throw ValidationError("Cannot create output directory: \(parentDir.path)")
                }
            }
        }
    }

    private func validateColorFormats(in context: GenerationContext) throws {
        let isSystemIcon = context.effectiveIconMode(generation.iconGenerationMode) == .system

        // The merged icon symbol color resolves differently by generation mode:
        // mica → ColorParser; system → appex color tokens. Validate accordingly.
        if let symbolColor = iconForeground.symbolColor {
            if isSystemIcon {
                _ = try resolveAppexColorArg(symbolColor, role: "--icon-symbol-color", key: .symbol)
            } else {
                do {
                    _ = try ColorParser.parseWithOpacity(symbolColor)
                } catch {
                    throw ValidationError("Invalid color format for --icon-symbol-color: '\(symbolColor)'. \(error.localizedDescription)")
                }
            }
        }

        // Palette colours (mica only). All three slots take the same forms,
        // including a `:opacity` suffix — the primary used to reject one for no
        // reason the GUI shares.
        if let palette = iconForeground.symbolPalette {
            for part in try splitPalette(palette, role: "--icon-symbol-palette") {
                do {
                    _ = try ColorParser.parseWithOpacity(part)
                } catch {
                    throw ValidationError("Invalid color format in --icon-symbol-palette ('\(part)'). \(error.localizedDescription)")
                }
            }
        }

        // Merged --icon-bg-color (folds base / appex-enclosure). Resolves by
        // generation mode + background kind.
        if let bgColor = background.color {
            if isSystemIcon {
                _ = try resolveAppexColorArg(bgColor, role: "--icon-bg-color", key: .enclosure)
            } else if case .preRendered = resolvedBackground() {
                guard validPreRenderedColors.contains(normalizeBritishSpelling(bgColor)) else {
                    throw ValidationError("--icon-bg-color for prerendered-liquid-glass must be one of: \(validPreRenderedColors.joined(separator: ", ")). You provided '\(bgColor)'.")
                }
            } else {
                do {
                    _ = try ColorParser.parseWithOpacity(bgColor)
                } catch {
                    throw ValidationError("Invalid color format for --icon-bg-color: '\(bgColor)'. \(error.localizedDescription)")
                }
            }
        }

        // --icon-bg-gradient-colors (custom-gradient): exactly two colours.
        if let gradientColors = background.gradientColors {
            for part in try splitGradientColors(gradientColors) {
                do {
                    _ = try ColorParser.parseWithOpacity(part)
                } catch {
                    throw ValidationError("Invalid color in --icon-bg-gradient-colors ('\(part)'). \(error.localizedDescription)")
                }
            }
        }

        // Badge colours (only when the badge is active), mode-aware. The merged
        // --badge-symbol-color / --badge-bg-color resolve differently per mode:
        // mica → ColorParser; system → appex colour tokens.
        if badgeIsActive(in: context) {
            let isSystemBadge = context.effectiveBadgeMode(generation.badgeGenerationMode) == .system

            if let badgeSymbolColor = badge.symbolColor {
                if isSystemBadge {
                    _ = try resolveAppexColorArg(badgeSymbolColor, role: "--badge-symbol-color", key: .symbol)
                } else {
                    do {
                        _ = try ColorParser.parseWithOpacity(badgeSymbolColor)
                    } catch {
                        throw ValidationError("Invalid color format for --badge-symbol-color: '\(badgeSymbolColor)'. \(error.localizedDescription)")
                    }
                }
            }

            // Badge palette (mica only). All three slots take the same forms.
            if let badgePalette = badge.symbolPalette {
                for part in try splitPalette(badgePalette, role: "--badge-symbol-palette") {
                    do {
                        _ = try ColorParser.parseWithOpacity(part)
                    } catch {
                        throw ValidationError("Invalid color format in --badge-symbol-palette ('\(part)'). \(error.localizedDescription)")
                    }
                }
            }

            if let badgeBgColor = badge.backgroundColor {
                if isSystemBadge {
                    _ = try resolveAppexColorArg(badgeBgColor, role: "--badge-bg-color", key: .enclosure)
                } else {
                    do {
                        _ = try ColorParser.parseWithOpacity(badgeBgColor)
                    } catch {
                        throw ValidationError("Invalid color format for --badge-bg-color: '\(badgeBgColor)'. \(error.localizedDescription)")
                    }
                }
            }

            // --badge-bg-gradient-colors (custom-gradient): exactly two colours.
            if let badgeGradientColors = badge.backgroundGradientColors {
                for part in try splitGradientColors(badgeGradientColors, role: "--badge-bg-gradient-colors") {
                    do {
                        _ = try ColorParser.parseWithOpacity(part)
                    } catch {
                        throw ValidationError("Invalid color in --badge-bg-gradient-colors ('\(part)'). \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

/// Split a gradient-colors value into exactly two component strings.
/// Throws a `ValidationError` if the count isn't two or any part is empty.
/// The splitting itself is `splitColorList`, shared with the configuration codec.
func splitGradientColors(_ raw: String, role: String = "--icon-bg-gradient-colors") throws -> [String] {
    switch splitColorList(raw, expecting: 2) {
    case .ok(let parts):
        return parts
    case .wrongCount(let count):
        throw ValidationError("\(role) requires exactly two comma-separated colors 'c1,c2'. You provided \(count).")
    case .emptyComponent:
        throw ValidationError("\(role) colors cannot be empty. Use 'c1,c2'.")
    }
}

/// Split a `--icon-symbol-palette` value into exactly three component strings.
/// Throws a `ValidationError` if the count isn't three or any part is empty.
/// The splitting itself is `splitColorList`, shared with the configuration codec.
func splitPalette(_ raw: String, role: String) throws -> [String] {
    switch splitColorList(raw, expecting: 3) {
    case .ok(let parts):
        return parts
    case .wrongCount(let count):
        throw ValidationError("\(role) requires exactly three comma-separated colors 'c1,c2,c3'. You provided \(count).")
    case .emptyComponent:
        throw ValidationError("\(role) colors cannot be empty. Use 'c1,c2,c3'.")
    }
}
