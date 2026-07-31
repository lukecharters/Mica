// Services/MicaConfig.swift
//
// The JSON configuration format: a flat object whose keys are the `generate`
// long flag names without `--`, shared by `mica-cli generate --config` and the
// GUI's Export/Import Configuration. One codec serves both, so a configuration
// the GUI writes is byte-for-byte something the CLI understands, and vice versa.
//
// Ground rules, each pinned by a test:
//
// - **Keys are the flag names** (`"icon-bg-color"`, `"size"`, `"badge-fg"`).
//   Process-level flags (`output`, `json`, `quiet`, `verbose`) are deliberately
//   not keys — they describe an invocation, not an icon. The positional symbol
//   shorthand has no key; use `"icon-fg": "symbol:star.fill"`.
// - **Decode is liberal**: toggles take JSON booleans or `"on"`/`"off"`; numbers
//   take JSON numbers or numeric strings; the four multi-colour keys take a
//   JSON array of colour strings or the CLI's comma-joined form (the array form
//   is what finally admits comma-containing colours like `extended-srgb:`);
//   British `-colour` spellings are accepted and the American key wins a tie.
// - **Encode is minimal**: every key equal to what decoding its absence would
//   produce is omitted, so an exported file reads as exactly the flags you
//   would have passed. Values are JSON-native (booleans, numbers, arrays).
// - **Unknown keys and unparseable values are warnings, not errors** — only
//   unreadable JSON is fatal. A configuration must still load; the CLI prints
//   warnings loudly on stderr and the GUI shows them in an alert.
// - **Decode mirrors `buildIconSettings`** (mica-cli/CLI/IconGenerationRunner.swift)
//   rule for rule — badge activation via `badge-fg`, fresh-import shadow
//   defaults, the inverted padding keys, mode-polymorphic colour keys. The
//   equivalence test in `ConfigFlagParityTests` is the drift alarm; change one
//   side only with that test in view.
// - **The palette is NOT seeded.** A flags-only `generate` seeds the CLI's
//   white-tints palette; a configuration is a *base*, so an absent
//   `icon-symbol-palette` means the model default (white/mint/yellow), exactly
//   as `--config`'s override machinery expects. This is the one deliberate
//   divergence between "decode a config" and "parse the same values as flags".
//
// Imported images are file paths (like the flags): relative paths resolve
// against the JSON file's directory, and the GUI export allocates sidecar PNGs
// through `MicaConfigAssetCatalog`. A missing or unreadable image is a warning
// and the layer keeps `source == .image` with no pixels — the configuration
// still loads, mirroring what the old document format did for missing assets.

import SwiftUI
import Foundation

// MARK: - Keys

/// Every configuration key IS a `generate` long flag name (without `--`).
/// `ConfigFlagParityTests` holds this equality in both directions.
enum MicaConfigKey: String, CaseIterable, Sendable {
    // Export
    case size
    case scale
    case colorSpace = "color-space"

    // Generation modes
    case iconGenerationMode = "icon-generation-mode"
    case badgeGenerationMode = "badge-generation-mode"

    // Icon foreground
    case iconFG = "icon-fg"
    case iconFGScale = "icon-fg-scale"
    case iconSymbolRendering = "icon-symbol-rendering"
    case iconSymbolColor = "icon-symbol-color"
    case iconSymbolPalette = "icon-symbol-palette"
    case iconSymbolWeight = "icon-symbol-weight"
    case iconSymbolGradient = "icon-symbol-gradient"
    case iconFGShadow = "icon-fg-shadow"
    case iconFGVisibility = "icon-fg-visibility"

    // Icon background
    case iconBG = "icon-bg"
    case iconBGColor = "icon-bg-color"
    case iconBGGradientColors = "icon-bg-gradient-colors"
    case iconBGGradient = "icon-bg-gradient"
    case iconBGCornerRadius = "icon-bg-corner-radius"
    case iconBGScale = "icon-bg-scale"
    case iconBGShadow = "icon-bg-shadow"
    case iconBGPadding = "icon-bg-padding"
    case iconBGVisibility = "icon-bg-visibility"

    // Badge foreground
    case badgeFG = "badge-fg"
    case badgeFGScale = "badge-fg-scale"
    case badgeSymbolRendering = "badge-symbol-rendering"
    case badgeSymbolColor = "badge-symbol-color"
    case badgeSymbolPalette = "badge-symbol-palette"
    case badgeSymbolWeight = "badge-symbol-weight"
    case badgeSymbolGradient = "badge-symbol-gradient"
    case badgeFGShadow = "badge-fg-shadow"
    case badgeFGVisibility = "badge-fg-visibility"

    // Badge background
    case badgeBG = "badge-bg"
    case badgeBGColor = "badge-bg-color"
    case badgeBGGradientColors = "badge-bg-gradient-colors"
    case badgeBGGradient = "badge-bg-gradient"
    case badgeBGScale = "badge-bg-scale"
    case badgeBGShadow = "badge-bg-shadow"
    case badgeBGPadding = "badge-bg-padding"
    case badgeBGVisibility = "badge-bg-visibility"

    // Badge layout
    case badgePosition = "badge-position"
    case badgeScale = "badge-scale"
    case badgeOffsetX = "badge-offset-x"
    case badgeOffsetY = "badge-offset-y"

