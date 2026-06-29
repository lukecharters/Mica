import ArgumentParser
import Foundation

// MARK: - Shared Validation Helpers

private let validRenderingModes = ["monochrome", "hierarchical", "multicolor", "palette"]
private let validSymbolWeights = ["auto", "ultralight", "thin", "light", "regular", "medium", "semibold", "bold", "heavy", "black"]
private let validAppexColors = ["black", "blue", "brown", "cyan", "gray", "green", "indigo", "orange", "pink", "purple", "red", "teal", "white", "yellow"]

/// Resolve an appex colour argument to the plist value stored on the command.
/// Accepts a named token, an `r,g,b,a` value (0–1 or 0–255), or a hex colour.
/// Throws a `ValidationError` (nicely surfaced by ArgumentParser) on failure.
private func resolveAppexColorArg(_ input: String, role: String) throws -> String {
    do {
        return try AppexColor.plistValue(fromCLIString: input)
    } catch {
        throw ValidationError("\(role) is invalid: '\(input)'. Use a named color (\(validAppexColors.joined(separator: ", "))), an r,g,b,a value (0–1, e.g. 1,0.0902,0.2118,1), or a hex color (e.g. #FF1736).")
    }
}

private func validateScale(_ scale: String, name: String) throws -> Double {
    guard let value = Double(scale) else {
        throw ValidationError("\(name) must be a number.")
    }
    guard IconSettings.manualSymbolScaleRange.contains(value) else {
        throw ValidationError("\(name) must be between 0.3 and 2.0. You provided: \(scale)")
    }
    return value
}

private func validateOffset(_ offset: String, name: String) throws -> Double {
    guard let value = Double(offset) else {
        throw ValidationError("\(name) must be a number.")
    }
    guard IconSettings.badgeOffsetRange.contains(value) else {
        throw ValidationError("\(name) must be between -1.0 and 1.0. You provided: \(offset)")
    }
    return value
}

// MARK: - Export Options

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
            "Export size in pixels (16-1024)",
            discussion: "Common sizes: 128, 256, 512, 1024.",
            valueName: "pixels"
        ),
        transform: { size in
            guard let intSize = Int(size) else {
                throw ValidationError("Size must be a whole number (no decimals).")
            }
            let minSize = Int(IconSettings.minExportSize)
            let maxSize = Int(IconSettings.maxExportSize)
            guard (minSize...maxSize).contains(intSize) else {
                throw ValidationError("Size must be between \(minSize) and \(maxSize) pixels. You provided: \(intSize)")
            }
            return intSize
        }
    )
    var size: Int = 512

    @Flag(name: .long, help: "Export at 2x resolution (doubles pixel dimensions)")
    var retina: Bool = false

    @Option(
        name: .long,
        help: ArgumentHelp("Color space: sRGB (default) or displayP3", valueName: "space"),
        transform: { space in
            guard ["sRGB", "displayP3"].contains(space) else {
                throw ValidationError("Color space must be 'sRGB' or 'displayP3'")
            }
            return space
        }
    )
    var colorSpace: String = "sRGB"
}

// MARK: - Generation Options

struct GenerationOptions: ParsableArguments {
    // Generation mode is taken in user-facing `mica`/`system` terms and stored
    // canonically as `custom`/`apple-reference` so the downstream settings
    // builder (which switches on `apple-reference`) stays unchanged.
    @Option(
        name: .customLong("icon-generation-mode"),
        help: ArgumentHelp(
            "How the icon is rendered: mica (SwiftUI, default) or system (Apple appex rendering)",
            valueName: "mica|system"
        ),
        transform: { try canonicalGenerationMode($0, role: "Icon") }
    )
    var iconGenerationMode: String = "custom"

    @Option(
        name: .customLong("badge-generation-mode"),
        help: ArgumentHelp(
            "How the badge is rendered: mica (SwiftUI, default) or system (Apple appex rendering)",
            valueName: "mica|system"
        ),
        transform: { try canonicalGenerationMode($0, role: "Badge") }
    )
    var badgeGenerationMode: String = "custom"

    /// Canonical icon mode (`custom` / `apple-reference`).
    var resolvedIconMode: String { iconGenerationMode }

