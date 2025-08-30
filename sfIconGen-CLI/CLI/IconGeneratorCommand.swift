import ArgumentParser
import Foundation

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
            
            Custom colors and rendering:
              sfIconGen-CLI heart.fill --base-color pink --size 512
              sfIconGen-CLI shield.fill --rendering-mode hierarchical --hierarchical-color white
              
            Advanced palette mode:
              sfIconGen-CLI person.3.fill --rendering-mode palette \\
                --palette-primary white --palette-secondary blue --palette-tertiary gray
                
            Badge support:
              sfIconGen-CLI star.fill --badge plus.circle --badge-position bottom-right
              
            High-resolution export:
              sfIconGen-CLI app.fill --size 1024 --retina --color-space displayP3
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
    
    // MARK: - Basic Options
    
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
            "Export size in pixels",
            discussion: "Standard icon sizes: 128, 256, 512, 1024",
            valueName: "pixels"
        ),
        transform: { size in
            guard let intSize = Int(size) else {
                throw ValidationError("Size must be a number")
            }
            let validSizes = [128, 256, 512, 1024]
            guard validSizes.contains(intSize) else {
                throw ValidationError("Size must be one of: \(validSizes.map(String.init).joined(separator: ", "))")
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
    
    // MARK: - Background Color Configuration
    
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
    
    // MARK: - Symbol Rendering Configuration
    
    @Option(
        name: .long, 
        help: ArgumentHelp(
            "Symbol rendering mode",
            discussion: """
                Rendering modes:
                • monochrome: Single color, uses --symbol-color
                • hierarchical: Multiple opacities of one color, uses --hierarchical-color
                • multicolor: Uses symbol's built-in colors
                • palette: Custom colors for each layer, uses --palette-* options
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
    
    // MARK: - Shadow Configuration
    
    @Flag(
        name: .long, 
        help: ArgumentHelp(
            "Disable background shadow",
            discussion: "Removes the subtle shadow behind the icon background"
        )
    )
    var noBackgroundShadow: Bool = false
    
    @Flag(
        name: .long, 
        help: ArgumentHelp(
            "Disable symbol shadow",
            discussion: "Removes the shadow behind the SF Symbol itself"
        )
    )
    var noSymbolShadow: Bool = false
    
    // MARK: - Badge Configuration
    
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
            discussion: "Where to place the badge on the icon",
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
    
    // MARK: - Command Execution
    
    func run() async throws {
        // Perform comprehensive validation
        try performValidation()
        
        // Create CLI generator instance
        let generator = IconGeneratorCLI()
        
        // Generate icon with enhanced error handling
        do {
            try await generator.generateIcon(from: self)
        } catch let error as ColorParseError {
            print("❌ Color Error: \(error.localizedDescription)")
            throw ExitCode.validationFailure
        } catch let error as CLIError {
            print("❌ Generation Error: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("❌ Unexpected Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    // MARK: - Enhanced Validation
    
    private func performValidation() throws {
        // Validate SF Symbol name format
        try validateSymbolName()
        
        // Validate color dependencies
        try validateColorDependencies()
        
        // Validate badge dependencies  
        try validateBadgeDependencies()
        
        // Validate output path
        try validateOutputPath()
        
        // Test color parsing early
        try validateColorFormats()
    }
    
    private func validateSymbolName() throws {
        guard !symbolName.isEmpty else {
            throw ValidationError("Symbol name cannot be empty")
        }
        
        // Basic format validation
        guard symbolName.allSatisfy({ $0.isLetter || $0.isNumber || ".-_".contains($0) }) else {
            throw ValidationError("Symbol name contains invalid characters. Use only letters, numbers, dots, dashes, and underscores.")
        }
    }
    
    private func validateColorDependencies() throws {
        if useCustomColors {
            if customPrimary == nil && customSecondary == nil {
                throw ValidationError("When --use-custom-colors is enabled, provide at least one of --custom-primary or --custom-secondary")
            }
        }
        
        if renderingMode == "palette" {
            // Ensure palette colors make sense
            if palettePrimary.isEmpty || paletteSecondary.isEmpty || paletteTertiary.isEmpty {
                throw ValidationError("Palette mode requires all three palette colors to be specified")
            }
        }
    }
    
    private func validateBadgeDependencies() throws {
        if badgeUseCustom && badge == nil {
            throw ValidationError("--badge-use-custom requires --badge to be specified")
        }
        
        if badge != nil {
            guard !badge!.isEmpty else {
                throw ValidationError("Badge symbol name cannot be empty")
            }
        }
    }
    
    private func validateOutputPath() throws {
        if let path = outputPath {
            let url = URL(fileURLWithPath: path)
            let parentDir = url.deletingLastPathComponent()
            
            // Check if parent directory exists or can be created
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                // Try to create it to validate permissions
                do {
                    try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                } catch {
                    throw ValidationError("Cannot create output directory: \(parentDir.path)")
                }
            }
        }
    }
    
    private func validateColorFormats() throws {
        // Test all color strings to catch format errors early
        let colorsToTest: [(String, String)] = [
            (baseColor, "base-color"),
            (symbolColor, "symbol-color"),
            (hierarchicalColor, "hierarchical-color"),
            (palettePrimary, "palette-primary"),
            (paletteSecondary, "palette-secondary"),
            (paletteTertiary, "palette-tertiary"),
            (badgeColor, "badge-color"),
            (badgeSymbolColor, "badge-symbol-color"),
            (badgePrimary, "badge-primary"),
            (badgeSecondary, "badge-secondary")
        ]
        
        // Add custom colors if specified
        var allColors = colorsToTest
        if let primary = customPrimary {
            allColors.append((primary, "custom-primary"))
        }
        if let secondary = customSecondary {
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

// MARK: - Enhanced Help and Examples

extension IconGeneratorCommand {
    static func examples() -> String {
        return """
        COMMON USAGE PATTERNS:
        
        Quick start:
          sfIconGen-CLI star.fill
          sfIconGen-CLI folder.fill -o my-icon.png
          
        Custom colors:
          sfIconGen-CLI heart.fill --base-color red
          sfIconGen-CLI app.fill --use-custom-colors --custom-primary "#FF6B35" --custom-secondary "#F7931E"
          
        Different rendering modes:
          sfIconGen-CLI folder.fill --rendering-mode hierarchical --hierarchical-color blue
          sfIconGen-CLI person.3.fill --rendering-mode palette --palette-primary white --palette-secondary blue
          
        High quality export:
          sfIconGen-CLI app.fill --size 1024 --retina --color-space displayP3
          
        With badges:
          sfIconGen-CLI star.fill --badge plus.circle --badge-position bottom-right --badge-color green
          
        Minimal style:
          sfIconGen-CLI circle --base-color black --no-background-shadow --no-symbol-shadow
        """
    }
}