    /// British spellings accepted on decode. Encode always writes the American
    /// key; when both spellings appear in one file the American one wins and the
    /// alias draws a warning.
    static let britishAliases: [String: MicaConfigKey] = [
        "colour-space": .colorSpace,
        "icon-symbol-colour": .iconSymbolColor,
        "icon-bg-colour": .iconBGColor,
        "icon-bg-gradient-colours": .iconBGGradientColors,
        "badge-symbol-colour": .badgeSymbolColor,
        "badge-bg-colour": .badgeBGColor,
        "badge-bg-gradient-colours": .badgeBGGradientColors,
    ]

    /// The `generate` flags that are deliberately not configuration keys, with
    /// the message an attempt to use one gets.
    static let processLevelNames: Set<String> = ["output", "o", "json", "quiet", "q", "verbose", "v", "config"]

    /// True for the badge-namespace keys, which are inert without `badge-fg`
    /// (the activation rule, mirroring the CLI's).
    var isBadgeKey: Bool {
        rawValue.hasPrefix("badge-")
    }
}

// MARK: - Results

/// Something a configuration said that this build could not honour. Never fatal.
struct MicaConfigWarning: Equatable, Sendable {
    var key: String
    var message: String
}

/// A configuration that could not be read at all. Everything recoverable is a
/// `MicaConfigWarning` instead.
enum MicaConfigError: Error, LocalizedError, Equatable {
    case invalidJSON(String)
    case notAnObject

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let detail): return "The configuration is not valid JSON: \(detail)"
        case .notAnObject: return "The configuration's top level must be a JSON object of flag-name keys."
        }
    }
}

/// What a configuration decoded to: the settings, the System-mode colours
/// beside them, and anything this build could not honour.
struct MicaConfigContents: Equatable {
    var settings: IconSettings
    var appexColors: MicaAppexColors
    var warnings: [MicaConfigWarning] = []
}

// MARK: - Codec

enum MicaConfigCodec {
    /// How decode turns a resolved image path into pixels. Injected so tests
    /// never touch the disk; the default is the same importer the flags use.
    typealias ImageLoader = (URL) throws -> ImportedImage

    static func defaultImageLoader(_ url: URL) throws -> ImportedImage {
        try ImageImportService.importFromURL(url)
    }

    // MARK: Decode

    /// Decode a configuration. `configDirectory` anchors relative image paths —
    /// pass the JSON file's directory. Only unreadable JSON throws.
    static func decode(
        json: Data,
        configDirectory: URL?,
        loadImage: @escaping ImageLoader = defaultImageLoader
    ) throws -> MicaConfigContents {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: json)
        } catch {
            throw MicaConfigError.invalidJSON(error.localizedDescription)
        }
        guard let dictionary = object as? [String: Any] else {
            throw MicaConfigError.notAnObject
        }

        var reader = ConfigReader(configDirectory: configDirectory, loadImage: loadImage)
        reader.normalizeKeys(from: dictionary)
        reader.apply()
        return MicaConfigContents(
            settings: reader.settings,
            appexColors: reader.appexColors,
            warnings: reader.warnings
        )
    }

    // MARK: Encode

    /// Encode a minimal configuration: every key equal to what decoding its
    /// absence would produce is omitted. Imported images become relative paths
    /// allocated by `assets` — no file I/O happens here; the caller writes
    /// `assets.assets` beside the JSON.
    static func encode(
        settings: IconSettings,
        appexColors: MicaAppexColors = MicaAppexColors(),
        assets: inout MicaConfigAssetCatalog
    ) throws -> Data {
        let dictionary = ConfigWriter(settings: settings, appexColors: appexColors)
            .dictionary(assets: &assets)
        return try JSONSerialization.data(
            withJSONObject: dictionary,
            options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        )
    }

    /// Encode when no layer holds an imported image (tests, programmatic use).
    /// Image slots that do hold one are allocated names that go nowhere — use
    /// the `assets:` overload whenever images matter.
    static func encode(
        settings: IconSettings,
        appexColors: MicaAppexColors = MicaAppexColors()
    ) throws -> Data {
        var assets = MicaConfigAssetCatalog()
        return try encode(settings: settings, appexColors: appexColors, assets: &assets)
    }
}

// MARK: - Decode implementation

private struct ConfigReader {
    let configDirectory: URL?
    let loadImage: MicaConfigCodec.ImageLoader

    var values: [MicaConfigKey: Any] = [:]
    var warnings: [MicaConfigWarning] = []
    var settings = IconSettings()
    var appexColors = MicaAppexColors()

    init(configDirectory: URL?, loadImage: @escaping MicaConfigCodec.ImageLoader) {
        self.configDirectory = configDirectory
        self.loadImage = loadImage
    }

    mutating func warn(_ key: String, _ message: String) {
        warnings.append(MicaConfigWarning(key: key, message: message))
    }

    // MARK: Key normalisation

    mutating func normalizeKeys(from dictionary: [String: Any]) {
        for (rawKey, value) in dictionary.sorted(by: { $0.key < $1.key }) {
            if let key = MicaConfigKey(rawValue: rawKey) {
                values[key] = value
            } else if let canonical = MicaConfigKey.britishAliases[rawKey] {
                if dictionary[canonical.rawValue] != nil {
                    warn(rawKey, "'\(canonical.rawValue)' is also present and wins; this alias is ignored")
                } else {
                    values[canonical] = value
                }
            } else if MicaConfigKey.processLevelNames.contains(rawKey) {
                warn(rawKey, "'\(rawKey)' is a command-line flag, not a configuration key — pass it on the command line")
            } else {
                warn(rawKey, "not a configuration key")
            }
        }
    }

