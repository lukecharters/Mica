import Foundation
import SwiftUI
import AppKit

/// CLI adapter that bridges between command arguments and the existing IconRenderer
class IconGeneratorCLI {
    
    func generateIcon(from command: IconGeneratorCommand) async throws {
        // Build IconSettings from command arguments
        let settings = try buildIconSettings(from: command)
        
        // Generate icon using existing renderer
        let image = await MainActor.run {
            IconRenderer.renderIconSafely(settings: settings)
        }
        
        // Determine output path
        let outputURL = resolveOutputPath(symbolName: command.symbolName, userPath: command.outputPath)
        
        // Save the image
        try saveImage(image, to: outputURL)
        
        print("✓ Icon generated successfully: \(outputURL.path)")
    }
    
    // MARK: - Settings Builder
    
    private func buildIconSettings(from command: IconGeneratorCommand) throws -> IconSettings {
        var settings = IconSettings()
        
        // Basic properties
        settings.symbolName = command.symbolName
        settings.exportSize = CGFloat(command.size)
        settings.exportRetinaSize = command.retina
        settings.exportColorSpace = parseColorSpace(command.colorSpace)
        
        // Background colors
        settings.baseColor = try ColorParser.parse(command.baseColor)
        settings.useCustomColors = command.useCustomColors
        
        if command.useCustomColors {
            if let primary = command.customPrimary {
                settings.customPrimaryColor = try ColorParser.parse(primary)
            }
            if let secondary = command.customSecondary {
                settings.customSecondaryColor = try ColorParser.parse(secondary)
            }
        }
        
        // Symbol rendering
        settings.symbolRenderingMode = parseRenderingMode(command.renderingMode)
        settings.symbolColor = try ColorParser.parse(command.symbolColor)
        settings.hierarchicalSymbolColor = try ColorParser.parse(command.hierarchicalColor)
        settings.paletteSymbolPrimaryColor = try ColorParser.parse(command.palettePrimary)
        settings.paletteSymbolSecondaryColor = try ColorParser.parseWithOpacity(command.paletteSecondary)
        settings.paletteSymbolTertiaryColor = try ColorParser.parseWithOpacity(command.paletteTertiary)
        
        // Shadow settings
        settings.enableBackgroundShadow = !command.noBackgroundShadow
        settings.enableSymbolShadow = !command.noSymbolShadow
        
        // Badge settings
        if let badgeSymbol = command.badge {
            settings.showBadge = true
            settings.badgeSymbolName = badgeSymbol
            settings.badgePosition = parseBadgePosition(command.badgePosition)
            settings.badgeBaseColor = try ColorParser.parse(command.badgeColor)
            settings.badgeUseCustomColors = command.badgeUseCustom
            
            if command.badgeUseCustom {
                settings.badgeCustomPrimaryColor = try ColorParser.parse(command.badgePrimary)
                settings.badgeCustomSecondaryColor = try ColorParser.parse(command.badgeSecondary)
            }
            
            settings.badgeSymbolRenderingMode = parseRenderingMode(command.badgeRendering)
            settings.badgeSymbolColor = try ColorParser.parse(command.badgeSymbolColor)
        }
        
        return settings
    }
    
    // MARK: - Parsing Helpers
    
    private func parseColorSpace(_ input: String) -> ExportColorSpace {
        switch input.lowercased() {
        case "srgb": return .sRGB
        case "displayp3": return .displayP3
        default: return .sRGB
        }
    }
    
    private func parseRenderingMode(_ input: String) -> SymbolRenderingMode {
        switch input.lowercased() {
        case "monochrome": return .monochrome
        case "hierarchical": return .hierarchical
        case "multicolor": return .multicolor
        case "palette": return .palette
        default: return .monochrome
        }
    }
    
    private func parseBadgePosition(_ input: String) -> BadgePosition {
        switch input.lowercased() {
        case "top-left": return .topLeft
        case "top-right": return .topRight
        case "bottom-left": return .bottomLeft
        case "bottom-right": return .bottomRight
        default: return .bottomRight
        }
    }
    
    // MARK: - File Operations
    
    private func resolveOutputPath(symbolName: String, userPath: String?) -> URL {
        if let userPath = userPath {
            return URL(fileURLWithPath: userPath)
        }
        
        // Create safe filename from symbol name
        let sanitized = symbolName
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        
        return URL(fileURLWithPath: "./\(sanitized).png")
    }
    
    private func saveImage(_ image: NSImage, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CLIError.imageConversion("Failed to convert image to PNG format")
        }
        
        // Create directory if needed
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        try pngData.write(to: url)
    }
}

// MARK: - Error Types

enum CLIError: LocalizedError {
    case imageConversion(String)
    case invalidSymbol(String)
    case fileSystem(String)
    
    var errorDescription: String? {
        switch self {
        case .imageConversion(let message):
            return "Image conversion error: \(message)"
        case .invalidSymbol(let symbol):
            return "Invalid SF Symbol: '\(symbol)'"
        case .fileSystem(let message):
            return "File system error: \(message)"
        }
    }
}
