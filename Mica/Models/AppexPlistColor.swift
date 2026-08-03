// Models/AppexPlistColor.swift
import SwiftUI
import AppKit

/// A colour string the appex `Info.plist` will actually accept — and the only
/// thing `AppexReferenceService` will write into one.
///
/// ## Why this is a type rather than a `String`
///
/// The plist grammar is closed and **fails silently.** `ISEnclosureColor` /
/// `ISSymbolColor` take exactly two forms, measured against ~50 candidates in §1.1
/// of `docs/plans/colour-resolution.md`: one of 15 lowercase token names, or four
/// plain decimals `"r,g,b,a"` in sRGB 0–1 with **no spaces**. Everything else —
/// `grey`, `#FF0000`, `srgb:1,0,0`, `" 1, 0, 0, 1 "`, `255,0,0,255`, a trailing
/// comma, `1e-05`, or any non-string plist type — is discarded by IconServices,
/// which then renders its *fallback* tile at 248,247,247. That is
/// indistinguishable from `white`, so a rejected value looks like a deliberate
/// choice and **no assertion on the rendered image can tell the difference**.
///
/// The render therefore cannot be the check, and "remember to validate first" is
/// not good enough for a failure this quiet. Every writer takes this type, so
/// there is no path that reaches the plist without passing the gate.
///
/// ## What it refuses, and why that is a rejection rather than a fix (decision D2)
///
/// Two things Mica can express and this pipeline cannot. Both are refused rather
/// than quietly altered, because the alternative is a render that differs from the
/// preview with nothing said:
///
/// - **A colour outside sRGB.** Out-of-range components are rejected by the
///   pipeline, so they would have to be clamped, and clamping silently
///   desaturates. Note this is narrower than "not sRGB": a Display P3 pick
///   *inside* sRGB's gamut converts exactly and is fine, which is most of them.
/// - **A translucent enclosure.** The OS honours alpha for the symbol and
///   **ignores it for the enclosure** — 0.01 through 0.99 all render fully opaque,
///   and only exactly 0 does anything (a flat 208,208,208 tile, not transparency).
///   Writing 0.5 there is a lie about what will happen, so `Role.enclosure`
///   requires alpha 1. The GUI closes the same door earlier by not offering
///   opacity on its System-mode background well.
struct AppexPlistColor: Hashable, Sendable {

    /// Which plist key the value is bound for. The grammar is identical either
    /// way; the alpha rule is not.
    ///
    /// The raw value is the plist key itself, so a role cannot be paired with the
    /// wrong one at the point of writing.
    enum Role: String, Hashable, CaseIterable, Sendable {
        case enclosure = "ISEnclosureColor"
        case symbol = "ISSymbolColor"

        /// Whether the OS does anything with the alpha component (§1.1).
        var honoursAlpha: Bool { self == .symbol }

        /// How to name this key to a person. `--icon-bg-color` and the inspector's
        /// "Background Color" both land on the enclosure.
        var noun: String { self == .enclosure ? "background" : "symbol" }
    }

    let role: Role

    /// The exact bytes written to the plist.
    let stringValue: String

    // MARK: - Defaults

    /// The pair both interfaces have always defaulted to — a white symbol on a
    /// blue enclosure.
    static let defaultEnclosure = AppexPlistColor(trusted: AppexNamedColor.blue.rawValue, role: .enclosure)
    static let defaultSymbol = AppexPlistColor(trusted: AppexNamedColor.white.rawValue, role: .symbol)

    /// For the two defaults above, which name tokens that must exist.
    /// `AppexPlistColorTests.defaults_wouldPassTheGate` is the backstop.
    private init(trusted string: String, role: Role) {
        self.stringValue = string
        self.role = role
    }

    // MARK: - The gate

    /// Accept a string only if the appex pipeline would.
    ///
    /// Deliberately strict where the pipeline is strict: whitespace is **not**
    /// trimmed (`" blue "` is rejected by IconServices, so it is rejected here),
    /// token matching is case-sensitive, and a component may contain only digits
    /// and a decimal point — which is what excludes `1e-05`, a form
    /// `String(format: "%g")` is one rounding change away from emitting.
    init(validating string: String, role: Role) throws {
        self.role = role

        // 1. A named token, verbatim. `AppexNamedColor` is itself a validated view
        //    of the `.appexNative` tokens, so this is the whole check.
        if AppexNamedColor(rawValue: string) != nil {
            self.stringValue = string
            return
        }

        // 2. Four plain decimals, no spaces.
        let parts = string.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 4 else {
            throw AppexColorError.notAPlistValue(
                string, role,
                "expected a named token or four comma-separated components, got \(parts.count)"
            )
        }

        var values: [Double] = []
        for part in parts {
            let text = String(part)
            guard !text.isEmpty,
                  text.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
                  let value = Double(text)
            else {
                throw AppexColorError.notAPlistValue(
                    string, role,
                    "\"\(text)\" is not a plain decimal — no spaces, signs or exponents"
                )
            }
            guard (0.0...1.0).contains(value) else {
                throw AppexColorError.notAPlistValue(string, role, "\(text) is outside 0-1")
            }
            values.append(value)
        }

        if !role.honoursAlpha, values[3] != 1 {
            throw AppexColorError.enclosureAlphaIgnored(string)
        }

        self.stringValue = string
    }