    /// Canonical badge mode (`custom` / `apple-reference`).
    var resolvedBadgeMode: String { badgeGenerationMode }

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Appex enclosure (background) color for system generation mode",
            discussion: "A named color (\(validAppexColors.joined(separator: ", "))), an r,g,b,a value (0–1, e.g. 1,0.0902,0.2118,1), or a hex color (e.g. #FF1736)",
            valueName: "color"
        ),
        transform: { try resolveAppexColorArg($0, role: "Appex enclosure color") }
    )
    var appexEnclosureColor: String = "blue"
}

/// Map the user-facing `mica`/`system` generation-mode tokens to the canonical
/// `custom`/`apple-reference` values used throughout the settings builder.
private func canonicalGenerationMode(_ mode: String, role: String) throws -> String {
    switch mode.lowercased() {
    case "mica": return "custom"
    case "system": return "apple-reference"
    default:
        throw ValidationError("\(role) generation mode must be 'mica' or 'system'.")
    }
}

// MARK: - Background Options

struct BackgroundOptions: ParsableArguments {
    @Option(
        name: .long,
        help: ArgumentHelp(
            "Background mode",
            discussion: "Options: custom (color/gradient, default), image (imported file)",
            valueName: "mode"
        ),
        transform: { mode in
            let valid = ["custom", "image"]
            guard valid.contains(mode.lowercased()) else {
                throw ValidationError("Background mode must be one of: \(valid.joined(separator: ", "))")
            }
            return mode.lowercased()
        }
    )
    var backgroundMode: String = "custom"

    @Option(name: .long, help: ArgumentHelp("Base gradient color", valueName: "color"))
    var baseColor: String = "blue"

    @Flag(name: .long, help: "Enable custom gradient colors (use with --custom-primary/--custom-secondary)")
    var useCustomColors: Bool = false

    @Option(name: .long, help: ArgumentHelp("Primary (top) gradient color", valueName: "color"))
    var customPrimary: String?

    @Option(name: .long, help: ArgumentHelp("Secondary (bottom) gradient color", valueName: "color"))
    var customSecondary: String?

    @Flag(name: .long, help: "Disable background gradient (use flat color)")
    var noGradient: Bool = false

    @Option(
        name: .long,
        help: ArgumentHelp("Corner radius: macos11 or macos26 (default)", valueName: "style"),
        transform: { style in
            guard ["macos11", "macos26"].contains(style.lowercased()) else {
                throw ValidationError("Corner radius must be 'macos11' or 'macos26'")
            }
            return style.lowercased()
        }
    )
    var cornerRadius: String = "macos26"

    // Optional (nil = unspecified) so imported image backgrounds can default to
    // no shadow while still honouring an explicit `--background-shadow-style`.
    @Option(
        name: .long,
        help: ArgumentHelp("Background shadow: off, macos11, or macos26 (default: off for imported backgrounds, macos26 otherwise)", valueName: "style"),
        transform: { style in
            guard ["off", "macos11", "macos26"].contains(style.lowercased()) else {
                throw ValidationError("Background shadow style must be 'off', 'macos11', or 'macos26'")
            }
            return style.lowercased()
        }
    )
    var backgroundShadowStyle: String?

    @Flag(name: .long, help: .hidden) // deprecated alias for --background-shadow-style off
    var noBackgroundShadow: Bool = false

    @Option(name: .long, help: ArgumentHelp("Path to image file for background", valueName: "path"))
    var importedBackground: String?

    @Option(
        name: .long,
        help: ArgumentHelp("Scale for imported background (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Imported background scale") }
    )
    var importedBackgroundScale: Double = 1.0

    // Inverted optional: imported backgrounds fill the frame (compensation on) by
    // default; `--no-imported-background-padding-compensation` keeps the padding.
    @Flag(name: .long, inversion: .prefixedNo,
          help: "Padding compensation for imported app icon backgrounds (default: on — scales up to fill the frame)")
    var importedBackgroundPaddingCompensation: Bool?

    /// Resolved background shadow style. The deprecated `--no-background-shadow`
    /// wins; then an explicit `--background-shadow-style`; otherwise imported
    /// image backgrounds default to no shadow and everything else to macOS 26.
    var effectiveShadowStyle: String {
        if noBackgroundShadow { return "off" }
        if let explicit = backgroundShadowStyle { return explicit }
        return backgroundMode == "image" ? "off" : "macos26"
    }

    /// Resolved padding compensation for an imported background — on unless the
    /// user explicitly opted out.
    var effectivePaddingCompensation: Bool {
        importedBackgroundPaddingCompensation ?? true
    }
}

