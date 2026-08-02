// Models/AppexNamedColor.swift
import SwiftUI

/// Named color tokens accepted by `ISEnclosureColor` / `ISSymbolColor` in an
/// `.appex` `Info.plist`. Raw values are the exact strings Apple's IconServices
/// pipeline expects.
///
/// This is a **derived view of `ColorTokenTable`**, not a list of its own: the
/// cases are whichever tokens carry `.appexNative`. It was a hand-written enum
/// until 2026-08-02 and had drifted — the pipeline accepts `mint` and the enum had
/// no case for it, so System mode silently could not express a colour the OS
/// supports. A gap like that is now a missing flag in one table rather than a
/// missing case in a second list.
///
/// The value is validated on construction, so every instance names a real token.
struct AppexNamedColor: RawRepresentable, Hashable, Identifiable, Sendable {
    let rawValue: String

    /// Case-sensitive by design: the plist grammar is lowercase, and accepting
    /// `"Blue"` here would let a wrong-case string reach a writer that has no way
    /// to report the rejection (an unrecognised value renders as a plausible
    /// white). Callers that want tolerance normalise first — see
    /// `AppexColor.plistValue(fromCLIString:)`.
    init?(rawValue: String) {
        guard ColorTokenTable.appexNative.contains(where: { $0.name == rawValue }) else { return nil }
        self.rawValue = rawValue
    }

    /// For the static constants below, which name tokens that must exist.
    /// `AppexNamedColorTests.staticConstants_areRealTokens` is the backstop.
    private init(validated name: String) {
        self.rawValue = name
    }

    var id: String { rawValue }

    private var token: ColorToken? { ColorTokenTable.token(named: rawValue) }

    var displayName: String { token?.displayName ?? rawValue.capitalized }

    /// The colour for a UI swatch. Resolves live, so it follows the appearance —
    /// but it is only ever a preview: the appex render uses Apple's curated
    /// rendering for the token, which is not the same colour (a named `red` tile
    /// is ≈235,85,80; the components `1,0,0,1` give ≈234,51,36).
    var previewColor: Color { token?.color ?? .clear }

    static var allCases: [AppexNamedColor] {
        ColorTokenTable.appexNative.map { AppexNamedColor(validated: $0.name) }
    }

    static let black = AppexNamedColor(validated: "black")
    static let blue = AppexNamedColor(validated: "blue")
    static let brown = AppexNamedColor(validated: "brown")
    static let cyan = AppexNamedColor(validated: "cyan")
    static let gray = AppexNamedColor(validated: "gray")
    static let green = AppexNamedColor(validated: "green")
    static let indigo = AppexNamedColor(validated: "indigo")
    static let mint = AppexNamedColor(validated: "mint")
    static let orange = AppexNamedColor(validated: "orange")
    static let pink = AppexNamedColor(validated: "pink")
    static let purple = AppexNamedColor(validated: "purple")
    static let red = AppexNamedColor(validated: "red")
    static let teal = AppexNamedColor(validated: "teal")
    static let white = AppexNamedColor(validated: "white")
    static let yellow = AppexNamedColor(validated: "yellow")
}

extension AppexNamedColor: CaseIterable {}
