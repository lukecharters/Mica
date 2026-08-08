// BadgeGeometry.swift - Where the badge sits and how much room it takes
//
// Two pure geometry enums, kept in one file because both are stateless
// arithmetic over the icon grid and neither is useful without the other's
// units. the project notes names `BadgeGeometry` the single source of truth for badge
// placement: every consumer routes through `offset(for:enclosureSize:)`, so new
// placement logic belongs here rather than at a call site.
import CoreGraphics

/// Single source of truth for badge geometry, derived from native macOS badge
/// measurements (100px badge on a 208px enclosure; Mica renders the badge at
/// 80% of native). Shared by the render pipeline (`IconContentView`,
/// `IconRenderer.renderAppexWithBadge`) and both previews (`ScaledIconPreview`,
/// `AppexPreviewPane`) so the numbers cannot drift between copies.
enum BadgeGeometry {
    
    /// Badge diameter as a fraction of the enclosure (80% of the native 100px).
    static let diameterRatio: CGFloat = 80.0 / 208.0    // ≈ 0.3846
    /// Badge anchor from enclosure center, matching native macOS.
    static let anchorXRatio: CGFloat = 76.0 / 208.0     // ≈ 0.3654
    static let anchorYRatio: CGFloat = 76.0 / 208.0     // ≈ 0.3654
    /// The faintest alpha an 8-bit render can hold. Past this the shadow is
    /// literally not in the image, so there is nothing left to make room for.
    static let shadowAlphaFloor: CGFloat = 0.5 / 255.0

    /// How far a SwiftUI `.shadow(radius:)` reaches past the shape before its
    /// alpha falls below `shadowAlphaFloor`.
    ///
    /// Scales with the radius and *also* with the opacity: a stronger shadow's
    /// tail stays above the floor for longer. Gaussian falloff puts that second
    /// term at `sqrt(ln(opacity / floor))`, which matches measurement closely —
    /// a shadowed circle's outermost non-transparent pixel sits at:
    ///
    ///     opacity   0.10   0.23   0.40   0.60   1.00
    ///     measured  1.875  2.083  2.222  2.292  2.361   (x radius)
    ///     formula   1.982  2.183  2.307  2.392  2.497
    ///
    /// …times a 5% margin, because the curve tracks the trend but not every
    /// point: at full opacity a small radius measured 2.500 against a predicted
    /// 2.497. Erring high costs a fraction of a point of clearance; erring low
    /// clips the shadow.
    ///
    /// Deriving the opacity term instead of hardcoding one factor is what lets
    /// the `badgeBackground` shadow be retuned freely: change `radiusMultiplier`,
    /// `offsetYMultiplier` or `opacity` in `ResolvedShadow` and the badge's
    /// clearance follows on its own. `BadgeShadowExtentTests` pins the table.
    static let shadowBlurExtentMargin: CGFloat = 1.05

    static func shadowBlurExtent(radius: CGFloat, opacity: CGFloat) -> CGFloat {
        guard radius > 0, opacity > shadowAlphaFloor else { return 0 }
        return radius * sqrt(log(opacity / shadowAlphaFloor)) * shadowBlurExtentMargin
    }

    /// The canvas is the enclosure plus `2 * backgroundInset` (25 at the 256pt
    /// reference), so the enclosure is 206/256 of it. Every caller works in
    /// enclosure units; this recovers the canvas they sit in, which is what the
    /// badge has to stay inside.
    static let enclosureToCanvasRatio: CGFloat = 256.0 / 206.0

    /// Badge diameter for a given enclosure and user badge scale.
    static func diameter(enclosureSize: CGFloat, badgeScale: CGFloat) -> CGFloat {
        enclosureSize * diameterRatio * badgeScale
    }

    /// How far the badge's drawn content — shadow included — reaches from the
    /// badge centre. Asymmetric vertically: the shadow is offset downward, so the
    /// bottom needs more room than the top.
    struct Extents: Equatable {
        var horizontal: CGFloat
        var up: CGFloat
        var down: CGFloat
    }