    // MARK: - The projection

    /// Project a stored `AppexColor` onto the plist grammar.
    ///
    /// A preset passes straight through, because a named token is what keeps
    /// Apple's curated rendering — and that is *not* the same colour as its own
    /// components (a named `red` tile is ≈235,85,80; `1,0,0,1` gives ≈234,51,36),
    /// which is why presets stay worth distinguishing from custom values.
    init(projecting color: AppexColor, role: Role) throws {
        guard color.isCustom else {
            try self.init(validating: color.preset.rawValue, role: role)
            return
        }
        let components = try Self.sRGBComponents(of: color.customColor, role: role)
        try self.init(
            validating: AppexColor.rgbaString(
                r: CGFloat(components.r),
                g: CGFloat(components.g),
                b: CGFloat(components.b),
                a: CGFloat(components.a)
            ),
            role: role
        )
    }

    /// Resolve to sRGB components, refusing anything the conversion would have to
    /// change.
    ///
    /// Read through `.extendedSRGB` rather than `.sRGB` on purpose: `.sRGB` has
    /// already clamped by the time you can look at it, so it cannot tell an
    /// in-gamut colour from a wide-gamut one that was flattened. The extended
    /// reading is the only way to see the difference.
    private static func sRGBComponents(
        of value: MicaColorValue,
        role: Role
    ) throws -> (r: Double, g: Double, b: Double, a: Double) {
        let resolved: Color
        do {
            resolved = try value.resolvedColor()
        } catch {
            throw AppexColorError.unresolvable(value.stringValue, role)
        }

        let ns = ColorParser.nsColor(from: resolved)
        guard let extended = ns.usingColorSpace(.extendedSRGB) else {
            throw AppexColorError.unresolvable(value.stringValue, role)
        }

        let components = (
            r: Double(extended.redComponent),
            g: Double(extended.greenComponent),
            b: Double(extended.blueComponent),
            a: Double(extended.alphaComponent)
        )

        // Half of the 4 dp quantum the writer rounds to, so float noise from a
        // colour-space conversion is not mistaken for a wide-gamut colour.
        let tolerance = 0.00005
        let channels = [components.r, components.g, components.b]
        if let offending = channels.first(where: { $0 < -tolerance || $0 > 1 + tolerance }) {
            throw AppexColorError.outOfSRGBGamut(
                value.stringValue,
                role,
                offending: offending,
                nearest: AppexColor.rgbaString(
                    r: CGFloat(components.r),
                    g: CGFloat(components.g),
                    b: CGFloat(components.b),
                    a: CGFloat(components.a)
                )
            )
        }

        if !role.honoursAlpha, abs(components.a - 1) > tolerance {
            throw AppexColorError.enclosureAlphaIgnored(value.stringValue)
        }

        return components
    }
}

// MARK: - Errors

/// Why a colour cannot reach the appex `Info.plist`.
///
/// These are user-facing in two places at once: `mica-cli` prints them to stderr
/// during validation, and the GUI shows them in the System-mode preview pane
/// (`IconViewModel.appexError`), which also blocks export through `canExport`.
/// So each one names both the limit and the way out.
enum AppexColorError: LocalizedError, Equatable {
    /// The colour is beyond sRGB, and the pipeline rejects out-of-range components.
    case outOfSRGBGamut(String, AppexPlistColor.Role, offending: Double, nearest: String)
    /// A translucent enclosure, whose alpha the OS discards.
    case enclosureAlphaIgnored(String)
    /// A token no table holds — only a hand-edited configuration reaches this.
    case unresolvable(String, AppexPlistColor.Role)
    /// The projection produced something the grammar refuses. A Mica bug, caught
    /// at the gate rather than rendered as a plausible white.
    case notAPlistValue(String, AppexPlistColor.Role, String)

    /// The 15 names, for a message that has to offer a way forward.
    private static var tokenList: String {
        AppexNamedColor.allCases.map(\.rawValue).joined(separator: ", ")
    }

    var errorDescription: String? {
        switch self {
        case .outOfSRGBGamut(let input, let role, let offending, let nearest):
            return """
                '\(input)' is outside sRGB (component \(String(format: "%.4f", offending))), \
                and System mode cannot show it: Apple's icon pipeline rejects out-of-range \
                components, and clamping would change the colour without saying so. \
                Use srgb:\(nearest) for the nearest sRGB colour, or one of: \(Self.tokenList).
                """
        case .enclosureAlphaIgnored(let input):
            return """
                '\(input)' cannot be a System-mode background colour: the OS ignores the \
                background's opacity, so it would render fully opaque. Drop the opacity, or \
                put it on the symbol colour, where it is honoured.
                """
        case .unresolvable(let input, let role):
            return "'\(input)' is not a colour Mica knows, so it cannot become a System-mode \(role.noun) colour."
        case .notAPlistValue(let input, let role, let reason):
            return """
                Mica produced '\(input)' for the System-mode \(role.noun) colour, which the \
                appex Info.plist would reject (\(reason)). This is a bug — a rejected value \
                renders as a plausible white rather than failing, so it is refused here instead.
                """
        }
    }
}
