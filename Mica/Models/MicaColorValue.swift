// Models/MicaColorValue.swift
import SwiftUI
import AppKit

/// A colour **and where it came from** — the type `IconSettings` stores in place of
/// a bare `Color`, and the one every surface reads.
///
/// ## Why provenance has to be stored
///
/// Nothing in Mica recorded where a colour came from until 2026-08-02, so both
/// surfaces reconstructed it by comparing values: the inspector asked "does this
/// equal a preset?" to decide whether to show a dropdown or a well, and the JSON
/// writer asked the same to decide between `"blue"` and components. By-value
/// inference is consistent as far as it goes — it can never emit a token that
/// resolves to a different colour — but it cannot tell *the* system blue from a
/// blue that happens to match today, and the colour well routinely produces
/// colours no token can describe (a Display P3 wheel pick is the default case, not
/// an exotic one).
///
/// The concrete bug it caused: `Color(.labelColor)` at 50% matched no token,
/// because the opacity broke equality, so a configuration saved in Aqua reopened
/// wrong in Dark Aqua. Here the token and the alpha are stored separately, so it
/// stays `label` and re-resolves.
///
/// ## Three invariants
///
/// - **A token survives an opacity change.** `.token("label")` with `alpha 0.5`
///   is still a token, so it follows the appearance and the OS.
/// - **Components are extended sRGB and never clamped**, so a wide-gamut pick
///   round-trips through JSON and reaches the Display P3 export path intact.
/// - **`alpha` is only ever a modifier on a token.** A `.components` source folds
///   its alpha into the components at construction, so `alpha == 1` there always.
///   Without that, `extended-srgb:1,0,0,0.5` and the same components at
///   `alpha 0.5` would be two spellings of one colour, and equality would have to
///   choose.
///
/// ## Precision
///
/// Components and alpha are rounded to five decimal places **at construction**
/// (decision D5, 2026-08-02), so synthesised `Equatable` means exactly "writes the
/// same string" and undo grouping cannot disagree with the file. Five places is
/// far beyond what a 16-bit-per-channel render can carry, so nothing visible is
/// lost.
struct MicaColorValue: Equatable, Hashable, Sendable {

    /// Where the colour came from. Deliberately closed: a colour is either a name
    /// the OS resolves, or numbers.
    enum Source: Equatable, Hashable, Sendable {
        /// A name in `ColorTokenTable` — `"blue"`, `"system.blue"`, `"label"`.
        /// Kept verbatim and resolved live, so it follows the appearance and the
        /// OS. Not validated on construction: a hand-edited configuration can
        /// name anything, and the offending string is worth keeping so an error
        /// can quote it.
        case token(String)
        /// Extended sRGB components, unclamped.
        case components(ColorParser.ExtendedComponents)
    }

    /// Five decimal places, matching Icon Composer and `ExtendedComponents`.
    static let precision = 5

    private(set) var source: Source

    /// A **multiplier** on whatever `source` resolves to, not a replacement
    /// (decision D4, 2026-08-02): `label:0.5` renders at ~42%, because
    /// `labelColor` is ~85% opaque, and that is the behaviour `mica-cli` has
    /// always had. Always `1` when `source` is `.components`.
    private(set) var alpha: Double

    // MARK: - Construction

    init(source: Source, alpha: Double = 1) {
        switch source {
        case .token(let name):
            self.source = .token(name)
            self.alpha = Self.round(min(max(alpha, 0), 1))
        case .components(let components):
            // Fold alpha in, so `.components` always carries its own opacity and
            // there is exactly one spelling of a translucent custom colour.
            self.source = .components(components.multiplyingAlpha(by: alpha).rounded(to: Self.precision))
            self.alpha = 1
        }
    }

    static func token(_ name: String, alpha: Double = 1) -> MicaColorValue {
        MicaColorValue(source: .token(name), alpha: alpha)
    }

    static func components(_ components: ColorParser.ExtendedComponents) -> MicaColorValue {
        MicaColorValue(source: .components(components))
    }

    /// Capture a colour that arrived with no provenance by matching it against the
    /// token table by value, and falling back to components.
    ///
    /// **Not for a colour well.** Its caller is a *string* that names no token —
    /// `#0088FF` from a configuration, which is worth writing back as `blue`. A
    /// well pick goes to `.components` directly (`Binding.asColor`), because it is
    /// custom by construction and minting a token from it swapped the inspector's
    /// control out mid-drag; see that binding's note.
    ///
    /// Matching is on **all four components**, deliberately. It would be possible
    /// to also match RGB-only and record the alpha ratio as a token modifier, and
    /// that is a trap: in Aqua `labelColor` is black at 84.7%, so `black` at 42% is
    /// *byte-identical* to `label` at 50% and no rule can tell them apart.
    /// Provenance flows from where a colour is **set** — a CLI token, a JSON token,
    /// the preset dropdown — and this initialiser is only the last resort for a
    /// value that genuinely has none.
    init(resolving color: Color) {
        let target = ColorParser.ExtendedComponents.resolving(color).rounded(to: Self.precision)
        for token in ColorTokenTable.all {
            let resolved = ColorParser.ExtendedComponents.resolving(token.color).rounded(to: Self.precision)
            if resolved == target {
                self.init(source: .token(token.name))
                return
            }
        }
        self.init(source: .components(target))
    }