    /// The badge's true drawn footprint, used to keep it inside the canvas.
    ///
    /// Everything here scales with the badge diameter, because that is what the
    /// badge's shadow scales with (`BadgeView` passes `badgeSize * multiplier` to
    /// `.shadow`). A buffer expressed as a fraction of the *enclosure* — which is
    /// what this used to be — decouples from the shadow as soon as `badgeScale`
    /// leaves 1.0: too generous when the badge shrinks (a visible gap at the
    /// edge), too mean when it grows (a clipped shadow).
    ///
    /// Resolves the shadow style from `settings` rather than any injected
    /// override; `BadgeView`'s `shadowOverride` is a Debug-playground hook and
    /// geometry can't see it.
    static func extents(for settings: IconSettings, enclosureSize: CGFloat) -> Extents {
        let diameter = diameter(enclosureSize: enclosureSize, badgeScale: settings.badge.scale)
        let half = diameter / 2

        // A System-mode badge is a bare appex raster — Mica draws no shadow
        // behind it, and the frame is exactly the diameter.
        guard settings.badge.foreground.source != .system else {
            return Extents(horizontal: half, up: half, down: half)
        }

        // An imported background is drawn unclipped into a frame that the import
        // scale and padding compensation can push past the nominal diameter, so
        // it, not the circle, can be the widest thing on screen.
        var base = half
        if settings.badge.background.drawsImage {
            base = max(base, half * settings.badge.background.effectiveImageScale)
        }

        // Only the background carries the outer shadow. With it hidden or its
        // shadow switched off there is nothing past the shape, and the badge
        // should be free to sit flush against the edge.
        let drawsBackground = !settings.badge.background.isHidden
        guard drawsBackground, settings.badge.background.drawsShadow else {
            return Extents(horizontal: base, up: base, down: base)
        }

        let style = ResolvedShadow.preset(for: settings.icon.background.shadowStyle).badgeBackground
        let blur = shadowBlurExtent(
            radius: diameter * style.radiusMultiplier,
            opacity: style.opacity
        )
        let dy = diameter * style.offsetYMultiplier

        return Extents(
            horizontal: base + blur,
            // The shape itself still reaches `base` upward however far the shadow
            // is pushed down, so the top can never need less room than the shape.
            up: base + max(0, blur - dy),
            down: base + blur + dy
        )
    }

    /// How far the badge centre may sit from the icon centre before its drawn
    /// content would leave the canvas, per direction (`up` is negative y).
    ///
    /// The canvas never grows to accommodate a badge — an export is always
    /// exactly its requested size — so an oversized badge moves inward instead.
    /// At default settings this only bites past `badgeScale ≈ 1.09`; below that
    /// the badge sits exactly where native macOS puts it.
    static func centreLimits(
        for settings: IconSettings,
        enclosureSize: CGFloat
    ) -> (horizontal: CGFloat, up: CGFloat, down: CGFloat) {
        let halfCanvas = enclosureSize * enclosureToCanvasRatio / 2
        let ext = extents(for: settings, enclosureSize: enclosureSize)
        // Clamped at 0: a badge wider than the canvas can't be placed legally, so
        // it centres. Unreachable at the 2.0 scale cap for a plain badge, but an
        // imported background at 2.0 with padding compensation can get there.
        return (
            horizontal: max(0, halfCanvas - ext.horizontal),
            up: max(0, halfCanvas - ext.up),
            down: max(0, halfCanvas - ext.down)
        )
    }

    /// Which corner a position anchors to, in SwiftUI's top-origin coordinates
    /// (y grows downward, so "top" is negative). The one place the four cases
    /// are spelled out — both `offset` and `manualOffsetRange` read it, so the
    /// forward placement and its inverse can't disagree about a corner.
    private static func anchorSigns(for position: BadgePosition) -> (x: CGFloat, y: CGFloat) {
        switch position {
        case .topRight:    return (1, -1)
        case .topLeft:     return (-1, -1)
        case .bottomRight: return (1, 1)
        case .bottomLeft:  return (-1, 1)
        }
    }

