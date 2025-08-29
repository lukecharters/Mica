import ArgumentParser
import Foundation

@main
struct IconGeneratorCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "sfIconGen-CLI",
        abstract: "Generate customized macOS app icons using SF Symbols",
        version: "1.0.0"
    )
    
    // MARK: - Required Arguments
    
    @Argument(help: "The SF Symbol name to render")
    var symbolName: String
    
    // MARK: - Basic Options
    
    @Option(name: [.customLong("output"), .customShort("o")], 
            help: "Output file path (default: ./{symbol}.png)")
    var outputPath: String?
    
    @Option(name: [.customLong("size"), .customShort("s")], 
            help: "Export size: 128, 256, 512, 1024 (default: 256)")
    var size: Int = 256
    
    @Flag(name: .long, 
          help: "Export at 2x resolution")
    var retina: Bool = false
    
    @Option(name: .long, 
            help: "Color space: sRGB, displayP3 (default: sRGB)")
    var colorSpace: String = "sRGB"
    
    // MARK: - Color Configuration
    
    @Option(name: .long, 
            help: "Base gradient color (default: blue)")
    var baseColor: String = "blue"
    
    @Flag(name: .long, 
          help: "Enable custom gradient colors")
    var useCustomColors: Bool = false
    
    @Option(name: .long, 
            help: "Primary gradient color")
    var customPrimary: String?
    
    @Option(name: .long, 
            help: "Secondary gradient color")
    var customSecondary: String?
    
    // MARK: - Symbol Rendering
    
    @Option(name: .long, 
            help: "Symbol rendering: monochrome, hierarchical, multicolor, palette (default: monochrome)")
    var renderingMode: String = "monochrome"
    
    @Option(name: .long, 
            help: "Symbol color for monochrome mode (default: white)")
    var symbolColor: String = "white"
    
    @Option(name: .long, 
            help: "Symbol color for hierarchical mode (default: white)")
    var hierarchicalColor: String = "white"
    
    @Option(name: .long, 
            help: "Primary color for palette mode (default: white)")
    var palettePrimary: String = "white"
    
    @Option(name: .long, 
            help: "Secondary color for palette mode (default: white:0.5)")
    var paletteSecondary: String = "white:0.5"
    
    @Option(name: .long, 
            help: "Tertiary color for palette mode (default: white:0.26)")
    var paletteTertiary: String = "white:0.26"
    
    // MARK: - Shadow Configuration
    
    @Flag(name: .long, 
          help: "Disable background shadow")
    var noBackgroundShadow: Bool = false
    
    @Flag(name: .long, 
          help: "Disable symbol shadow")
    var noSymbolShadow: Bool = false
    
    // MARK: - Badge Configuration
    
    @Option(name: .long, 
            help: "Add badge with SF Symbol")
    var badge: String?
    
    @Option(name: .long, 
            help: "Badge position: top-left, top-right, bottom-left, bottom-right (default: bottom-right)")
    var badgePosition: String = "bottom-right"
    
    @Option(name: .long, 
            help: "Badge base color (default: gray)")
    var badgeColor: String = "gray"
    
    @Flag(name: .long, 
          help: "Enable custom badge colors")
    var badgeUseCustom: Bool = false
    
    @Option(name: .long, 
            help: "Badge primary color (default: white)")
    var badgePrimary: String = "white"
    
    @Option(name: .long, 
            help: "Badge secondary color (default: indigo)")
    var badgeSecondary: String = "indigo"
    
    @Option(name: .long, 
            help: "Badge rendering mode (default: monochrome)")
    var badgeRendering: String = "monochrome"
    
    @Option(name: .long, 
            help: "Badge symbol color (default: white)")
    var badgeSymbolColor: String = "white"
    
    // MARK: - Command Execution
    
    func run() async throws {
        // Validate arguments
        try validateArguments()
        
        // Create CLI generator instance
        let generator = IconGeneratorCLI()
        
        // Generate icon
        try await generator.generateIcon(from: self)
    }
    
    // MARK: - Validation
    
    private func validateArguments() throws {
        // Validate size
        let validSizes = [128, 256, 512, 1024]
        guard validSizes.contains(size) else {
            throw ValidationError("Invalid size '\(size)'. Must be one of: \(validSizes.map(String.init).joined(separator: ", "))")
        }
        
        // Validate color space
        let validColorSpaces = ["sRGB", "displayP3"]
        guard validColorSpaces.contains(colorSpace) else {
            throw ValidationError("Invalid color space '\(colorSpace)'. Must be one of: \(validColorSpaces.joined(separator: ", "))")
        }
        
        // Validate rendering mode
        let validRenderingModes = ["monochrome", "hierarchical", "multicolor", "palette"]
        guard validRenderingModes.contains(renderingMode) else {
            throw ValidationError("Invalid rendering mode '\(renderingMode)'. Must be one of: \(validRenderingModes.joined(separator: ", "))")
        }
        
        // Validate badge position if badge is specified
        if badge != nil {
            let validPositions = ["top-left", "top-right", "bottom-left", "bottom-right"]
            guard validPositions.contains(badgePosition) else {
                throw ValidationError("Invalid badge position '\(badgePosition)'. Must be one of: \(validPositions.joined(separator: ", "))")
            }
        }
    }
}
