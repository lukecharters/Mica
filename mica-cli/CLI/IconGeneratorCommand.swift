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
    @Option(
        name: .long,
        help: ArgumentHelp(
            "Generation mode (deprecated alias — sets both --icon-mode and --badge-mode)",
            discussion: "Options: custom (SwiftUI rendering, default), apple-reference (system appex rendering)",
            valueName: "mode"
        ),
        transform: { mode in
            let valid = ["custom", "apple-reference"]
            guard valid.contains(mode.lowercased()) else {
                throw ValidationError("Generation mode must be one of: \(valid.joined(separator: ", "))")
            }
            return mode.lowercased()
        }
    )
    var generationMode: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Generation mode for the icon",
            discussion: "Options: custom (SwiftUI rendering, default), apple-reference (system appex rendering)",
            valueName: "mode"
        ),
        transform: { mode in
            let valid = ["custom", "apple-reference"]
            guard valid.contains(mode.lowercased()) else {
                throw ValidationError("Icon mode must be one of: \(valid.joined(separator: ", "))")
            }
            return mode.lowercased()
        }
    )
    var iconMode: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Generation mode for the badge",
            discussion: "Options: custom (SwiftUI rendering, default), apple-reference (system appex rendering)",
            valueName: "mode"
        ),
        transform: { mode in
            let valid = ["custom", "apple-reference"]
            guard valid.contains(mode.lowercased()) else {
                throw ValidationError("Badge mode must be one of: \(valid.joined(separator: ", "))")
            }
            return mode.lowercased()
        }
    )
    var badgeMode: String?

    /// Resolved icon mode: explicit `--icon-mode` wins, then `--generation-mode`, default custom.
    var resolvedIconMode: String { iconMode ?? generationMode ?? "custom" }

    /// Resolved badge mode: explicit `--badge-mode` wins, then `--generation-mode`, default custom.
    var resolvedBadgeMode: String { badgeMode ?? generationMode ?? "custom" }

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Icon source type",
            discussion: "Options: symbol (SF Symbol, default), image (imported file)",
            valueName: "source"
        ),
        transform: { source in
            let valid = ["symbol", "image"]
            guard valid.contains(source.lowercased()) else {
                throw ValidationError("Icon source must be one of: \(valid.joined(separator: ", "))")
            }
            return source.lowercased()
        }
    )
    var iconSource: String = "symbol"

    @Option(
        name: .long,
        help: ArgumentHelp("Path to image file for icon symbol (use with --icon-source image)", valueName: "path")
    )
    var importedImage: String?

    @Option(
        name: .long,
        help: ArgumentHelp("Scale for imported symbol image (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Imported image scale") }
    )
    var importedImageScale: Double = 1.0

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Appex enclosure (background) color for Apple Reference mode",
            discussion: "A named color (\(validAppexColors.joined(separator: ", "))), an r,g,b,a value (0–1, e.g. 1,0.0902,0.2118,1), or a hex color (e.g. #FF1736)",
            valueName: "color"
        ),
        transform: { try resolveAppexColorArg($0, role: "Appex enclosure color") }
    )
    var appexEnclosureColor: String = "blue"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Appex symbol color for Apple Reference mode",
            discussion: "A named color (\(validAppexColors.joined(separator: ", "))), an r,g,b,a value (0–1, e.g. 1,0.0902,0.2118,1), or a hex color (e.g. #FF1736)",
            valueName: "color"
        ),
        transform: { try resolveAppexColorArg($0, role: "Appex symbol color") }
    )
    var appexSymbolColor: String = "white"
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

// MARK: - Symbol Options

struct SymbolOptions: ParsableArguments {
    @Option(
        name: .long,
        help: ArgumentHelp(
            "Symbol rendering mode",
            discussion: "monochrome (default), hierarchical, multicolor, or palette",
            valueName: "mode"
        ),
        transform: { mode in
            guard validRenderingModes.contains(mode.lowercased()) else {
                throw ValidationError("Rendering mode must be one of: \(validRenderingModes.joined(separator: ", "))")
            }
            return mode.lowercased()
        }
    )
    var renderingMode: String = "monochrome"

    @Option(name: .long, help: ArgumentHelp("Symbol color (monochrome mode)", valueName: "color"))
    var symbolColor: String = "white"

    @Option(name: .long, help: ArgumentHelp("Symbol color (hierarchical mode)", valueName: "color"))
    var hierarchicalColor: String = "white"

    @Option(name: .long, help: ArgumentHelp("Primary color (palette mode)", valueName: "color"))
    var palettePrimary: String = "white"

    @Option(name: .long, help: ArgumentHelp("Secondary color (palette mode, supports opacity e.g. 'white:0.5')", valueName: "color"))
    var paletteSecondary: String = "white:0.5"

    @Option(name: .long, help: ArgumentHelp("Tertiary color (palette mode, supports opacity e.g. 'white:0.26')", valueName: "color"))
    var paletteTertiary: String = "white:0.26"

    // Inverted optional: nil = unspecified, so the effective value can default
    // based on the icon source (off for imported images, on for SF Symbols).
    // `--no-symbol-shadow` is preserved; `--symbol-shadow` forces it back on.
    @Flag(name: .long, inversion: .prefixedNo,
          help: "Symbol shadow (default: off for imported images, on for SF Symbols)")
    var symbolShadow: Bool?

