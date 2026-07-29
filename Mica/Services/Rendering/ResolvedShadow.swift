// ResolvedShadow.swift - Shadow presets resolved to numbers
//
// The numeric form of the `BackgroundShadowStyle` preset a user picks. Separate
// from the views that apply it so the preset table can be read without reading
// the render code.
import CoreGraphics

/// Drop-shadow parameter set for the full render pipeline. Canvas shadows
/// (background chiclet, symbol) are base-256pt values scaled by
/// `displaySize / 256`; badge shadows are multipliers of the badge diameter.
/// `IconContentView`/`BadgeView` resolve their style from
/// `settings.icon.background.shadowStyle` unless an explicit override is injected
/// (Debug playgrounds only).
///
/// Named `ResolvedShadow` rather than `ShadowStyle` for two reasons: it shadowed
/// `SwiftUI.ShadowStyle`, which forced a `typealias` workaround in the tests, and
/// it sat one letter away from `BackgroundShadowStyle` — the *enum of presets a
/// user picks*, which this type is the resolved numeric form of.
struct ResolvedShadow: Equatable {
    struct CanvasShadow: Equatable {
        /// Blur radius at the 256pt reference size.
        var radius: CGFloat
        /// Vertical offset at the 256pt reference size.
        var offsetY: CGFloat
        var opacity: CGFloat

        static let none = CanvasShadow(radius: 0, offsetY: 0, opacity: 0)
    }

    struct BadgeShadow: Equatable {
        /// Blur radius as a fraction of the badge diameter.
        var radiusMultiplier: CGFloat
        /// Vertical offset as a fraction of the badge diameter.
        var offsetYMultiplier: CGFloat
        var opacity: CGFloat
    }

    var background: CanvasShadow
    var symbol: CanvasShadow
    var badgeBackground: BadgeShadow
    var badgeSymbol: BadgeShadow

    // Badge shadows are identical across presets; the canvas background and
    // symbol shadows differ — macOS 26 lightened both relative to Sequoia.
    static let macOS26 = ResolvedShadow(
        background: CanvasShadow(radius: 3.6, offsetY: 2.5, opacity: 0.23),
        symbol: CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.15),
        badgeBackground: BadgeShadow(radiusMultiplier: 0.03, offsetYMultiplier: 0.04, opacity: 0.23),
        badgeSymbol: BadgeShadow(radiusMultiplier: 0.02, offsetYMultiplier: 0.025, opacity: 0.15)
    )

    static let sequoia = ResolvedShadow(
        background: CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.31),
        symbol: CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.23),
        badgeBackground: BadgeShadow(radiusMultiplier: 0.03, offsetYMultiplier: 0.04, opacity: 0.23),
        badgeSymbol: BadgeShadow(radiusMultiplier: 0.02, offsetYMultiplier: 0.025, opacity: 0.15)
    )

    /// The preset matching a settings-level shadow style. `.off` disables only
    /// the background shadow — symbol and badge shadows remain gated solely by
    /// their own `enable…Shadow` flags.
    static func preset(for style: BackgroundShadowStyle) -> ResolvedShadow {
        switch style {
        case .off:
            var style = ResolvedShadow.macOS26
            style.background = .none
            return style
        case .sequoia:
            return .sequoia
        case .macOS26:
            return .macOS26
        }
    }
}