    // MARK: Typed readers
    //
    // Each returns nil (after recording a warning) when the value cannot be
    // read, so a bad value degrades to the key being absent.

    /// JSONSerialization surfaces both booleans and numbers as NSNumber; only a
    /// CFBoolean is a boolean. Without this check `"size": true` reads as 1.
    private func isBool(_ value: Any) -> Bool {
        value is NSNumber && CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID()
    }

    mutating func string(_ key: MicaConfigKey) -> String? {
        guard let value = values[key] else { return nil }
        guard let string = value as? String, !isBool(value) else {
            warn(key.rawValue, "expected a string")
            return nil
        }
        return string
    }

    mutating func toggle(_ key: MicaConfigKey) -> Bool? {
        guard let value = values[key] else { return nil }
        if isBool(value), let bool = value as? Bool { return bool }
        if let string = value as? String {
            if let state = ToggleState(rawValue: string.lowercased()) { return state.isOn }
            warn(key.rawValue, "expected true/false or \"on\"/\"off\", got \"\(string)\"")
            return nil
        }
        warn(key.rawValue, "expected true/false or \"on\"/\"off\"")
        return nil
    }

    mutating func number(_ key: MicaConfigKey, in range: ClosedRange<Double>) -> Double? {
        guard let value = values[key] else { return nil }
        let parsed: Double?
        if isBool(value) {
            parsed = nil
        } else if let numeric = value as? NSNumber {
            parsed = numeric.doubleValue
        } else if let string = value as? String {
            parsed = Double(string)
        } else {
            parsed = nil
        }
        guard let number = parsed else {
            warn(key.rawValue, "expected a number")
            return nil
        }
        guard range.contains(number) else {
            warn(key.rawValue, "\(number) is outside \(range.lowerBound)–\(range.upperBound)")
            return nil
        }
        return number
    }

    /// A multi-colour key: a JSON array of colour strings, or the CLI's
    /// comma-joined form. The array form admits comma-containing colours
    /// (`extended-srgb:`), which the flag never could.
    mutating func colorList(_ key: MicaConfigKey, expecting count: Int) -> [String]? {
        guard let value = values[key] else { return nil }
        if let array = value as? [Any] {
            let strings = array.compactMap { $0 as? String }
            guard strings.count == array.count, strings.count == count else {
                warn(key.rawValue, "expected \(count) colour strings, got \(array.count)")
                return nil
            }
            return strings
        }
        if let string = value as? String {
            switch splitColorList(string, expecting: count) {
            case .ok(let parts):
                return parts
            case .wrongCount(let got):
                warn(key.rawValue, "expected \(count) comma-separated colours, got \(got)")
                return nil
            case .emptyComponent:
                warn(key.rawValue, "colours cannot be empty")
                return nil
            }
        }
        warn(key.rawValue, "expected an array of colour strings or a comma-joined string")
        return nil
    }

    mutating func token<T: SettingsTokenConvertible>(_ key: MicaConfigKey, as type: T.Type) -> T? {
        guard let raw = string(key) else { return nil }
        guard let value = T.from(cliToken: normalizeBritishSpelling(raw)) else {
            warn(key.rawValue, "\"\(raw)\" is not one of: \(T.allCLITokens.joined(separator: ", "))")
            return nil
        }
        return value
    }

    mutating func swiftUIColor(_ key: MicaConfigKey) -> Color? {
        guard let raw = string(key) else { return nil }
        do {
            return try ColorParser.parseWithOpacity(raw)
        } catch {
            warn(key.rawValue, "\"\(raw)\" is not a recognisable colour")
            return nil
        }
    }

    mutating func appexColor(_ key: MicaConfigKey) -> AppexColor? {
        guard let raw = string(key) else { return nil }
        do {
            return try AppexColor.parsing(cliString: raw)
        } catch {
            warn(key.rawValue, "\"\(raw)\" is not a recognisable colour")
            return nil
        }
    }

    // MARK: Images

    /// Resolve an image path (tilde-expanded; relative paths anchor to the
    /// configuration's directory) and load it. A failure warns and returns nil —
    /// the layer keeps its `.image` source with no pixels, so the configuration
    /// still loads.
    mutating func importImage(atPath path: String, key: MicaConfigKey) -> ImportedImage? {
        let expanded = (path as NSString).expandingTildeInPath
        let url: URL
        if expanded.hasPrefix("/") {
            url = URL(fileURLWithPath: expanded)
        } else if let configDirectory {
            url = configDirectory.appendingPathComponent(expanded)
        } else {
            url = URL(fileURLWithPath: expanded)
        }
        do {
            return try loadImage(url)
        } catch {
            warn(key.rawValue, "image \"\(path)\" could not be loaded — the layer opens without it")
            return nil
        }
    }

    // MARK: Application
    //
    // Mirrors `buildIconSettings` in mica-cli/CLI/IconGenerationRunner.swift,
    // rule for rule, applied onto fresh defaults. The badge block is gated on
    // `badge-fg` exactly as the builder gates on `--badge-fg`.

