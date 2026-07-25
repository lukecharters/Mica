// PreviewHitTester.swift - Maps a click in the preview to the layer it hit
//
// Lets the previews drive inspector selection: click the badge glyph to edit the
// badge's foreground, the chiclet to edit the icon's background, and so on.
//
// Pure geometry, no view dependencies, so it can be unit-tested directly. All
// badge geometry comes from `BadgeGeometry` and all symbol sizing from
// `SymbolSizingService`, so the hit regions cannot drift from what
// `IconContentView` actually draws.

import CoreGraphics
import Foundation

/// The layer a preview click resolved to.
enum PreviewHitTarget: Equatable {
    case iconForeground
    case iconBackground
    case badgeForeground
    case badgeBackground

    var group: IconLayerGroup {
        switch self {
        case .iconForeground, .iconBackground:   return .icon
        case .badgeForeground, .badgeBackground: return .badge
        }
    }

    var tab: LayerTab {
        switch self {
        case .iconForeground, .badgeForeground: return .foreground
        case .iconBackground, .badgeBackground: return .background
        }
    }
}

enum PreviewHitTester {

    /// Fraction of the badge *radius* treated as the glyph (foreground) region;
    /// beyond it is the ring (background). The badge glyph is sized as a fraction
    /// of the badge — typically 0.5–0.55 of the diameter, so its half-extent is
    /// roughly 0.55–0.75 of the radius. A fixed ratio keeps the target stable
    /// while the user scales the glyph, which matters because neither region is
    /// visible.
    static let badgeInnerHitRatio: CGFloat = 0.62

    /// Fraction of the enclosure used by a custom foreground image
    /// (mirrors `IconContentView.iconContent`'s `enclosureSize * 0.85` frame).
    private static let customImageEnclosureRatio: CGFloat = 0.85

    // MARK: - Mica-mode preview

    /// Resolves a click in `ScaledIconPreview`.
    ///
    /// - Parameters:
    ///   - point: Location in the square canvas whose side is
    ///     `IconContentView.totalCanvasSize(for:displaySize:)`, origin top-left.
    ///     The icon's center is the canvas center: badge overflow is added
    ///     symmetrically on all four sides.
    ///   - symbolSizing: Injection seam for tests. Production omits it and the
    ///     sizing is resolved from `SymbolSizingService`.
    /// - Returns: The layer hit, or nil for a click that landed on nothing
    ///   visible (the canvas margin, or outside the chiclet's rounded corners).
    static func target(
        at point: CGPoint,
        settings: IconSettings,
        displaySize: CGFloat,
        symbolSizing: ResolvedSymbolSizing? = nil
    ) -> PreviewHitTarget? {
        let canvasSize = IconContentView.totalCanvasSize(for: settings, displaySize: displaySize)
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        let enclosure = enclosureSize(displaySize: displaySize)

        // Badge first — it draws over the icon, so a hit there never falls through.
        if let badgeTarget = badgeTarget(at: point, from: center, settings: settings, enclosureSize: enclosure) {
            return badgeTarget
        }

        if iconForegroundContains(point, from: center, settings: settings,
                                  enclosureSize: enclosure, symbolSizing: symbolSizing) {
            return .iconForeground
        }

        if iconBackgroundContains(point, from: center, settings: settings,
                                  displaySize: displaySize, enclosureSize: enclosure) {
            return .iconBackground
        }

        return nil
    }

    // MARK: - System-mode preview

    /// Resolves a click in `AppexPreviewPane`, whose canvas is the `iconSize`
    /// square appex image. The icon itself is one flat image there, so a hit on it
    /// reports `.iconBackground` and the caller collapses that to the Icon group;
    /// the badge is still composited by Mica, so its layers resolve normally.
    static func systemTarget(
        at point: CGPoint,
        settings: IconSettings,
        iconSize: CGFloat
    ) -> PreviewHitTarget? {
        let center = CGPoint(x: iconSize / 2, y: iconSize / 2)
        let enclosure = enclosureSize(displaySize: iconSize)

        if let badgeTarget = badgeTarget(at: point, from: center, settings: settings, enclosureSize: enclosure) {
            return badgeTarget
        }

        // The appex image fills the enclosure; no separate foreground to hit.
        if roundedRectContains(point, center: center, side: enclosure,
                               cornerRadius: cornerRadius(for: settings, displaySize: iconSize)) {
            return .iconBackground
        }

        return nil
    }

    // MARK: - Geometry (mirrors IconContentView)

    /// Chiclet dimension at a given display size.
    /// `IconContentView`: `displaySize - 2 * (baseBackgroundInset * scaleFactor)`.
    static func enclosureSize(displaySize: CGFloat) -> CGFloat {
        displaySize - 2 * (25 * displaySize / 256)
    }

    private static func cornerRadius(for settings: IconSettings, displaySize: CGFloat) -> CGFloat {
        let base: CGFloat = settings.cornerRadiusStyle == .macOS26 ? 54 : 46
        return base * (displaySize / 256)
    }

