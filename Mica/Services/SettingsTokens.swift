// Services/SettingsTokens.swift
//
// The CLI/config token vocabulary. Every model enum that surfaces in a
// `generate` flag or a JSON configuration value has exactly one stable spelling
// per case, defined here and nowhere else — the flag transforms, the settings
// builder and the configuration codec all read this file, so a token cannot
// drift between them. (Until 2026-07-31 the lists lived twice: inline arrays in
// `GenerateCommand`'s transforms and a second set of switches in
// `IconGenerationRunner`'s private mappers.)
//
// `cliToken` is switch-based on purpose: a new enum case fails to compile until
// someone decides its spelling, rather than silently inheriting a raw value
// that tracks interface wording (raw values are authoritative for nothing —
// see `ForegroundSource` in Models/IconSettings.swift). The two exceptions are
// `GenerationMode` and `ExportColorSpace`, whose raw values *are* their CLI
// tokens by design and are pinned as such by `SettingsTokensTests`.

import Foundation

/// A model enum with one stable CLI/config spelling per case.
protocol SettingsTokenConvertible: CaseIterable {
    /// The stable CLI/config spelling for this case (e.g. "top-left", "macos11").
    var cliToken: String { get }
}

extension SettingsTokenConvertible {
    /// Every valid token, in case order — for help text and error messages.
    static var allCLITokens: [String] { allCases.map(\.cliToken) }

    /// The case for a token, matched case-insensitively; nil for an unknown token.
    static func from(cliToken token: String) -> Self? {
        let lowered = token.lowercased()
        return allCases.first { $0.cliToken.lowercased() == lowered }
    }
}

extension SymbolRenderingStyle: SettingsTokenConvertible {
    var cliToken: String {
        switch self {
        case .monochrome: return "monochrome"
        case .hierarchical: return "hierarchical"
        case .palette: return "palette"
        case .multicolor: return "multicolor"
        }
    }
}

extension SymbolWeight: SettingsTokenConvertible {
    var cliToken: String {
        switch self {
        case .auto: return "auto"
        case .ultraLight: return "ultralight"
        case .thin: return "thin"
        case .light: return "light"
        case .regular: return "regular"
        case .medium: return "medium"
        case .semibold: return "semibold"
        case .bold: return "bold"
        case .heavy: return "heavy"
        case .black: return "black"
        }
    }
}

extension BadgePosition: SettingsTokenConvertible {
    var cliToken: String {
        switch self {
        case .topLeft: return "top-left"
        case .topRight: return "top-right"
        case .bottomLeft: return "bottom-left"
        case .bottomRight: return "bottom-right"
        }
    }
}

extension IconCornerRadiusStyle: SettingsTokenConvertible {
    var cliToken: String {
        switch self {
        case .macOS11: return "macos11"
        case .macOS26: return "macos26"
        }
    }
}

extension BackgroundShadowStyle: SettingsTokenConvertible {
    var cliToken: String {
        switch self {
        case .off: return "off"
        // `.sequoia` spells as "macos11": the case is named for the last release
        // of the design it draws, the token for the range users recognise.
        case .sequoia: return "macos11"
        case .macOS26: return "macos26"
        }
    }
}

extension GenerationMode: SettingsTokenConvertible {
    /// Raw values are "mica"/"system" — the CLI tokens — by design.
    var cliToken: String { rawValue }
}

extension ExportColorSpace: SettingsTokenConvertible {
    /// Raw values are the `--color-space` tokens ("sRGB"/"displayP3") by design.
    var cliToken: String { rawValue }
}

// MARK: - Toggles and scales

/// A two-state `on|off` toggle taken as an option value (rather than a boolean
/// flag) so the `mica-cli` surface reads consistently, e.g.
/// `--icon-fg-shadow on` / `--icon-symbol-gradient off`. Shared by every
/// foreground/background/badge toggle across `generate` and by the JSON
/// configuration codec (which also accepts JSON booleans).
enum ToggleState: String, CaseIterable, Sendable {
    case on
    case off

    /// Whether this toggle is enabled.
    var isOn: Bool { self == .on }

    /// Build a toggle from a resolved boolean (used when mapping defaults that
    /// depend on other flags, e.g. shadow defaults that vary by icon source).
    init(_ isOn: Bool) { self = isOn ? .on : .off }
}

