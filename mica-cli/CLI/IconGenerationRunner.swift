import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Runs one generation: takes an already-parsed `GenerateCommand`, validates it,
/// builds the `IconSettings`, renders through `IconRenderer` and writes the PNG.
/// It parses nothing and owns no command-line surface — `GenerateCommand` does that.
class IconGenerationRunner {

    // MARK: - Main Generation Method

    /// Render and save the icon, returning a description of the produced file.
    /// Diagnostics go through `reporter` (verbose phase detail to stderr); the
    /// caller is responsible for the success/error reporting and exit code.
    func generateIcon(from command: GenerateCommand, reporter: OutputReporter) async throws -> OutputFileJSON {
        // Phase 1: Validation
        reporter.detail("Validating…")
        try await performEnhancedValidation(command)

        // Phase 2: Build settings
        reporter.detail("Building settings…")
        let settings = try buildIconSettings(from: command)

        // Phase 3: Render
        let image: NSImage

        if command.generation.effectiveIconMode == .system {
            reporter.detail("Rendering via the Apple Reference (appex) pipeline…")
            image = try await renderAppleReference(command: command, settings: settings)
        } else {
            reporter.detail("Rendering…")
            // Load badge appex image if badge uses the System (appex) source.
            // `let` keeps this in a disconnected region so it can be sent
            // into the @MainActor render task (NSImage is non-Sendable).
            let badgeAppexImage: NSImage? = (settings.badge.isVisible && settings.badge.foreground.source == .system)
                ? try renderAppexIcon(
                    symbolName: settings.badge.foreground.symbolName,
                    enclosureColor: command.resolvedBadgeAppexEnclosureColor(),
                    symbolColor: command.resolvedBadgeAppexSymbolColor(),
                    settings: settings
                )
                : nil
            image = try await renderIconWithErrorHandling(settings: settings, badgeAppexImage: badgeAppexImage)
        }

        // Phase 4: Save
        let outputURL = try resolveOutputPath(basename: command.defaultOutputBasename(), userPath: command.export.outputPath)
        reporter.detail("Saving to \(outputURL.path)…")
        let pixelSize = try await saveImageWithValidation(image, to: outputURL, settings: settings)

        // Phase 5: Describe the result. Reports the dimensions actually measured
        // off the file rather than restating the request, so a rendering bug
        // shows up in the output instead of being papered over.
        return OutputFileJSON(
            path: outputURL.path,
            width: pixelSize.width,
            height: pixelSize.height,
            bytes: fileByteCount(outputURL),
            source: command.defaultOutputBasename()
        )
    }

    // MARK: - Apple Reference Rendering