    /// Parse a stored or typed string — a token, a token with a `:opacity`
    /// suffix, or anything else `ColorParser` understands.
    ///
    /// Deliberately tolerant about tokens: a name that is not in the table is
    /// still kept as `.token`, unvalidated, so a hand-edited configuration
    /// surfaces at `resolvedColor()` — which can quote the offending string —
    /// rather than failing the whole load somewhere that cannot. Throws only when
    /// a form that *names itself* is malformed, such as
    /// `"extended-srgb:oops"`.
    init(parsing string: String) throws {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // The space-prefixed forms contain a colon and carry their own alpha, so
        // they must be recognised before the `name:opacity` split — otherwise
        // "display-p3" reads as a colour name. Same ordering rule as
        // `ColorParser.parseWithOpacity`; do not reorder.
        if let components = try ColorParser.spacePrefixedComponents(parsing: trimmed) {
            self.init(source: .components(components))
            return
        }

        // A token, optionally with an opacity suffix. Checked against the table
        // rather than against `ColorParser`, so a name the table does not hold
        // cannot be stored as a `.token` nothing else in Mica understands.
        let parts = trimmed.split(separator: ":", maxSplits: 1)
        let base = String(parts.first ?? "")
        if let token = ColorTokenTable.token(named: base) {
            if parts.count == 2 {
                guard let opacity = Double(parts[1]), (0.0...1.0).contains(opacity) else {
                    throw ColorParseError.invalidOpacity(String(parts[1]), "Opacity must be between 0.0 and 1.0")
                }
                self.init(source: .token(token.name), alpha: opacity)
            } else {
                self.init(source: .token(token.name))
            }
            return
        }

        // Anything else ColorParser understands resolves to components now — hex,
        // rgb(), hsl(). There is no provenance to keep.
        if let color = try? ColorParser.parseWithOpacity(trimmed) {
            self.init(resolving: color)
            return
        }

        // Not a form we recognise at all. Keep it as a token so the error can name
        // it; `resolvedColor()` is where it fails.
        self.init(source: .token(trimmed))
    }

    /// Parse, and refuse a token the table does not hold.
    ///
    /// The CLI's entry point: a flag value is typed by a person at a prompt, and
    /// the moment to tell them `--icon-bg-color notacolour` is wrong is now, with
    /// `ColorParser`'s suggestions, rather than at a render that would silently
    /// draw nothing.
    init(strictlyParsing string: String) throws {
        try self.init(parsing: string)
        _ = try resolvedColor()
    }

    // MARK: - Resolving

    /// The colour, resolved against the current drawing appearance.
    ///
    /// Throws when `source` is a token the table does not hold — which only a
    /// hand-edited configuration can produce.
    func resolvedColor() throws -> Color {
        switch source {
        case .token(let name):
            let base = try ColorParser.parseWithOpacity(name)
            return alpha == 1 ? base : base.opacity(alpha)
        case .components(let components):
            return components.color
        }
    }

    /// The colour, for rendering and for UI swatches.
    ///
    /// Non-throwing because every render site needs a colour and none of them can
    /// report an error. An unresolvable token is refused at import, so reaching
    /// the fallback means a bug rather than bad input.
    var resolved: Color {
        (try? resolvedColor()) ?? .clear
    }

    /// Whether this names a token the table holds.
    var isToken: Bool {
        if case .token(let name) = source { return ColorTokenTable.token(named: name) != nil }
        return false
    }

    /// The token's name, if this is one the table holds.
    var tokenName: String? {
        guard case .token(let name) = source else { return nil }
        return ColorTokenTable.token(named: name)?.name
    }

    /// Whether this is a token offered as a preset swatch — what decides whether
    /// the inspector shows a dropdown or a colour well.
    var isPresentableToken: Bool {
        guard let name = tokenName else { return false }
        return ColorTokenTable.token(named: name)?.isPresentable ?? false
    }

    // MARK: - Writing

    /// The string written to a JSON configuration, and accepted back by
    /// `init(parsing:)`.
    var stringValue: String {
        switch source {
        case .token(let name):
            return alpha == 1 ? name : "\(name):\(Self.format(alpha))"
        case .components(let components):
            return components.stringValue
        }
    }

    // MARK: - Rounding

    private static func round(_ value: Double) -> Double {
        guard value.isFinite else { return value }
        let scale = pow(10.0, Double(precision))
        return (value * scale).rounded() / scale
    }

    /// Trailing zeros trimmed, so an opacity of 0.5 writes as `0.5` rather than
    /// `0.50000` — the suffix is user-facing in a way components are not.
    private static func format(_ value: Double) -> String {
        var text = String(format: "%.\(precision)f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}

// MARK: - Codable

extension MicaColorValue: Codable {
    init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        try self.init(parsing: string)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

// MARK: - Token conveniences
//
// Named to mirror `Color`'s, so a spec's default reads the same as it did when the
// property was a bare `Color`. Every one names a `.presentable` token, which
// `MicaColorValueTests.staticConveniencesArePresentableTokens` pins.

extension MicaColorValue {
    static let black = MicaColorValue.token("black")
    static let blue = MicaColorValue.token("blue")
    static let brown = MicaColorValue.token("brown")
    static let clear = MicaColorValue.token("clear")
    static let cyan = MicaColorValue.token("cyan")
    static let gray = MicaColorValue.token("gray")
    static let green = MicaColorValue.token("green")
    static let indigo = MicaColorValue.token("indigo")
    static let mint = MicaColorValue.token("mint")
    static let orange = MicaColorValue.token("orange")
    static let pink = MicaColorValue.token("pink")
    static let purple = MicaColorValue.token("purple")
    static let red = MicaColorValue.token("red")
    static let teal = MicaColorValue.token("teal")
    static let white = MicaColorValue.token("white")
    static let yellow = MicaColorValue.token("yellow")
}