    mutating func apply() {
        // Generation modes first: the four colour keys are mode-polymorphic.
        let iconMode = token(.iconGenerationMode, as: GenerationMode.self)
        let badgeMode = token(.badgeGenerationMode, as: GenerationMode.self)
        let effectiveIconMode = iconMode ?? IconSpec().mode
        let effectiveBadgeMode = badgeMode ?? BadgeSpec().mode

        // Export.
        if let size = number(.size, in: Double(ExportSpec.minSize)...Double(ExportSpec.maxSize)) {
            settings.export.size = CGFloat(size)
        }
        if let scale = exportScale() {
            settings.export.isRetina = scale.factor == 2
        }
        if let colorSpace = token(.colorSpace, as: ExportColorSpace.self) {
            settings.export.colorSpace = colorSpace
        }

        // Icon foreground source.
        var importedForeground = false
        if let raw = string(.iconFG) {
            if let value = ForegroundValue(parsing: raw) {
                switch value {
                case .symbol(let name):
                    settings.icon.foreground.source = .symbol
                    settings.icon.foreground.symbolName = name
                case .image(let path):
                    settings.icon.foreground.source = .image
                    // symbolName is cosmetic for image foregrounds; use the basename.
                    settings.icon.foreground.symbolName =
                        ((path as NSString).lastPathComponent as NSString).deletingPathExtension
                    settings.icon.foreground.image = importImage(atPath: path, key: .iconFG)
                    importedForeground = true
                }
            } else {
                warn(MicaConfigKey.iconFG.rawValue, "'symbol:' requires a symbol name, e.g. symbol:star.fill")
            }
        }

        // icon-fg-scale applies to whichever source is now in effect.
        if let scale = number(.iconFGScale, in: ForegroundSpec.symbolScaleRange) {
            if settings.icon.foreground.source == .image {
                settings.icon.foreground.imageScale = scale
            } else {
                settings.icon.foreground.symbolScale = scale
            }
        }

        // Icon background.
        var importedBackground = false
        let backgroundValue = string(.iconBG).map(IconBackgroundValue.init(parsing:))
        switch backgroundValue {
        case .standard:
            settings.icon.background.source = .color
            settings.icon.background.usesCustomGradient = false
            fallthrough
        case nil:
            // Absent behaves as the default background; the colour still tints it.
            if effectiveIconMode != .system, let color = swiftUIColor(.iconBGColor) {
                settings.icon.background.color = color
            }
        case .customGradient:
            settings.icon.background.source = .color
            settings.icon.background.usesCustomGradient = true
            if let parts = colorList(.iconBGGradientColors, expecting: 2) {
                if let start = parseColor(parts[0], key: .iconBGGradientColors) {
                    settings.icon.background.gradientStartColor = start
                }
                if let end = parseColor(parts[1], key: .iconBGGradientColors) {
                    settings.icon.background.gradientEndColor = end
                }
            }
            settings.icon.background.color = settings.icon.background.gradientStartColor
        case .preRendered:
            settings.icon.background.source = .preRendered
            if let name = string(.iconBGColor) {
                let normalized = normalizeBritishSpelling(name)
                if validPreRenderedColors.contains(normalized.lowercased()) {
                    settings.icon.background.preRenderedColorName = normalized
                } else {
                    warn(MicaConfigKey.iconBGColor.rawValue,
                         "\"\(name)\" is not a pre-rendered colour; expected one of: \(validPreRenderedColors.joined(separator: ", "))")
                }
            }
        case .image(let path):
            settings.icon.background.source = .image
            settings.icon.background.image = importImage(atPath: path, key: .iconBG)
            if let scale = number(.iconBGScale, in: ForegroundSpec.imageScaleRange) {
                settings.icon.background.imageScale = scale
            }
            settings.icon.background.compensatesForPadding = !(toggle(.iconBGPadding) ?? false)
            importedBackground = true
        }

        // In system mode the enclosure colour rides `icon-bg-color`.
        if effectiveIconMode == .system, let enclosure = appexColor(.iconBGColor) {
            appexColors.iconEnclosure = enclosure
        }

        // Icon background style.
        if let gradient = toggle(.iconBGGradient) {
            settings.icon.background.usesGradient = gradient
        }
        if let cornerRadius = token(.iconBGCornerRadius, as: IconCornerRadiusStyle.self) {
            settings.icon.background.cornerRadiusStyle = cornerRadius
        }
        // An explicit shadow wins; otherwise only a freshly imported background
        // forces the shadow off (mirroring `IconBackgroundSpec.apply(_:)`).
        if let shadow = token(.iconBGShadow, as: BackgroundShadowStyle.self) {
            settings.icon.background.shadowStyle = shadow
        } else if importedBackground {
            settings.icon.background.shadowStyle = .off
        }
        if let visibility = toggle(.iconBGVisibility) {
            settings.icon.background.isHidden = !visibility
        }

        // Icon symbol styling.
        if let rendering = token(.iconSymbolRendering, as: SymbolRenderingStyle.self) {
            settings.icon.foreground.renderingStyle = rendering
        }
        if effectiveIconMode != .system {
            if let color = swiftUIColor(.iconSymbolColor) {
                settings.icon.foreground.color = color
                settings.icon.foreground.hierarchicalColor = color
            }
        } else if let symbol = appexColor(.iconSymbolColor) {
            appexColors.iconSymbol = symbol
        }
        // The palette is deliberately NOT seeded with the CLI default — a
        // configuration is a base, and an absent key means the model default.
        if let parts = colorList(.iconSymbolPalette, expecting: 3) {
            if let primary = parseColor(parts[0], key: .iconSymbolPalette) {
                settings.icon.foreground.palettePrimaryColor = primary
            }
            if let secondary = parseColor(parts[1], key: .iconSymbolPalette) {
                settings.icon.foreground.paletteSecondaryColor = secondary
            }
            if let tertiary = parseColor(parts[2], key: .iconSymbolPalette) {
                settings.icon.foreground.paletteTertiaryColor = tertiary
            }
        }
        if let shadow = toggle(.iconFGShadow) {
            settings.icon.foreground.drawsShadow = shadow
        } else if importedForeground {
            settings.icon.foreground.drawsShadow = false
        }
        if let weight = token(.iconSymbolWeight, as: SymbolWeight.self) {
            settings.icon.foreground.symbolWeight = weight
        }
        if let gradient = toggle(.iconSymbolGradient) {
            settings.icon.foreground.fillStyle = gradient ? .gradient : .flat
        }
        if let visibility = toggle(.iconFGVisibility) {
            settings.icon.foreground.isHidden = !visibility
        }
        if let iconMode {
            settings.icon.mode = iconMode
        }

        // Badge. Gated on `badge-fg` exactly as the CLI gates on `--badge-fg`:
        // without it, badge keys are inert — but a config author deserves to
        // hear that, where a flag user gets the same silence the CLI gives.
        let badgeForegroundRaw = string(.badgeFG)
        if let badgeForegroundRaw {
            applyBadge(foregroundRaw: badgeForegroundRaw,
                       badgeMode: badgeMode,
                       effectiveBadgeMode: effectiveBadgeMode)
        } else {
            let inert = MicaConfigKey.allCases.filter { $0.isBadgeKey && $0 != .badgeFG && values[$0] != nil }
            if !inert.isEmpty {
                warn(MicaConfigKey.badgeFG.rawValue,
                     "absent, so the badge stays off and these keys are inert: \(inert.map(\.rawValue).joined(separator: ", "))")
            }
        }
    }

