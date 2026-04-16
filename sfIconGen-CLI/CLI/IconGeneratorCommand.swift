import ArgumentParser
import Foundation

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
            discussion: "Specify any integer size between 16 and 1024 pixels. Common sizes: 128, 256, 512, 1024.",
            valueName: "pixels"
        ),
        transform: { size in
            guard let intSize = Int(size) else {
                throw ValidationError("Size must be a whole number (no decimals).")
            }
            let minSize = Int(IconSettings.minExportSize)
            let maxSize = Int(IconSettings.maxExportSize)
            guard (minSize...maxSize).contains(intSize) else {
                throw ValidationError(
                    "Size must be between \(minSize) and \(maxSize) pixels. You provided: \(intSize)"
                )
            }
            return intSize
        }
    )
    var size: Int = 256

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Export at 2x resolution",
            discussion: "Doubles the pixel dimensions for high-DPI displays"
        )
    )
    var retina: Bool = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Color space for export",
            discussion: "Options: sRGB (standard), displayP3 (wide gamut for modern displays)",
            valueName: "space"
        ),
        transform: { space in
            let validSpaces = ["sRGB", "displayP3"]
            guard validSpaces.contains(space) else {
                throw ValidationError("Color space must be one of: \(validSpaces.joined(separator: ", "))")
            }
            return space
        }
    )
    var colorSpace: String = "sRGB"
}

// MARK: - Background Options

struct BackgroundOptions: ParsableArguments {
    @Option(
        name: .long,
        help: ArgumentHelp(
            "Base gradient color",
            discussion: "Supports named colors (blue, red, green, etc.), hex codes (#FF5733), or RGB values (255,87,51)",
            valueName: "color"
        )
    )
    var baseColor: String = "blue"

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Enable custom gradient colors",
            discussion: "When enabled, use --custom-primary and --custom-secondary to define gradient"
        )
    )
    var useCustomColors: Bool = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Primary gradient color",
            discussion: "Top color of the gradient. Only used with --use-custom-colors",
            valueName: "color"
        )
    )
    var customPrimary: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Secondary gradient color",
            discussion: "Bottom color of the gradient. Only used with --use-custom-colors",
            valueName: "color"
        )
    )
    var customSecondary: String?

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Disable background gradient",
            discussion: "Uses a flat color instead of a gradient for the background"
        )
    )
    var noGradient: Bool = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Corner radius style",
            discussion: "Options: macos11 (macOS 11-15 style), macos26 (macOS 26 style, default)",
            valueName: "style"
        ),
        transform: { style in
            let valid = ["macos11", "macos26"]
            guard valid.contains(style.lowercased()) else {
                throw ValidationError("Corner radius must be one of: \(valid.joined(separator: ", "))")
            }
            return style.lowercased()
        }
    )
    var cornerRadius: String = "macos26"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Background shadow style",
            discussion: "Options: off (no shadow), macos11 (macOS 11-15 style), macos26 (macOS 26 style, default)",
            valueName: "style"
        ),
        transform: { style in
            let valid = ["off", "macos11", "macos26"]
            guard valid.contains(style.lowercased()) else {
                throw ValidationError("Background shadow style must be one of: \(valid.joined(separator: ", "))")
            }
            return style.lowercased()
        }
    )
    var backgroundShadowStyle: String = "macos26"

    // Hidden deprecated alias for --background-shadow-style off
    @Flag(
        name: .long,
        help: .hidden
    )
    var noBackgroundShadow: Bool = false

    /// Resolves the effective shadow style, accounting for the deprecated --no-background-shadow flag.
    var effectiveShadowStyle: String {
        noBackgroundShadow ? "off" : backgroundShadowStyle
    }
}

// MARK: - Symbol Options

