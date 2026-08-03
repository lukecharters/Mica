import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Runs one generation: takes an already-parsed `GenerateCommand`, validates it,
/// builds the `IconSettings`, renders through `IconRenderer` and writes the PNG.
/// It parses nothing and owns no command-line surface — `GenerateCommand` does that.
class IconGenerationRunner {

    /// The palette `generate` falls back to when `--icon-symbol-palette` /
    /// `--badge-symbol-palette` is absent: three tints of white.
    ///
    /// This is the one CLI default that genuinely differs from the model —
    /// `ForegroundSpec` defaults to white/mint/yellow, which is the GUI's pick. It
    /// is kept as a seed rather than an inline `??` so that `--config` can decline
    /// it and let a configuration's own palette stand.
    static let cliPaletteDefault = "white,white:0.5,white:0.26"

    // MARK: - Main Generation Method

    /// Render and save the icon, returning a description of the produced file.
    /// Diagnostics go through `reporter` (verbose phase detail to stderr); the
    /// caller is responsible for the success/error reporting and exit code.
    ///
    /// `context` is what `--config` loaded, or `.none` for a flags-only run. Every
    /// decision below that used to read a flag directly now reads the *built
    /// settings* or the context instead, because with a configuration the flag may
    /// be absent and the answer still be yes.
    func generateIcon(from command: GenerateCommand, context: GenerationContext = .none, reporter: OutputReporter) async throws -> OutputFileJSON {
        // Phase 1: Validation
        reporter.detail("Validating…")
        try await performEnhancedValidation(command, context: context)

        // Phase 2: Build settings
        reporter.detail("Building settings…")
        let settings = try buildIconSettings(from: command, onto: context.base)

        // The symbols are checked against the *resolved* settings rather than the
        // flags: a configuration can supply either symbol, and a name that does
        // not exist has to fail the same way whichever supplied it.
        try validateResolvedSymbols(settings)

        // Phase 3: Render
        let image: NSImage

        if settings.icon.mode == .system {
            reporter.detail("Rendering via the Apple Reference (appex) pipeline…")
            image = try await renderAppleReference(command: command, context: context, settings: settings)
        } else {
            reporter.detail("Rendering…")
            // Load badge appex image if badge uses the System (appex) source.
            // `let` keeps this in a disconnected region so it can be sent
            // into the @MainActor render task (NSImage is non-Sendable).
            let badgeAppexImage: NSImage? = (settings.badge.isVisible && settings.badge.foreground.source == .system)
                ? try renderAppexIcon(
                    symbolName: settings.badge.foreground.symbolName,
                    enclosureColor: command.resolvedBadgeAppexEnclosureColor(in: context),
                    symbolColor: command.resolvedBadgeAppexSymbolColor(in: context),
                    settings: settings
                )
                : nil
            image = try await renderIconWithErrorHandling(settings: settings, badgeAppexImage: badgeAppexImage)
        }

        // Phase 4: Save
        let basename = command.defaultOutputBasename(in: context)
        let outputURL = try resolveOutputPath(basename: basename, userPath: command.export.outputPath)
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
            source: basename
        )
    }

    // MARK: - Apple Reference Rendering

    private func renderAppleReference(command: GenerateCommand, context: GenerationContext, settings: IconSettings) async throws -> NSImage {
        let appexPath = "/System/Library/ExtensionKit/Extensions/Storage.appex"
        guard FileManager.default.fileExists(atPath: appexPath) else {
            throw CLIError.renderingError("Apple Reference mode requires Storage.appex at \(appexPath). This file is not available on this system.")
        }

        // System mode renders an SF Symbol via the appex pipeline; image
        // foregrounds are only supported in mica mode. Read off the settings, so a
        // configuration's foreground counts as much as a flag's.
        guard settings.icon.foreground.source != .image else {
            throw CLIError.configurationError("System generation mode (--icon-generation-mode system) requires an SF Symbol foreground; image foregrounds are only supported in mica mode.")
        }
        let foregroundSymbol = settings.icon.foreground.symbolName

        // In system mode --icon-symbol-color and --icon-bg-color resolve to appex
        // colour tokens (symbol + enclosure), falling back to the configuration's.
        let appexSymbolColor = try command.resolvedIconAppexSymbolColor(in: context)
        let appexEnclosureColor = try command.resolvedIconAppexEnclosureColor(in: context)

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
                    enclosureColor: command.resolvedBadgeAppexEnclosureColor(in: context),
                    symbolColor: command.resolvedBadgeAppexSymbolColor(in: context),
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

    /// `enclosureColor` / `symbolColor` have already passed `AppexPlistColor`'s
    /// gate, in `validate()` — so by the time anything renders, a colour System
    /// mode cannot express has already been reported and nothing was written.
    private func renderAppexIcon(symbolName: String, enclosureColor: AppexPlistColor, symbolColor: AppexPlistColor, settings: IconSettings) throws -> NSImage {
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
    
    private func performEnhancedValidation(_ command: GenerateCommand, context: GenerationContext) async throws {
        // SF Symbol existence is checked *after* the settings are built, by
        // `validateResolvedSymbols` — the name can come from a configuration as
        // easily as from a flag, and only the built settings know which won.

        // Color strings are validated once, in the command layer
        // (GenerateCommand.validateColorFormats) — it runs before this
        // method, covers System-mode appex tokens too, and previously had a
        // near-verbatim (dead) duplicate here that had started to drift.

        // Validate file system permissions
        if let outputPath = command.export.outputPath {
            try validateOutputPermissions(outputPath)
        }

        // Validate rendering mode consistency
        try validateRenderingModeConsistency(command, context: context)
    }

    /// Both symbols the settings will actually render, whatever supplied them.
    private func validateResolvedSymbols(_ settings: IconSettings) throws {
        // `.image` foregrounds keep a cosmetic `symbolName` (the file's stem),
        // which is not a symbol and must not be looked up. `.system` is the appex
        // raster of a real SF Symbol, so it is checked like `.symbol`.
        if settings.icon.foreground.source != .image {
            try validateSFSymbolExists(settings.icon.foreground.symbolName)
        }
        if settings.badge.isVisible, settings.badge.foreground.source != .image {
            try validateSFSymbolExists(settings.badge.foreground.symbolName)
        }
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
    
    private func validateRenderingModeConsistency(_ command: GenerateCommand, context: GenerationContext) throws {
        if command.iconForeground.symbolRendering == "palette",
           let palette = command.iconForeground.symbolPalette {
            // Enforce exactly three palette components.
            _ = try splitPalette(palette, role: "--icon-symbol-palette")
        }
        if command.badgeIsActive(in: context), command.badge.symbolRendering == "palette",
           let palette = command.badge.symbolPalette {
            _ = try splitPalette(palette, role: "--badge-symbol-palette")
        }
    }
    
    // MARK: - Enhanced Settings Builder
    
    /// Apply the flags the user actually passed onto `base`.
    ///
    /// `base == nil` is a flags-only `generate`: start from the model defaults. A
    /// non-nil base is `--config`, where the base is a decoded configuration and
    /// **every** assignment here must be conditional on its flag being present — an
    /// unconditional write would silently discard what the user saved.
    ///
    /// That is why almost nothing below assigns eagerly. The two deliberate
    /// exceptions are the palette (see `cliPaletteDefault`) and the badge
    /// activation rule, both commented where they happen.
    private func buildIconSettings(from command: GenerateCommand, onto base: IconSettings? = nil) throws -> IconSettings {
        var settings = base ?? IconSettings()

        // The CLI's default palette is three tints of white, which deliberately
        // differs from `ForegroundSpec`'s white/mint/yellow (the GUI's pick). It
        // is a real CLI default, so a flags-only `generate` seeds it; `--config`
        // must not, or a configuration's palette would be overwritten whenever
        // the flag is absent.
        let seedsCLIDefaults = (base == nil)

        do {
            // Export properties. Each flag is Optional and assigned only when
            // passed, so an absent flag leaves whatever is already in
            // `settings` — the ExportSpec default, or a `--config` value.
            if let size = command.export.size {
                settings.export.size = CGFloat(size)
            }
            if let scale = command.export.scale {
                settings.export.isRetina = scale.factor == 2
            }
            if let colorSpace = command.export.colorSpace {
                settings.export.colorSpace = colorSpace
            }

            // Icon foreground source. Absent with `--config` means the
            // configuration's foreground stands; a flags-only `generate` requires
            // one, and its error comes from the throwing `resolvedForeground()` in
            // performEnhancedValidation.
            var commandImportedForeground = false
            if let foreground = try command.providedForeground() {
                switch foreground {
                case .symbol(let name):
                    settings.icon.foreground.source = .symbol
                    settings.icon.foreground.symbolName = name
                case .image(let path):
                    settings.icon.foreground.source = .image
                    // symbolName is cosmetic for image foregrounds; use the basename.
                    settings.icon.foreground.symbolName = command.defaultOutputBasename()
                    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                    settings.icon.foreground.image = try ImageImportService.importFromURL(url)
                    commandImportedForeground = true
                }
            }

            // --icon-fg-scale applies to whichever source is now in effect, which
            // with `--config` may be the configuration's rather than a flag's.
            if let scale = command.iconForeground.scale {
                if settings.icon.foreground.source == .image {
                    settings.icon.foreground.imageScale = scale
                } else {
                    settings.icon.foreground.symbolScale = scale
                }
            }

            // Icon background (folds --icon-bg + --icon-bg-color + gradient-colors + scale + padding).
            //
            // `resolvedBackground()` reports `.standard` both when the user asked
            // for it and when `--icon-bg` was absent entirely, so the `.standard`
            // arm checks `selection` before asserting a source: `--icon-bg-color`
            // alone must still tint a configuration's image or gradient background
            // rather than silently flattening it to a plain colour fill.
            var commandImportedBackground = false
            switch command.resolvedBackground() {
            case .standard:
                if command.background.selection != nil {
                    settings.icon.background.source = .color
                    settings.icon.background.usesCustomGradient = false
                }
                // In system mode the enclosure colour is resolved separately in
                // renderAppleReference, so leave the SwiftUI base colour alone.
                if command.generation.effectiveIconMode != .system, let color = command.background.color {
                    settings.icon.background.color = try MicaColorValue(strictlyParsing: color)
                }
            case .customGradient:
                settings.icon.background.source = .color
                settings.icon.background.usesCustomGradient = true
                if let gradientColors = command.background.gradientColors {
                    let parts = try splitGradientColors(gradientColors)
                    settings.icon.background.gradientStartColor = try MicaColorValue(strictlyParsing: parts[0])
                    settings.icon.background.gradientEndColor = try MicaColorValue(strictlyParsing: parts[1])
                }
                settings.icon.background.color = settings.icon.background.gradientStartColor
            case .preRendered:
                settings.icon.background.source = .preRendered
                // preRenderedAssetName lowercases this when building the asset name.
                if let color = command.background.color {
                    settings.icon.background.preRenderedColorName = normalizeBritishSpelling(color)
                }
            case .image(let path):
                settings.icon.background.source = .image
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                settings.icon.background.image = try ImageImportService.importFromURL(url)
                if let scale = command.background.scale {
                    settings.icon.background.imageScale = scale
                }
                settings.icon.background.compensatesForPadding = command.background.effectivePaddingCompensation
                commandImportedBackground = true
            }

            // Background style
            if let gradient = command.background.gradient {
                settings.icon.background.usesGradient = gradient.isOn
            }
            if let cornerRadius = command.background.cornerRadius {
                settings.icon.background.cornerRadiusStyle = try parseCornerRadius(cornerRadius)
            }
            // An explicit --icon-bg-shadow wins; otherwise only a *freshly imported*
            // background forces the shadow off (mirroring
            // `IconBackgroundSpec.apply(_:)`). Absent flag + no import leaves the
            // base's shadow, which is what a document needs.
            if let shadow = command.background.shadow {
                settings.icon.background.shadowStyle = try parseShadowStyle(shadow)
            } else if commandImportedBackground {
                settings.icon.background.shadowStyle = .off
            }

            // Background visibility (new --icon-bg-visibility → iconBackgroundHidden)
            if let visibility = command.background.visibility {
                settings.icon.background.isHidden = !visibility.isOn
            }

            // Symbol rendering
            if let symbolRendering = command.iconForeground.symbolRendering {
                settings.icon.foreground.renderingStyle = try parseRenderingMode(symbolRendering)
            }

            // Merged --icon-symbol-color. In mica mode it drives the SwiftUI
            // symbol/hierarchical/multicolor tint; in system mode the colour is
            // resolved as an appex token in renderAppleReference, so the SwiftUI
            // colour is left at its (unused) default here.
            if command.generation.effectiveIconMode != .system, let symbolColor = command.iconForeground.symbolColor {
                let parsed = try MicaColorValue(strictlyParsing: symbolColor)
                settings.icon.foreground.color = parsed
                settings.icon.foreground.hierarchicalColor = parsed
            }

            // Palette colours. A flags-only `generate` seeds the CLI default;
            // `--config` leaves the configuration's palette alone unless
            // --icon-symbol-palette says otherwise.
            if let palette = command.iconForeground.symbolPalette
                ?? (seedsCLIDefaults ? Self.cliPaletteDefault : nil) {
                let parts = try splitPalette(palette, role: "--icon-symbol-palette")
                settings.icon.foreground.palettePrimaryColor = try MicaColorValue(strictlyParsing: parts[0])
                settings.icon.foreground.paletteSecondaryColor = try MicaColorValue(strictlyParsing: parts[1])
                settings.icon.foreground.paletteTertiaryColor = try MicaColorValue(strictlyParsing: parts[2])
            }

            // Symbol style. As with the background shadow, only a fresh import
            // forces the shadow off (mirroring `ForegroundSpec.apply(_:)`).
            if let shadow = command.iconForeground.shadow {
                settings.icon.foreground.drawsShadow = shadow.isOn
            } else if commandImportedForeground {
                settings.icon.foreground.drawsShadow = false
            }
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

            // Icon generation mode. Conditional like everything else: reading
            // `effectiveIconMode` here would fold a configuration's `.system` back
            // to `.mica` whenever --icon-generation-mode was absent.
            if let iconMode = command.generation.iconGenerationMode {
                settings.icon.mode = iconMode
            }

            // Badge settings. Active when --badge-fg activates it, *or* when the base
            // already has a visible badge — with `--config` the configuration
            // supplies the badge, and gating purely on --badge-fg would make every
            // other badge flag silently do nothing.
            let commandBadgeForeground = try command.resolvedBadgeForeground()
            if commandBadgeForeground != nil || settings.badge.isVisible {
                // Badge foreground source (folds --badge-fg + --badge-fg-scale).
                var commandImportedBadgeForeground = false
                switch commandBadgeForeground {
                case .symbol(let name):
                    settings.badge.foreground.source = .symbol
                    settings.badge.foreground.symbolName = name
                case .image(let path):
                    settings.badge.foreground.source = .image
                    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                    settings.badge.foreground.image = try ImageImportService.importFromURL(url)
                    commandImportedBadgeForeground = true
                case nil:
                    break
                }

                // --badge-fg-scale applies to whichever source is now in effect.
                if let foregroundScale = command.badge.foregroundScale {
                    if settings.badge.foreground.source == .image {
                        settings.badge.foreground.imageScale = foregroundScale
                    } else {
                        settings.badge.foreground.symbolScale = foregroundScale
                    }
                }

                // Badge background (folds --badge-bg + color + gradient-colors + scale + padding).
                // Same shape as the icon background above: `.standard` also means
                // "--badge-bg absent", so it checks the flag before asserting a source.
                var commandImportedBadgeBackground = false
                switch command.resolvedBadgeBackground() {
                case .standard:
                    if command.badge.background != nil {
                        settings.badge.background.source = .color
                        settings.badge.background.usesCustomGradient = false
                    }
                    // In system mode the enclosure colour is resolved separately
                    // via the appex pipeline, so leave the SwiftUI base alone.
                    if command.generation.effectiveBadgeMode != .system, let backgroundColor = command.badge.backgroundColor {
                        settings.badge.background.color = try MicaColorValue(strictlyParsing: backgroundColor)
                    }
                case .customGradient:
                    settings.badge.background.source = .color
                    settings.badge.background.usesCustomGradient = true
                    if let gradientColors = command.badge.backgroundGradientColors {
                        let parts = try splitGradientColors(gradientColors, role: "--badge-bg-gradient-colors")
                        settings.badge.background.gradientStartColor = try MicaColorValue(strictlyParsing: parts[0])
                        settings.badge.background.gradientEndColor = try MicaColorValue(strictlyParsing: parts[1])
                    }
                    settings.badge.background.color = settings.badge.background.gradientStartColor
                case .image(let path):
                    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                    settings.badge.background.source = .image
                    settings.badge.background.image = try ImageImportService.importFromURL(url)
                    if let backgroundScale = command.badge.backgroundScale {
                        settings.badge.background.imageScale = backgroundScale
                    }
                    settings.badge.background.compensatesForPadding = command.badge.effectiveBackgroundPaddingCompensation
                    commandImportedBadgeBackground = true
                }

                // Badge background style.
                if let backgroundGradient = command.badge.backgroundGradient {
                    settings.badge.background.usesGradient = backgroundGradient.isOn
                }
                if let backgroundShadow = command.badge.backgroundShadow {
                    settings.badge.background.drawsShadow = backgroundShadow.isOn
                } else if commandImportedBadgeBackground {
                    settings.badge.background.drawsShadow = false
                }

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
                if command.generation.effectiveBadgeMode != .system, let symbolColor = command.badge.symbolColor {
                    let parsed = try MicaColorValue(strictlyParsing: symbolColor)
                    settings.badge.foreground.color = parsed
                    settings.badge.foreground.hierarchicalColor = parsed
                }

                // Badge palette — seeded for `generate` only, as with the icon's.
                if let badgePalette = command.badge.symbolPalette
                    ?? (seedsCLIDefaults ? Self.cliPaletteDefault : nil) {
                    let parts = try splitPalette(badgePalette, role: "--badge-symbol-palette")
                    settings.badge.foreground.palettePrimaryColor = try MicaColorValue(strictlyParsing: parts[0])
                    settings.badge.foreground.paletteSecondaryColor = try MicaColorValue(strictlyParsing: parts[1])
                    settings.badge.foreground.paletteTertiaryColor = try MicaColorValue(strictlyParsing: parts[2])
                }

                if let symbolWeight = command.badge.symbolWeight {
                    settings.badge.foreground.symbolWeight = try parseSymbolWeight(symbolWeight)
                }
                if let symbolGradient = command.badge.symbolGradient {
                    settings.badge.foreground.fillStyle = symbolGradient.isOn ? .gradient : .flat
                }

                // Badge foreground shadow — off only for a fresh import.
                if let foregroundShadow = command.badge.foregroundShadow {
                    settings.badge.foreground.drawsShadow = foregroundShadow.isOn
                } else if commandImportedBadgeForeground {
                    settings.badge.foreground.drawsShadow = false
                }

                // Badge generation mode (system → appex pipeline).
                if let badgeMode = command.generation.badgeGenerationMode {
                    settings.badge.mode = badgeMode
                }

                // Badge layer visibility. When --badge-fg activated the badge this is
                // NOT conditional on a visibility flag: both specs default their
                // layers to hidden, and supplying --badge-fg is what makes the badge
                // appear, so the `?? true` is that activation rule rather than a
                // restated spec default. When the badge instead came from the base
                // document, its per-layer visibility must survive — writing both
                // layers there would resurrect a background the user had hidden.
                if commandBadgeForeground != nil {
                    settings.badge.foreground.isHidden = !(command.badge.foregroundVisibility?.isOn ?? true)
                    settings.badge.background.isHidden = !(command.badge.backgroundVisibility?.isOn ?? true)
                } else {
                    if let foregroundVisibility = command.badge.foregroundVisibility {
                        settings.badge.foreground.isHidden = !foregroundVisibility.isOn
                    }
                    if let backgroundVisibility = command.badge.backgroundVisibility {
                        settings.badge.background.isHidden = !backgroundVisibility.isOn
                    }
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
    //
    // Thin wrappers over the shared token vocabulary (Services/SettingsTokens.swift)
    // that own the CLI's error wording. The flag transforms have already validated
    // these values, so the throws are a second line of defence.

    private func parseRenderingMode(_ input: String) throws -> SymbolRenderingStyle {
        guard let style = SymbolRenderingStyle.from(cliToken: input) else {
            throw CLIError.invalidArgument("Invalid rendering mode: \(input). Must be one of: \(SymbolRenderingStyle.allCLITokens.joined(separator: ", "))")
        }
        return style
    }

    private func parseBadgePosition(_ input: String) throws -> BadgePosition {
        guard let position = BadgePosition.from(cliToken: input) else {
            throw CLIError.invalidArgument("Invalid badge position: \(input). Must be one of: \(BadgePosition.allCLITokens.joined(separator: ", "))")
        }
        return position
    }

    private func parseCornerRadius(_ input: String) throws -> IconCornerRadiusStyle {
        guard let style = IconCornerRadiusStyle.from(cliToken: input) else {
            throw CLIError.invalidArgument("Invalid corner radius: \(input). Must be one of: \(IconCornerRadiusStyle.allCLITokens.joined(separator: ", "))")
        }
        return style
    }

    private func parseShadowStyle(_ input: String) throws -> BackgroundShadowStyle {
        guard let style = BackgroundShadowStyle.from(cliToken: input) else {
            throw CLIError.invalidArgument("Invalid shadow style: \(input). Must be one of: \(BackgroundShadowStyle.allCLITokens.joined(separator: ", "))")
        }
        return style
    }

    private func parseSymbolWeight(_ input: String) throws -> SymbolWeight {
        guard let weight = SymbolWeight.from(cliToken: input) else {
            throw CLIError.invalidArgument("Invalid symbol weight: \(input). Must be one of: \(SymbolWeight.allCLITokens.joined(separator: ", "))")
        }
        return weight
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

    /// Expose the `--config` path — flags applied onto a decoded configuration —
    /// for testing, so override precedence can be asserted without touching the disk.
    func buildTestSettings(from command: GenerateCommand, onto base: IconSettings) throws -> IconSettings {
        return try buildIconSettings(from: command, onto: base)
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
