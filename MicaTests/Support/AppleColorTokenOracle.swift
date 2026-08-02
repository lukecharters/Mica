// AppleColorTokenOracle.swift
//
// Apple's own values for the fifteen colour tokens, so a test can assert that
// Mica's tokens resolve to what Apple says they mean — rather than to a literal
// somebody typed in once and never revisited.
//
// ## Why this exists at all
//
// A token's whole point is that it *moves*: `blue` was #007AFF through macOS 15
// and is #0088FF on macOS 26. Mica resolves tokens live so it follows that. The
// risk is the opposite one — that a resolution silently changes and nobody
// notices, or that a refactor freezes a token to a component triple. This table
// is the one place in the repo where an Apple system colour may be compared to a
// literal, and it names the OS version it encodes. `CLAUDE.md`'s "never pin an
// Apple system colour to a literal in a test" applies everywhere else.
//
// ## Provenance, and why it is transcribed rather than read
//
// The values are Apple's published macOS 26 system colours, cross-checked against
// the SF Symbols app's own `colors-26.csv` (the "Light Standard" and
// "Dark Standard" columns) which is kept, Apple-derived and unpublished, in
// `.local/sf-symbols-app/`. This file is a hand transcription of fifteen rows
// rather than a copy of Apple's file, decided as D6 in
// `docs/plans/colour-resolution.md` on 2026-08-02. Do not add a build step that
// reads the CSV — it is gitignored, so such a test is a no-op on any other Mac.
//
// ## Known deviations
//
// Apple's table and the live system do not agree everywhere; `deviations` records
// what was measured on macOS 26.0 on 2026-08-02, so a future divergence is a test
// failure rather than a shrug. Two of the twenty CSV rows disagreed with AppKit:
// `indigo` Dark Standard (recorded below) and `quinary`, which is flagged
// `Symbol App Ready = FALSE` in Apple's own file and is not a Mica token.

import Foundation

/// A token's expected sRGB bytes in one appearance.
struct AppleTokenRGB: Equatable, Sendable {
    let r: Int
    let g: Int
    let b: Int

    init(_ r: Int, _ g: Int, _ b: Int) {
        self.r = r
        self.g = g
        self.b = b
    }
}

enum AppleColorTokenOracle {

    /// The OS these values describe. Named, because they are version-specific.
    static let osVersion = "macOS 26"

    /// Apple's Light Standard / Dark Standard values for the fifteen tokens the
    /// appex pipeline accepts by name.
    ///
    /// Standard is one of *eight* renderings Apple publishes per token — Light/Dark
    /// × Standard/Vibrant × Standard/Increased Contrast. Standard is the pair Mica
    /// renders into, since an exported PNG has no vibrancy and no accessibility
    /// context; the other six are why freezing a token to components loses more
    /// than "light or dark".
    static let standard: [String: (light: AppleTokenRGB, dark: AppleTokenRGB)] = [
        "red":    (AppleTokenRGB(255, 56, 60),    AppleTokenRGB(255, 66, 69)),
        "orange": (AppleTokenRGB(255, 141, 40),   AppleTokenRGB(255, 146, 48)),
        "yellow": (AppleTokenRGB(255, 204, 0),    AppleTokenRGB(255, 214, 0)),
        "green":  (AppleTokenRGB(52, 199, 89),    AppleTokenRGB(48, 209, 88)),
        "mint":   (AppleTokenRGB(0, 200, 179),    AppleTokenRGB(0, 218, 195)),
        "teal":   (AppleTokenRGB(0, 195, 208),    AppleTokenRGB(0, 210, 224)),
        "cyan":   (AppleTokenRGB(0, 192, 232),    AppleTokenRGB(60, 211, 254)),
        "blue":   (AppleTokenRGB(0, 136, 255),    AppleTokenRGB(0, 145, 255)),
        "indigo": (AppleTokenRGB(97, 85, 245),    AppleTokenRGB(107, 93, 255)),
        "purple": (AppleTokenRGB(203, 48, 224),   AppleTokenRGB(219, 52, 242)),
        "pink":   (AppleTokenRGB(255, 45, 85),    AppleTokenRGB(255, 55, 95)),
        "brown":  (AppleTokenRGB(172, 127, 94),   AppleTokenRGB(183, 138, 102)),
        "white":  (AppleTokenRGB(255, 255, 255),  AppleTokenRGB(255, 255, 255)),
        "gray":   (AppleTokenRGB(142, 142, 147),  AppleTokenRGB(152, 152, 157)),
        "black":  (AppleTokenRGB(0, 0, 0),        AppleTokenRGB(0, 0, 0)),
    ]

    /// Where the live system disagrees with `standard`, as measured on
    /// macOS 26.0 on 2026-08-02. Keyed by token, then appearance.
    ///
    /// A deviation is not a bug in Mica — it is Apple's published table being
    /// behind Apple's shipped AppKit. Recording it is what keeps the rest of the
    /// oracle strict.
    static let deviations: [String: (light: AppleTokenRGB?, dark: AppleTokenRGB?)] = [
        // Apple's table says 107, 93, 255; AppKit's systemIndigoColor says this.
        "indigo": (light: nil, dark: AppleTokenRGB(109, 124, 255)),
    ]

    /// What `token` should resolve to in `appearance`, deviations applied.
    static func expected(for token: String, dark: Bool) -> AppleTokenRGB? {
        guard let published = standard[token] else { return nil }
        let deviation = dark ? deviations[token]?.dark : deviations[token]?.light
        return deviation ?? (dark ? published.dark : published.light)
    }

    /// Whether `token` is one Apple's table and the live system disagree on, in
    /// `appearance` — for a test that wants to report the two separately.
    static func hasDeviation(_ token: String, dark: Bool) -> Bool {
        (dark ? deviations[token]?.dark : deviations[token]?.light) != nil
    }
}
