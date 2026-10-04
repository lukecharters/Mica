// ResolvedShadow.swift - Shadow presets resolved to numbers
//
// The numeric form of the `DropShadowStyle` preset a user picks. Separate
// from the views that apply it so the preset table can be read without reading
// the render code.
import CoreGraphics

/// Drop-shadow parameter set for the full render pipeline. Canvas shadows
/// (background chiclet, symbol) are base-256pt values scaled by
/// `displaySize / 256`; badge shadows are multipliers of the badge diameter.
/// Each layer picks its own `DropShadowStyle`: the icon background from
/// `icon.background.shadowStyle`, each foreground from its own
/// `foreground.shadowStyle`. The badge background follows the icon background's
/// style. An injected override replaces every value (Debug playgrounds only).
///
/// Named `ResolvedShadow` rather than `ShadowStyle` because it shadowed
/// `SwiftUI.ShadowStyle`, which forced a `typealias` workaround in the tests.
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

        static let none = BadgeShadow(radiusMultiplier: 0, offsetYMultiplier: 0, opacity: 0)
    }

    /// The icon enclosure at the 256pt reference size.
    static let referenceEnclosure: CGFloat = 206

    var background: CanvasShadow
    var symbol: CanvasShadow
    var badgeBackground: BadgeShadow
    var badgeSymbol: BadgeShadow

    static let macOS26 = ResolvedShadow(
        background: CanvasShadow(radius: 4, offsetY: 2, opacity: 0.255),
        symbol: CanvasShadow(radius: 5, offsetY: 3.5, opacity: 0.03)
    )

    static let macOS27 = ResolvedShadow(
        background: CanvasShadow(radius: 4, offsetY: 2, opacity: 0.255),
        symbol: CanvasShadow(radius: 4.4, offsetY: 7.3, opacity: 0.11)
    )

    static let macOS15 = ResolvedShadow(
        background: CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.31),
        symbol: CanvasShadow(radius: 2, offsetY: 2.5, opacity: 0.21)
    )

    /// The preset matching a settings-level shadow style. `.off` disables only
    /// the background shadow; read a foreground's shadow through `symbol(for:)` or
    /// `badgeSymbol(for:)`, which do honour `.off`.
    static func preset(for style: DropShadowStyle) -> ResolvedShadow {
        switch style {
        case .off:
            var style = ResolvedShadow.macOS27
            style.background = .none
            return style
        case .macOS15:
            return .macOS15
        case .macOS26:
            return .macOS26
        case .macOS27:
            return .macOS27
        }
    }

    /// The icon symbol shadow a foreground's own style draws.
    static func symbol(for style: DropShadowStyle) -> CanvasShadow {
        style == .off ? .none : preset(for: style).symbol
    }

    /// The badge symbol shadow a foreground's own style draws.
    static func badgeSymbol(for style: DropShadowStyle) -> BadgeShadow {
        style == .off ? .none : preset(for: style).badgeSymbol
    }
}

extension ResolvedShadow {
    /// The badge background shadow, shared by every preset.
    static let badgeBackgroundShadow = BadgeShadow(radiusMultiplier: 0.03, offsetYMultiplier: 0.04, opacity: 0.23)

    /// A preset whose badge symbol shadow is its icon symbol shadow, scaled to the badge.
    init(background: CanvasShadow, symbol: CanvasShadow) {
        self.init(
            background: background,
            symbol: symbol,
            badgeBackground: Self.badgeBackgroundShadow,
            badgeSymbol: BadgeShadow(matching: symbol)
        )
    }
}

extension ResolvedShadow.BadgeShadow {
    /// An icon symbol shadow carried onto the badge, with the badge diameter
    /// standing in for the icon's enclosure.
    init(matching symbol: ResolvedShadow.CanvasShadow) {
        self.init(
            radiusMultiplier: symbol.radius / ResolvedShadow.referenceEnclosure,
            offsetYMultiplier: symbol.offsetY / ResolvedShadow.referenceEnclosure,
            opacity: symbol.opacity
        )
    }
}