// MARK: - Icon Foreground Options

struct IconForegroundOptions: ParsableArguments {
    // Folds the old --icon-source + --imported-image. `symbol:<name>` selects an
    // SF Symbol; anything else is treated as an image file path. When omitted,
    // the positional symbol-name shorthand on the command supplies the value.
    @Option(
        name: .customLong("icon-fg"),
        help: ArgumentHelp(
            "Icon foreground source",
            discussion: "Either 'symbol:<name>' for an SF Symbol (e.g. symbol:star.fill) or a path to an image file. Overrides the positional symbol-name shorthand.",
            valueName: "symbol:NAME|path"
        )
    )
    var foreground: String?

    // Folds --symbol-scale + --imported-image-scale into one flag that drives
    // whichever source (symbol or image) is active.
    @Option(
        name: .customLong("icon-fg-scale"),
        help: ArgumentHelp("Foreground scale multiplier (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Icon foreground scale") }
    )
    var scale: Double = 1.0

    @Option(
        name: .customLong("icon-symbol-rendering"),
        help: ArgumentHelp(
            "Symbol rendering mode",
            discussion: "monochrome (default), hierarchical, multicolor, or palette",
            valueName: "mode"
        ),
        transform: { mode in
            guard validRenderingModes.contains(mode.lowercased()) else {
                throw ValidationError("Symbol rendering mode must be one of: \(validRenderingModes.joined(separator: ", "))")
            }
            return mode.lowercased()
        }
    )
    var symbolRendering: String = "monochrome"

    // Folds --symbol-color + --hierarchical-color + --appex-symbol-color into a
    // single colour. Stored RAW; resolved in the settings builder by generation
    // mode (mica → ColorParser, system → AppexColor.plistValue) since the
    // transform can't see the chosen mode. nil → mode-appropriate default.
    @Option(
        name: .customLong("icon-symbol-color"),
        help: ArgumentHelp(
            "Symbol color (monochrome, hierarchical, and multicolor modes)",
            discussion: "For mica mode: a named color, r,g,b(,a), or hex. For system mode: a named/r,g,b,a/hex appex color. Default: white.",
            valueName: "color"
        )
    )
    var symbolColor: String?

    // Folds --palette-primary/secondary/tertiary. Comma-separated `c1,c2,c3`;
    // c2/c3 accept a `:opacity` suffix. Validated/parsed in the builder.
    @Option(
        name: .customLong("icon-symbol-palette"),
        help: ArgumentHelp(
            "Palette colors for palette rendering",
            discussion: "Three comma-separated colors 'c1,c2,c3'; the 2nd and 3rd accept a ':opacity' suffix (e.g. 'blue,white:0.5,white:0.26'). Default: white,white:0.5,white:0.26.",
            valueName: "c1,c2,c3"
        )
    )
    var symbolPalette: String?

    @Option(
        name: .customLong("icon-symbol-weight"),
        help: ArgumentHelp("Symbol weight: auto, ultralight, thin, light, regular, medium, semibold, bold, heavy, black", valueName: "weight"),
        transform: { weight in
            guard validSymbolWeights.contains(weight.lowercased()) else {
                throw ValidationError("Symbol weight must be one of: \(validSymbolWeights.joined(separator: ", "))")
            }
            return weight.lowercased()
        }
    )
    var symbolWeight: String = "auto"

    // Was --symbol-color-rendering flat|gradient.
    @Option(
        name: .customLong("icon-symbol-gradient"),
        help: ArgumentHelp("Symbol gradient fill: on or off (default; gradient requires macOS 26+)", valueName: "on|off")
    )
    var symbolGradient: ToggleState = .off

    // nil = unspecified, so the effective value can default based on the source
    // (off for imported images, on for SF Symbols).
    @Option(
        name: .customLong("icon-fg-shadow"),
        help: ArgumentHelp("Foreground shadow: on or off (default: off for images, on for SF Symbols)", valueName: "on|off")
    )
    var shadow: ToggleState?

    @Option(
        name: .customLong("icon-fg-visibility"),
        help: ArgumentHelp("Foreground visibility: on (default) or off to hide the foreground", valueName: "on|off")
    )
    var visibility: ToggleState = .on
}

