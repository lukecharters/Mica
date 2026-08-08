// Models/ColorTokens.swift
import SwiftUI
import AppKit

/// One named colour in Mica's vocabulary — the single source every surface reads.
///
/// A token is a *name*, not a value. `color` resolves live, so a token follows the
/// OS: `blue` is 0,136,255 in Aqua on macOS 26 and 0,122,255 on macOS 15, and Mica
/// renders whichever the machine says today. Freezing a token to components is what
/// `MicaColor` deliberately avoids, and what `ColorTokenOracleTests` guards against.
struct ColorToken: Identifiable, Sendable {

    /// What a token may be used *for*. A token is not automatically valid
    /// everywhere: `label` parses and writes fine but has no appex spelling, and
    /// `clear` is writable but is not a preset anyone should pick from a swatch.
    struct Capabilities: OptionSet, Sendable {
        let rawValue: Int

        /// Offered as a preset swatch in the inspector's colour dropdowns.
        static let presentable = Capabilities(rawValue: 1 << 0)

        /// Accepted verbatim by `ISSymbolColor` / `ISEnclosureColor` in an appex
        /// `Info.plist`. Anything else has to be resolved to components and
        /// clamped, because a value the pipeline rejects renders as a plausible
        /// white rather than failing.
        static let appexNative = Capabilities(rawValue: 1 << 1)
    }

    /// The canonical spelling — always lowercase, and the one that gets written.
    let name: String

    /// Other spellings that parse to this token. Never written.
    ///
    /// Only three kinds survive Phase 3: a British spelling (`grey`,
    /// `system.grey`), a different *word* for the same colour (`transparent`),
    /// and nothing else. The thirteen `systemblue`-style **no-dot forms were
    /// dropped on 2026-08-03** — they were the canonical name with its dot
    /// deleted, which is a second spelling of one token rather than a second name
    /// for it (§4.3 of the colour-resolution plan). Adding one back gives
    /// `--icon-bg-color` two ways to say the same thing and the help text two
    /// things to document.
    let aliases: [String]

    let capabilities: Capabilities

    private let resolve: @Sendable () -> Color

    init(
        _ name: String,
        aliases: [String] = [],
        _ capabilities: Capabilities = [],
        resolve: @escaping @Sendable () -> Color
    ) {
        self.name = name
        self.aliases = aliases
        self.capabilities = capabilities
        self.resolve = resolve
    }

    var id: String { name }

    /// Resolved against the current drawing appearance, every time it is read.
    var color: Color { resolve() }

    /// Title case, derived from `name` — there is deliberately no second
    /// hand-written list of display strings to drift out of step.
    /// `system.blue` → `System Blue`, `secondary.label` → `Secondary Label`.
    var displayName: String {
        name.split(separator: ".").map { $0.capitalized }.joined(separator: " ")
    }

    var isPresentable: Bool { capabilities.contains(.presentable) }
    var isAppexNative: Bool { capabilities.contains(.appexNative) }
}

/// Mica's colour-token vocabulary, in one place.
///
/// There used to be four independent lists — `OptionsCatalog.colorOptions` (15,
/// Title-Case), `MicaColor.semanticTokens` (33, lowercase), `AppexNamedColor`
/// (14 cases) and `ColorParser`'s two `switch` statements — none derived from any
/// other. They drifted: the appex pipeline accepts `mint` and `AppexNamedColor`
/// did not offer it. Everything now reads this table, so that class of gap is a
/// missing flag rather than a missing case.
enum ColorTokenTable {

    /// Every token, **in the order the JSON writer prefers them**.
    ///
    /// Order matters only where two tokens resolve to the same colour — SwiftUI's
    /// `.blue` and `Color(.systemBlue)` are byte-identical on macOS 26 — and the
    /// shorter, more portable name is the one worth writing. Achromatic first,
    /// then the plain palette, then the AppKit `system.*` spellings, then the
    /// appearance-dependent label ladder.
    static let all: [ColorToken] = [
        // Achromatic — the most common foreground and background choices.
        ColorToken("white", [.presentable, .appexNative]) { .white },
        ColorToken("black", [.presentable, .appexNative]) { .black },
        ColorToken("clear", aliases: ["transparent"]) { .clear },
        ColorToken("gray", aliases: ["grey"], [.presentable, .appexNative]) { .gray },

        // SwiftUI's adaptive palette. These fifteen (with the three achromatic
        // ones above) are exactly what the appex `Info.plist` accepts as a name.
        ColorToken("blue", [.presentable, .appexNative]) { .blue },
        ColorToken("red", [.presentable, .appexNative]) { .red },
        ColorToken("green", [.presentable, .appexNative]) { .green },
        ColorToken("orange", [.presentable, .appexNative]) { .orange },
        ColorToken("yellow", [.presentable, .appexNative]) { .yellow },
        ColorToken("pink", [.presentable, .appexNative]) { .pink },
        ColorToken("purple", [.presentable, .appexNative]) { .purple },
        ColorToken("indigo", [.presentable, .appexNative]) { .indigo },
        ColorToken("teal", [.presentable, .appexNative]) { .teal },
        ColorToken("mint", [.presentable, .appexNative]) { .mint },
        ColorToken("cyan", [.presentable, .appexNative]) { .cyan },
        ColorToken("brown", [.presentable, .appexNative]) { .brown },

        // AppKit's system palette, for colours the above does not cover.
        ColorToken("system.blue") { Color(.systemBlue) },
        ColorToken("system.red") { Color(.systemRed) },
        ColorToken("system.green") { Color(.systemGreen) },
        ColorToken("system.orange") { Color(.systemOrange) },
        ColorToken("system.yellow") { Color(.systemYellow) },
        ColorToken("system.pink") { Color(.systemPink) },
        ColorToken("system.purple") { Color(.systemPurple) },
        ColorToken("system.teal") { Color(.systemTeal) },
        ColorToken("system.indigo") { Color(.systemIndigo) },
        ColorToken("system.mint") { Color(.systemMint) },
        ColorToken("system.cyan") { Color(.systemCyan) },
        ColorToken("system.brown") { Color(.systemBrown) },
        ColorToken("system.gray", aliases: ["system.grey"]) { Color(.systemGray) },

        // Appearance-dependent label colours.
        ColorToken("label") { Color(.labelColor) },
        ColorToken("secondary.label") { Color(.secondaryLabelColor) },
        ColorToken("tertiary.label") { Color(.tertiaryLabelColor) },
        ColorToken("quaternary.label") { Color(.quaternaryLabelColor) },
    ]

    /// Preset swatches, alphabetically by display name — the order the inspector
    /// dropdowns have always shown.
    static let presentable: [ColorToken] =
        all.filter(\.isPresentable).sorted { $0.displayName < $1.displayName }

    /// The tokens an appex `Info.plist` takes verbatim, alphabetically by name.
    static let appexNative: [ColorToken] =
        all.filter(\.isAppexNative).sorted { $0.name < $1.name }

    /// The canonical names, in writer-preference order.
    static let names: [String] = all.map(\.name)

    /// Look a token up by canonical name or alias, case-insensitively — the
    /// parser's rule. Exact-spelling consumers (the appex plist) compare against
    /// `name` themselves.
    static func token(named name: String) -> ColorToken? {
        index[name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    /// Resolve a token name to its colour, or `nil` if it is not a token.
    static func color(forToken name: String) -> Color? {
        token(named: name)?.color
    }

    private static let index: [String: ColorToken] = {
        var map: [String: ColorToken] = [:]
        for token in all {
            for key in [token.name] + token.aliases {
                map[key.lowercased()] = token
            }
        }
        return map
    }()
}
