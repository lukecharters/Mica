// Models/AppexColor.swift
import SwiftUI
import AppKit

/// A colour for the Apple Reference (`.appex`) pipeline. It is either one of
/// Apple's named system tokens (`AppexNamedColor`) or an arbitrary custom
/// colour. Both resolve to a string that `ISEnclosureColor` / `ISSymbolColor`
/// in the appex `Info.plist` accept:
///
/// - Named token → its raw value, e.g. `"blue"`. Apple's IconServices pipeline
///   applies its curated rendering for that token.
/// - Custom colour → an `"r,g,b,a"` component string in sRGB, e.g.
///   `"1,0.0902,0.2118,1"`. This is the same format Apple uses in real system
///   icon plists, and IconServices parses it directly.
///
/// Equality and hashing are based on `plistValue` — two `AppexColor`s are equal
/// when they render identically, so generation keys only invalidate on a change
/// that actually affects the output.
struct AppexColor {
    /// The named preset used when `isCustom == false`.
    var preset: AppexNamedColor
    /// The custom colour used when `isCustom == true`.
    var customColor: Color
    /// Whether the custom colour (vs. the named preset) is active.
    var isCustom: Bool

    init(preset: AppexNamedColor = .blue, customColor: Color? = nil, isCustom: Bool = false) {
        self.preset = preset
        self.customColor = customColor ?? preset.previewColor
        self.isCustom = isCustom
    }

    /// A colour backed by one of Apple's named system tokens.
    static func named(_ preset: AppexNamedColor) -> AppexColor {
        AppexColor(preset: preset, isCustom: false)
    }

    /// An arbitrary custom colour.
    static func custom(_ color: Color) -> AppexColor {
        AppexColor(preset: .blue, customColor: color, isCustom: true)
    }

    /// The string written to the `.appex` `Info.plist` colour key.
    var plistValue: String {
        isCustom ? AppexColor.rgbaString(from: customColor) : preset.rawValue
    }

    /// The colour shown in the UI swatch / colour picker.
    var displayColor: Color {
        isCustom ? customColor : preset.previewColor
    }

    // MARK: - Convenience constants (mirror the named tokens)

    static let black = AppexColor.named(.black)
    static let blue = AppexColor.named(.blue)
    static let brown = AppexColor.named(.brown)
    static let cyan = AppexColor.named(.cyan)
    static let gray = AppexColor.named(.gray)
    static let green = AppexColor.named(.green)
    static let indigo = AppexColor.named(.indigo)
    static let orange = AppexColor.named(.orange)
    static let pink = AppexColor.named(.pink)
    static let purple = AppexColor.named(.purple)
    static let red = AppexColor.named(.red)
    static let teal = AppexColor.named(.teal)
    static let white = AppexColor.named(.white)
    static let yellow = AppexColor.named(.yellow)

    // MARK: - Colour → plist string

    /// Resolve a SwiftUI `Color` to an `"r,g,b,a"` string in sRGB, matching the
    /// component format Apple uses in system icon plists (e.g.
    /// `"1,0.0902,0.2118,1"`). Components are rounded to four decimal places and
    /// whole numbers render compactly (`1`, not `1.0`).
    static func rgbaString(from color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        return rgbaString(r: ns.redComponent, g: ns.greenComponent, b: ns.blueComponent, a: ns.alphaComponent)
    }

    /// Format raw sRGB components (0–1) into the appex `"r,g,b,a"` plist string.
    static func rgbaString(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> String {
        func fmt(_ value: CGFloat) -> String {
            let clamped = min(max(value, 0), 1)
            let rounded = (clamped * 10000).rounded() / 10000
            if rounded == rounded.rounded() { return String(Int(rounded)) }
            return String(format: "%g", rounded)
        }
        return "\(fmt(r)),\(fmt(g)),\(fmt(b)),\(fmt(a))"
    }
}

extension AppexColor: Equatable, Hashable {
    static func == (lhs: AppexColor, rhs: AppexColor) -> Bool {
        lhs.plistValue == rhs.plistValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(plistValue)
    }
}
