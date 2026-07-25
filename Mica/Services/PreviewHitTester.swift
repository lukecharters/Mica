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

/// What the preview is currently editing, for drawing a selection outline. Wider
/// than `PreviewHitTarget` because a group can be selected without a specific
/// layer — the badge's Layout tab edits the badge as a whole, and a System-mode
/// group has no layers at all.
enum PreviewSelection: Equatable {
    case iconForeground
    case iconBackground
    /// The icon as a whole (System mode).
    case icon
    case badgeForeground
    case badgeBackground
    /// The badge as a whole (its Layout tab, or System mode).
    case badge

    /// Derives what to outline from the inspector's current group and tab.
    static func from(group: IconLayerGroup, tab: LayerTab, isSystem: Bool) -> PreviewSelection {
        switch group {
        case .icon:
            guard !isSystem else { return .icon }
            return tab == .background ? .iconBackground : .iconForeground
        case .badge:
            guard !isSystem else { return .badge }
            switch tab {
            case .layout:     return .badge
            case .foreground: return .badgeForeground
            case .background: return .badgeBackground
            }
        }
    }
}

/// The outline shape for a selection, in canvas coordinates.
enum PreviewSelectionShape: Equatable {
    case roundedRect(CGRect, cornerRadius: CGFloat)
    case circle(center: CGPoint, radius: CGFloat)
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

    // MARK: - Selection outline

    /// The shape to outline for `selection`, in the coordinates of the square
    /// canvas returned by `IconContentView.totalCanvasSize(for:displaySize:)`.
    /// Deliberately the same geometry the hit tests use, so what's outlined is
    /// exactly what's clickable.
    ///
    /// Returns nil when there's nothing to outline — a badge selection with the
    /// badge switched off, or a foreground with no symbol or image drawn.
    /// A *hidden* layer still returns its shape: the user has it selected and
    /// needs to see where it sits.
    ///
    /// One deliberate divergence from the hit regions: a foreground selection is
    /// outlined as the glyph's own box rather than the click target, because a
    /// circle drawn through the middle of a badge glyph reads as a mistake.
    /// Everything else traces exactly what a click resolves to.
    ///
    /// Pass `iconSize` instead of a canvas size for the System-mode preview,
    /// whose canvas is the appex image itself.
    static func selectionShape(
        for selection: PreviewSelection,
        settings: IconSettings,
        displaySize: CGFloat,
        canvasSize: CGFloat? = nil,
        symbolSizing: ResolvedSymbolSizing? = nil,
        badgeSymbolSizing: ResolvedSymbolSizing? = nil
    ) -> PreviewSelectionShape? {
        let canvas = canvasSize ?? IconContentView.totalCanvasSize(for: settings, displaySize: displaySize)
        let center = CGPoint(x: canvas / 2, y: canvas / 2)
        let enclosure = enclosureSize(displaySize: displaySize)

        switch selection {
        case .icon, .iconBackground:
            return .roundedRect(
                centeredSquare(center: center, side: backgroundSide(settings: settings, enclosureSize: enclosure) ?? enclosure),
                cornerRadius: cornerRadius(for: settings, displaySize: displaySize)
            )

        case .iconForeground:
            guard let box = foregroundBox(center: center, settings: settings,
                                          enclosureSize: enclosure, symbolSizing: symbolSizing) else {
                return nil
            }
            // Small radius: this is a bounding box, not a drawn shape.
            return .roundedRect(box, cornerRadius: min(box.width, box.height) * 0.08)

        case .badge, .badgeBackground, .badgeForeground:
            guard settings.showBadge else { return nil }
            let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosure)
            let badgeCenter = CGPoint(x: center.x + offset.width, y: center.y + offset.height)
            let diameter = BadgeGeometry.diameter(enclosureSize: enclosure, badgeScale: settings.badgeScale)
            guard diameter > 0 else { return nil }

            if selection == .badgeForeground {
                // Box the badge glyph, sized as BadgeView sizes it (badgeSize ×
                // multiplier × badgeSymbolScale, centred, no offsets).
                guard settings.badgeIconSource != .system else { return nil }
                let sizing = badgeSymbolSizing ?? SymbolSizingService.resolve(for: settings.badgeSymbolName)
                let side = diameter * sizing.multiplier * settings.badgeSymbolScale
                guard side > 0 else { return nil }
                let box = centeredSquare(center: badgeCenter, side: side)
                return .roundedRect(box, cornerRadius: min(box.width, box.height) * 0.08)
            }

            return .circle(center: badgeCenter, radius: diameter / 2)
        }
    }

    /// Bounding box of the icon's drawn foreground, or nil when nothing is drawn.
    private static func foregroundBox(
        center: CGPoint,
        settings: IconSettings,
        enclosureSize: CGFloat,
        symbolSizing: ResolvedSymbolSizing?
    ) -> CGRect? {
        guard settings.backgroundMode != .importedImage else { return nil }

        switch settings.iconSource {
        case .sfSymbol:
            let sizing = symbolSizing ?? SymbolSizingService.resolve(for: settings.symbolName)
            let side = enclosureSize * sizing.multiplier * settings.manualSymbolScale
            guard side > 0 else { return nil }
            return centeredSquare(
                center: CGPoint(
                    x: center.x + enclosureSize * sizing.xOffset,
                    y: center.y + enclosureSize * sizing.yOffset
                ),
                side: side
            )

        case .customImage:
            guard settings.importedImage?.nsImage != nil else { return nil }
            let side = enclosureSize * customImageEnclosureRatio * settings.importedImageScale
            guard side > 0 else { return nil }
            return centeredSquare(center: center, side: side)

        case .system:
            return nil
        }
    }

    /// Side length of the drawn icon background, or nil to use the enclosure.
    private static func backgroundSide(settings: IconSettings, enclosureSize: CGFloat) -> CGFloat? {
        guard settings.backgroundMode == .importedImage,
              settings.importedBackground?.nsImage != nil else { return nil }
        let scale = settings.importedBackgroundScale
            * (settings.importedBackgroundPaddingCompensation
                ? ImportedImageGeometry.paddingCompensationFactor : 1.0)
        return enclosureSize * scale
    }

    private static func centeredSquare(center: CGPoint, side: CGFloat) -> CGRect {
        CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
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