// MARK: - Badge Options

struct BadgeOptions: ParsableArguments {
    // Badge activation and position
    @Option(name: .long, help: ArgumentHelp("Add badge with SF Symbol", valueName: "symbol"))
    var badge: String?

    @Option(
        name: .long,
        help: ArgumentHelp("Badge position: top-left, top-right, bottom-left, bottom-right", valueName: "position"),
        transform: { pos in
            let valid = ["top-left", "top-right", "bottom-left", "bottom-right"]
            guard valid.contains(pos.lowercased()) else {
                throw ValidationError("Badge position must be one of: \(valid.joined(separator: ", "))")
            }
            return pos.lowercased()
        }
    )
    var badgePosition: String = "bottom-right"

    // Badge layout
    @Option(
        name: .long,
        help: ArgumentHelp("Overall badge scale (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Badge scale") }
    )
    var badgeScale: Double = 1.0

    @Option(
        name: .long,
        help: ArgumentHelp("Badge symbol scale within badge (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Badge symbol scale") }
    )
    var badgeSymbolScale: Double = 1.0

    @Option(
        name: .long,
        help: ArgumentHelp("Badge horizontal offset (-1.0 to 1.0)", valueName: "offset"),
        transform: { try validateOffset($0, name: "Badge offset X") }
    )
    var badgeOffsetX: Double = 0.0

    @Option(
        name: .long,
        help: ArgumentHelp("Badge vertical offset (-1.0 to 1.0)", valueName: "offset"),
        transform: { try validateOffset($0, name: "Badge offset Y") }
    )
    var badgeOffsetY: Double = 0.0

    // Badge background colors
    @Option(name: .long, help: ArgumentHelp("Badge base color", valueName: "color"))
    var badgeColor: String = "gray"

    @Flag(name: .long, help: "Enable custom badge gradient (use with --badge-primary/--badge-secondary)")
    var badgeUseCustom: Bool = false

    @Option(name: .long, help: ArgumentHelp("Badge primary (top) gradient color", valueName: "color"))
    var badgePrimary: String = "white"

    @Option(name: .long, help: ArgumentHelp("Badge secondary (bottom) gradient color", valueName: "color"))
    var badgeSecondary: String = "indigo"

    // Badge symbol rendering
    @Option(
        name: .long,
        help: ArgumentHelp("Badge rendering mode: monochrome, hierarchical, multicolor, palette", valueName: "mode"),
        transform: { mode in
            guard validRenderingModes.contains(mode.lowercased()) else {
                throw ValidationError("Badge rendering mode must be one of: \(validRenderingModes.joined(separator: ", "))")
            }
            return mode.lowercased()
        }
    )
    var badgeRendering: String = "monochrome"

    @Option(name: .long, help: ArgumentHelp("Badge symbol color (monochrome)", valueName: "color"))
    var badgeSymbolColor: String = "white"

    @Option(name: .long, help: ArgumentHelp("Badge symbol color (hierarchical)", valueName: "color"))
    var badgeHierarchicalColor: String = "white"

    @Option(name: .long, help: ArgumentHelp("Badge primary color (palette)", valueName: "color"))
    var badgePalettePrimary: String = "white"

    @Option(name: .long, help: ArgumentHelp("Badge secondary color (palette, supports opacity)", valueName: "color"))
    var badgePaletteSecondary: String = "white:0.5"

    @Option(name: .long, help: ArgumentHelp("Badge tertiary color (palette, supports opacity)", valueName: "color"))
    var badgePaletteTertiary: String = "white:0.26"

    @Option(
        name: .long,
        help: ArgumentHelp("Badge symbol weight", valueName: "weight"),
        transform: { weight in
            guard validSymbolWeights.contains(weight.lowercased()) else {
                throw ValidationError("Badge symbol weight must be one of: \(validSymbolWeights.joined(separator: ", "))")
            }
            return weight.lowercased()
        }
    )
    var badgeSymbolWeight: String = "auto"

    @Option(
        name: .long,
        help: ArgumentHelp("Badge symbol color rendering: flat or gradient", valueName: "mode"),
        transform: { mode in
            guard ["flat", "gradient"].contains(mode.lowercased()) else {
                throw ValidationError("Badge symbol color rendering must be 'flat' or 'gradient'")
            }
            return mode.lowercased()
        }
    )
    var badgeSymbolColorRendering: String = "flat"

    // Badge shadow/gradient toggles
    @Flag(name: .long, help: "Disable badge background gradient")
    var badgeNoGradient: Bool = false

    // Inverted optionals (nil = unspecified) so imported badge images default to
    // no shadow while `--badge-background-shadow` / `--badge-symbol-shadow` force
    // them back on. `--badge-no-…-shadow` forms are preserved.
    @Flag(name: .long, inversion: .prefixedNo,
          help: "Badge background shadow (default: off for imported badge backgrounds, on otherwise)")
    var badgeBackgroundShadow: Bool?

    @Flag(name: .long, inversion: .prefixedNo,
          help: "Badge symbol shadow (default: off for imported images, on for SF Symbols)")
    var badgeSymbolShadow: Bool?

    // Badge icon source
    @Option(
        name: .long,
        help: ArgumentHelp("Badge icon source: symbol (default), image, apple-reference", valueName: "source"),
        transform: { source in
            let valid = ["symbol", "image", "apple-reference"]
            guard valid.contains(source.lowercased()) else {
                throw ValidationError("Badge icon source must be one of: \(valid.joined(separator: ", "))")
            }
            return source.lowercased()
        }
    )
    var badgeIconSource: String = "symbol"

    @Option(name: .long, help: ArgumentHelp("Path to image file for badge symbol", valueName: "path"))
    var badgeImportedImage: String?

    @Option(
        name: .long,
        help: ArgumentHelp("Scale for imported badge image (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Badge imported image scale") }
    )
    var badgeImportedImageScale: Double = 1.0

    // Badge appex colors
    @Option(
        name: .long,
        help: ArgumentHelp("Badge appex enclosure color (Apple Reference badge): named, r,g,b,a (0–1), or hex", valueName: "color"),
        transform: { try resolveAppexColorArg($0, role: "Badge appex enclosure color") }
    )
    var badgeAppexEnclosureColor: String = "blue"

    @Option(
        name: .long,
        help: ArgumentHelp("Badge appex symbol color (Apple Reference badge): named, r,g,b,a (0–1), or hex", valueName: "color"),
        transform: { try resolveAppexColorArg($0, role: "Badge appex symbol color") }
    )
    var badgeAppexSymbolColor: String = "white"

    // Badge imported background
    @Option(name: .long, help: ArgumentHelp("Path to image file for badge background", valueName: "path"))
    var badgeImportedBackground: String?

    @Option(
        name: .long,
        help: ArgumentHelp("Scale for imported badge background (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Badge imported background scale") }
    )
    var badgeImportedBackgroundScale: Double = 1.0

    // Inverted optional: imported badge backgrounds fill the frame by default.
    @Flag(name: .long, inversion: .prefixedNo,
          help: "Padding compensation for imported badge backgrounds (default: on — scales up to fill the frame)")
    var badgeImportedBackgroundPaddingCompensation: Bool?

    /// Resolved padding compensation for an imported badge background.
    var effectiveBadgePaddingCompensation: Bool {
        badgeImportedBackgroundPaddingCompensation ?? true
    }
}

