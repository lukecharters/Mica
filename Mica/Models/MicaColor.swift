// Models/MicaColor.swift
import SwiftUI
import AppKit

/// A colour as written in a Mica JSON configuration, encoding to and from a single
/// JSON string. Two different kinds of value share that one field, following Icon
/// Composer's `.icon` format:
///
/// - a **semantic token** — `"blue"`, `"system.blue"`, `"label"` — kept verbatim, so
///   a dynamic colour stays dynamic and re-resolves against whatever appearance the
///   configuration is later loaded in;
/// - **resolved components** — `"extended-srgb:0.00000,0.47843,1.00000,1.00000"` —
///   for a colour with no token, such as one picked in a colour well.
///
/// The distinction is not cosmetic. `Color.blue` is *not* a fixed triple; it is
/// `#007AFF` in Aqua and `#0A84FF` in Dark Aqua. Writing the token keeps both;
/// writing components freezes whichever appearance happened to be current when the
/// configuration was written.
///
/// ### Which one gets written
///
/// The plan called for preserving a token "only when the user picked one", but
/// `IconSettings` stores `Color`, not the string it was parsed from — by the time a
/// colour reaches here the original token is long gone. So the writer works by
/// value instead: if a colour is *equal* to a known token's colour, that token is
/// written. This is strictly better than tracking provenance, because it also
/// recovers the token for a colour that arrived some other way, and it can never
/// emit a token that resolves to a different colour than the one it replaced.
enum MicaColor: Equatable, Hashable, Sendable {
    /// A token resolved by `ColorParser` at read time.
    case token(String)
    /// Components resolved at write time.
    case components(ColorParser.ExtendedComponents)

    // MARK: - Writing

    /// Capture a `Color` for storage, preferring a semantic token.
    init(resolving color: Color) {
        if let token = Self.semanticToken(for: color) {
            self = .token(token)
        } else {
            self = .components(.resolving(color))
        }
    }

    /// The string written to `icon.json`.
    var stringValue: String {
        switch self {
        case .token(let token): return token
        case .components(let components): return components.stringValue
        }
    }

    // MARK: - Reading

    /// Parse a stored string.
    ///
    /// Deliberately tolerant: anything that is not the extended-component form is
    /// kept as a token *without* being validated, so an unrecognised colour surfaces
    /// at `resolvedColor()` rather than failing the whole configuration load — and
    /// it keeps the offending string available to name in a warning.
    init(parsing string: String) throws {
        if let components = try ColorParser.ExtendedComponents(parsing: string) {
            self = .components(components)
        } else {
            self = .token(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Resolve to a `Color`, throwing if a token is not one `ColorParser`
    /// understands. A hand-edited configuration can contain anything.
    func resolvedColor() throws -> Color {
        switch self {
        case .token(let token): return try ColorParser.parseWithOpacity(token)
        case .components(let components): return components.color
        }
    }

    // MARK: - Semantic tokens

    /// The tokens the writer may emit, in the order they are tried.
    ///
    /// Order matters where two tokens hold the same colour — SwiftUI's `.blue` and
    /// `Color(.systemBlue)` may well be identical — and the shorter, more portable
    /// token is the one worth writing, so the plain names come first.
    ///
    /// Every entry must parse back to the colour it was matched on.
    /// `MicaColorTests.everySemanticTokenReparsesToItsOwnColour` pins that, which is
    /// what makes `tokenColors` safe to build with `compactMap`: a token that stops
    /// parsing would be silently dropped here, and fails loudly there.
    static let semanticTokens: [String] = [
        // Achromatic first — the most common foreground and background choices.
        "white", "black", "clear", "gray",
        // SwiftUI's adaptive palette.
        "blue", "red", "green", "orange", "yellow",
        "pink", "purple", "indigo", "teal", "mint", "cyan", "brown",
        // AppKit's system palette, for colours the above does not cover.
        "system.blue", "system.red", "system.green", "system.orange", "system.yellow",
        "system.pink", "system.purple", "system.teal", "system.indigo", "system.mint",
        "system.cyan", "system.brown", "system.gray",
        // Appearance-dependent label colours.
        "label", "secondary.label", "tertiary.label", "quaternary.label",
    ]

    private static let tokenColors: [(token: String, color: Color)] = semanticTokens.compactMap { token in
        guard let color = try? ColorParser.parse(token) else { return nil }
        return (token, color)
    }

    /// The canonical token for `color`, or `nil` if it is not one.
    static func semanticToken(for color: Color) -> String? {
        tokenColors.first { $0.color == color }?.token
    }
}

// MARK: - Codable

extension MicaColor: Codable {
    init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        try self.init(parsing: string)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}