    // MARK: - Badge

    private static func badgeTarget(
        at point: CGPoint,
        from center: CGPoint,
        settings: IconSettings,
        enclosureSize: CGFloat
    ) -> PreviewHitTarget? {
        guard settings.showBadge else { return nil }

        let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize)
        let badgeCenter = CGPoint(x: center.x + offset.width, y: center.y + offset.height)
        let radius = BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badgeScale) / 2
        guard radius > 0 else { return nil }

        let distance = hypot(point.x - badgeCenter.x, point.y - badgeCenter.y)
        guard distance <= radius else { return nil }

        // An imported badge background suppresses the glyph entirely
        // (mirrors BadgeView.showsImportedBackground), so the whole badge is
        // background in that state.
        let glyphSuppressed = settings.badgeForegroundHidden
            || (!settings.badgeBackgroundHidden
                && settings.badgeUseImportedBackground
                && settings.badgeImportedBackground?.nsImage != nil)

        if distance <= radius * badgeInnerHitRatio {
            return glyphSuppressed ? .badgeBackground : .badgeForeground
        }
        // `showBadge` guarantees at least one badge layer is visible, so a hidden
        // background means the glyph is what's on screen out here.
        return settings.badgeBackgroundHidden ? .badgeForeground : .badgeBackground
    }

    // MARK: - Icon foreground

    private static func iconForegroundContains(
        _ point: CGPoint,
        from center: CGPoint,
        settings: IconSettings,
        enclosureSize: CGFloat,
        symbolSizing: ResolvedSymbolSizing?
    ) -> Bool {
        // Same gates as IconContentView: an imported background replaces the
        // foreground entirely.
        guard !settings.iconForegroundHidden, settings.backgroundMode != .importedImage else {
            return false
        }

        switch settings.iconSource {
        case .sfSymbol:
            let sizing = symbolSizing ?? SymbolSizingService.resolve(for: settings.symbolName)
            // symbolSize is a font point size, so the glyph's ink is somewhat
            // smaller than this box — close enough for picking, and generous in
            // the direction that matters (it's the topmost icon layer).
            let side = enclosureSize * sizing.multiplier * settings.manualSymbolScale
            let glyphCenter = CGPoint(
                x: center.x + enclosureSize * sizing.xOffset,
                y: center.y + enclosureSize * sizing.yOffset
            )
            return squareContains(point, center: glyphCenter, side: side)

        case .customImage:
            // Renderer draws nothing until the data decodes, so neither do we.
            guard settings.importedImage?.nsImage != nil else { return false }
            let side = enclosureSize * customImageEnclosureRatio * settings.importedImageScale
            return squareContains(point, center: center, side: side)

        case .system:
            // Appex image replaces the whole icon; nothing drawn here.
            return false
        }
    }

    // MARK: - Icon background

    private static func iconBackgroundContains(
        _ point: CGPoint,
        from center: CGPoint,
        settings: IconSettings,
        displaySize: CGFloat,
        enclosureSize: CGFloat
    ) -> Bool {
        // Click what you see: a hidden background isn't on screen, so clicking
        // where it would be selects nothing. Its tab is still one click away.
        guard !settings.iconBackgroundHidden else { return false }

        let side: CGFloat
        if settings.backgroundMode == .importedImage {
            guard settings.importedBackground?.nsImage != nil else { return false }
            // Imported backgrounds are framed at a scaled multiple of the
            // enclosure and clipped to the chiclet's corner radius.
            let scale = settings.importedBackgroundScale
                * (settings.importedBackgroundPaddingCompensation
                    ? ImportedImageGeometry.paddingCompensationFactor : 1.0)
            side = enclosureSize * scale
        } else {
            side = enclosureSize
        }

        return roundedRectContains(point, center: center, side: side,
                                   cornerRadius: cornerRadius(for: settings, displaySize: displaySize))
    }

    // MARK: - Shape helpers

    private static func squareContains(_ point: CGPoint, center: CGPoint, side: CGFloat) -> Bool {
        guard side > 0 else { return false }
        let half = side / 2
        return abs(point.x - center.x) <= half && abs(point.y - center.y) <= half
    }

    /// Containment for a centered rounded square. The chiclet is drawn with
    /// `.continuous` corners; this tests circular corners instead, which differs
    /// only by a fraction of a point in the corner arcs.
    private static func roundedRectContains(
        _ point: CGPoint,
        center: CGPoint,
        side: CGFloat,
        cornerRadius: CGFloat
    ) -> Bool {
        guard side > 0 else { return false }
        let half = side / 2
        let dx = abs(point.x - center.x)
        let dy = abs(point.y - center.y)
        guard dx <= half, dy <= half else { return false }

        let radius = min(max(cornerRadius, 0), half)
        let cornerX = half - radius
        let cornerY = half - radius
        guard dx > cornerX, dy > cornerY else { return true } // straight edges
        return hypot(dx - cornerX, dy - cornerY) <= radius
    }
}