// MARK: - Main Command

/// The resolved icon foreground after combining the positional symbol-name
/// shorthand with an explicit `--icon-fg` value.
enum ResolvedForeground {
    case symbol(String)
    case image(String)
}

struct IconGeneratorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate customized macOS app icons using SF Symbols",
        usage: """
            mica-cli [generate] <symbol-name> [<options>]
            mica-cli star.fill -o ~/Desktop/my-icon.png
            mica-cli generate folder.fill --size 512 --icon-bg-color red
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

            System (Apple) generation mode:
              mica-cli star.fill --icon-generation-mode system \\
                --appex-enclosure-color blue --icon-symbol-color white

            Imported image foreground:
              mica-cli --icon-fg ~/my-icon.png --icon-fg-scale 0.9

            High-resolution export:
              mica-cli app.fill --size 1024 --scale 2x --color-space displayP3
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

    @OptionGroup(title: "Export")
    var export: ExportOptions

    @OptionGroup(title: "Generation")
    var generation: GenerationOptions

    @OptionGroup(title: "Background")
    var background: BackgroundOptions

    @OptionGroup(title: "Icon Foreground")
    var iconForeground: IconForegroundOptions

    @OptionGroup(title: "Badge")
    var badge: BadgeOptions

    // MARK: - Foreground Resolution

    /// Resolve the icon foreground. An explicit `--icon-fg` wins over the
    /// positional symbol-name shorthand. A `symbol:` prefix selects an SF
    /// Symbol; any other value is treated as an image file path.
    func resolvedForeground() throws -> ResolvedForeground {
        let raw: String
        if let foreground = iconForeground.foreground {
            raw = foreground
        } else if let symbolName {
            raw = "symbol:\(symbolName)"
        } else {
            throw ValidationError("Provide an icon foreground: a positional SF Symbol name, or --icon-fg <symbol:NAME|path>.")
        }

        if raw.lowercased().hasPrefix("symbol:") {
            let name = String(raw.dropFirst("symbol:".count))
            guard !name.isEmpty else {
                throw ValidationError("--icon-fg 'symbol:' requires a symbol name, e.g. symbol:star.fill")
            }
            return .symbol(name)
        }
        return .image(raw)
    }

    /// Default output basename (no extension) derived from the resolved
    /// foreground: the symbol name, or the image file's basename.
    func defaultOutputBasename() -> String {
        switch try? resolvedForeground() {
        case .symbol(let name):
            return name
        case .image(let path):
            return ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        case .none:
            return symbolName ?? "icon"
        }
    }

    // MARK: - Command Execution

    func run() async throws {
        try performValidation()

        let generator = IconGeneratorCLI()

        do {
            try await generator.generateIcon(from: self)
        } catch let error as ColorParseError {
            print("Color Error: \(error.localizedDescription)")
            throw ExitCode.validationFailure
        } catch let error as CLIError {
            print("Generation Error: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("Unexpected Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    // MARK: - Testing Support

    /// Expose the private validation chain for unit tests. Mirrors the
    /// `IconGeneratorCLI.buildTestSettings(from:)` pattern.
    func performValidationForTesting() throws {
        try performValidation()
    }

    // MARK: - Validation

    private func performValidation() throws {
        try validateForeground()
        try validateColorDependencies()
        try validateBadgeDependencies()
        try validateGenerationDependencies()
        try validateImagePaths()
        try validateOutputPath()
        try validateColorFormats()
    }

    private func validateForeground() throws {
        // Resolves and surfaces any "no foreground supplied" / empty-symbol errors.
        let foreground = try resolvedForeground()
        if case .symbol(let name) = foreground {
            guard name.allSatisfy({ $0.isLetter || $0.isNumber || ".-_".contains($0) }) else {
                throw ValidationError("Symbol name contains invalid characters. Use only letters, numbers, dots, dashes, and underscores.")
            }
        }
    }

    private func validateColorDependencies() throws {
        if background.useCustomColors {
            if background.customPrimary == nil && background.customSecondary == nil {
                throw ValidationError("When --use-custom-colors is enabled, provide at least one of --custom-primary or --custom-secondary")
            }
        }
        if iconForeground.symbolRendering == "palette", let palette = iconForeground.symbolPalette {
            // Validate the count up front; format is checked in validateColorFormats.
            _ = try splitPalette(palette, role: "--icon-symbol-palette")
        }
    }

    private func validateBadgeDependencies() throws {
        if badge.badgeUseCustom && badge.badge == nil {
            throw ValidationError("--badge-use-custom requires --badge to be specified")
        }
        if let badgeName = badge.badge, badgeName.isEmpty {
            throw ValidationError("Badge symbol name cannot be empty")
        }
        if badge.badgeIconSource == "image" && badge.badgeImportedImage == nil {
            throw ValidationError("--badge-icon-source image requires --badge-imported-image")
        }
        if badge.badgeImportedImage != nil && badge.badge == nil && badge.badgeIconSource != "image" {
            throw ValidationError("--badge-imported-image requires --badge and --badge-icon-source image")
        }
    }

    private func validateGenerationDependencies() throws {
        if background.backgroundMode == "image" && background.importedBackground == nil {
            throw ValidationError("--background-mode image requires --imported-background <path>")
        }
    }

    private func validateImagePaths() throws {
        // An image foreground (`--icon-fg <path>`) must point at an existing file.
        var foregroundImagePath: String?
        if case .image(let path) = try resolvedForeground() {
            foregroundImagePath = path
        }

        let paths: [(String?, String)] = [
            (foregroundImagePath, "--icon-fg"),
            (background.importedBackground, "--imported-background"),
            (badge.badgeImportedImage, "--badge-imported-image"),
            (badge.badgeImportedBackground, "--badge-imported-background"),
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
            let url = URL(fileURLWithPath: path)
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

    private func validateColorFormats() throws {
        // The merged icon symbol color resolves differently by generation mode:
        // mica → ColorParser; system → appex color tokens. Validate accordingly.
        if let symbolColor = iconForeground.symbolColor {
            if generation.resolvedIconMode == "apple-reference" {
                _ = try resolveAppexColorArg(symbolColor, role: "--icon-symbol-color")
            } else {
                do {
                    _ = try ColorParser.parse(symbolColor)
                } catch {
                    throw ValidationError("Invalid color format for --icon-symbol-color: '\(symbolColor)'. \(error.localizedDescription)")
                }
            }
        }

        // Palette colours (mica only): first is opaque, the other two allow opacity.
        if let palette = iconForeground.symbolPalette {
            let parts = try splitPalette(palette, role: "--icon-symbol-palette")
            for (index, part) in parts.enumerated() {
                do {
                    if index == 0 {
                        _ = try ColorParser.parse(part)
                    } else {
                        _ = try ColorParser.parseWithOpacity(part)
                    }
                } catch {
                    throw ValidationError("Invalid color format in --icon-symbol-palette ('\(part)'). \(error.localizedDescription)")
                }
            }
        }

        // Background + badge colours are unchanged in this phase.
        let colorsToTest: [(String, String)] = [
            (background.baseColor, "base-color"),
            (badge.badgeColor, "badge-color"),
            (badge.badgeSymbolColor, "badge-symbol-color"),
            (badge.badgePrimary, "badge-primary"),
            (badge.badgeSecondary, "badge-secondary"),
            (badge.badgeHierarchicalColor, "badge-hierarchical-color"),
            (badge.badgePalettePrimary, "badge-palette-primary"),
            (badge.badgePaletteSecondary, "badge-palette-secondary"),
            (badge.badgePaletteTertiary, "badge-palette-tertiary"),
        ]

        var allColors = colorsToTest
        if let primary = background.customPrimary {
            allColors.append((primary, "custom-primary"))
        }
        if let secondary = background.customSecondary {
            allColors.append((secondary, "custom-secondary"))
        }

        for (colorStr, paramName) in allColors {
            do {
                if paramName.contains("secondary") || paramName.contains("tertiary") {
                    _ = try ColorParser.parseWithOpacity(colorStr)
                } else {
                    _ = try ColorParser.parse(colorStr)
                }
            } catch {
                throw ValidationError("Invalid color format for --\(paramName): '\(colorStr)'. \(error.localizedDescription)")
            }
        }
    }
}

/// Split a `--icon-symbol-palette` value into exactly three component strings.
/// Throws a `ValidationError` if the count isn't three or any part is empty.
func splitPalette(_ raw: String, role: String) throws -> [String] {
    let parts = raw
        .split(separator: ",", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count == 3 else {
        throw ValidationError("\(role) requires exactly three comma-separated colors 'c1,c2,c3'. You provided \(parts.count).")
    }
    guard parts.allSatisfy({ !$0.isEmpty }) else {
        throw ValidationError("\(role) colors cannot be empty. Use 'c1,c2,c3'.")
    }
    return parts
}
