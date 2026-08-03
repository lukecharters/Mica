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
// - **Encode is minimal above an identity set, and gated by applicability.**
//   The keys that say *what the icon is* are always written, even at their
//   defaults; every other key equal to what decoding its absence would produce
//   is omitted; and any key that cannot affect the render is dropped whatever
//   its value. So an exported file reads as the flags you would have passed to
//   build this icon from scratch — not a diff against this build's defaults,
//   and not a record of settings that draw nothing. Values are JSON-native
//   (booleans, numbers, arrays). Both rules, the gate list, and the lossiness
//   they buy are set out on `ConfigWriter` below.
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

    // Group visibility. Decode-only — see `decodeOnlyNames`.
    case iconVisibility = "icon-visibility"
    case badgeVisibility = "badge-visibility"

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

    /// Keys accepted on the way in and never produced on the way out.
    ///
    /// A different thing from `processLevelNames`, which is excluded because those
    /// flags describe an *invocation* rather than an icon. These describe the icon
    /// perfectly well — they are sugar for writing both of a group's layer keys at
    /// once, and the canonical output form stays the two layer keys, so a file never
    /// carries two spellings of one state. Importing and re-exporting therefore
    /// rewrites them, which is the format working rather than a bug.
    ///
    /// The precedent for a legitimate input with no canonical key is the positional
    /// symbol. **The encoder must never emit one of these**; the flag/key parity in
    /// both directions still holds, because each is a real flag as well as a key.
    static let decodeOnlyNames: Set<String> = [
        MicaConfigKey.iconVisibility.rawValue,
        MicaConfigKey.badgeVisibility.rawValue,
    ]

    /// True for a key the decoder accepts but the encoder never writes.
    var isDecodeOnly: Bool { Self.decodeOnlyNames.contains(rawValue) }

    /// True for the badge-namespace keys — the *namespace*, not the activation rule.
    ///
    /// **Do not promote this to the activation predicate.** Three keys activate the
    /// badge (`activatingBadgeNames`); the rest of the namespace says how a badge
    /// looks or where it sits. Making every `badge-` key an activator would let
    /// `badge-position` conjure a default gearshape nobody named, and would make
    /// `badge-visibility: false` switch the badge on in order to hide it.
    var isBadgeKey: Bool {
        rawValue.hasPrefix("badge-")
    }

    /// The three keys that activate the badge, mirroring the CLI's
    /// `GenerateCommand.badgeIsActive`: the two that name what the badge *is*, plus
    /// the one that asks for it directly. `badge-visibility` activates only when
    /// true — see §3 of
    /// `docs/plans/visibility-activation-and-imported-backgrounds.md`.
    static let activatingBadgeNames: Set<String> = [
        MicaConfigKey.badgeFG.rawValue,
        MicaConfigKey.badgeBG.rawValue,
        MicaConfigKey.badgeVisibility.rawValue,
    ]

    /// True for a key that can switch the badge on.
    var canActivateBadge: Bool { Self.activatingBadgeNames.contains(rawValue) }

    /// The keys that style a group's *foreground*, which is rule 2 of the foreground
    /// rule: over an imported background, any one of these present means the user wants
    /// a foreground, so the import's hide-it default is overruled.
    ///
    /// **One list, read by both halves of the codec** — the reader to decide the
    /// baseline, the writer to decide whether that baseline was met. Two lists would
    /// drift, and the failure would be a configuration that decodes to a different icon
    /// than it was exported from. The corresponding CLI predicates are
    /// `IconForegroundOptions.foregroundArgumentGiven` and
    /// `BadgeOptions.foregroundArgumentGiven`.
    ///
    /// The visibility key is deliberately absent from both: it is rule 1, honoured
    /// exactly, and counting it would make an `off` imply a wanted foreground while
    /// asking to hide one.
    static let iconForegroundKeys: [MicaConfigKey] = [
        .iconFG, .iconFGScale, .iconSymbolRendering, .iconSymbolColor,
        .iconSymbolPalette, .iconSymbolWeight, .iconSymbolGradient, .iconFGShadow,
    ]

    /// The badge's counterpart to `iconForegroundKeys`.
    static let badgeForegroundKeys: [MicaConfigKey] = [
        .badgeFG, .badgeFGScale, .badgeSymbolRendering, .badgeSymbolColor,
        .badgeSymbolPalette, .badgeSymbolWeight, .badgeSymbolGradient, .badgeFGShadow,
    ]
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
        // Existence is this loader's business, not `importImage`'s, so an injected
        // loader stays in full control of what "loadable" means (the tests never
        // touch the disk). It has to be checked *somewhere*, because
        // `ImageImportService.importFromURL` does not fail on a path that isn't
        // there: its last resort is the file's Finder icon, and for a missing file
        // that is the generic document icon. Right for a deliberate import of an
        // app or a document, wrong for a typo in a configuration — which would
        // then render a blank page instead of warning. The flag path never meets
        // this, because `validateImagePaths` rejects a missing `--icon-fg` first.
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: url.path])
        }
        return try ImageImportService.importFromURL(url)
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

    /// A colour, **keeping its provenance**: a token in the file stays a token, so
    /// it re-resolves against whatever appearance and OS the configuration is next
    /// opened in. Resolving it here — which is what this did until 2026-08-02 —
    /// froze `"blue"` to whatever blue meant on the machine that read it.
    mutating func colorValue(_ key: MicaConfigKey) -> MicaColorValue? {
        guard let raw = string(key) else { return nil }
        return parseColor(raw, key: key)
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

        // Group visibility, before anything that writes a layer's own visibility:
        // the group key applies first and a layer key overrides it, mirroring the
        // builder rule for rule. Decode-only — the encoder writes the two layer keys
        // instead, so a round trip normalises this away.
        // The spec's `isHidden` setter writes both layers — see the builder, which
        // this mirrors, for why that setter rather than the GUI's
        // `setGroupVisible(_:for:)` wrapper.
        if let iconVisible = toggle(.iconVisibility) {
            settings.icon.isHidden = !iconVisible
        }
        let badgeGroupVisible = toggle(.badgeVisibility)
        if let badgeGroupVisible {
            settings.badge.isHidden = !badgeGroupVisible
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
            if effectiveIconMode != .system, let color = colorValue(.iconBGColor) {
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
        // The third conditional baseline: absent `icon-bg-corner-radius` + an imported
        // icon background ⇒ `.off`, mirroring `IconSpec.applyBackgroundImage`. Artwork
        // that fills its own bounds loses its corners to any radius at all, so a fresh
        // import turns clipping off; encode uses the same baseline.
        if let cornerRadius = token(.iconBGCornerRadius, as: IconCornerRadiusStyle.self) {
            settings.icon.background.cornerRadiusStyle = cornerRadius
        } else if importedBackground {
            settings.icon.background.cornerRadiusStyle = .off
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
            if let color = colorValue(.iconSymbolColor) {
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
        // The icon's foreground rule, mirroring the builder branch for branch:
        //
        //   1. `icon-fg-visibility` present → honour it exactly.
        //   2. Else an imported background + any other icon foreground key → visible.
        //   3. Else an imported background → hidden.
        //
        // Absent `icon-fg-visibility` + an imported icon background ⇒ hidden is one of
        // the three conditional baselines phase 7 must match on encode.
        //
        // Unlike the badge, this writes nothing without an imported background or an
        // explicit key: the badge's decode always writes both layers because activation
        // is what turns it on, whereas a visible icon foreground is the spec default
        // decode starts from. Writing unconditionally here would restate that default
        // and lose a `--config` base's value.
        //
        // No positional symbol to exclude — a configuration has none, so `icon-fg` is
        // always an explicit foreground request in a file.
        if let visibility = toggle(.iconFGVisibility) {
            settings.icon.foreground.isHidden = !visibility
        } else if importedBackground {
            settings.icon.foreground.isHidden = !iconForegroundKeyGiven
        }
        if let iconMode {
            settings.icon.mode = iconMode
        }

        // Badge. Gated on `badge-fg` exactly as the CLI gates on `--badge-fg`:
        // without it, badge keys are inert — but a config author deserves to
        // hear that, where a flag user gets the same silence the CLI gives.
        let badgeForegroundRaw = string(.badgeFG)
        // Three keys activate the badge, mirroring the CLI's `badgeIsActive`: the two
        // that name what the badge *is*, plus `badge-visibility` when true. Only
        // `true` counts, so `{"badge-visibility": false}` alone leaves the badge off —
        // a key that switches something off must never be what switches it on.
        //
        // A `false` does not veto the other two: activation and visibility are
        // separate steps, so `badge-fg` still activates and its layers then start
        // hidden, which is what lets a layer key reveal one.
        let badgeIsActive = badgeForegroundRaw != nil
            || string(.badgeBG) != nil
            || badgeGroupVisible == true
        if badgeIsActive {
            applyBadge(foregroundRaw: badgeForegroundRaw,
                       badgeMode: badgeMode,
                       effectiveBadgeMode: effectiveBadgeMode,
                       groupVisible: badgeGroupVisible)
        } else {
            // Nothing asked for a badge, so the rest of the namespace is inert. The
            // activating keys are excluded from the list: two are absent by
            // definition here, and `badge-visibility: false` is not inert — it was
            // applied above and is the reason we are in this branch. A config author
            // deserves to hear this, where a flag user gets the same silence the CLI
            // gives.
            let inert = MicaConfigKey.allCases.filter {
                $0.isBadgeKey && !$0.canActivateBadge && values[$0] != nil
            }
            if !inert.isEmpty {
                let activators = MicaConfigKey.activatingBadgeNames.sorted().joined(separator: ", ")
                warn(MicaConfigKey.badgeFG.rawValue,
                     "the badge is off — none of \(activators) asked for one — so these keys are inert: \(inert.map(\.rawValue).joined(separator: ", "))")
            }
        }
    }

    /// `foregroundRaw` is optional because `badge-fg` is no longer the only key that
    /// activates the badge: `badge-bg` or `badge-visibility: true` brings one on with
    /// its default foreground, which is the artwork-only case.
    private mutating func applyBadge(foregroundRaw: String?,
                                     badgeMode: GenerationMode?,
                                     effectiveBadgeMode: GenerationMode,
                                     groupVisible: Bool?) {
        var importedBadgeForeground = false
        if let foregroundRaw {
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
            if effectiveBadgeMode != .system, let color = colorValue(.badgeBGColor) {
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
            if let color = colorValue(.badgeSymbolColor) {
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

        // Layer visibility, in the same three-rule order as the builder: activation,
        // then the foreground rule, then the layer keys.
        //
        //   1. Activation sets both layers from the group baseline — `badge-visibility`
        //      when the file gave one, since the group key applied first and activation
        //      must not undo it. The fallback is the activation rule, not a restated
        //      spec default: both badge specs start hidden.
        //   2. Over a freshly imported badge background the foreground defaults
        //      *hidden*, unless another badge foreground key was given, which is an
        //      unambiguous request for one.
        //   3. A layer key wins over either.
        //
        // Absent `badge-fg-visibility` + an imported badge background ⇒ hidden is one
        // of the three conditional baselines phase 7 must mirror on encode.
        let groupBaseline = groupVisible ?? true
        let foregroundBaseline = (importedBadgeBackground && !badgeForegroundKeyGiven)
            ? false
            : groupBaseline
        settings.badge.foreground.isHidden = !(toggle(.badgeFGVisibility) ?? foregroundBaseline)
        settings.badge.background.isHidden = !(toggle(.badgeBGVisibility) ?? groupBaseline)
    }

    /// True when any key styling the icon *foreground* is present — rule 2 of the
    /// foreground rule. Mirrors `IconForegroundOptions.foregroundArgumentGiven`, and
    /// excludes `icon-fg-visibility` for the same reason: it is rule 1, honoured
    /// exactly, and counting it would make `icon-fg-visibility: false` imply a wanted
    /// foreground while asking to hide one.
    private var iconForegroundKeyGiven: Bool {
        MicaConfigKey.iconForegroundKeys.contains { values[$0] != nil }
    }

    /// True when any key styling the badge *foreground* is present — rule 2 of the
    /// foreground rule. `badge-fg-visibility` is excluded deliberately: it is rule 1,
    /// honoured exactly, and counting it would make `badge-fg-visibility: false` imply
    /// a wanted foreground while asking to hide one. Mirrors
    /// `BadgeOptions.foregroundArgumentGiven`.
    private var badgeForegroundKeyGiven: Bool {
        MicaConfigKey.badgeForegroundKeys.contains { values[$0] != nil }
    }

    /// A colour, provenance kept; failures warn under the given key.
    ///
    /// `MicaColorValue(parsing:)` is deliberately tolerant of unknown token names,
    /// so the validity check is `resolvedColor()` — that is the call that knows
    /// whether the name means anything, and it can quote the offending string.
    mutating func parseColor(_ raw: String, key: MicaConfigKey) -> MicaColorValue? {
        do {
            let value = try MicaColorValue(parsing: raw)
            _ = try value.resolvedColor()
            return value
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

    // MARK: The identity set
    //
    // The keys that identify the artwork are written even when they hold their
    // default value. Mica has no document model — an exported configuration is
    // the *only* record of a user's work — so a file that omits everything
    // default does not describe an icon, it describes whatever this build's
    // defaults happen to be. Change `ForegroundSpec.iconDefault` in a later
    // version and every such file silently renders something else.
    //
    // The set: `size`, the two generation modes, each group's foreground
    // source, its symbol colour, and whichever background key is operative.
    // Everything else is a *modifier* of those and stays omit-at-default —
    // which is what keeps an exported file readable as a short list of
    // intentions rather than all 51 keys. Resist adding to it for any weaker
    // reason than "a reader cannot tell what they would get without this".
    //
    // MARK: The applicability gates
    //
    // Cutting *across* identity: a key that cannot affect the render is never
    // written, whatever its value. The file describes the render, so a key that
    // draws nothing has no business in it. The gates, each named at the site
    // that applies it and each mirroring a specific render decision:
    //
    //   1. System mode        — the appex raster reads only symbol name, symbol
    //                           colour and enclosure colour; every other
    //                           Mica-side key in that group is dropped.
    //   2. *deleted*          — was "an imported background replaces its group's
    //                           foreground". Deleted on 2026-08-03 with the
    //                           render veto it mirrored: importing now merely
    //                           *hides* the foreground, so gate 6 drops exactly
    //                           the same keys and drops them correctly when the
    //                           user switches the foreground back on, which this
    //                           gate could not do. The number is left standing so
    //                           the others keep the names they are called by.
    //   3. Non-symbol foreground — an image reads no `*-symbol-*` key.
    //   4. Rendering style    — `*-symbol-color` under palette, or
    //                           `*-symbol-palette` under anything else.
    //   5. Background source  — `.color` reads the colour/gradient keys,
    //                           `.image` reads scale/padding/corner radius,
    //                           `.preRendered` reads neither gradient nor
    //                           corner radius; it is drawn as-is.
    //   6. Hidden layer       — a layer that does not draw takes its appearance
    //                           keys with it, `badge-fg` included since gate 2
    //                           went. Visibility keys themselves are never
    //                           gated: they are what did the hiding.
    //
    // Three baselines are *conditional* on a freshly imported background, and each
    // is applied at its emission site with the decode rule it mirrors named there:
    // absent `icon-fg-visibility` ⇒ hidden, absent `badge-fg-visibility` ⇒ hidden,
    // absent `icon-bg-corner-radius` ⇒ `.off`. The first two are read off the keys
    // this encode actually wrote, using the same `MicaConfigKey.…ForegroundKeys`
    // list decode reads, so the two halves agree by construction.
    //
    // **This is deliberately lossy**, on the same terms as the already-documented
    // invisible badge: set a palette, switch to monochrome, export, and the
    // palette is gone. That is the accepted cost of the file meaning exactly
    // what it renders. Before relaxing a gate, check the render code rather than
    // the key's name — `icon-bg-corner-radius` looks inert for an imported
    // background and is not (`IconContentView.swift:180` clips with it), while
    // it genuinely is inert for a pre-rendered one.

    func dictionary(assets: inout MicaConfigAssetCatalog) -> [String: Any] {
        var output: [String: Any] = [:]

        func put(_ key: MicaConfigKey, _ value: Any) {
            // The encoder is the only writer, so this is where "decode-only" is
            // enforced. A group visibility key here would put a second spelling of
            // one state into the file, which is exactly what the canonical form
            // exists to prevent.
            assert(!key.isDecodeOnly, "'\(key.rawValue)' is decode-only and must never be written")
            guard !key.isDecodeOnly else { return }
            output[key.rawValue] = value
        }

        let iconFG = settings.icon.foreground
        let iconBG = settings.icon.background
        let isSystem = settings.icon.mode == .system
        let iconFGIsImage = iconFG.source == .image && iconFG.image != nil
        let iconBGIsImage = iconBG.source == .image && iconBG.image != nil

        // Applicability gates. Each names the render site it mirrors; if one of
        // those moves, this moves with it or the file starts describing keys
        // that draw nothing.
        //
        // System mode replaces the whole Mica pipeline with an appex raster
        // (`IconRenderer.renderAppexWithBadge`), and `AppexReferenceService`
        // takes exactly three inputs: symbol name, symbol colour, enclosure
        // colour. Every other Mica-side key describes a pipeline that did not
        // run.
        //
        // Gate 2 is gone: an imported background no longer replaces the
        // foreground, so there is nothing here for it to mirror. What used to be
        // dropped by "imported background" is now dropped by gate 6 — a hidden
        // layer takes its appearance keys with it — and dropped *correctly* when
        // the user switches the foreground back on, which gate 2 could not do.
        let iconFGDraws = !isSystem && !iconFG.isHidden
        // Symbol styling needs a symbol; an image foreground reads none of it.
        let iconSymbolStyling = iconFGDraws && !iconFGIsImage
        // Palette and the single symbol colour are mutually exclusive
        // (`IconContentView.applySymbolColor`).
        let iconUsesPalette = iconFG.renderingStyle == .palette
        let iconBGDraws = !isSystem && !iconBG.isHidden

        // Export — always operative. `size` is identity: an implicit export size
        // is the one thing you cannot recover by looking at the file.
        put(.size, Int(settings.export.size))
        if settings.export.isRetina { put(.scale, ExportScale.twoX.rawValue) }
        if settings.export.colorSpace != defaults.export.colorSpace {
            put(.colorSpace, settings.export.colorSpace.cliToken)
        }
        // Identity: which pipeline drew this decides what every other key means.
        put(.iconGenerationMode, settings.icon.mode.cliToken)

        // Icon foreground source — identity. Written in System mode too, where
        // the symbol name is what the appex is built from.
        if isSystem || iconFGDraws {
            switch iconFG.source {
            case .symbol, .system:
                put(.iconFG, ForegroundValue.symbol(iconFG.symbolName).cliValue)
            case .image:
                // An image source with no pixels is inexpressible.
                if let image = iconFG.image {
                    put(.iconFG, assets.relativePath(for: image))
                }
            }
        }
        if iconFGDraws {
            let scale = iconFGIsImage ? iconFG.imageScale : iconFG.symbolScale
            if scale != 1.0 { put(.iconFGScale, scale) }
        }
        if iconSymbolStyling, iconFG.renderingStyle != defaults.icon.foreground.renderingStyle {
            put(.iconSymbolRendering, iconFG.renderingStyle.cliToken)
        }
        // The operative symbol colour is identity, and exactly one key carries
        // it: `icon-symbol-color` or `icon-symbol-palette`, never both. The
        // effective colour wins (the hierarchical well writes its own field in
        // the GUI, but decode sets both from this key, as the flags do).
        if isSystem {
            put(.iconSymbolColor, appexColors.iconSymbol.configValue)
        } else if iconSymbolStyling, !iconUsesPalette {
            let effective = iconFG.renderingStyle == .hierarchical ? iconFG.hierarchicalColor : iconFG.color
            put(.iconSymbolColor, effective.stringValue)
        }
        if iconSymbolStyling, iconUsesPalette {
            put(.iconSymbolPalette, [
                iconFG.palettePrimaryColor.stringValue,
                iconFG.paletteSecondaryColor.stringValue,
                iconFG.paletteTertiaryColor.stringValue,
            ])
        }
        if iconSymbolStyling, iconFG.symbolWeight != defaults.icon.foreground.symbolWeight {
            put(.iconSymbolWeight, iconFG.symbolWeight.cliToken)
        }
        if iconSymbolStyling, iconFG.fillStyle != defaults.icon.foreground.fillStyle {
            put(.iconSymbolGradient, iconFG.fillStyle == .gradient)
        }
        // Baseline mirrors decode's fresh-import rule: an imported foreground's
        // shadow defaults off.
        if iconFGDraws,
           iconFG.drawsShadow != (iconFGIsImage ? false : defaults.icon.foreground.drawsShadow) {
            put(.iconFGShadow, iconFG.drawsShadow)
        }
        // Visibility is never gated — it is what did the hiding — but its baseline is
        // conditional, mirroring decode's foreground rule: over an imported background,
        // absent `icon-fg-visibility` means *hidden* unless another icon foreground key
        // is present.
        //
        // So the baseline is read off the keys this encode actually wrote, using the
        // same key list decode's `iconForegroundKeyGiven` reads. That is what makes the
        // two agree by construction rather than by both being right. The pleasant
        // consequence: over imported artwork the key is usually omitted entirely, since
        // the presence or absence of the foreground's own keys already carries the
        // state. The exception is real and is why this is computed rather than assumed —
        // an image foreground with no pixels writes no `icon-fg`, so the key is needed
        // to say the foreground is visible.
        //
        // `iconBGImportWritten`, not `iconBGIsImage`: in System mode gate 1 drops the
        // background entirely, so the *file* has no imported background for decode's
        // rule to fire on, whatever the settings hold.
        let iconBGImportWritten = iconBGDraws && iconBGIsImage
        let iconForegroundKeyWritten = MicaConfigKey.iconForegroundKeys.contains { output[$0.rawValue] != nil }
        let iconFGHiddenBaseline = iconBGImportWritten
            ? !iconForegroundKeyWritten
            : defaults.icon.foreground.isHidden
        if iconFG.isHidden != iconFGHiddenBaseline {
            put(.iconFGVisibility, !iconFG.isHidden)
        }

        // Icon background. Whichever key describes the operative background is
        // identity; the rest is gated on the source, because each source reads a
        // different subset (`IconContentView.backgroundLayer`).
        if iconBGDraws {
            switch iconBG.source {
            case .color:
                if iconBG.usesCustomGradient {
                    put(.iconBG, IconBackgroundValue.customGradient.cliValue)
                    put(.iconBGGradientColors, [
                        iconBG.gradientStartColor.stringValue,
                        iconBG.gradientEndColor.stringValue,
                    ])
                } else {
                    put(.iconBGColor, iconBG.color.stringValue)
                }
                if iconBG.usesGradient != defaults.icon.background.usesGradient {
                    put(.iconBGGradient, iconBG.usesGradient)
                }
            case .preRendered:
                // Drawn as-is: no gradient, no scale, and no corner radius.
                put(.iconBG, IconBackgroundValue.preRendered.cliValue)
                put(.iconBGColor, iconBG.preRenderedColorName.lowercased())
            case .image:
                if let image = iconBG.image {
                    put(.iconBG, assets.relativePath(for: image))
                    if iconBG.imageScale != 1.0 { put(.iconBGScale, iconBG.imageScale) }
                    // The padding key is the inverse of the stored compensation,
                    // and decode's baseline for an image background is on.
                    if !iconBG.compensatesForPadding { put(.iconBGPadding, true) }
                }
            }
            // The corner radius shapes the chiclet and clips an imported image
            // (`IconContentView`'s `.image` branch, which skips `clipShape` entirely at
            // `.off`), but a pre-rendered asset is drawn unclipped and ignores it.
            //
            // Baseline mirrors decode's fresh-import rule, the third of the three: an
            // imported background's corner radius defaults to `.off`, so a user who
            // wants their artwork clipped produces a key and a user who accepts the
            // import default does not.
            if iconBG.source != .preRendered {
                let cornerBaseline: IconCornerRadiusStyle = iconBGImportWritten
                    ? .off
                    : defaults.icon.background.cornerRadiusStyle
                if iconBG.cornerRadiusStyle != cornerBaseline {
                    put(.iconBGCornerRadius, iconBG.cornerRadiusStyle.cliToken)
                }
            }
            // Every source draws the background shadow. Baseline mirrors
            // decode's fresh-import rule: an imported background's shadow is off.
            if iconBG.shadowStyle != (iconBGIsImage ? .off : defaults.icon.background.shadowStyle) {
                put(.iconBGShadow, iconBG.shadowStyle.cliToken)
            }
        }
        if isSystem {
            put(.iconBGColor, appexColors.iconEnclosure.configValue)
        }
        // As with the foreground: still what gates the appex raster in System
        // mode, so it is never suppressed.
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
            // The encoder is the only writer, so this is where "decode-only" is
            // enforced. A group visibility key here would put a second spelling of
            // one state into the file, which is exactly what the canonical form
            // exists to prevent.
            assert(!key.isDecodeOnly, "'\(key.rawValue)' is decode-only and must never be written")
            guard !key.isDecodeOnly else { return }
            output[key.rawValue] = value
        }

        let badge = settings.badge
        let badgeFG = badge.foreground
        let badgeBG = badge.background
        let badgeDefault = ForegroundSpec.badgeDefault
        let badgeFGIsImage = badgeFG.source == .image && badgeFG.image != nil

        // The badge's gates, mirroring the icon's. Two are specific to it:
        //
        // A System badge draws *only* the appex raster (`BadgeView.swift:42`),
        // so every Mica-side badge key below describes nothing.
        //
        // Gate 2 is gone here too: an imported badge background no longer suppresses
        // the badge symbol, so gate 6 does this work instead — and does it correctly
        // when the user switches the symbol back on.
        let badgeIsSystem = badge.mode == .system
        let badgeBGDrawsImage = badgeBG.drawsImage
        let badgeFGDraws = !badgeIsSystem && !badgeFG.isHidden
        let badgeSymbolStyling = badgeFGDraws && !badgeFGIsImage
        let badgeUsesPalette = badgeFG.renderingStyle == .palette
        let badgeBGDraws = !badgeIsSystem && !badgeBG.isHidden

        // Identity, on the same terms as the icon's — but only reached at all
        // once the badge is visible, so a switched-off badge stays absent.
        put(.badgeGenerationMode, badge.mode.cliToken)

        // `badge-fg` loses its blanket "never gated" exemption: gate 6 applies to it
        // like any other foreground key, so an artwork-only badge writes no symbol name
        // and re-imports as artwork-only rather than as a symbol nobody asked for.
        //
        // What replaces the exemption is an invariant — **a visible badge must carry at
        // least one activating key**, or the whole group decodes as absent. `badge-bg`
        // is the other activator, and it is written for imported artwork and for a
        // custom gradient. It is *not* written for a plain colour background, which
        // writes only `badge-bg-color`; that key does not activate. So `badge-fg` is
        // also written as the fallback activator whenever nothing else would be, which
        // is narrower than the old exemption and provable rather than assumed.
        //
        // A system badge writes its symbol name too — decode applies
        // `badge-generation-mode` after the source, restoring `.system` as the builder
        // does for flags.
        let badgeBGKeyWritten = badgeBGDraws
            && ((badgeBG.source == .color && badgeBG.usesCustomGradient)
                || (badgeBG.source == .image && badgeBG.image != nil))
        if badgeFGDraws || badgeIsSystem || !badgeBGKeyWritten {
            if badgeFGIsImage, let image = badgeFG.image {
                put(.badgeFG, assets.relativePath(for: image))
            } else {
                put(.badgeFG, ForegroundValue.symbol(badgeFG.symbolName).cliValue)
            }
        }
        if badgeFGDraws {
            let scale = badgeFGIsImage ? badgeFG.imageScale : badgeFG.symbolScale
            if scale != 1.0 { put(.badgeFGScale, scale) }
        }
        if badgeSymbolStyling, badgeFG.renderingStyle != SymbolRenderingStyle.monochrome {
            put(.badgeSymbolRendering, badgeFG.renderingStyle.cliToken)
        }
        // Exactly one of colour / palette, as with the icon.
        if badgeIsSystem {
            put(.badgeSymbolColor, appexColors.badgeSymbol.configValue)
        } else if badgeSymbolStyling, !badgeUsesPalette {
            let effective = badgeFG.renderingStyle == .hierarchical ? badgeFG.hierarchicalColor : badgeFG.color
            put(.badgeSymbolColor, effective.stringValue)
        }
        if badgeSymbolStyling, badgeUsesPalette {
            put(.badgeSymbolPalette, [
                badgeFG.palettePrimaryColor.stringValue,
                badgeFG.paletteSecondaryColor.stringValue,
                badgeFG.paletteTertiaryColor.stringValue,
            ])
        }
        if badgeSymbolStyling, badgeFG.symbolWeight != badgeDefault.symbolWeight {
            put(.badgeSymbolWeight, badgeFG.symbolWeight.cliToken)
        }
        if badgeSymbolStyling, badgeFG.fillStyle != badgeDefault.fillStyle {
            put(.badgeSymbolGradient, badgeFG.fillStyle == .gradient)
        }
        if badgeFGDraws, badgeFG.drawsShadow != (badgeFGIsImage ? false : badgeDefault.drawsShadow) {
            put(.badgeFGShadow, badgeFG.drawsShadow)
        }
        // Never gated — these are what switch the badge's layers off at all — but the
        // foreground's baseline is now *two* conditions composed, so it is written out
        // in full rather than left to be recomposed by the next reader:
        //
        //   * The activation baseline is both layers visible, not the spec default
        //     (which is hidden): activating the badge is what shows it.
        //   * Over an imported badge background, absent `badge-fg-visibility` means
        //     hidden unless another badge foreground key is present — decode's
        //     foreground rule, read off the keys this encode actually wrote.
        //
        // Composed: hidden is the baseline exactly when the file describes imported
        // artwork and no badge foreground key went with it.
        let badgeBGImportWritten = badgeBGDraws && badgeBG.source == .image && badgeBG.image != nil
        let badgeForegroundKeyWritten = MicaConfigKey.badgeForegroundKeys.contains { output[$0.rawValue] != nil }
        let badgeFGHiddenBaseline = badgeBGImportWritten && !badgeForegroundKeyWritten
        if badgeFG.isHidden != badgeFGHiddenBaseline {
            put(.badgeFGVisibility, !badgeFG.isHidden)
        }
        if badgeBG.isHidden { put(.badgeBGVisibility, false) }

        // Badge background. The badge has no corner-radius key — it is a
        // `Circle()` unless an imported image gives it a shape of its own.
        if badgeBGDraws {
            switch badgeBG.source {
            case .color:
                if badgeBG.usesCustomGradient {
                    put(.badgeBG, BadgeBackgroundValue.customGradient.cliValue)
                    put(.badgeBGGradientColors, [
                        badgeBG.gradientStartColor.stringValue,
                        badgeBG.gradientEndColor.stringValue,
                    ])
                } else {
                    put(.badgeBGColor, badgeBG.color.stringValue)
                }
                if badgeBG.usesGradient != BadgeBackgroundSpec().usesGradient {
                    put(.badgeBGGradient, badgeBG.usesGradient)
                }
            case .image:
                if let image = badgeBG.image {
                    put(.badgeBG, assets.relativePath(for: image))
                    if badgeBG.imageScale != 1.0 { put(.badgeBGScale, badgeBG.imageScale) }
                    if !badgeBG.compensatesForPadding { put(.badgeBGPadding, true) }
                }
            }
            if badgeBG.drawsShadow != (badgeBGDrawsImage ? false : BadgeBackgroundSpec().drawsShadow) {
                put(.badgeBGShadow, badgeBG.drawsShadow)
            }
        }
        if badgeIsSystem {
            put(.badgeBGColor, appexColors.badgeEnclosure.configValue)
        }

        // Layout.
        if badge.position != BadgeSpec().position { put(.badgePosition, badge.position.cliToken) }
        if badge.scale != BadgeSpec().scale { put(.badgeScale, badge.scale) }
        if badge.offsetX != BadgeSpec().offsetX { put(.badgeOffsetX, badge.offsetX) }
        if badge.offsetY != BadgeSpec().offsetY { put(.badgeOffsetY, badge.offsetY) }
    }
}