    private func renderAppleReference(command: GenerateCommand, settings: IconSettings) async throws -> NSImage {
        let appexPath = "/System/Library/ExtensionKit/Extensions/Storage.appex"
        guard FileManager.default.fileExists(atPath: appexPath) else {
            throw CLIError.renderingError("Apple Reference mode requires Storage.appex at \(appexPath). This file is not available on this system.")
        }

        // System mode renders an SF Symbol via the appex pipeline; image
        // foregrounds are only supported in mica mode.
        let foregroundSymbol: String
        switch try command.resolvedForeground() {
        case .symbol(let name):
            foregroundSymbol = name
        case .image:
            throw CLIError.configurationError("System generation mode (--icon-generation-mode system) requires an SF Symbol foreground; image foregrounds are only supported in mica mode.")
        }

        // In system mode --icon-symbol-color and --icon-bg-color resolve to appex
        // colour tokens (symbol + enclosure).
        let appexSymbolColor = try AppexColor.plistValue(fromCLIString: command.iconForeground.symbolColor ?? "white")
        let appexEnclosureColor = try AppexColor.plistValue(fromCLIString: command.background.color ?? "blue")

        let scaleFactor = settings.export.isRetina ? 2 : 1
        let appexImage = try AppexReferenceService.renderForExport(
            symbolName: foregroundSymbol,
            enclosureColor: appexEnclosureColor,
            symbolColor: appexSymbolColor,
            pointSize: settings.export.size,
            scaleFactor: scaleFactor,
            colorSpace: settings.export.colorSpace
        )

        // If badge is present, composite via renderAppexWithBadge
        if settings.badge.isVisible {
            // `let` keeps this in a disconnected region so it can be sent
            // into the @MainActor render task (NSImage is non-Sendable).
            let badgeAppexImage: NSImage? = settings.badge.foreground.source == .system
                ? try renderAppexIcon(
                    symbolName: settings.badge.foreground.symbolName,
                    enclosureColor: command.resolvedBadgeAppexEnclosureColor(),
                    symbolColor: command.resolvedBadgeAppexSymbolColor(),
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
        let scaleFactor = settings.export.isRetina ? 2 : 1
        return try AppexReferenceService.renderForExport(
            symbolName: symbolName,
            enclosureColor: enclosureColor,
            symbolColor: symbolColor,
            pointSize: settings.export.size,
            scaleFactor: scaleFactor,
            colorSpace: settings.export.colorSpace
        )
    }

    // MARK: - Enhanced Validation
    
    private func performEnhancedValidation(_ command: GenerateCommand) async throws {
        // Validate SF Symbol exists (only when the foreground is an SF Symbol)
        if case .symbol(let name) = try command.resolvedForeground() {
            try validateSFSymbolExists(name)
        }

        // Validate badge symbol exists (only when the badge foreground is an SF Symbol)
        if case .symbol(let name)? = try command.resolvedBadgeForeground() {
            try validateSFSymbolExists(name)
        }

        // Color strings are validated once, in the command layer
        // (GenerateCommand.validateColorFormats) — it runs before this
        // method, covers System-mode appex tokens too, and previously had a
        // near-verbatim (dead) duplicate here that had started to drift.

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
    
    private func validateOutputPermissions(_ outputPath: String) throws {
        // Expand ~ — must agree with resolveOutputPath, or this creates (and
        // validates) a literal ./~ directory instead of the real destination.
        let url = URL(fileURLWithPath: (outputPath as NSString).expandingTildeInPath)
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
    
    private func validateRenderingModeConsistency(_ command: GenerateCommand) throws {
        if command.iconForeground.symbolRendering == "palette",
           let palette = command.iconForeground.symbolPalette {
            // Enforce exactly three palette components.
            _ = try splitPalette(palette, role: "--icon-symbol-palette")
        }
        if command.badgeIsActive, command.badge.symbolRendering == "palette",
           let palette = command.badge.symbolPalette {
            _ = try splitPalette(palette, role: "--badge-symbol-palette")
        }
    }
    
    // MARK: - Enhanced Settings Builder
    
    private func buildIconSettings(from command: GenerateCommand) throws -> IconSettings {
        var settings = IconSettings()

        do {
            // Export properties. Each flag is Optional and assigned only when
            // passed, so an absent flag leaves whatever is already in
            // `settings` — the ExportSpec default today, and a `--config`
            // document's value once Phase 5 lands.
            if let size = command.export.size {
                settings.export.size = CGFloat(size)
            }
            if let scale = command.export.scale {
                settings.export.isRetina = scale.factor == 2
            }
            if let colorSpace = command.export.colorSpace {
                settings.export.colorSpace = colorSpace
            }

            // Icon foreground source (folds --icon-fg + --icon-fg-scale)
            switch try command.resolvedForeground() {
            case .symbol(let name):
                settings.icon.foreground.source = .symbol
                settings.icon.foreground.symbolName = name
                if let scale = command.iconForeground.scale {
                    settings.icon.foreground.symbolScale = scale
                }
            case .image(let path):
                settings.icon.foreground.source = .image
                // symbolName is cosmetic for image foregrounds; use the basename.
                settings.icon.foreground.symbolName = command.defaultOutputBasename()
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                settings.icon.foreground.image = try ImageImportService.importFromURL(url)
                if let scale = command.iconForeground.scale {
                    settings.icon.foreground.imageScale = scale
                }
            }

            // Icon background (folds --icon-bg + --icon-bg-color + gradient-colors + scale + padding)
            switch command.resolvedBackground() {
            case .standard:
                settings.icon.background.source = .color
                settings.icon.background.usesCustomGradient = false
                // In system mode the enclosure colour is resolved separately in
                // renderAppleReference, so leave the SwiftUI base colour default.
                if command.generation.effectiveIconMode != .system {
                    settings.icon.background.color = try ColorParser.parseWithOpacity(command.background.color ?? "blue")
                }
            case .customGradient:
                settings.icon.background.source = .color
                settings.icon.background.usesCustomGradient = true
                let parts = try splitGradientColors(command.background.gradientColors ?? "blue,purple")
                settings.icon.background.gradientStartColor = try ColorParser.parseWithOpacity(parts[0])
                settings.icon.background.gradientEndColor = try ColorParser.parseWithOpacity(parts[1])
                settings.icon.background.color = settings.icon.background.gradientStartColor
            case .preRendered:
                settings.icon.background.source = .preRendered
                // preRenderedAssetName lowercases this when building the asset name.
                settings.icon.background.preRenderedColorName = normalizeBritishSpelling(command.background.color ?? "blue")
            case .image(let path):
                settings.icon.background.source = .image
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                settings.icon.background.image = try ImageImportService.importFromURL(url)
                if let scale = command.background.scale {
                    settings.icon.background.imageScale = scale
                }
                settings.icon.background.compensatesForPadding = command.background.effectivePaddingCompensation
            }

            // Background style
            if let gradient = command.background.gradient {
                settings.icon.background.usesGradient = gradient.isOn
            }
            if let cornerRadius = command.background.cornerRadius {
                settings.icon.background.cornerRadiusStyle = try parseCornerRadius(cornerRadius)
            }
            settings.icon.background.shadowStyle = try parseShadowStyle(command.background.effectiveShadowStyle)

            // Background visibility (new --icon-bg-visibility → iconBackgroundHidden)
            if let visibility = command.background.visibility {
                settings.icon.background.isHidden = !visibility.isOn
            }

            // Symbol rendering
            if let symbolRendering = command.iconForeground.symbolRendering {
                settings.icon.foreground.renderingStyle = try parseRenderingMode(symbolRendering)
            }

            let isImageForeground = settings.icon.foreground.source == .image

            // Merged --icon-symbol-color. In mica mode it drives the SwiftUI
            // symbol/hierarchical/multicolor tint; in system mode the colour is
            // resolved as an appex token in renderAppleReference, so the SwiftUI
            // colour is left at its (unused) default here.
            if command.generation.effectiveIconMode != .system {
                let parsed = try ColorParser.parseWithOpacity(command.iconForeground.symbolColor ?? "white")
                settings.icon.foreground.color = parsed
                settings.icon.foreground.hierarchicalColor = parsed
            }

            // Palette colours (folds --palette-primary/secondary/tertiary).
            let paletteParts = try splitPalette(
                command.iconForeground.symbolPalette ?? "white,white:0.5,white:0.26",
                role: "--icon-symbol-palette"
            )
            settings.icon.foreground.palettePrimaryColor = try ColorParser.parseWithOpacity(paletteParts[0])
            settings.icon.foreground.paletteSecondaryColor = try ColorParser.parseWithOpacity(paletteParts[1])
            settings.icon.foreground.paletteTertiaryColor = try ColorParser.parseWithOpacity(paletteParts[2])

            // Symbol style
            settings.icon.foreground.drawsShadow = command.iconForeground.shadow?.isOn ?? (isImageForeground ? false : true)
            if let symbolWeight = command.iconForeground.symbolWeight {
                settings.icon.foreground.symbolWeight = try parseSymbolWeight(symbolWeight)
            }
            if let symbolGradient = command.iconForeground.symbolGradient {
                settings.icon.foreground.fillStyle = symbolGradient.isOn ? .gradient : .flat
            }

            // Foreground visibility (new --icon-fg-visibility → iconForegroundHidden)
            if let visibility = command.iconForeground.visibility {
                settings.icon.foreground.isHidden = !visibility.isOn
            }

            // Icon generation mode (always set, independent of badge presence — the
            // render path reads command.generation.effectiveIconMode directly, but
            // keeping this in sync is correct and avoids a latent quirk).
            settings.icon.mode = command.generation.effectiveIconMode

            // Badge settings — gated on --badge-fg activation.
            if let badgeForeground = try command.resolvedBadgeForeground() {
                // Badge foreground source (folds --badge-fg + --badge-fg-scale).
                let isBadgeImageForeground: Bool
                switch badgeForeground {
                case .symbol(let name):
                    settings.badge.foreground.source = .symbol
                    settings.badge.foreground.symbolName = name
                    if let foregroundScale = command.badge.foregroundScale {
                        settings.badge.foreground.symbolScale = foregroundScale
                    }
                    isBadgeImageForeground = false
                case .image(let path):
                    settings.badge.foreground.source = .image
                    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                    settings.badge.foreground.image = try ImageImportService.importFromURL(url)
                    if let foregroundScale = command.badge.foregroundScale {
                        settings.badge.foreground.imageScale = foregroundScale
                    }
                    isBadgeImageForeground = true
                }

                // Badge background (folds --badge-bg + color + gradient-colors + scale + padding).
                switch command.resolvedBadgeBackground() {
                case .standard:
                    settings.badge.background.source = .color
                    settings.badge.background.usesCustomGradient = false
                    // In system mode the enclosure colour is resolved separately
                    // via the appex pipeline, so leave the SwiftUI base default.
                    if command.generation.effectiveBadgeMode != .system {
                        settings.badge.background.color = try ColorParser.parseWithOpacity(command.badge.backgroundColor ?? "gray")
                    }
                case .customGradient:
                    settings.badge.background.source = .color
                    settings.badge.background.usesCustomGradient = true
                    let parts = try splitGradientColors(command.badge.backgroundGradientColors ?? "white,indigo", role: "--badge-bg-gradient-colors")
                    settings.badge.background.gradientStartColor = try ColorParser.parseWithOpacity(parts[0])
                    settings.badge.background.gradientEndColor = try ColorParser.parseWithOpacity(parts[1])
                    settings.badge.background.color = settings.badge.background.gradientStartColor
                case .image(let path):
                    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                    settings.badge.background.source = .image
                    settings.badge.background.image = try ImageImportService.importFromURL(url)
                    if let backgroundScale = command.badge.backgroundScale {
                        settings.badge.background.imageScale = backgroundScale
                    }
                    settings.badge.background.compensatesForPadding = command.badge.effectiveBackgroundPaddingCompensation
                }

                // Badge background style.
                if let backgroundGradient = command.badge.backgroundGradient {
                    settings.badge.background.usesGradient = backgroundGradient.isOn
                }
                settings.badge.background.drawsShadow = command.badge.backgroundShadow?.isOn ?? (command.badge.isImageBackground ? false : true)

                // Badge layout.
                if let position = command.badge.position {
                    settings.badge.position = try parseBadgePosition(position)
                }
                if let badgeScale = command.badge.scale {
                    settings.badge.scale = badgeScale
                }
                if let offsetX = command.badge.offsetX {
                    settings.badge.offsetX = offsetX
                }
                if let offsetY = command.badge.offsetY {
                    settings.badge.offsetY = offsetY
                }

                // Badge symbol rendering.
                if let symbolRendering = command.badge.symbolRendering {
                    settings.badge.foreground.renderingStyle = try parseRenderingMode(symbolRendering)
                }

                // Merged --badge-symbol-color. In mica mode it drives the SwiftUI
                // symbol/hierarchical/multicolor tint; in system mode the colour is
                // resolved as an appex token, so the SwiftUI colour is left default.
                if command.generation.effectiveBadgeMode != .system {
                    let parsed = try ColorParser.parseWithOpacity(command.badge.symbolColor ?? "white")
                    settings.badge.foreground.color = parsed
                    settings.badge.foreground.hierarchicalColor = parsed
                }

                // Badge palette (folds --badge-palette-primary/secondary/tertiary).
                let badgePaletteParts = try splitPalette(
                    command.badge.symbolPalette ?? "white,white:0.5,white:0.26",
                    role: "--badge-symbol-palette"
                )
                settings.badge.foreground.palettePrimaryColor = try ColorParser.parseWithOpacity(badgePaletteParts[0])
                settings.badge.foreground.paletteSecondaryColor = try ColorParser.parseWithOpacity(badgePaletteParts[1])
                settings.badge.foreground.paletteTertiaryColor = try ColorParser.parseWithOpacity(badgePaletteParts[2])

                if let symbolWeight = command.badge.symbolWeight {
                    settings.badge.foreground.symbolWeight = try parseSymbolWeight(symbolWeight)
                }
                if let symbolGradient = command.badge.symbolGradient {
                    settings.badge.foreground.fillStyle = symbolGradient.isOn ? .gradient : .flat
                }

                // Badge foreground shadow (off for images, on for SF Symbols by default).
                settings.badge.foreground.drawsShadow = command.badge.foregroundShadow?.isOn ?? (isBadgeImageForeground ? false : true)

                // Badge generation mode (system → appex pipeline).
                if command.generation.effectiveBadgeMode == .system {
                    settings.badge.foreground.source = .system
                }

                // Badge layer visibility. Unlike every other flag here this is
                // NOT conditional on the flag being passed: both specs default
                // their layers to hidden, and supplying --badge-fg is what makes
                // the badge appear. So an active badge is visible unless a flag
                // says otherwise — the `?? true` is that activation rule, not a
                // restatement of a spec default.
                settings.badge.foreground.isHidden = !(command.badge.foregroundVisibility?.isOn ?? true)
                settings.badge.background.isHidden = !(command.badge.backgroundVisibility?.isOn ?? true)
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
    
    private func resolveOutputPath(basename: String, userPath: String?) throws -> URL {
        if let userPath = userPath {
            // Expand ~ like every other path the CLI accepts (extract -o, image
            // inputs) — otherwise a quoted '~/…' creates a literal ./~ directory.
            let url = URL(fileURLWithPath: (userPath as NSString).expandingTildeInPath)

            // Ensure it has .png extension
            if url.pathExtension.lowercased() != "png" {
                throw CLIError.fileSystem("Output file must have .png extension: \(userPath)")
            }

            return url
        }

        // Create safe filename from the default basename (symbol name or image basename)
        let sanitized = basename
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        return URL(fileURLWithPath: "./\(sanitized).png")
    }
    
    /// Encode via the shared `PNGExporter` (same DPI metadata as GUI exports)
    /// and write the file. Returns the pixel dimensions measured off the encoded
    /// image; these should always be `exportSize × scale` (the canvas is fixed —
    /// `BadgeGeometry` moves an oversized badge inward rather than growing it),
    /// but they're reported as measured rather than assumed.
    private func saveImageWithValidation(_ image: NSImage, to url: URL, settings: IconSettings) async throws -> (width: Int, height: Int) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw CLIError.imageConversion("Failed to create bitmap representation of rendered image")
        }

        let scaleFactor = settings.export.isRetina ? 2 : 1
        let pngData: Data
        do {
            pngData = try PNGExporter.pngData(from: cgImage, scaleFactor: scaleFactor)
        } catch {
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

        return (cgImage.width, cgImage.height)
    }
    
    // MARK: - Enhanced Parsing Helpers

    private func parseRenderingMode(_ input: String) throws -> SymbolRenderingStyle {
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

    // MARK: - File Metadata

    /// Size of a file in bytes, or 0 if it can't be read.
    private func fileByteCount(_ url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.intValue ?? 0
    }

    // MARK: - Testing Support Methods
    
    /// Expose buildIconSettings for testing
    func buildTestSettings(from command: GenerateCommand) throws -> IconSettings {
        return try buildIconSettings(from: command)
    }
    
    /// Expose resolveOutputPath for testing
    func testResolveOutputPath(basename: String, userPath: String?) throws -> URL {
        return try resolveOutputPath(basename: basename, userPath: userPath)
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

    /// Stable token for the JSON error schema.
    var kind: String {
        switch self {
        case .imageConversion: return "image"
        case .invalidSymbol: return "symbol"
        case .fileSystem: return "filesystem"
        case .invalidColorFormat: return "color"
        case .invalidArgument: return "argument"
        case .configurationError: return "configuration"
        case .renderingError: return "rendering"
        case .unexpectedError: return "unexpected"
        }
    }
}
