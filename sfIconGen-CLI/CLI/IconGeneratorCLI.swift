import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Enhanced CLI adapter that bridges between command arguments and the existing IconRenderer
/// Provides comprehensive error handling, validation, and progress reporting
class IconGeneratorCLI {
    
    // MARK: - Generation Progress
    
    enum GenerationPhase {
        case validation
        case settingsBuilding
        case rendering
        case saving
        case complete
    }
    
    private var currentPhase: GenerationPhase = .validation
    private var isVerbose: Bool = false
    
    // MARK: - Main Generation Method
    
    func generateIcon(from command: IconGeneratorCommand) async throws {
        do {
            // Phase 1: Enhanced validation
            currentPhase = .validation
            try await performEnhancedValidation(command)
            
            // Phase 2: Build settings with comprehensive error handling
            currentPhase = .settingsBuilding
            let settings = try buildIconSettings(from: command)
            
            // Phase 3: Render icon with progress tracking
            currentPhase = .rendering
            let image = try await renderIconWithErrorHandling(settings: settings)
            
            // Phase 4: Save with enhanced file operations
            currentPhase = .saving
            let outputURL = try resolveOutputPath(symbolName: command.symbolName, userPath: command.outputPath)
            try await saveImageWithValidation(image, to: outputURL, settings: settings)
            
            // Phase 5: Success reporting
            currentPhase = .complete
            reportSuccess(outputURL: outputURL, settings: settings)
            
        } catch let error as CLIError {
            handleCLIError(error, phase: currentPhase)
            throw error
        } catch let error as ColorParseError {
            handleColorError(error, phase: currentPhase)
            throw error
        } catch {
            handleUnexpectedError(error, phase: currentPhase)
            throw CLIError.unexpectedError("Unexpected error during \(currentPhase): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Enhanced Validation
    
    private func performEnhancedValidation(_ command: IconGeneratorCommand) async throws {
        // Validate SF Symbol exists (if possible)
        try validateSFSymbolExists(command.symbolName)
        
        // Pre-validate all color strings with context
        try validateAllColors(command)
        
        // Validate file system permissions
        if let outputPath = command.outputPath {
            try validateOutputPermissions(outputPath)
        }
        
        // Validate rendering mode consistency
        try validateRenderingModeConsistency(command)
    }
    
    private func validateSFSymbolExists(_ symbolName: String) throws {
        // Check if symbol exists by attempting to create UIImage
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        if image == nil {
            throw CLIError.invalidSymbol("SF Symbol '\(symbolName)' does not exist. Verify the symbol name in Apple's SF Symbols app.")
        }
    }
    
    private func validateAllColors(_ command: IconGeneratorCommand) throws {
        let colorValidations: [(String, String, Bool)] = [
            (command.baseColor, "base-color", true),
            (command.symbolColor, "symbol-color", true),
            (command.hierarchicalColor, "hierarchical-color", command.renderingMode == "hierarchical"),
            (command.palettePrimary, "palette-primary", command.renderingMode == "palette"),
            (command.paletteSecondary, "palette-secondary", command.renderingMode == "palette"),
            (command.paletteTertiary, "palette-tertiary", command.renderingMode == "palette"),
            (command.badgeColor, "badge-color", command.badge != nil),
            (command.badgeSymbolColor, "badge-symbol-color", command.badge != nil)
        ]
        
        // Add custom colors if specified
        var allValidations = colorValidations
        if let primary = command.customPrimary {
            allValidations.append((primary, "custom-primary", command.useCustomColors))
        }
        if let secondary = command.customSecondary {
            allValidations.append((secondary, "custom-secondary", command.useCustomColors))
        }
        if command.badgeUseCustom {
            allValidations.append((command.badgePrimary, "badge-primary", true))
            allValidations.append((command.badgeSecondary, "badge-secondary", true))
        }
        
        for (colorStr, paramName, shouldValidate) in allValidations {
            guard shouldValidate else { continue }
            
            do {
                if paramName.contains("secondary") || paramName.contains("tertiary") {
                    _ = try ColorParser.parseWithOpacity(colorStr)
                } else {
                    _ = try ColorParser.parse(colorStr)
                }
            } catch {
                throw CLIError.invalidColorFormat(
                    "Invalid color format for --\(paramName): '\(colorStr)'. \(error.localizedDescription)"
                )
            }
        }
    }
    
    private func validateOutputPermissions(_ outputPath: String) throws {
        let url = URL(fileURLWithPath: outputPath)
        let directory = url.deletingLastPathComponent()
        
        // Check if directory exists and is writable
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)
        
        if exists && !isDirectory.boolValue {
            throw CLIError.fileSystem("Output path parent is not a directory: \(directory.path)")
        }
        
        if !exists {
            // Try to create directory
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                throw CLIError.fileSystem("Cannot create output directory: \(directory.path) - \(error.localizedDescription)")
            }
        }
        
        // Check if we can write to the directory
        if !FileManager.default.isWritableFile(atPath: directory.path) {
            throw CLIError.fileSystem("No write permission for directory: \(directory.path)")
        }
    }
    
    private func validateRenderingModeConsistency(_ command: IconGeneratorCommand) throws {
        // Validate that rendering mode and color arguments are consistent
        switch command.renderingMode {
        case "palette":
            // Ensure all palette colors are provided
            if command.palettePrimary.isEmpty || command.paletteSecondary.isEmpty || command.paletteTertiary.isEmpty {
                throw CLIError.configurationError("Palette rendering mode requires all three palette colors (--palette-primary, --palette-secondary, --palette-tertiary)")
            }
        case "hierarchical":
            // Hierarchical should have hierarchical color
            if command.hierarchicalColor.isEmpty {
                throw CLIError.configurationError("Hierarchical rendering mode should specify --hierarchical-color")
            }
        default:
            break
        }
    }
    
    // MARK: - Enhanced Settings Builder
    
    private func buildIconSettings(from command: IconGeneratorCommand) throws -> IconSettings {
        var settings = IconSettings()
        settings.backgroundMode = .custom
        
        do {
            // Basic properties with validation
            settings.symbolName = command.symbolName
            settings.exportSize = CGFloat(command.size)
            settings.exportRetinaSize = command.retina
            settings.exportColorSpace = try parseColorSpace(command.colorSpace)
            
            // Background colors with enhanced parsing
            settings.baseColor = try ColorParser.parse(command.baseColor)
            settings.useCustomColors = command.useCustomColors
            
            if command.useCustomColors {
                if let primary = command.customPrimary {
                    settings.customPrimaryColor = try ColorParser.parse(primary)
                } else {
                    // Use base color as fallback
                    settings.customPrimaryColor = settings.baseColor
                }
                
                if let secondary = command.customSecondary {
                    settings.customSecondaryColor = try ColorParser.parse(secondary)
                } else {
                    // Create a darker version of primary as fallback
                    settings.customSecondaryColor = createDarkerColor(settings.customPrimaryColor)
                }
            }
            
            // Symbol rendering with mode-specific validation
            settings.symbolRenderingMode = try parseRenderingMode(command.renderingMode)
            settings.symbolColor = try ColorParser.parse(command.symbolColor)
            settings.hierarchicalSymbolColor = try ColorParser.parse(command.hierarchicalColor)
            settings.paletteSymbolPrimaryColor = try ColorParser.parse(command.palettePrimary)
            settings.paletteSymbolSecondaryColor = try ColorParser.parseWithOpacity(command.paletteSecondary)
            settings.paletteSymbolTertiaryColor = try ColorParser.parseWithOpacity(command.paletteTertiary)
            
            // Shadow settings
            settings.backgroundShadowStyle = command.noBackgroundShadow ? .off : .macOS26
            settings.enableSymbolShadow = !command.noSymbolShadow
            
            // Badge settings with comprehensive validation
            if let badgeSymbol = command.badge {
                try validateSFSymbolExists(badgeSymbol) // Validate badge symbol exists
                
                settings.showBadge = true
                settings.badgeSymbolName = badgeSymbol
                settings.badgePosition = try parseBadgePosition(command.badgePosition)
                settings.badgeBaseColor = try ColorParser.parse(command.badgeColor)
                settings.badgeUseCustomColors = command.badgeUseCustom
                
                if command.badgeUseCustom {
                    settings.badgeCustomPrimaryColor = try ColorParser.parse(command.badgePrimary)
                    settings.badgeCustomSecondaryColor = try ColorParser.parse(command.badgeSecondary)
                }
                
                settings.badgeSymbolRenderingMode = try parseRenderingMode(command.badgeRendering)
                settings.badgeSymbolColor = try ColorParser.parse(command.badgeSymbolColor)
                settings.badgeHierarchicalSymbolColor = try ColorParser.parse(command.badgeSymbolColor)
                
                // Set badge palette colors (using main palette colors as defaults if badge uses palette mode)
                if command.badgeRendering == "palette" {
                    settings.badgePaletteSymbolPrimaryColor = settings.paletteSymbolPrimaryColor
                    settings.badgePaletteSymbolSecondaryColor = settings.paletteSymbolSecondaryColor
                    settings.badgePaletteSymbolTertiaryColor = settings.paletteSymbolTertiaryColor
                }
            }
            
        } catch let error as ColorParseError {
            throw CLIError.invalidColorFormat("Color parsing error: \(error.localizedDescription)")
        }
        
        return settings
    }
    
    // MARK: - Enhanced Rendering
    
    private func renderIconWithErrorHandling(settings: IconSettings) async throws -> NSImage {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let image = IconRenderer.renderIconSafely(settings: settings)
                
                // Validate the rendered image
                guard image.size.width > 0 && image.size.height > 0 else {
                    continuation.resume(throwing: CLIError.renderingError("Generated image has invalid dimensions"))
                    return
                }
                
                // Validate image has content
                guard image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil else {
                    continuation.resume(throwing: CLIError.renderingError("Failed to generate valid image content"))
                    return
                }
                
                continuation.resume(returning: image)
            }
        }
    }
    
    // MARK: - Enhanced File Operations
    
    private func resolveOutputPath(symbolName: String, userPath: String?) throws -> URL {
        if let userPath = userPath {
            let url = URL(fileURLWithPath: userPath)
            
            // Ensure it has .png extension
            if url.pathExtension.lowercased() != "png" {
                throw CLIError.fileSystem("Output file must have .png extension: \(userPath)")
            }
            
            return url
        }
        
        // Create safe filename from symbol name
        let sanitized = symbolName
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        return URL(fileURLWithPath: "./\(sanitized).png")
    }
    
    private func saveImageWithValidation(_ image: NSImage, to url: URL, settings: IconSettings) async throws {
        // Prepare PNG data with proper settings
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw CLIError.imageConversion("Failed to create bitmap representation of rendered image")
        }
        
        // Set bitmap properties based on settings
        bitmap.size = NSSize(width: settings.exportSize, height: settings.exportSize)
        
        // Configure PNG properties
        var pngProperties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        
        // Set DPI based on retina setting
        if settings.exportRetinaSize {
            pngProperties[.compressionFactor] = NSNumber(value: 0.9) // High quality
        }
        
        guard let pngData = bitmap.representation(using: .png, properties: pngProperties) else {
            throw CLIError.imageConversion("Failed to convert image to PNG format")
        }
        
        // Validate PNG data
        guard pngData.count > 0 else {
            throw CLIError.imageConversion("Generated PNG data is empty")
        }
        
        // Create directory if needed
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                throw CLIError.fileSystem("Cannot create output directory: \(directory.path) - \(error.localizedDescription)")
            }
        }
        
        // Write file atomically
        do {
            try pngData.write(to: url, options: .atomic)
        } catch {
            throw CLIError.fileSystem("Cannot write file to \(url.path): \(error.localizedDescription)")
        }
        
        // Verify file was written successfully
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CLIError.fileSystem("File was not created successfully: \(url.path)")
        }
        
        // Verify file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber, fileSize.intValue == 0 {
                throw CLIError.fileSystem("Created file is empty: \(url.path)")
            }
        } catch {
            throw CLIError.fileSystem("Cannot verify created file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Enhanced Parsing Helpers
    
    private func parseColorSpace(_ input: String) throws -> ExportColorSpace {
        switch input.lowercased() {
        case "srgb": return .sRGB
        case "displayp3": return .displayP3
        default: 
            throw CLIError.invalidArgument("Invalid color space: \(input). Must be 'sRGB' or 'displayP3'")
        }
    }
    
    private func parseRenderingMode(_ input: String) throws -> SymbolRenderingMode {
        switch input.lowercased() {
        case "monochrome": return .monochrome
        case "hierarchical": return .hierarchical
        case "multicolor": return .multicolor
        case "palette": return .palette
        default: 
            throw CLIError.invalidArgument("Invalid rendering mode: \(input). Must be 'monochrome', 'hierarchical', 'multicolor', or 'palette'")
        }
    }
    
    private func parseBadgePosition(_ input: String) throws -> BadgePosition {
        switch input.lowercased() {
        case "top-left": return .topLeft
        case "top-right": return .topRight
        case "bottom-left": return .bottomLeft
        case "bottom-right": return .bottomRight
        default: 
            throw CLIError.invalidArgument("Invalid badge position: \(input). Must be 'top-left', 'top-right', 'bottom-left', or 'bottom-right'")
        }
    }
    
    // MARK: - Utility Methods
    
    private func createDarkerColor(_ color: Color) -> Color {
        // Convert to NSColor and create a darker version
        let nsColor = NSColor(color)
        let darkerColor = NSColor(
            hue: nsColor.hueComponent,
            saturation: nsColor.saturationComponent,
            brightness: nsColor.brightnessComponent * 0.7,
            alpha: nsColor.alphaComponent
        )
        return Color(darkerColor)
    }
    
    // MARK: - Progress and Error Reporting
    
    private func reportSuccess(outputURL: URL, settings: IconSettings) {
        let fileSize = getFileSize(outputURL)
        let dimensions = settings.exportRetinaSize ? 
            "\(Int(settings.exportSize * 2))x\(Int(settings.exportSize * 2))" : 
            "\(Int(settings.exportSize))x\(Int(settings.exportSize))"
        
        print("✅ Icon generated successfully!")
        print("   📄 File: \(outputURL.path)")
        print("   📐 Size: \(dimensions) pixels")
        print("   🎨 Mode: \(settings.symbolRenderingMode.rawValue)")
        print("   💾 File size: \(fileSize)")
        
        if settings.showBadge {
            print("   🏷️  Badge: \(settings.badgeSymbolName)")
        }
    }
    
    private func getFileSize(_ url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber {
                let bytes = fileSize.intValue
                if bytes < 1024 {
                    return "\(bytes) bytes"
                } else if bytes < 1024 * 1024 {
                    return String(format: "%.1f KB", Double(bytes) / 1024.0)
                } else {
                    return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
                }
            }
        } catch {
            return "unknown size"
        }
        return "unknown size"
    }
    
    private func handleCLIError(_ error: CLIError, phase: GenerationPhase) {
        print("❌ Error during \(phase): \(error.localizedDescription)")
    }
    
    private func handleColorError(_ error: ColorParseError, phase: GenerationPhase) {
        print("❌ Color parsing error during \(phase): \(error.localizedDescription)")
    }
    
    private func handleUnexpectedError(_ error: Error, phase: GenerationPhase) {
        print("❌ Unexpected error during \(phase): \(error.localizedDescription)")
    }
    
    // MARK: - Testing Support Methods
    
    /// Expose buildIconSettings for testing
    func buildTestSettings(from command: IconGeneratorCommand) throws -> IconSettings {
        return try buildIconSettings(from: command)
    }
    
    /// Expose resolveOutputPath for testing
    func testResolveOutputPath(symbolName: String, userPath: String?) throws -> URL {
        return try resolveOutputPath(symbolName: symbolName, userPath: userPath)
    }
}

// MARK: - Enhanced Error Types

enum CLIError: LocalizedError {
    case imageConversion(String)
    case invalidSymbol(String)
    case fileSystem(String)
    case invalidColorFormat(String)
    case invalidArgument(String)
    case configurationError(String)
    case renderingError(String)
    case unexpectedError(String)
    
    var errorDescription: String? {
        switch self {
        case .imageConversion(let message):
            return "Image conversion error: \(message)"
        case .invalidSymbol(let symbol):
            return "Invalid SF Symbol: \(symbol)"
        case .fileSystem(let message):
            return "File system error: \(message)"
        case .invalidColorFormat(let message):
            return "Invalid color format: \(message)"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .renderingError(let message):
            return "Rendering error: \(message)"
        case .unexpectedError(let message):
            return "Unexpected error: \(message)"
        }
    }
}