    private mutating func applyBadge(foregroundRaw: String, badgeMode: GenerationMode?, effectiveBadgeMode: GenerationMode) {
        var importedBadgeForeground = false
        if let value = ForegroundValue(parsing: foregroundRaw) {
            switch value {
            case .symbol(let name):
                settings.badge.foreground.source = .symbol
                settings.badge.foreground.symbolName = name
            case .image(let path):
                settings.badge.foreground.source = .image
                settings.badge.foreground.image = importImage(atPath: path, key: .badgeFG)
                importedBadgeForeground = true
            }
        } else {
            warn(MicaConfigKey.badgeFG.rawValue, "'symbol:' requires a symbol name, e.g. symbol:plus.circle")
        }

        if let scale = number(.badgeFGScale, in: ForegroundSpec.symbolScaleRange) {
            if settings.badge.foreground.source == .image {
                settings.badge.foreground.imageScale = scale
            } else {
                settings.badge.foreground.symbolScale = scale
            }
        }

        // Badge background.
        var importedBadgeBackground = false
        let backgroundValue = string(.badgeBG).map(BadgeBackgroundValue.init(parsing:))
        switch backgroundValue {
        case .standard:
            settings.badge.background.source = .color
            settings.badge.background.usesCustomGradient = false
            fallthrough
        case nil:
            if effectiveBadgeMode != .system, let color = swiftUIColor(.badgeBGColor) {
                settings.badge.background.color = color
            }
        case .customGradient:
            settings.badge.background.source = .color
            settings.badge.background.usesCustomGradient = true
            if let parts = colorList(.badgeBGGradientColors, expecting: 2) {
                if let start = parseColor(parts[0], key: .badgeBGGradientColors) {
                    settings.badge.background.gradientStartColor = start
                }
                if let end = parseColor(parts[1], key: .badgeBGGradientColors) {
                    settings.badge.background.gradientEndColor = end
                }
            }
            settings.badge.background.color = settings.badge.background.gradientStartColor
        case .image(let path):
            settings.badge.background.source = .image
            settings.badge.background.image = importImage(atPath: path, key: .badgeBG)
            if let scale = number(.badgeBGScale, in: ForegroundSpec.imageScaleRange) {
                settings.badge.background.imageScale = scale
            }
            settings.badge.background.compensatesForPadding = !(toggle(.badgeBGPadding) ?? false)
            importedBadgeBackground = true
        }

        // In system badge mode the enclosure colour rides `badge-bg-color`.
        if effectiveBadgeMode == .system, let enclosure = appexColor(.badgeBGColor) {
            appexColors.badgeEnclosure = enclosure
        }

        if let gradient = toggle(.badgeBGGradient) {
            settings.badge.background.usesGradient = gradient
        }
        if let shadow = toggle(.badgeBGShadow) {
            settings.badge.background.drawsShadow = shadow
        } else if importedBadgeBackground {
            settings.badge.background.drawsShadow = false
        }

        // Layout.
        if let position = token(.badgePosition, as: BadgePosition.self) {
            settings.badge.position = position
        }
        if let scale = number(.badgeScale, in: ForegroundSpec.symbolScaleRange) {
            settings.badge.scale = scale
        }
        if let offsetX = number(.badgeOffsetX, in: BadgeSpec.offsetRange) {
            settings.badge.offsetX = offsetX
        }
        if let offsetY = number(.badgeOffsetY, in: BadgeSpec.offsetRange) {
            settings.badge.offsetY = offsetY
        }

        // Symbol styling.
        if let rendering = token(.badgeSymbolRendering, as: SymbolRenderingStyle.self) {
            settings.badge.foreground.renderingStyle = rendering
        }
        if effectiveBadgeMode != .system {
            if let color = swiftUIColor(.badgeSymbolColor) {
                settings.badge.foreground.color = color
                settings.badge.foreground.hierarchicalColor = color
            }
        } else if let symbol = appexColor(.badgeSymbolColor) {
            appexColors.badgeSymbol = symbol
        }
        if let parts = colorList(.badgeSymbolPalette, expecting: 3) {
            if let primary = parseColor(parts[0], key: .badgeSymbolPalette) {
                settings.badge.foreground.palettePrimaryColor = primary
            }
            if let secondary = parseColor(parts[1], key: .badgeSymbolPalette) {
                settings.badge.foreground.paletteSecondaryColor = secondary
            }
            if let tertiary = parseColor(parts[2], key: .badgeSymbolPalette) {
                settings.badge.foreground.paletteTertiaryColor = tertiary
            }
        }
        if let weight = token(.badgeSymbolWeight, as: SymbolWeight.self) {
            settings.badge.foreground.symbolWeight = weight
        }
        if let gradient = toggle(.badgeSymbolGradient) {
            settings.badge.foreground.fillStyle = gradient ? .gradient : .flat
        }
        if let shadow = toggle(.badgeFGShadow) {
            settings.badge.foreground.drawsShadow = shadow
        } else if importedBadgeForeground {
            settings.badge.foreground.drawsShadow = false
        }
        if let badgeMode {
            settings.badge.mode = badgeMode
        }

        // Layer visibility: supplying `badge-fg` is what turns the badge on, so
        // the `?? true` here is the activation rule, not a restated default.
        settings.badge.foreground.isHidden = !(toggle(.badgeFGVisibility) ?? true)
        settings.badge.background.isHidden = !(toggle(.badgeBGVisibility) ?? true)
    }

