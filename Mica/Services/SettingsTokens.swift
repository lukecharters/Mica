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
    /// The stable CLI/config spelling for this case (e.g. "top-left", "macos15").
    var cliToken: String { get }

    /// Superseded spellings still accepted on input. Read by `from(cliToken:)`
    /// and by nothing else: they are absent from `allCLITokens`, so they never
    /// reach help text, an error message or the configuration encoder. A
    /// configuration carrying one therefore round-trips to the canonical token.
    var supersededCLITokens: [String] { get }
}

extension SettingsTokenConvertible {
    /// No superseded spellings, which is the case for every enum but one.
    var supersededCLITokens: [String] { [] }

    /// Every valid token, in case order — for help text and error messages.
    static var allCLITokens: [String] { allCases.map(\.cliToken) }

    /// The case for a token, matched case-insensitively; nil for an unknown
    /// token. Canonical spellings are tried first, so a token that is canonical
    /// for one case can never be shadowed by another case's superseded list.
    static func from(cliToken token: String) -> Self? {
        let lowered = token.lowercased()
        if let canonical = allCases.first(where: { $0.cliToken.lowercased() == lowered }) {
            return canonical
        }
        return allCases.first { $0.supersededCLITokens.contains { $0.lowercased() == lowered } }
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
        case .off: return "off"
        case .macOS15: return "macos15"
        case .macOS26: return "macos26"
        }
    }

    var supersededCLITokens: [String] {
        switch self {
        // "macos11" named the *first* release of the macOS 11–15 design and was
        // the shipped token until 2026-08-08. Still decoded so configurations
        // exported before then keep loading; never written.
        case .macOS15: return ["macos11"]
        case .off, .macOS26: return []
        }
    }
}

extension BackgroundShadowStyle: SettingsTokenConvertible {
    var cliToken: String {
        switch self {
        case .off: return "off"
        case .macOS15: return "macos15"
        case .macOS26: return "macos26"
        }
    }

    /// Same supersession as `IconCornerRadiusStyle` — the two flags always took
    /// the same vocabulary and must keep doing so.
    var supersededCLITokens: [String] {
        switch self {
        case .macOS15: return ["macos11"]
        case .off, .macOS26: return []
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

    /// The disambiguator, and the whole reason it exists: this value is overloaded
    /// between a symbol name and an image path, so a symbol has to say so.
    ///
    /// `--icon-symbol` / `--badge-symbol` are *not* overloaded, which is why they
    /// take a bare name and reject this prefix rather than tolerating it — there is
    /// nothing there to disambiguate from.
    static let symbolPrefix = "symbol:"

    /// nil only when the value is `symbol:` with an empty name — the caller owns
    /// the error or warning wording for that.
    init?(parsing raw: String) {
        if raw.lowercased().hasPrefix(Self.symbolPrefix) {
            let name = String(raw.dropFirst(Self.symbolPrefix.count))
            guard !name.isEmpty else { return nil }
            self = .symbol(name)
        } else {
            self = .image(raw)
        }
    }

    /// True when `raw` carries the `symbol:` prefix, whatever follows it — including
    /// the empty name `init(parsing:)` rejects. The check a bare-name flag needs, and
    /// deliberately not spelled `init(parsing:) != nil`, which cannot tell a prefixed
    /// value from an image path.
    static func hasSymbolPrefix(_ raw: String) -> Bool {
        raw.lowercased().hasPrefix(symbolPrefix)
    }

    /// The CLI/config spelling of this value.
    var cliValue: String {
        switch self {
        case .symbol(let name): return "\(Self.symbolPrefix)\(name)"
        case .image(let path): return path
        }
    }
}

/// The value of `--icon-bg` (and the matching config key): a recognised keyword
/// selects a generated background, anything else is an image file path.
enum IconBackgroundValue: Equatable, Sendable {
    case standard
    case customGradient
    case image(String)

    /// The recognised keywords, for "is this a path?" checks and help text.
    static let keywords = ["standard", "custom-gradient"]

    /// Keywords that were recognised once and are now refused.
    ///
    /// `prerendered-liquid-glass` selected one of 35 bundled Liquid Glass images
    /// and was removed on 2026-08-16. It is named here rather than simply deleted
    /// because `init(parsing:)`'s fallback is `.image`, so a stale value would
    /// otherwise be read as a *file path* and reported as unreadable artwork —
    /// a file-not-found for a file the user never named. Callers check this first
    /// and say what actually happened.
    ///
    /// Unlike `SettingsTokenConvertible.supersededCLITokens`, a retired keyword
    /// does not resolve to anything: there is no surviving spelling of it.
    static let retiredKeywords = ["prerendered-liquid-glass"]

    /// True for a value that names a retired keyword rather than an image path.
    static func isRetiredKeyword(_ raw: String) -> Bool {
        retiredKeywords.contains(raw.lowercased())
    }

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

/// The value of `--badge-bg` (and the matching config key). Case-for-case
/// identical to the icon's since the pre-rendered assets went; see
/// `BadgeBackgroundSource` for why it stays a separate type.
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