struct SymbolOptions: ParsableArguments {
    @Option(
        name: .long,
        help: ArgumentHelp(
            "Symbol rendering mode",
            discussion: """
                Rendering modes:
                \u{2022} monochrome: Single color, uses --symbol-color
                \u{2022} hierarchical: Multiple opacities of one color, uses --hierarchical-color
                \u{2022} multicolor: Uses symbol's built-in colors
                \u{2022} palette: Custom colors for each layer, uses --palette-* options
                """,
            valueName: "mode"
        ),
        transform: { mode in
            let validModes = ["monochrome", "hierarchical", "multicolor", "palette"]
            guard validModes.contains(mode.lowercased()) else {
                throw ValidationError("Rendering mode must be one of: \(validModes.joined(separator: ", "))")
            }
            return mode.lowercased()
        }
    )
    var renderingMode: String = "monochrome"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Symbol color for monochrome mode",
            valueName: "color"
        )
    )
    var symbolColor: String = "white"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Symbol color for hierarchical mode",
            valueName: "color"
        )
    )
    var hierarchicalColor: String = "white"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Primary color for palette mode",
            valueName: "color"
        )
    )
    var palettePrimary: String = "white"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Secondary color for palette mode",
            discussion: "Supports opacity notation: 'white:0.5' for 50% opacity",
            valueName: "color"
        )
    )
    var paletteSecondary: String = "white:0.5"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Tertiary color for palette mode",
            discussion: "Supports opacity notation: 'white:0.26' for 26% opacity",
            valueName: "color"
        )
    )
    var paletteTertiary: String = "white:0.26"

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Disable symbol shadow",
            discussion: "Removes the shadow behind the SF Symbol itself"
        )
    )
    var noSymbolShadow: Bool = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Symbol weight",
            discussion: "Options: auto, ultralight, thin, light, regular, medium, semibold, bold, heavy, black",
            valueName: "weight"
        ),
        transform: { weight in
            let valid = ["auto", "ultralight", "thin", "light", "regular", "medium", "semibold", "bold", "heavy", "black"]
            guard valid.contains(weight.lowercased()) else {
                throw ValidationError("Symbol weight must be one of: \(valid.joined(separator: ", "))")
            }
            return weight.lowercased()
        }
    )
    var symbolWeight: String = "auto"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Manual symbol scale multiplier (0.3-2.0)",
            discussion: "Adjusts the size of the symbol relative to the icon. Default: 1.0",
            valueName: "scale"
        ),
        transform: { scale in
            guard let value = Double(scale) else {
                throw ValidationError("Symbol scale must be a number.")
            }
            guard IconSettings.manualSymbolScaleRange.contains(value) else {
                throw ValidationError("Symbol scale must be between 0.3 and 2.0. You provided: \(scale)")
            }
            return value
        }
    )
    var symbolScale: Double = 1.0

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Symbol color rendering mode (macOS 26+)",
            discussion: "Options: flat (default), gradient",
            valueName: "mode"
        ),
        transform: { mode in
            let valid = ["flat", "gradient"]
            guard valid.contains(mode.lowercased()) else {
                throw ValidationError("Symbol color rendering must be one of: \(valid.joined(separator: ", "))")
            }
            return mode.lowercased()
        }
    )
    var symbolColorRendering: String = "flat"
}

// MARK: - Badge Options