    /// A colour inside a multi-colour list; failures warn under the list's key.
    private mutating func parseColor(_ raw: String, key: MicaConfigKey) -> Color? {
        do {
            return try ColorParser.parseWithOpacity(raw)
        } catch {
            warn(key.rawValue, "\"\(raw)\" is not a recognisable colour")
            return nil
        }
    }

    /// `scale` takes "1x"/"2x", or (liberally) the bare numbers 1 and 2.
    private mutating func exportScale() -> ExportScale? {
        guard let value = values[.scale] else { return nil }
        if let string = value as? String, !isBool(value) {
            if let scale = ExportScale(rawValue: string.lowercased()) { return scale }
        } else if let numeric = value as? NSNumber, !isBool(value) {
            if numeric.intValue == 1 { return .oneX }
            if numeric.intValue == 2 { return .twoX }
        }
        warn(MicaConfigKey.scale.rawValue, "expected \"1x\" or \"2x\"")
        return nil
    }
}

// MARK: - Encode implementation

private struct ConfigWriter {
    let settings: IconSettings
    let appexColors: MicaAppexColors

    /// Reference values for omit-at-default decisions. These are what decoding
    /// an absent key produces, so `decode(encode(s))` reproduces `s` for any
    /// canonically-shaped settings value. Where the baseline is conditional
    /// (fresh-import shadows, padding compensation) the condition is applied at
    /// the emission site, with a comment naming the decode rule it mirrors.
    private let defaults = IconSettings()
    private let defaultAppexColors = MicaAppexColors()