    /// The badge's anchor point before any manual offset.
    private static func anchor(for position: BadgePosition, enclosureSize: CGFloat) -> CGSize {
        let signs = anchorSigns(for: position)
        return CGSize(
            width: signs.x * enclosureSize * anchorXRatio,
            height: signs.y * enclosureSize * anchorYRatio
        )
    }

    /// Offset of the badge center from the icon center, including the
    /// normalized manual offset (stored as fractions of enclosure size),
    /// clamped per axis so the badge stays within the canvas.
    static func offset(for settings: IconSettings, enclosureSize: CGFloat) -> CGSize {
        let anchor = anchor(for: settings.badge.position, enclosureSize: enclosureSize)
        let unclamped = CGSize(
            width: anchor.width + enclosureSize * settings.badge.offsetX,
            height: anchor.height + enclosureSize * settings.badge.offsetY
        )

        // Per axis, not radially: a badge with no manual offset stays on its
        // diagonal anyway, and a dragged one slides along the edge it hit rather
        // than being dragged around a circle. Y is asymmetric because the shadow
        // falls downward, so the badge can sit closer to the top edge than the
        // bottom (negative height is up).
        let limits = centreLimits(for: settings, enclosureSize: enclosureSize)
        return CGSize(
            width: min(max(unclamped.width, -limits.horizontal), limits.horizontal),
            height: min(max(unclamped.height, -limits.up), limits.down)
        )
    }

    /// The clamp of `offset(for:enclosureSize:)` expressed back in stored manual
    /// offset units, so a control can stop at the limit instead of banking up a
    /// value the badge can't use. Intersected with `BadgeSpec.offsetRange`.
    ///
    /// The range is asymmetric, and past `badgeScale ≈ 1.09` it no longer
    /// contains zero — the badge *must* sit inward of its anchor by then. That's
    /// why this only clamps live gestures; re-clamping stored settings against it
    /// would silently rewrite a user's 0% into -6%.
    static func manualOffsetRange(
        for settings: IconSettings,
        enclosureSize: CGFloat
    ) -> (x: ClosedRange<Double>, y: ClosedRange<Double>) {
        let limits = centreLimits(for: settings, enclosureSize: enclosureSize)
        // The point the manual offset is measured from.
        let anchor = anchor(for: settings.badge.position, enclosureSize: enclosureSize)

        func range(anchor: CGFloat, negative: CGFloat, positive: CGFloat) -> ClosedRange<Double> {
            let outer = BadgeSpec.offsetRange
            let lower = max(Double((-negative - anchor) / enclosureSize), outer.lowerBound)
            let upper = min(Double((positive - anchor) / enclosureSize), outer.upperBound)
            // The two clamps can cross when the geometric window falls entirely
            // outside badgeOffsetRange; collapse rather than trap on an invalid range.
            return lower <= upper ? lower...upper : lower...lower
        }

        return (
            x: range(anchor: anchor.width, negative: limits.horizontal, positive: limits.horizontal),
            y: range(anchor: anchor.height, negative: limits.up, positive: limits.down)
        )
    }
}

/// Geometry for imported images that already carry the macOS icon grid's
/// built-in margins (Finder/app icons extracted via NSWorkspace).
enum ImportedImageGeometry {
    /// Scale-up applied when "Icon Padding" compensation is on: a native macOS
    /// icon's chiclet occupies 824 of its 1024-pixel canvas, so scaling the
    /// image by 1024/824 makes that chiclet fill the target frame. Mica's own
    /// chiclet ratio (enclosure 206 of a 256 canvas) is identical, which is
    /// what lets a dropped app icon export pixel-for-pixel identical to
    /// `mica-cli extract`. Shared by the icon and badge background paths.
    static let paddingCompensationFactor: CGFloat = 1024.0 / 824.0 // ≈ 1.2427
}
