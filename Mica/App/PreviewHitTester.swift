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

    /// Derives what to outline from the inspector's current group and tab, or nil
    /// when nothing should be outlined.
    ///
    /// - Parameter isSystem: whether this group renders through the appex pipeline.
    ///   A System group has no layer tabs — it's one image — so it outlines as a
    ///   whole, and `tab`, whatever the tab bar was last left on, must not leak in.
    /// - Parameter advancedControlsEnabled: the outline is an advanced-controls
    ///   affordance. With them off the inspector shows a single un-tabbed pane per
    ///   group and the sidebar already says which group that is, so an accent ring
    ///   over the artwork would be noise rather than orientation: nothing outlines.
    static func from(
        group: IconLayerGroup,
        tab: LayerTab,
        isSystem: Bool,
        advancedControlsEnabled: Bool
    ) -> PreviewSelection? {
        guard advancedControlsEnabled else { return nil }
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

    /// Corner radius of a non-circular badge, as a fraction of its side.
    ///
    /// Only the colour badge is a `Circle()`. A System-mode badge is an app-icon
    /// squircle drawn by IconServices, and an imported badge background is
    /// unclipped artwork that defines its own shape — most often a squircle,
    /// since the images people badge with are app or file icons. A squircle is
    /// the closest honest bounding shape for either.
    ///
    /// Measured off a rendered 1024pt appex badge: ≈0.235 of the badge side.
    /// Deliberately a constant rather than `cornerRadiusStyle` — that setting
    /// shapes Mica's own chiclet and has no effect on an OS-rendered badge, so
    /// it must not move this outline. (It sits between the two chiclet ratios,
    /// 46/206 ≈ 0.223 and 54/206 ≈ 0.262, matching neither.)
    static let badgeCornerRadiusRatio: CGFloat = 0.235

    // MARK: - Mica-mode preview

    /// Resolves a click in `ScaledIconPreview`.
    ///
    /// - Parameters:
    ///   - point: Location in the `displaySize` square canvas, origin top-left,
    ///     with the icon centered in it. The canvas never grows for a badge —
    ///     `BadgeGeometry` moves an oversized badge inward instead — so this is
    ///     the same square the export is written at.
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
        let center = CGPoint(x: displaySize / 2, y: displaySize / 2)
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

    /// The shape to outline for `selection`, in the coordinates of the
    /// `displaySize` square canvas. Deliberately the same geometry the hit tests
    /// use, so what's outlined is exactly what's clickable.
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
    /// For the System-mode preview, pass the appex image's side as `displaySize`
    /// — that pane's canvas is the image itself, which is the same square.
    static func selectionShape(
        for selection: PreviewSelection,
        settings: IconSettings,
        displaySize: CGFloat,
        symbolSizing: ResolvedSymbolSizing? = nil,
        badgeSymbolSizing: ResolvedSymbolSizing? = nil
    ) -> PreviewSelectionShape? {
        let center = CGPoint(x: displaySize / 2, y: displaySize / 2)
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
            guard settings.badge.isVisible else { return nil }
            let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosure)
            let badgeCenter = CGPoint(x: center.x + offset.width, y: center.y + offset.height)
            let diameter = BadgeGeometry.diameter(enclosureSize: enclosure, badgeScale: settings.badge.scale)
            guard diameter > 0 else { return nil }

            if selection == .badgeForeground {
                guard let box = badgeForegroundBox(settings: settings, badgeCenter: badgeCenter,
                                                   diameter: diameter,
                                                   badgeSymbolSizing: badgeSymbolSizing) else {
                    return nil
                }
                // Small radius: this is a bounding box, not a drawn shape.
                return .roundedRect(box, cornerRadius: min(box.width, box.height) * 0.08)
            }

            return badgeShape(settings: settings, center: badgeCenter, diameter: diameter)
        }
    }

    // MARK: - Badge footprint

    /// The badge's drawn shape, centred on `center`.
    ///
    /// The colour badge is a circle; a System-mode badge and a drawn imported
    /// background are squircles (see `badgeCornerRadiusRatio`). Shared by the
    /// outline and the hit test so the two cannot disagree.
    private static func badgeShape(
        settings: IconSettings,
        center: CGPoint,
        diameter: CGFloat
    ) -> PreviewSelectionShape {
        guard let side = badgeSquircleSide(settings: settings, diameter: diameter) else {
            return .circle(center: center, radius: diameter / 2)
        }
        return .roundedRect(
            centeredSquare(center: center, side: side),
            cornerRadius: side * badgeCornerRadiusRatio
        )
    }

    /// Bounding box of the badge's drawn glyph, sized as `BadgeView` sizes it
    /// (badge diameter × multiplier × symbol scale, centred, no offsets). Nil when
    /// there is no glyph of its own — System mode bakes it into the appex image.
    ///
    /// Shared by the outline and the hit test so clicking the glyph and outlining it
    /// cannot disagree. That matters more than it used to: the glyph can now sit
    /// over imported badge artwork, so this box is what splits the badge's footprint
    /// into two layers there.
    private static func badgeForegroundBox(
        settings: IconSettings,
        badgeCenter: CGPoint,
        diameter: CGFloat,
        badgeSymbolSizing: ResolvedSymbolSizing?
    ) -> CGRect? {
        guard settings.badge.foreground.source != .system else { return nil }
        let sizing = badgeSymbolSizing ?? SymbolSizingService.resolve(for: settings.badge.foreground.symbolName)
        let side = diameter * sizing.multiplier * settings.badge.foreground.symbolScale
        guard side > 0 else { return nil }
        return centeredSquare(center: nudged(badgeCenter, by: settings.badge.foreground, unit: diameter),
                              side: side)
    }

    /// Visible side of a squircle badge, or nil when the circular colour badge
    /// is what draws.
    private static func badgeSquircleSide(settings: IconSettings, diameter: CGFloat) -> CGFloat? {
        // A System-mode badge is an appex image, and its tile sits inside its own
        // canvas exactly as the icon's chiclet sits inside the icon canvas. So the
        // visible squircle is the *enclosure* of the badge frame (≈0.80 of it),
        // not the frame — the rest is the padding the appex render carries.
        if settings.badge.foreground.source == .system {
            return enclosureSize(displaySize: diameter)
        }

        // An imported background is meant to present as a tile at the badge's
        // nominal size: padding compensation widens the frame by exactly the
        // padding a standard app icon carries, so the artwork lands back at
        // `diameter × scale` either way, and only the scale slider moves it.
        // Artwork that doesn't match that assumption can defeat this — the
        // compensation toggle is the user's claim about the image, not a
        // measurement of it.
        guard !settings.badge.background.isHidden,
              settings.badge.background.source == .image,
              settings.badge.background.image?.nsImage != nil else { return nil }
        return diameter * settings.badge.background.imageScale
    }

    /// Bounding box of the icon's drawn foreground, or nil when nothing is drawn.
    private static func foregroundBox(
        center: CGPoint,
        settings: IconSettings,
        enclosureSize: CGFloat,
        symbolSizing: ResolvedSymbolSizing?
    ) -> CGRect? {
        // No `background.source != .image` gate: an imported background no longer
        // replaces the foreground, so a foreground over imported artwork has a box
        // to outline. Deliberately no `isHidden` gate either — a hidden-but-selected
        // layer still outlines.
        switch settings.icon.foreground.source {
        case .symbol:
            let sizing = symbolSizing ?? SymbolSizingService.resolve(for: settings.icon.foreground.symbolName)
            let side = enclosureSize * sizing.multiplier * settings.icon.foreground.symbolScale
            guard side > 0 else { return nil }
            return centeredSquare(
                center: nudged(
                    CGPoint(
                        x: center.x + enclosureSize * sizing.xOffset,
                        y: center.y + enclosureSize * sizing.yOffset
                    ),
                    by: settings.icon.foreground,
                    unit: enclosureSize
                ),
                side: side
            )

        case .image:
            guard settings.icon.foreground.image?.nsImage != nil else { return nil }
            let side = enclosureSize * customImageEnclosureRatio * settings.icon.foreground.imageScale
            guard side > 0 else { return nil }
            return centeredSquare(
                center: nudged(center, by: settings.icon.foreground, unit: enclosureSize),
                side: side
            )

        case .system:
            return nil
        }
    }

    /// Side length of the drawn icon background, or nil to use the enclosure.
    private static func backgroundSide(settings: IconSettings, enclosureSize: CGFloat) -> CGFloat? {
        guard settings.icon.background.source == .image,
              settings.icon.background.image?.nsImage != nil else { return nil }
        let scale = settings.icon.background.imageScale
            * (settings.icon.background.compensatesForPadding
                ? ImportedImageGeometry.paddingCompensationFactor : 1.0)
        return enclosureSize * scale
    }

    private static func centeredSquare(center: CGPoint, side: CGFloat) -> CGRect {
        CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }

    /// A foreground layer's centre after its manual nudge, mirroring the `.offset`
    /// `IconContentView` and `BadgeView` apply to the whole layer.
    ///
    /// `unit` is the frame the offset is a fraction of — the icon enclosure for an
    /// icon foreground, the badge diameter for a badge one. One helper for all four
    /// sites (two boxes, two hit tests), so a nudged glyph cannot be outlined in one
    /// place and picked in another.
    private static func nudged(_ center: CGPoint, by foreground: ForegroundSpec, unit: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + unit * foreground.offsetX,
            y: center.y + unit * foreground.offsetY
        )
    }

    // MARK: - Geometry (mirrors IconContentView)

    /// Chiclet dimension at a given display size.
    /// `IconContentView`: `displaySize - 2 * (baseBackgroundInset * scaleFactor)`.
    static func enclosureSize(displaySize: CGFloat) -> CGFloat {
        displaySize - 2 * (25 * displaySize / 256)
    }

    private static func cornerRadius(for settings: IconSettings, displaySize: CGFloat) -> CGFloat {
        // Mirrors `IconContentView.cornerRadius`, including `.off` at 0 — a
        // squircular hit region over a square chiclet would miss its corners.
        let base: CGFloat
        switch settings.icon.background.cornerRadiusStyle {
        case .off: base = 0
        case .macOS15: base = 46
        case .macOS26: base = 54
        }
        return base * (displaySize / 256)
    }

    // MARK: - Badge

    private static func badgeTarget(
        at point: CGPoint,
        from center: CGPoint,
        settings: IconSettings,
        enclosureSize: CGFloat
    ) -> PreviewHitTarget? {
        guard settings.badge.isVisible else { return nil }

        let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize)
        let badgeCenter = CGPoint(x: center.x + offset.width, y: center.y + offset.height)
        let diameter = BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badge.scale)
        guard diameter > 0 else { return nil }

        let shape = badgeShape(settings: settings, center: badgeCenter, diameter: diameter)
        guard shapeContains(point, shape) else { return nil }

        // A System-mode badge really is one editable layer: symbol and enclosure are
        // baked into a single appex image, so there is no glyph to split off.
        if settings.badge.foreground.source == .system { return .badgeBackground }

        // A drawn imported background used to be the same case, because it
        // suppressed the glyph. It no longer does, so the glyph is pickable by its
        // own box — the box the outline traces. The badgeInnerHitRatio split below
        // is no use here: this footprint is the *artwork's* frame, which runs to
        // ~2.5× the diameter, while the glyph is still sized off the diameter.
        if settings.badge.background.drawsImage {
            if !settings.badge.foreground.isHidden,
               let glyph = badgeForegroundBox(settings: settings, badgeCenter: badgeCenter,
                                              diameter: diameter, badgeSymbolSizing: nil),
               glyph.contains(point) {
                return .badgeForeground
            }
            return .badgeBackground
        }

        guard case .circle(_, let radius) = shape else { return .badgeBackground }

        let distance = hypot(point.x - badgeCenter.x, point.y - badgeCenter.y)
        if distance <= radius * badgeInnerHitRatio {
            return settings.badge.foreground.isHidden ? .badgeBackground : .badgeForeground
        }
        // `showBadge` guarantees at least one badge layer is visible, so a hidden
        // background means the glyph is what's on screen out here.
        return settings.badge.background.isHidden ? .badgeForeground : .badgeBackground
    }

    // MARK: - Icon foreground

    private static func iconForegroundContains(
        _ point: CGPoint,
        from center: CGPoint,
        settings: IconSettings,
        enclosureSize: CGFloat,
        symbolSizing: ResolvedSymbolSizing?
    ) -> Bool {
        // Same single gate as IconContentView: the foreground's own visibility.
        // An imported background no longer suppresses it, so a foreground switched
        // back on over imported artwork is clickable — and must be, or selection
        // would disagree with what is on screen.
        guard !settings.icon.foreground.isHidden else { return false }

        switch settings.icon.foreground.source {
        case .symbol:
            let sizing = symbolSizing ?? SymbolSizingService.resolve(for: settings.icon.foreground.symbolName)
            // symbolSize is a font point size, so the glyph's ink is somewhat
            // smaller than this box — close enough for picking, and generous in
            // the direction that matters (it's the topmost icon layer).
            let side = enclosureSize * sizing.multiplier * settings.icon.foreground.symbolScale
            let glyphCenter = nudged(
                CGPoint(
                    x: center.x + enclosureSize * sizing.xOffset,
                    y: center.y + enclosureSize * sizing.yOffset
                ),
                by: settings.icon.foreground,
                unit: enclosureSize
            )
            return squareContains(point, center: glyphCenter, side: side)

        case .image:
            // Renderer draws nothing until the data decodes, so neither do we.
            guard settings.icon.foreground.image?.nsImage != nil else { return false }
            let side = enclosureSize * customImageEnclosureRatio * settings.icon.foreground.imageScale
            return squareContains(
                point,
                center: nudged(center, by: settings.icon.foreground, unit: enclosureSize),
                side: side
            )

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
        guard !settings.icon.background.isHidden else { return false }

        let side: CGFloat
        if settings.icon.background.source == .image {
            guard settings.icon.background.image?.nsImage != nil else { return false }
            // Imported backgrounds are framed at a scaled multiple of the
            // enclosure and clipped to the chiclet's corner radius.
            let scale = settings.icon.background.imageScale
                * (settings.icon.background.compensatesForPadding
                    ? ImportedImageGeometry.paddingCompensationFactor : 1.0)
            side = enclosureSize * scale
        } else {
            side = enclosureSize
        }

        return roundedRectContains(point, center: center, side: side,
                                   cornerRadius: cornerRadius(for: settings, displaySize: displaySize))
    }

    // MARK: - Shape helpers

    /// Containment for either selection shape. Its rects are always centred
    /// squares, so the rounded-rect case defers to `roundedRectContains`.
    private static func shapeContains(_ point: CGPoint, _ shape: PreviewSelectionShape) -> Bool {
        switch shape {
        case .circle(let center, let radius):
            guard radius > 0 else { return false }
            return hypot(point.x - center.x, point.y - center.y) <= radius
        case .roundedRect(let rect, let cornerRadius):
            return roundedRectContains(
                point,
                center: CGPoint(x: rect.midX, y: rect.midY),
                side: rect.width,
                cornerRadius: cornerRadius
            )
        }
    }

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