    func dictionary(assets: inout MicaConfigAssetCatalog) -> [String: Any] {
        var output: [String: Any] = [:]

        func put(_ key: MicaConfigKey, _ value: Any) {
            output[key.rawValue] = value
        }

        // Export.
        if settings.export.size != defaults.export.size { put(.size, Int(settings.export.size)) }
        if settings.export.isRetina { put(.scale, ExportScale.twoX.rawValue) }
        if settings.export.colorSpace != defaults.export.colorSpace {
            put(.colorSpace, settings.export.colorSpace.cliToken)
        }
        if settings.icon.mode == .system { put(.iconGenerationMode, GenerationMode.system.cliToken) }

        // Icon foreground source. Written unless it is the default symbol; an
        // image source with no pixels is inexpressible and stays omitted.
        let iconFG = settings.icon.foreground
        switch iconFG.source {
        case .symbol, .system:
            if iconFG.symbolName != defaults.icon.foreground.symbolName {
                put(.iconFG, ForegroundValue.symbol(iconFG.symbolName).cliValue)
            }
        case .image:
            if let image = iconFG.image {
                put(.iconFG, assets.relativePath(for: image))
            }
        }
        let iconFGIsImage = iconFG.source == .image && iconFG.image != nil
        if iconFGIsImage {
            if iconFG.imageScale != 1.0 { put(.iconFGScale, iconFG.imageScale) }
        } else if iconFG.symbolScale != 1.0 {
            put(.iconFGScale, iconFG.symbolScale)
        }
        if iconFG.renderingStyle != defaults.icon.foreground.renderingStyle {
            put(.iconSymbolRendering, iconFG.renderingStyle.cliToken)
        }
        // One key carries the symbol colour; the effective one wins (the
        // hierarchical well writes its own field in the GUI, but decode sets
        // both from this key, which is also what the flags do).
        if settings.icon.mode == .system {
            if appexColors.iconSymbol != defaultAppexColors.iconSymbol {
                put(.iconSymbolColor, appexColors.iconSymbol.plistValue)
            }
        } else {
            let effective = iconFG.renderingStyle == .hierarchical ? iconFG.hierarchicalColor : iconFG.color
            if effective != defaults.icon.foreground.color {
                put(.iconSymbolColor, MicaColor(resolving: effective).stringValue)
            }
        }
        let defaultPalette = (defaults.icon.foreground.palettePrimaryColor,
                              defaults.icon.foreground.paletteSecondaryColor,
                              defaults.icon.foreground.paletteTertiaryColor)
        if (iconFG.palettePrimaryColor, iconFG.paletteSecondaryColor, iconFG.paletteTertiaryColor) != defaultPalette {
            put(.iconSymbolPalette, [
                MicaColor(resolving: iconFG.palettePrimaryColor).stringValue,
                MicaColor(resolving: iconFG.paletteSecondaryColor).stringValue,
                MicaColor(resolving: iconFG.paletteTertiaryColor).stringValue,
            ])
        }
        if iconFG.symbolWeight != defaults.icon.foreground.symbolWeight {
            put(.iconSymbolWeight, iconFG.symbolWeight.cliToken)
        }
        if iconFG.fillStyle != defaults.icon.foreground.fillStyle {
            put(.iconSymbolGradient, iconFG.fillStyle == .gradient)
        }
        // Baseline mirrors decode's fresh-import rule: an imported foreground's
        // shadow defaults off.
        if iconFG.drawsShadow != (iconFGIsImage ? false : defaults.icon.foreground.drawsShadow) {
            put(.iconFGShadow, iconFG.drawsShadow)
        }
        if iconFG.isHidden != defaults.icon.foreground.isHidden {
            put(.iconFGVisibility, !iconFG.isHidden)
        }

        // Icon background.
        let iconBG = settings.icon.background
        let iconBGIsImage = iconBG.source == .image && iconBG.image != nil
        switch iconBG.source {
        case .color:
            if iconBG.usesCustomGradient {
                put(.iconBG, IconBackgroundValue.customGradient.cliValue)
                let defaultGradient = (defaults.icon.background.gradientStartColor,
                                       defaults.icon.background.gradientEndColor)
                if (iconBG.gradientStartColor, iconBG.gradientEndColor) != defaultGradient {
                    put(.iconBGGradientColors, [
                        MicaColor(resolving: iconBG.gradientStartColor).stringValue,
                        MicaColor(resolving: iconBG.gradientEndColor).stringValue,
                    ])
                }
            } else if settings.icon.mode != .system, iconBG.color != defaults.icon.background.color {
                put(.iconBGColor, MicaColor(resolving: iconBG.color).stringValue)
            }
        case .preRendered:
            put(.iconBG, IconBackgroundValue.preRendered.cliValue)
            if iconBG.preRenderedColorName.lowercased() != defaults.icon.background.preRenderedColorName.lowercased() {
                put(.iconBGColor, iconBG.preRenderedColorName.lowercased())
            }
        case .image:
            if let image = iconBG.image {
                put(.iconBG, assets.relativePath(for: image))
                if iconBG.imageScale != 1.0 { put(.iconBGScale, iconBG.imageScale) }
                // The padding key is the inverse of the stored compensation, and
                // decode's baseline for an image background is compensation on.
                if !iconBG.compensatesForPadding { put(.iconBGPadding, true) }
            }
        }
        if settings.icon.mode == .system, appexColors.iconEnclosure != defaultAppexColors.iconEnclosure {
            put(.iconBGColor, appexColors.iconEnclosure.plistValue)
        }
        if iconBG.usesGradient != defaults.icon.background.usesGradient {
            put(.iconBGGradient, iconBG.usesGradient)
        }
        if iconBG.cornerRadiusStyle != defaults.icon.background.cornerRadiusStyle {
            put(.iconBGCornerRadius, iconBG.cornerRadiusStyle.cliToken)
        }
        // Baseline mirrors decode's fresh-import rule: an imported background's
        // shadow defaults off.
        if iconBG.shadowStyle != (iconBGIsImage ? .off : defaults.icon.background.shadowStyle) {
            put(.iconBGShadow, iconBG.shadowStyle.cliToken)
        }
        if iconBG.isHidden != defaults.icon.background.isHidden {
            put(.iconBGVisibility, !iconBG.isHidden)
        }

        // Badge: an invisible badge is omitted whole (its stored state is the
        // documented lossiness); a visible one always writes `badge-fg`, the
        // activation key.
        if settings.badge.isVisible {
            writeBadge(into: &output, assets: &assets)
        }

        return output
    }