struct BadgeOptions: ParsableArguments {
    @Option(
        name: .long,
        help: ArgumentHelp(
            "Add badge with SF Symbol",
            discussion: "Overlays a smaller circular badge with the specified symbol",
            valueName: "symbol"
        )
    )
    var badge: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Badge position",
            discussion: "Options: top-left, top-right, bottom-left, bottom-right",
            valueName: "position"
        ),
        transform: { position in
            let validPositions = ["top-left", "top-right", "bottom-left", "bottom-right"]
            guard validPositions.contains(position.lowercased()) else {
                throw ValidationError("Badge position must be one of: \(validPositions.joined(separator: ", "))")
            }
            return position.lowercased()
        }
    )
    var badgePosition: String = "bottom-right"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Badge base color",
            discussion: "Base color for badge gradient when not using custom colors",
            valueName: "color"
        )
    )
    var badgeColor: String = "gray"

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Enable custom badge colors",
            discussion: "Use --badge-primary and --badge-secondary for custom badge gradient"
        )
    )
    var badgeUseCustom: Bool = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Badge primary color",
            discussion: "Top color of badge gradient. Only used with --badge-use-custom",
            valueName: "color"
        )
    )
    var badgePrimary: String = "white"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Badge secondary color",
            discussion: "Bottom color of badge gradient. Only used with --badge-use-custom",
            valueName: "color"
        )
    )
    var badgeSecondary: String = "indigo"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Badge rendering mode",
            discussion: "Same modes as main symbol: monochrome, hierarchical, multicolor, palette",
            valueName: "mode"
        ),
        transform: { mode in
            let validModes = ["monochrome", "hierarchical", "multicolor", "palette"]
            guard validModes.contains(mode.lowercased()) else {
                throw ValidationError("Badge rendering mode must be one of: \(validModes.joined(separator: ", "))")
            }
            return mode.lowercased()
        }
    )
    var badgeRendering: String = "monochrome"

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Badge symbol color",
            discussion: "Color of the symbol within the badge",
            valueName: "color"
        )
    )
    var badgeSymbolColor: String = "white"
}

// MARK: - Main Command

@main
struct IconGeneratorCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "sfIconGen-CLI",
        abstract: "Generate customized macOS app icons using SF Symbols",
        usage: """
            sfIconGen-CLI <symbol-name> [<options>]
            sfIconGen-CLI star.fill --output ~/Desktop/my-icon.png
            sfIconGen-CLI folder.fill --size 512 --retina --base-color red
            """,
        discussion: """
            EXAMPLES:

            Basic usage:
              sfIconGen-CLI star.fill
              sfIconGen-CLI folder.fill -o ~/Desktop/folder-icon.png

            Custom sizes (16-1024 pixels):
              sfIconGen-CLI heart.fill --size 450
              sfIconGen-CLI app.fill --size 1024 --retina --color-space displayP3

            Custom colors and rendering:
              sfIconGen-CLI shield.fill --rendering-mode hierarchical --hierarchical-color white
              sfIconGen-CLI person.3.fill --rendering-mode palette \\
                --palette-primary white --palette-secondary blue --palette-tertiary gray

            Background customization:
              sfIconGen-CLI app.fill --use-custom-colors --custom-primary "#FF6B35" --custom-secondary "#F7931E"
              sfIconGen-CLI app.fill --corner-radius macos11 --no-gradient
              sfIconGen-CLI app.fill --background-shadow-style off

            Symbol adjustments:
              sfIconGen-CLI star.fill --symbol-weight bold --symbol-scale 1.3
              sfIconGen-CLI star.fill --symbol-color-rendering gradient

            Badge support:
              sfIconGen-CLI star.fill --badge plus.circle --badge-position bottom-right
              sfIconGen-CLI star.fill --badge gear --badge-color green --badge-use-custom \\
                --badge-primary white --badge-secondary green

            Minimal style:
              sfIconGen-CLI circle --base-color black --background-shadow-style off --no-symbol-shadow
            """,
        version: "1.0.0"
    )

    // MARK: - Required Arguments

    @Argument(
        help: ArgumentHelp(
            "The SF Symbol name to render",
            discussion: "Use any valid SF Symbol name (e.g., 'star.fill', 'folder.badge.plus', 'heart.circle'). You can find symbol names in Apple's SF Symbols app or documentation.",
            valueName: "symbol-name"
        )
    )
    var symbolName: String

    // MARK: - Option Groups

    @OptionGroup(title: "Export")
    var export: ExportOptions

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

    // MARK: - Validation

    private func performValidation() throws {
        try validateSymbolName()
        try validateColorDependencies()
        try validateBadgeDependencies()
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
        if let badgeName = badge.badge {
            guard !badgeName.isEmpty else {
                throw ValidationError("Badge symbol name cannot be empty")
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
            (badge.badgeSecondary, "badge-secondary")
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
