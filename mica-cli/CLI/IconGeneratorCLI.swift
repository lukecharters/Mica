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
            // Phase 1: Validation
            currentPhase = .validation
            try await performEnhancedValidation(command)

            // Phase 2: Build settings
            currentPhase = .settingsBuilding
            let settings = try buildIconSettings(from: command)

            // Phase 3: Render
            currentPhase = .rendering
            let image: NSImage

            if command.generation.resolvedIconMode == "apple-reference" {
                image = try await renderAppleReference(command: command, settings: settings)
            } else {
                // Load badge appex image if badge uses apple-reference source.
                // `let` keeps this in a disconnected region so it can be sent
                // into the @MainActor render task (NSImage is non-Sendable).
                let badgeAppexImage: NSImage? = (settings.showBadge && settings.badgeIconSource == .appleReference)
                    ? try renderAppexIcon(
                        symbolName: settings.badgeSymbolName,
                        enclosureColor: command.badge.badgeAppexEnclosureColor,
                        symbolColor: command.badge.badgeAppexSymbolColor,
                        settings: settings
                    )
                    : nil
                image = try await renderIconWithErrorHandling(settings: settings, badgeAppexImage: badgeAppexImage)
            }

            // Phase 4: Save
            currentPhase = .saving
            let outputURL = try resolveOutputPath(symbolName: command.symbolName, userPath: command.export.outputPath)
            try await saveImageWithValidation(image, to: outputURL, settings: settings)

            // Phase 5: Report
            currentPhase = .complete
            reportSuccess(outputURL: outputURL, settings: settings, generationMode: command.generation.resolvedIconMode)

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

    // MARK: - Apple Reference Rendering

    private func renderAppleReference(command: IconGeneratorCommand, settings: IconSettings) async throws -> NSImage {
        let appexPath = "/System/Library/ExtensionKit/Extensions/Storage.appex"
        guard FileManager.default.fileExists(atPath: appexPath) else {
            throw CLIError.renderingError("Apple Reference mode requires Storage.appex at \(appexPath). This file is not available on this system.")
        }

        let scaleFactor = settings.exportRetinaSize ? 2 : 1
        let appexImage = try AppexReferenceService.renderForExport(
            symbolName: command.symbolName,
            enclosureColor: command.generation.appexEnclosureColor,
            symbolColor: command.generation.appexSymbolColor,
            pointSize: settings.exportSize,
            scaleFactor: scaleFactor,
            colorSpace: settings.exportColorSpace
        )

        // If badge is present, composite via renderAppexWithBadge
        if settings.showBadge {
            // `let` keeps this in a disconnected region so it can be sent
            // into the @MainActor render task (NSImage is non-Sendable).
            let badgeAppexImage: NSImage? = settings.badgeIconSource == .appleReference
                ? try renderAppexIcon(
                    symbolName: settings.badgeSymbolName,
                    enclosureColor: command.badge.badgeAppexEnclosureColor,
                    symbolColor: command.badge.badgeAppexSymbolColor,
                    settings: settings
                )
                : nil
            return try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    let composited = IconRenderer.renderAppexWithBadge(
                        appexImage: appexImage,
                        settings: settings,
                        badgeAppexImage: badgeAppexImage
                    )
                    continuation.resume(returning: composited)
                }
            }
        }

        return appexImage
    }

    /// `enclosureColor` / `symbolColor` are already-resolved plist values
    /// (named token or `r,g,b,a` string) produced by the argument transforms.
    private func renderAppexIcon(symbolName: String, enclosureColor: String, symbolColor: String, settings: IconSettings) throws -> NSImage {
        let scaleFactor = settings.exportRetinaSize ? 2 : 1
        return try AppexReferenceService.renderForExport(
            symbolName: symbolName,
            enclosureColor: enclosureColor,
            symbolColor: symbolColor,
            pointSize: settings.exportSize,
            scaleFactor: scaleFactor,
            colorSpace: settings.exportColorSpace
        )
    }

    // MARK: - Enhanced Validation
    
    private func performEnhancedValidation(_ command: IconGeneratorCommand) async throws {
        // Validate SF Symbol exists (only when using SF Symbol source)
        if command.generation.iconSource == "symbol" {
            try validateSFSymbolExists(command.symbolName)
        }

        // Validate badge symbol exists (only when badge uses SF Symbol source)
        if let badgeName = command.badge.badge, command.badge.badgeIconSource == "symbol" {
            try validateSFSymbolExists(badgeName)
        }

        // Pre-validate all color strings with context
        try validateAllColors(command)

        // Validate file system permissions
        if let outputPath = command.export.outputPath {
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
            (command.background.baseColor, "base-color", true),
            (command.symbol.symbolColor, "symbol-color", true),
            (command.symbol.hierarchicalColor, "hierarchical-color", command.symbol.renderingMode == "hierarchical"),
            (command.symbol.palettePrimary, "palette-primary", command.symbol.renderingMode == "palette"),
            (command.symbol.paletteSecondary, "palette-secondary", command.symbol.renderingMode == "palette"),
            (command.symbol.paletteTertiary, "palette-tertiary", command.symbol.renderingMode == "palette"),
            (command.badge.badgeColor, "badge-color", command.badge.badge != nil),
            (command.badge.badgeSymbolColor, "badge-symbol-color", command.badge.badge != nil)
        ]

        var allValidations = colorValidations
        if let primary = command.background.customPrimary {
            allValidations.append((primary, "custom-primary", command.background.useCustomColors))
        }
        if let secondary = command.background.customSecondary {
            allValidations.append((secondary, "custom-secondary", command.background.useCustomColors))
        }
        if command.badge.badgeUseCustom {
            allValidations.append((command.badge.badgePrimary, "badge-primary", true))
            allValidations.append((command.badge.badgeSecondary, "badge-secondary", true))
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
        switch command.symbol.renderingMode {
        case "palette":
            if command.symbol.palettePrimary.isEmpty || command.symbol.paletteSecondary.isEmpty || command.symbol.paletteTertiary.isEmpty {
                throw CLIError.configurationError("Palette rendering mode requires all three palette colors (--palette-primary, --palette-secondary, --palette-tertiary)")
            }
        case "hierarchical":
            if command.symbol.hierarchicalColor.isEmpty {
                throw CLIError.configurationError("Hierarchical rendering mode should specify --hierarchical-color")
            }
        default:
            break
        }
    }
    
    // MARK: - Enhanced Settings Builder
    
    private func buildIconSettings(from command: IconGeneratorCommand) throws -> IconSettings {
        var settings = IconSettings()

        do {
            // Export properties
            settings.symbolName = command.symbolName
            settings.exportSize = CGFloat(command.export.size)
            settings.exportRetinaSize = command.export.retina
            settings.exportColorSpace = try parseColorSpace(command.export.colorSpace)

            // Icon source
            switch command.generation.iconSource {
            case "image":
                settings.iconSource = .customImage
                if let path = command.generation.importedImage {
                    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                    settings.importedImage = try ImageImportService.importFromURL(url)
                    settings.importedImageScale = command.generation.importedImageScale
                }
            default:
                settings.iconSource = .sfSymbol
            }

            // Background mode
            switch command.background.backgroundMode {
            case "image":
                settings.backgroundMode = .importedImage
                if let path = command.background.importedBackground {
                    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                    settings.importedBackground = try ImageImportService.importFromURL(url)
                    settings.importedBackgroundScale = command.background.importedBackgroundScale
                    settings.importedBackgroundPaddingCompensation = command.background.effectivePaddingCompensation
                }
            default:
                settings.backgroundMode = .custom
            }

            // Background colors
            settings.baseColor = try ColorParser.parse(command.background.baseColor)
            settings.useCustomColors = command.background.useCustomColors

            if command.background.useCustomColors {
                if let primary = command.background.customPrimary {
                    settings.customPrimaryColor = try ColorParser.parse(primary)
                } else {
                    settings.customPrimaryColor = settings.baseColor
                }
                if let secondary = command.background.customSecondary {
                    settings.customSecondaryColor = try ColorParser.parse(secondary)
                } else {
                    settings.customSecondaryColor = createDarkerColor(settings.customPrimaryColor)
                }
            }

            // Background style
            settings.enableBackgroundGradient = !command.background.noGradient
            settings.cornerRadiusStyle = try parseCornerRadius(command.background.cornerRadius)
            settings.backgroundShadowStyle = try parseShadowStyle(command.background.effectiveShadowStyle)

            // Symbol rendering
            settings.symbolRenderingMode = try parseRenderingMode(command.symbol.renderingMode)
            settings.symbolColor = try ColorParser.parse(command.symbol.symbolColor)
            settings.hierarchicalSymbolColor = try ColorParser.parse(command.symbol.hierarchicalColor)
            settings.paletteSymbolPrimaryColor = try ColorParser.parse(command.symbol.palettePrimary)
            settings.paletteSymbolSecondaryColor = try ColorParser.parseWithOpacity(command.symbol.paletteSecondary)
            settings.paletteSymbolTertiaryColor = try ColorParser.parseWithOpacity(command.symbol.paletteTertiary)

            // Symbol style
            settings.enableSymbolShadow = command.symbol.symbolShadow ?? (command.generation.iconSource == "image" ? false : true)
            settings.symbolWeight = try parseSymbolWeight(command.symbol.symbolWeight)
            settings.manualSymbolScale = command.symbol.symbolScale
            settings.symbolColorRenderingMode = try parseSymbolColorRendering(command.symbol.symbolColorRendering)

            // Badge settings
            if let badgeSymbol = command.badge.badge {
                settings.showBadge = true
                settings.badgeSymbolName = badgeSymbol
                settings.badgePosition = try parseBadgePosition(command.badge.badgePosition)

                // Badge layout
                settings.badgeScale = command.badge.badgeScale
                settings.badgeSymbolScale = command.badge.badgeSymbolScale
                settings.badgeManualOffsetX = command.badge.badgeOffsetX
                settings.badgeManualOffsetY = command.badge.badgeOffsetY

                // Badge background
                settings.badgeBaseColor = try ColorParser.parse(command.badge.badgeColor)
                settings.badgeUseCustomColors = command.badge.badgeUseCustom
                if command.badge.badgeUseCustom {
                    settings.badgeCustomPrimaryColor = try ColorParser.parse(command.badge.badgePrimary)
                    settings.badgeCustomSecondaryColor = try ColorParser.parse(command.badge.badgeSecondary)
                }
                settings.badgeEnableBackgroundGradient = !command.badge.badgeNoGradient
                settings.badgeEnableBackgroundShadow = command.badge.badgeBackgroundShadow ?? (command.badge.badgeImportedBackground != nil ? false : true)
                settings.badgeEnableSymbolShadow = command.badge.badgeSymbolShadow ?? (command.badge.badgeIconSource == "image" ? false : true)

                // Badge symbol rendering
                settings.badgeSymbolRenderingMode = try parseRenderingMode(command.badge.badgeRendering)
                settings.badgeSymbolColor = try ColorParser.parse(command.badge.badgeSymbolColor)
                settings.badgeHierarchicalSymbolColor = try ColorParser.parse(command.badge.badgeHierarchicalColor)
                settings.badgePaletteSymbolPrimaryColor = try ColorParser.parse(command.badge.badgePalettePrimary)
                settings.badgePaletteSymbolSecondaryColor = try ColorParser.parseWithOpacity(command.badge.badgePaletteSecondary)
                settings.badgePaletteSymbolTertiaryColor = try ColorParser.parseWithOpacity(command.badge.badgePaletteTertiary)
                settings.badgeSymbolWeight = try parseSymbolWeight(command.badge.badgeSymbolWeight)
                settings.badgeSymbolColorRenderingMode = try parseSymbolColorRendering(command.badge.badgeSymbolColorRendering)

                // Badge icon source
                switch command.badge.badgeIconSource {
                case "image":
                    settings.badgeIconSource = .customImage
                    if let path = command.badge.badgeImportedImage {
                        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                        settings.badgeImportedImage = try ImageImportService.importFromURL(url)
                        settings.badgeImportedImageScale = command.badge.badgeImportedImageScale
                    }
                case "apple-reference":
                    settings.badgeIconSource = .appleReference
                default:
                    settings.badgeIconSource = .sfSymbol
                }

                // Per-group generation modes. `--icon-mode` / `--badge-mode` win
                // over the legacy `--generation-mode`; --badge-mode also overrides
                // an explicit --badge-source value.
                settings.iconGenerationMode = command.generation.resolvedIconMode == "apple-reference" ? .appleReference : .swiftUI
                if command.generation.resolvedBadgeMode == "apple-reference" {
                    settings.badgeIconSource = .appleReference
                }

                // Badge imported background
                if let path = command.badge.badgeImportedBackground {
                    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                    settings.badgeUseImportedBackground = true
                    settings.badgeImportedBackground = try ImageImportService.importFromURL(url)
                    settings.badgeImportedBackgroundScale = command.badge.badgeImportedBackgroundScale
                    settings.badgeImportedBackgroundPaddingCompensation = command.badge.effectiveBadgePaddingCompensation
                }
            }

        } catch let error as ColorParseError {
            throw CLIError.invalidColorFormat("Color parsing error: \(error.localizedDescription)")
        } catch let error as ImageImportError {
            throw CLIError.imageConversion("Image import error: \(error.localizedDescription)")
        }

        return settings
    }
    
    // MARK: - Enhanced Rendering
    
    // Rendering is genuinely main-actor-bound (IconRenderer.renderIconSafely
    // drives SwiftUI's ImageRenderer), so this hops to the main actor directly
    // rather than bridging through a continuation + detached Task. The caller
    // awaits the actor hop; `sending` transfers ownership of the non-Sendable
    // badge image across the isolation boundary.
    @MainActor
    private func renderIconWithErrorHandling(settings: IconSettings, badgeAppexImage: sending NSImage? = nil) throws -> NSImage {
        let image = IconRenderer.renderIconSafely(settings: settings, badgeAppexImage: badgeAppexImage)

        guard image.size.width > 0 && image.size.height > 0 else {
            throw CLIError.renderingError("Generated image has invalid dimensions")
        }
        guard image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil else {
            throw CLIError.renderingError("Failed to generate valid image content")
        }
        return image
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

    private func parseCornerRadius(_ input: String) throws -> IconCornerRadiusStyle {
        switch input.lowercased() {
        case "macos11": return .macOS11
        case "macos26": return .macOS26
        default:
            throw CLIError.invalidArgument("Invalid corner radius: \(input). Must be 'macos11' or 'macos26'")
        }
    }

    private func parseShadowStyle(_ input: String) throws -> BackgroundShadowStyle {
        switch input.lowercased() {
        case "off": return .off
        case "macos11": return .sequoia
        case "macos26": return .macOS26
        default:
            throw CLIError.invalidArgument("Invalid shadow style: \(input). Must be 'off', 'macos11', or 'macos26'")
        }
    }

    private func parseSymbolWeight(_ input: String) throws -> SymbolWeight {
        switch input.lowercased() {
        case "auto": return .auto
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default:
            throw CLIError.invalidArgument("Invalid symbol weight: \(input). Must be one of: auto, ultralight, thin, light, regular, medium, semibold, bold, heavy, black")
        }
    }

    private func parseSymbolColorRendering(_ input: String) throws -> SymbolColorRenderingMode {
        switch input.lowercased() {
        case "flat": return .flat
        case "gradient": return .gradient
        default:
            throw CLIError.invalidArgument("Invalid symbol color rendering: \(input). Must be 'flat' or 'gradient'")
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
    
    private func reportSuccess(outputURL: URL, settings: IconSettings, generationMode: String = "custom") {
        let fileSize = getFileSize(outputURL)
        let dimensions = settings.exportRetinaSize ?
            "\(Int(settings.exportSize * 2))x\(Int(settings.exportSize * 2))" :
            "\(Int(settings.exportSize))x\(Int(settings.exportSize))"

        print("Icon generated successfully!")
        print("  File: \(outputURL.path)")
        print("  Size: \(dimensions) pixels")
        if generationMode == "apple-reference" {
            print("  Mode: Apple Reference")
        } else {
            print("  Rendering: \(settings.symbolRenderingMode.rawValue)")
        }
        print("  File size: \(fileSize)")

        if settings.showBadge {
            print("  Badge: \(settings.badgeSymbolName)")
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