/// Output resolution multiplier shared by every `mica-cli` subcommand and the
/// JSON configuration's "scale" key. `1x` renders at the requested pixel size;
/// `2x` doubles it (retina).
enum ExportScale: String, CaseIterable, Sendable {
    case oneX = "1x"
    case twoX = "2x"

    /// Integer multiplier applied to the base pixel size.
    var factor: Int { self == .twoX ? 2 : 1 }

    /// The scale matching `ExportSpec`'s default, so `--scale`'s documented
    /// default is derived from the settings rather than restated as a literal.
    static var settingsDefault: ExportScale { ExportSpec().isRetina ? .twoX : .oneX }
}

// MARK: - Overloaded source values

/// The value of `--icon-fg` / `--badge-fg` (and the matching config keys): a
/// `symbol:` prefix selects an SF Symbol, anything else is an image file path.
enum ForegroundValue: Equatable, Sendable {
    case symbol(String)
    case image(String)

    /// nil only when the value is `symbol:` with an empty name — the caller owns
    /// the error or warning wording for that.
    init?(parsing raw: String) {
        if raw.lowercased().hasPrefix("symbol:") {
            let name = String(raw.dropFirst("symbol:".count))
            guard !name.isEmpty else { return nil }
            self = .symbol(name)
        } else {
            self = .image(raw)
        }
    }

    /// The CLI/config spelling of this value.
    var cliValue: String {
        switch self {
        case .symbol(let name): return "symbol:\(name)"
        case .image(let path): return path
        }
    }
}

/// The value of `--icon-bg` (and the matching config key): a recognised keyword
/// selects a generated background, anything else is an image file path.
enum IconBackgroundValue: Equatable, Sendable {
    case standard
    case customGradient
    case preRendered
    case image(String)

    /// The recognised keywords, for "is this a path?" checks and help text.
    static let keywords = ["standard", "custom-gradient", "prerendered-liquid-glass"]

    init(parsing raw: String) {
        switch raw.lowercased() {
        case "standard": self = .standard
        case "custom-gradient": self = .customGradient
        case "prerendered-liquid-glass": self = .preRendered
        default: self = .image(raw)
        }
    }

    /// The CLI/config spelling of this value.
    var cliValue: String {
        switch self {
        case .standard: return "standard"
        case .customGradient: return "custom-gradient"
        case .preRendered: return "prerendered-liquid-glass"
        case .image(let path): return path
        }
    }
}

/// The value of `--badge-bg` (and the matching config key). Smaller than the
/// icon's set — there are no pre-rendered badge assets.
enum BadgeBackgroundValue: Equatable, Sendable {
    case standard
    case customGradient
    case image(String)

    /// The recognised keywords, for "is this a path?" checks and help text.
    static let keywords = ["standard", "custom-gradient"]

    init(parsing raw: String) {
        switch raw.lowercased() {
        case "standard": self = .standard
        case "custom-gradient": self = .customGradient
        default: self = .image(raw)
        }
    }

    /// The CLI/config spelling of this value.
    var cliValue: String {
        switch self {
        case .standard: return "standard"
        case .customGradient: return "custom-gradient"
        case .image(let path): return path
        }
    }
}

// MARK: - Multi-colour values

/// The outcome of splitting a comma-joined colour list. The two failure cases
/// are distinct because the CLI reports them differently.
enum ColorListSplit: Equatable, Sendable {
    case ok([String])
    case wrongCount(Int)
    case emptyComponent
}

/// Split a comma-joined colour list into exactly `count` trimmed components.
/// The caller owns the error/warning wording — the CLI turns failures into
/// `ValidationError`s, the configuration codec into warnings.
func splitColorList(_ raw: String, expecting count: Int) -> ColorListSplit {
    let parts = raw
        .split(separator: ",", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count == count else { return .wrongCount(parts.count) }
    guard parts.allSatisfy({ !$0.isEmpty }) else { return .emptyComponent }
    return .ok(parts)
}

// MARK: - Pre-rendered background colours

/// Named asset colours available for `prerendered-liquid-glass` backgrounds.
/// Matches the `background-<color>-<gradient|solid>` assets in Assets.xcassets.
let validPreRenderedColors = [
    "black", "blue", "brown", "cyan", "darkgray", "darkmode", "gray", "green",
    "indigo", "lightgray", "mint", "orange", "pink", "purple", "red", "teal",
    "white", "yellow",
]