    private func writeBadge(into output: inout [String: Any], assets: inout MicaConfigAssetCatalog) {
        func put(_ key: MicaConfigKey, _ value: Any) {
            output[key.rawValue] = value
        }

        let badge = settings.badge
        let badgeFG = badge.foreground
        let badgeBG = badge.background

        if badge.mode == .system { put(.badgeGenerationMode, GenerationMode.system.cliToken) }

        // The activation key. A system badge writes its symbol name too —
        // decode applies `badge-generation-mode` after the source, restoring
        // `.system` exactly as the builder does for the flags.
        let badgeFGIsImage = badgeFG.source == .image && badgeFG.image != nil
        if badgeFGIsImage, let image = badgeFG.image {
            put(.badgeFG, assets.relativePath(for: image))
        } else {
            put(.badgeFG, ForegroundValue.symbol(badgeFG.symbolName).cliValue)
        }
        if badgeFGIsImage {
            if badgeFG.imageScale != 1.0 { put(.badgeFGScale, badgeFG.imageScale) }
        } else if badgeFG.symbolScale != 1.0 {
            put(.badgeFGScale, badgeFG.symbolScale)
        }
        if badgeFG.renderingStyle != SymbolRenderingStyle.monochrome {
            put(.badgeSymbolRendering, badgeFG.renderingStyle.cliToken)
        }
        if badge.mode == .system {
            if appexColors.badgeSymbol != defaultAppexColors.badgeSymbol {
                put(.badgeSymbolColor, appexColors.badgeSymbol.plistValue)
            }
        } else {
            let effective = badgeFG.renderingStyle == .hierarchical ? badgeFG.hierarchicalColor : badgeFG.color
            if effective != ForegroundSpec.badgeDefault.color {
                put(.badgeSymbolColor, MicaColor(resolving: effective).stringValue)
            }
        }
        let badgeDefault = ForegroundSpec.badgeDefault
        if (badgeFG.palettePrimaryColor, badgeFG.paletteSecondaryColor, badgeFG.paletteTertiaryColor)
            != (badgeDefault.palettePrimaryColor, badgeDefault.paletteSecondaryColor, badgeDefault.paletteTertiaryColor) {
            put(.badgeSymbolPalette, [
                MicaColor(resolving: badgeFG.palettePrimaryColor).stringValue,
                MicaColor(resolving: badgeFG.paletteSecondaryColor).stringValue,
                MicaColor(resolving: badgeFG.paletteTertiaryColor).stringValue,
            ])
        }
        if badgeFG.symbolWeight != badgeDefault.symbolWeight {
            put(.badgeSymbolWeight, badgeFG.symbolWeight.cliToken)
        }
        if badgeFG.fillStyle != badgeDefault.fillStyle {
            put(.badgeSymbolGradient, badgeFG.fillStyle == .gradient)
        }
        if badgeFG.drawsShadow != (badgeFGIsImage ? false : badgeDefault.drawsShadow) {
            put(.badgeFGShadow, badgeFG.drawsShadow)
        }
        // The activation baseline is both layers visible, not the spec default
        // (which is hidden) — supplying `badge-fg` is what shows the badge.
        if badgeFG.isHidden { put(.badgeFGVisibility, false) }
        if badgeBG.isHidden { put(.badgeBGVisibility, false) }

        // Badge background.
        let badgeBGIsImage = badgeBG.source == .image && badgeBG.image != nil
        switch badgeBG.source {
        case .color:
            if badgeBG.usesCustomGradient {
                put(.badgeBG, BadgeBackgroundValue.customGradient.cliValue)
                let defaultGradient = (BadgeBackgroundSpec().gradientStartColor,
                                       BadgeBackgroundSpec().gradientEndColor)
                if (badgeBG.gradientStartColor, badgeBG.gradientEndColor) != defaultGradient {
                    put(.badgeBGGradientColors, [
                        MicaColor(resolving: badgeBG.gradientStartColor).stringValue,
                        MicaColor(resolving: badgeBG.gradientEndColor).stringValue,
                    ])
                }
            } else if badge.mode != .system, badgeBG.color != BadgeBackgroundSpec().color {
                put(.badgeBGColor, MicaColor(resolving: badgeBG.color).stringValue)
            }
        case .image:
            if let image = badgeBG.image {
                put(.badgeBG, assets.relativePath(for: image))
                if badgeBG.imageScale != 1.0 { put(.badgeBGScale, badgeBG.imageScale) }
                if !badgeBG.compensatesForPadding { put(.badgeBGPadding, true) }
            }
        }
        if badge.mode == .system, appexColors.badgeEnclosure != defaultAppexColors.badgeEnclosure {
            put(.badgeBGColor, appexColors.badgeEnclosure.plistValue)
        }
        if badgeBG.usesGradient != BadgeBackgroundSpec().usesGradient {
            put(.badgeBGGradient, badgeBG.usesGradient)
        }
        if badgeBG.drawsShadow != (badgeBGIsImage ? false : BadgeBackgroundSpec().drawsShadow) {
            put(.badgeBGShadow, badgeBG.drawsShadow)
        }

        // Layout.
        if badge.position != BadgeSpec().position { put(.badgePosition, badge.position.cliToken) }
        if badge.scale != BadgeSpec().scale { put(.badgeScale, badge.scale) }
        if badge.offsetX != BadgeSpec().offsetX { put(.badgeOffsetX, badge.offsetX) }
        if badge.offsetY != BadgeSpec().offsetY { put(.badgeOffsetY, badge.offsetY) }
    }
}