    @Option(
        name: .long,
        help: ArgumentHelp("Symbol weight: auto, ultralight, thin, light, regular, medium, semibold, bold, heavy, black", valueName: "weight"),
        transform: { weight in
            guard validSymbolWeights.contains(weight.lowercased()) else {
                throw ValidationError("Symbol weight must be one of: \(validSymbolWeights.joined(separator: ", "))")
            }
            return weight.lowercased()
        }
    )
    var symbolWeight: String = "auto"

    @Option(
        name: .long,
        help: ArgumentHelp("Symbol scale multiplier (0.3-2.0)", valueName: "scale"),
        transform: { try validateScale($0, name: "Symbol scale") }
    )
    var symbolScale: Double = 1.0

    @Option(
        name: .long,
        help: ArgumentHelp("Symbol color rendering: flat (default) or gradient (macOS 26+)", valueName: "mode"),
        transform: { mode in
            guard ["flat", "gradient"].contains(mode.lowercased()) else {
                throw ValidationError("Symbol color rendering must be 'flat' or 'gradient'")
            }
            return mode.lowercased()
        }
    )
    var symbolColorRendering: String = "flat"
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

struct IconGeneratorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate customized macOS app icons using SF Symbols",
        usage: """
            mica-cli [generate] <symbol-name> [<options>]
            mica-cli star.fill -o ~/Desktop/my-icon.png
            mica-cli generate folder.fill --size 512 --retina --base-color red
            """,
        discussion: """
            EXAMPLES (the `generate` subcommand name is optional — it is the default):

            Basic usage:
              mica-cli star.fill
              mica-cli folder.fill -o ~/Desktop/folder-icon.png

            Custom colors and rendering:
              mica-cli shield.fill --rendering-mode hierarchical --hierarchical-color white
              mica-cli app.fill --use-custom-colors --custom-primary "#FF6B35" --custom-secondary "#F7931E"

            Symbol adjustments:
              mica-cli star.fill --symbol-weight bold --symbol-scale 1.3
              mica-cli star.fill --corner-radius macos11 --no-gradient

            Apple Reference mode:
              mica-cli star.fill --generation-mode apple-reference \\
                --appex-enclosure-color blue --appex-symbol-color white

            Imported image icon:
              mica-cli star.fill --icon-source image --imported-image ~/my-icon.png

            Imported background:
              mica-cli star.fill --background-mode image --imported-background ~/bg.png

            Badge support:
              mica-cli star.fill --badge plus.circle --badge-position bottom-right
              mica-cli star.fill --badge gear --badge-scale 1.3 \\
                --badge-offset-x 0.2 --badge-offset-y -0.1

            Badge with Apple Reference:
              mica-cli star.fill --badge gear --badge-icon-source apple-reference \\
                --badge-appex-enclosure-color red --badge-appex-symbol-color white

            High-resolution export:
              mica-cli app.fill --size 1024 --retina --color-space displayP3
            """
    )

    @Argument(
        help: ArgumentHelp(
            "The SF Symbol name to render",
            discussion: "Use any valid SF Symbol name (e.g., 'star.fill', 'folder.badge.plus'). When using --icon-source image, this is still required but only used for the output filename.",
            valueName: "symbol-name"
        )
    )
    var symbolName: String

    @OptionGroup(title: "Export")
    var export: ExportOptions

    @OptionGroup(title: "Generation")
    var generation: GenerationOptions

    @OptionGroup(title: "Background")
    var background: BackgroundOptions

    @OptionGroup(title: "Symbol")
    var symbol: SymbolOptions

    @OptionGroup(title: "Badge")
    var badge: BadgeOptions

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
        try validateSymbolName()
        try validateColorDependencies()
        try validateBadgeDependencies()
        try validateGenerationDependencies()
        try validateImagePaths()
        try validateOutputPath()
        try validateColorFormats()
    }

    private func validateSymbolName() throws {
        guard !symbolName.isEmpty else {
            throw ValidationError("Symbol name cannot be empty")
        }
        guard symbolName.allSatisfy({ $0.isLetter || $0.isNumber || ".-_".contains($0) }) else {
            throw ValidationError("Symbol name contains invalid characters. Use only letters, numbers, dots, dashes, and underscores.")
        }
    }

    private func validateColorDependencies() throws {
        if background.useCustomColors {
            if background.customPrimary == nil && background.customSecondary == nil {
                throw ValidationError("When --use-custom-colors is enabled, provide at least one of --custom-primary or --custom-secondary")
            }
        }
        if symbol.renderingMode == "palette" {
            if symbol.palettePrimary.isEmpty || symbol.paletteSecondary.isEmpty || symbol.paletteTertiary.isEmpty {
                throw ValidationError("Palette mode requires all three palette colors to be specified")
            }
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
        if generation.iconSource == "image" && generation.importedImage == nil {
            throw ValidationError("--icon-source image requires --imported-image <path>")
        }
        if background.backgroundMode == "image" && background.importedBackground == nil {
            throw ValidationError("--background-mode image requires --imported-background <path>")
        }
    }

    private func validateImagePaths() throws {
        let paths: [(String?, String)] = [
            (generation.importedImage, "--imported-image"),
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
        let colorsToTest: [(String, String)] = [
            (background.baseColor, "base-color"),
            (symbol.symbolColor, "symbol-color"),
            (symbol.hierarchicalColor, "hierarchical-color"),
            (symbol.palettePrimary, "palette-primary"),
            (symbol.paletteSecondary, "palette-secondary"),
            (symbol.paletteTertiary, "palette-tertiary"),
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
