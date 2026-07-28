// IconRenderer.swift - Handles rendering the icon for export
import SwiftUI
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
        let diameter = diameter(enclosureSize: enclosureSize, badgeScale: settings.badgeScale)
        let half = diameter / 2

        // A System-mode badge is a bare appex raster — Mica draws no shadow
        // behind it, and the frame is exactly the diameter.
        guard settings.badgeIconSource != .system else {
            return Extents(horizontal: half, up: half, down: half)
        }

        // An imported background is drawn unclipped into a frame that the import
        // scale and padding compensation can push past the nominal diameter, so
        // it, not the circle, can be the widest thing on screen.
        var base = half
        if settings.badgeDrawsImportedBackground {
            base = max(base, half * settings.badgeImportedBackgroundEffectiveScale)
        }

        // Only the background carries the outer shadow. With it hidden or its
        // shadow switched off there is nothing past the shape, and the badge
        // should be free to sit flush against the edge.
        let drawsBackground = !settings.badgeBackgroundHidden
        guard drawsBackground, settings.badgeEnableBackgroundShadow else {
            return Extents(horizontal: base, up: base, down: base)
        }

        let style = ResolvedShadow.preset(for: settings.backgroundShadowStyle).badgeBackground
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
        let anchor = anchor(for: settings.badgePosition, enclosureSize: enclosureSize)
        let unclamped = CGSize(
            width: anchor.width + enclosureSize * settings.badgeManualOffsetX,
            height: anchor.height + enclosureSize * settings.badgeManualOffsetY
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
    /// value the badge can't use. Intersected with `IconSettings.badgeOffsetRange`.
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
        let anchor = anchor(for: settings.badgePosition, enclosureSize: enclosureSize)

        func range(anchor: CGFloat, negative: CGFloat, positive: CGFloat) -> ClosedRange<Double> {
            let outer = IconSettings.badgeOffsetRange
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

/// Drop-shadow parameter set for the full render pipeline. Canvas shadows
/// (background chiclet, symbol) are base-256pt values scaled by
/// `displaySize / 256`; badge shadows are multipliers of the badge diameter.
/// `IconContentView`/`BadgeView` resolve their style from
/// `settings.backgroundShadowStyle` unless an explicit override is injected
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

struct IconRenderer {
    /// Integer supersampling factor for a nominal export pixel size. Exports
    /// below 1024px are rendered at the smallest integer multiple that reaches
    /// 1024 and downsampled. At 1x, shape frames are snapped to integral pixel
    /// bounds while Core Text rounds SF Symbol glyph origins independently —
    /// the two can disagree by up to a full device pixel, which reads as an
    /// off-centre symbol (worst on badges at small sizes). Supersampling keeps
    /// that mismatch sub-pixel in the output.
    static func supersampleFactor(forPixelSize pixelSize: CGFloat) -> Int {
        guard pixelSize > 0, pixelSize < 1024 else { return 1 }
        return Int((1024 / pixelSize).rounded(.up))
    }

    // Public entry – must run on MainActor due to SwiftUI/ImageRenderer isolation
    @MainActor
    static func renderIcon(settings: IconSettings, badgeAppexImage: NSImage? = nil) -> NSImage {
        let exportSize = settings.finalExportSize
        let iconView = IconContentView(settings: settings, displaySize: exportSize, badgeAppexImage: badgeAppexImage)
            .frame(width: exportSize, height: exportSize)

        let factor = supersampleFactor(forPixelSize: exportSize)
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = CGFloat(factor)
        renderer.isOpaque = false

        if let nsImage = renderer.nsImage {
            let colorSpaceConverted = convertToColorSpace(
                image: nsImage,
                colorSpace: settings.exportColorSpace,
                downsampleFactor: factor
            )
            return setImageDPI(image: colorSpaceConverted, settings: settings)
        }
        return NSImage(size: CGSize(width: exportSize, height: exportSize))
    }

    /// Render an appex base image with a badge overlay composited on top.
    @MainActor
    static func renderAppexWithBadge(
        appexImage: NSImage,
        settings: IconSettings,
        badgeAppexImage: NSImage? = nil
    ) -> NSImage {
        let exportSize = settings.finalExportSize
        let scaleFactor = exportSize / 256.0
        let backgroundInset = 25 * scaleFactor
        let enclosureSize = exportSize - 2 * backgroundInset
        let badgeSize = BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badgeScale)

        let compositeView = ZStack {
            // Mirrors the Mica path: a hidden icon group isn't drawn, leaving just
            // the badge on a transparent canvas.
            if !settings.iconHidden {
                Image(nsImage: appexImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: exportSize, height: exportSize)
            } else {
                Color.clear
                    .frame(width: exportSize, height: exportSize)
            }

            if settings.showBadge {
                BadgeView(
                    settings: settings,
                    badgeSize: badgeSize,
                    badgeAppexImage: badgeAppexImage
                )
                .offset(BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize))
            }
        }
        .frame(width: exportSize, height: exportSize)

        // Supersample only when a badge overlay is drawn — without one the view
        // is a straight passthrough of the appex raster, and an upsample/downsample
        // round trip would soften it for no benefit.
        let factor = settings.showBadge ? supersampleFactor(forPixelSize: exportSize) : 1
        let renderer = ImageRenderer(content: compositeView)
        renderer.scale = CGFloat(factor)
        renderer.isOpaque = false

        if let nsImage = renderer.nsImage {
            let colorSpaceConverted = convertToColorSpace(
                image: nsImage,
                colorSpace: settings.exportColorSpace,
                downsampleFactor: factor
            )
            return setImageDPI(image: colorSpaceConverted, settings: settings)
        }
        return NSImage(size: CGSize(width: exportSize, height: exportSize))
    }

    // Thread-safe wrapper that hops to the main queue when needed
    static func renderIconSafely(settings: IconSettings, badgeAppexImage: NSImage? = nil) -> NSImage {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { renderIcon(settings: settings, badgeAppexImage: badgeAppexImage) }
        }
        var output = NSImage(size: CGSize(width: settings.finalExportSize, height: settings.finalExportSize))
        DispatchQueue.main.sync {
            output = MainActor.assumeIsolated { renderIcon(settings: settings, badgeAppexImage: badgeAppexImage) }
        }
        return output
    }

    // MARK: - Color space and DPI helpers
    static func setImageDPI(image: NSImage, settings: IconSettings) -> NSImage {
        guard let originalCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        // Logical size derives from the actual raster and the export scale rather
        // than settings.exportSize, so a supersampled render that has already been
        // reduced isn't re-labelled with a point size it no longer has.
        let scale: CGFloat = settings.exportRetinaSize ? 2 : 1
        let logicalSize = CGSize(
            width: CGFloat(originalCGImage.width) / scale,
            height: CGFloat(originalCGImage.height) / scale
        )
        let newImage = NSImage(size: logicalSize)
        let bitmapRep = NSBitmapImageRep(cgImage: originalCGImage)
        bitmapRep.size = logicalSize
        newImage.addRepresentation(bitmapRep)
        return newImage
    }

    static func convertToColorSpace(image: NSImage, colorSpace: ExportColorSpace, downsampleFactor: Int = 1) -> NSImage {
        guard let originalCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        // Use the bitmap's own pixel dimensions rather than the logical size,
        // which can be fractional at a retina scale and would resample the whole
        // image into a context up to 1px smaller. A supersampled render is the
        // exception: it is deliberately reduced by its integer factor here, so
        // conversion and downsample are one pass.
        let width: Int
        let height: Int
        if downsampleFactor > 1 {
            width = Int((Double(originalCGImage.width) / Double(downsampleFactor)).rounded())
            height = Int((Double(originalCGImage.height) / Double(downsampleFactor)).rounded())
        } else {
            width = originalCGImage.width
            height = originalCGImage.height
        }

        let targetCGColorSpace: CGColorSpace = {
            switch colorSpace {
            case .sRGB: return CGColorSpace(name: CGColorSpace.sRGB)!
            case .displayP3: return CGColorSpace(name: CGColorSpace.displayP3)!
            }
        }()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: targetCGColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.interpolationQuality = .high
        context.draw(originalCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let newCGImage = context.makeImage() else { return image }
        return NSImage(cgImage: newCGImage, size: image.size)
    }
}

// MARK: - Icon View used for rendering and previews
struct IconContentView: View {
    let settings: IconSettings
    let displaySize: CGFloat
    var badgeAppexImage: NSImage? = nil
    /// Debug-playground hook: when non-nil, replaces the preset derived from
    /// `settings.backgroundShadowStyle`. Production paths leave this nil.
    var shadowOverride: ResolvedShadow? = nil
    /// Debug-playground hook: when true, the custom-colour icon background is
    /// filled with SwiftUI's automatic `Color.gradient` (top-light → bottom-dark),
    /// matching the gradient macOS/IconServices bakes onto appex enclosures by
    /// default. Lets the calibration playground's "Ours" render match the
    /// System Icon reference. Production paths leave this false.
    var forceAutoBackgroundGradient: Bool = false

    // Base layout constants tuned for 256pt reference
    private let baseSize: CGFloat = 256
    private let baseCornerRadiusSequoia: CGFloat = 46
    private let baseCornerRadius: CGFloat = 54
    private let baseBackgroundInset: CGFloat = 25

    // Badge layout ratios live in BadgeGeometry (shared with the previews).

    private var scaleFactor: CGFloat { displaySize / baseSize }

    // Scaled layout constants
    private var iconSize: CGFloat { displaySize }
    private var cornerRadius: CGFloat {
        let baseRadius = settings.cornerRadiusStyle == .macOS26 ? baseCornerRadius : baseCornerRadiusSequoia
        return baseRadius * scaleFactor
    }
    private var backgroundInset: CGFloat { baseBackgroundInset * scaleFactor }

    /// The chiclet dimension (background rect size, excluding outer padding)
    private var enclosureSize: CGFloat {
        iconSize - (2 * backgroundInset)
    }

    /// Resolved sizing from family calibration data (always used as baseline)
    private var resolvedSizing: ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: settings.symbolName)
    }

    private var symbolSize: CGFloat {
        enclosureSize * resolvedSizing.multiplier * settings.manualSymbolScale
    }

    private var symbolFontWeight: Font.Weight {
        settings.symbolWeight.fontWeight ?? resolvedSizing.weight
    }

    private var symbolXOffset: CGFloat {
        enclosureSize * resolvedSizing.xOffset
    }

    private var symbolYOffset: CGFloat {
        enclosureSize * resolvedSizing.yOffset
    }

    private var resolvedShadow: ResolvedShadow {
        shadowOverride ?? .preset(for: settings.backgroundShadowStyle)
    }

    private var backgroundShadowRadius: CGFloat { resolvedShadow.background.radius * scaleFactor }
    private var backgroundShadowOffset: CGFloat { resolvedShadow.background.offsetY * scaleFactor }
    private var backgroundShadowOpacity: CGFloat { resolvedShadow.background.opacity }
    private var symbolShadowRadius: CGFloat { resolvedShadow.symbol.radius * scaleFactor }
    private var symbolShadowOffset: CGFloat { resolvedShadow.symbol.offsetY * scaleFactor }

    // Badge scaled values — all derived from enclosure size
    private var badgeSize: CGFloat {
        BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badgeScale)
    }

    var body: some View {
        ZStack {
            if !settings.iconBackgroundHidden {
                backgroundLayer
            }

            // Icon content (SF Symbol or custom image) — hidden when background is an imported image,
            // or when the foreground layer is explicitly hidden via the layer sidebar's eye toggle.
            if !settings.iconForegroundHidden, settings.backgroundMode != .image {
                iconContent
                    .shadow(
                        color: settings.enableSymbolShadow ? Color.black.opacity(resolvedShadow.symbol.opacity) : Color.clear,
                        radius: settings.enableSymbolShadow ? symbolShadowRadius : 0,
                        y: settings.enableSymbolShadow ? symbolShadowOffset : 0
                    )
            }

            if settings.showBadge {
                BadgeView(
                    settings: settings,
                    badgeSize: badgeSize,
                    badgeAppexImage: badgeAppexImage,
                    shadowOverride: shadowOverride
                )
                .offset(BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize))
            }
        }
        // Always the display size: BadgeGeometry keeps the badge inside the
        // canvas rather than the canvas growing to fit the badge.
        .frame(width: displaySize, height: displaySize)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            switch settings.backgroundMode {
            case .preRendered:
                Image(settings.preRenderedAssetName)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(backgroundInset)
                    .shadow(
                        color: Color.black.opacity(backgroundShadowOpacity),
                        radius: backgroundShadowRadius,
                        y: backgroundShadowOffset
                    )
                    .frame(width: iconSize, height: iconSize)

            case .color:
                if settings.useCustomColors {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            forceAutoBackgroundGradient
                                ? AnyShapeStyle(settings.customPrimaryColor.gradient)
                                : settings.enableBackgroundGradient
                                    ? AnyShapeStyle(LinearGradient(
                                        gradient: Gradient(colors: settings.gradientColors),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    : AnyShapeStyle(settings.customPrimaryColor)
                        )
                        .padding(backgroundInset)
                        .shadow(
                            color: Color.black.opacity(backgroundShadowOpacity),
                            radius: backgroundShadowRadius,
                            y: backgroundShadowOffset
                        )
                        .frame(width: iconSize, height: iconSize)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(settings.enableBackgroundGradient ? AnyShapeStyle(settings.baseColor.gradient) : AnyShapeStyle(settings.baseColor))
                        .shadow(
                            color: Color.black.opacity(backgroundShadowOpacity),
                            radius: backgroundShadowRadius,
                            y: backgroundShadowOffset
                        )
                        .padding(backgroundInset)
                        .frame(width: iconSize, height: iconSize)
                }

            case .image:
                if let nsImage = settings.importedBackground?.nsImage {
                    let effectiveScale = settings.importedBackgroundScale
                        * (settings.importedBackgroundPaddingCompensation
                            ? ImportedImageGeometry.paddingCompensationFactor : 1.0)
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: enclosureSize * effectiveScale,
                            height: enclosureSize * effectiveScale
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .shadow(
                            color: Color.black.opacity(backgroundShadowOpacity),
                            radius: backgroundShadowRadius,
                            y: backgroundShadowOffset
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func applySymbolColor<Content: View>(to view: Content) -> some View {
        switch settings.symbolRenderingMode {
        case .monochrome, .multicolor:
            view.foregroundColor(settings.symbolColor)
        case .hierarchical:
            view.foregroundStyle(settings.hierarchicalSymbolColor)
        case .palette:
            view.foregroundStyle(
                settings.paletteSymbolPrimaryColor,
                settings.paletteSymbolSecondaryColor,
                settings.paletteSymbolTertiaryColor
            )
        }
    }

    @ViewBuilder
    private func applySymbolColorRenderingMode<Content: View>(to view: Content) -> some View {
        if #available(macOS 26.0, *) {
            view.symbolColorRenderingMode(settings.symbolColorRenderingMode.symbolColorRenderingMode)
        } else {
            view
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch settings.iconSource {
        case .symbol:
            applySymbolColorRenderingMode(
                to: applySymbolColor(
                    to: Image(systemName: settings.symbolName)
                        .font(.system(size: symbolSize, weight: symbolFontWeight))
                )
                .symbolRenderingMode(settings.symbolRenderingMode.symbolRenderingMode)
            )
            .offset(x: symbolXOffset, y: symbolYOffset)
            .frame(width: iconSize, height: iconSize)
            .padding(-backgroundInset)

        case .image:
            if let nsImage = settings.importedImage?.nsImage {
                let effectiveScale = settings.importedImageScale
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: enclosureSize * 0.85 * effectiveScale,
                        height: enclosureSize * 0.85 * effectiveScale
                    )
            }

        case .system:
            EmptyView() // Handled by GenerationMode — appex image replaces the whole icon
        }
    }

}

struct BadgeView: View {
    let settings: IconSettings
    let badgeSize: CGFloat
    var badgeAppexImage: NSImage? = nil
    /// Debug-playground hook — see `IconContentView.shadowOverride`.
    var shadowOverride: ResolvedShadow? = nil

    // Badge shadow values are identical across all presets today, so resolving
    // through `settings.backgroundShadowStyle` is behavior-neutral here; a
    // future `.macOS27` preset is where badge shadows would start to differ.
    private var resolvedShadow: ResolvedShadow {
        shadowOverride ?? .preset(for: settings.backgroundShadowStyle)
    }

    private var resolvedBadgeSizing: ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: settings.badgeSymbolName)
    }

    private var badgeSymbolSize: CGFloat {
        badgeSize * resolvedBadgeSizing.multiplier * settings.badgeSymbolScale
    }

    private var badgeSymbolWeight: Font.Weight {
        settings.badgeSymbolWeight.fontWeight ?? resolvedBadgeSizing.weight
    }

    /// Whether an imported badge background will actually draw. Shared with
    /// `BadgeGeometry.extents(for:enclosureSize:)`, which sizes the badge's
    /// footprint off the same answer.
    private var showsImportedBackground: Bool {
        settings.badgeDrawsImportedBackground
    }

    var body: some View {
        if settings.badgeIconSource == .system {
            // System-mode badge: draw only the rendered appex image. While it is
            // still generating (nil) draw nothing — this is the shared export
            // render path, so preview-only affordances (spinner, error) live in
            // BadgeAppexStatusView instead.
            if let appexImage = badgeAppexImage {
                Image(nsImage: appexImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: badgeSize, height: badgeSize)
            }
        } else {
            // Existing rendering for SF Symbol and Imported modes
            ZStack {
                if showsImportedBackground, let nsImage = settings.badgeImportedBackground?.nsImage {
                    let effectiveScale = settings.badgeImportedBackgroundEffectiveScale
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: badgeSize * effectiveScale,
                            height: badgeSize * effectiveScale
                        )
                        // Deliberately unclipped: an imported badge background
                        // defines its own shape through its alpha. This used to
                        // clip to a Circle() inscribed in the frame, which sliced
                        // the corners off any artwork that filled its own bounds
                        // (a tight graphic or a square file icon) while leaving a
                        // padded app icon untouched. The shadow follows the
                        // artwork's shape for the same reason.
                        .shadow(
                            color: settings.badgeEnableBackgroundShadow ? Color.black.opacity(resolvedShadow.badgeBackground.opacity) : Color.clear,
                            radius: settings.badgeEnableBackgroundShadow ? badgeSize * resolvedShadow.badgeBackground.radiusMultiplier : 0,
                            y: settings.badgeEnableBackgroundShadow ? badgeSize * resolvedShadow.badgeBackground.offsetYMultiplier : 0
                        )
                } else if !settings.badgeBackgroundHidden, settings.badgeUseCustomColors {
                    Circle()
                        .fill(
                            settings.badgeEnableBackgroundGradient
                                ? AnyShapeStyle(LinearGradient(
                                    gradient: Gradient(colors: settings.badgeGradientColors),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                : AnyShapeStyle(settings.badgeCustomPrimaryColor)
                        )
                        .shadow(
                            color: settings.badgeEnableBackgroundShadow ? Color.black.opacity(resolvedShadow.badgeBackground.opacity) : Color.clear,
                            radius: settings.badgeEnableBackgroundShadow ? badgeSize * resolvedShadow.badgeBackground.radiusMultiplier : 0,
                            y: settings.badgeEnableBackgroundShadow ? badgeSize * resolvedShadow.badgeBackground.offsetYMultiplier : 0
                        )
                } else if !settings.badgeBackgroundHidden {
                    Circle()
                        .fill(settings.badgeEnableBackgroundGradient ? AnyShapeStyle(settings.badgeBaseColor.gradient) : AnyShapeStyle(settings.badgeBaseColor))
                        .shadow(
                            color: settings.badgeEnableBackgroundShadow ? Color.black.opacity(resolvedShadow.badgeBackground.opacity) : Color.clear,
                            radius: settings.badgeEnableBackgroundShadow ? badgeSize * resolvedShadow.badgeBackground.radiusMultiplier : 0,
                            y: settings.badgeEnableBackgroundShadow ? badgeSize * resolvedShadow.badgeBackground.offsetYMultiplier : 0
                        )
                }

                // Badge symbol — gated on the foreground visibility toggle, and (preserving the old
                // behavior) suppressed when the badge background is an imported image that is itself visible.
                if !settings.badgeForegroundHidden, !showsImportedBackground {
                    badgeContent
                        .shadow(
                            color: settings.badgeEnableSymbolShadow ? Color.black.opacity(resolvedShadow.badgeSymbol.opacity) : Color.clear,
                            radius: settings.badgeEnableSymbolShadow ? badgeSize * resolvedShadow.badgeSymbol.radiusMultiplier : 0,
                            y: settings.badgeEnableSymbolShadow ? badgeSize * resolvedShadow.badgeSymbol.offsetYMultiplier : 0
                        )
                }
            }
            .frame(width: badgeSize, height: badgeSize)
        }
    }

    @ViewBuilder
    private var badgeContent: some View {
        switch settings.badgeIconSource {
        case .symbol:
            applyBadgeSymbolColorRenderingMode(
                to: Group {
                    switch settings.badgeSymbolRenderingMode {
                    case .monochrome:
                        Image(systemName: settings.badgeSymbolName)
                            .font(.system(size: badgeSymbolSize, weight: badgeSymbolWeight))
                            .foregroundColor(settings.badgeSymbolColor)
                            .symbolRenderingMode(.monochrome)
                    case .hierarchical:
                        Image(systemName: settings.badgeSymbolName)
                            .font(.system(size: badgeSymbolSize, weight: badgeSymbolWeight))
                            .foregroundStyle(settings.badgeHierarchicalSymbolColor)
                            .symbolRenderingMode(.hierarchical)
                    case .multicolor:
                        Image(systemName: settings.badgeSymbolName)
                            .font(.system(size: badgeSymbolSize, weight: badgeSymbolWeight))
                            .foregroundColor(settings.badgeSymbolColor)
                            .symbolRenderingMode(.multicolor)
                    case .palette:
                        Image(systemName: settings.badgeSymbolName)
                            .font(.system(size: badgeSymbolSize, weight: badgeSymbolWeight))
                            .foregroundStyle(
                                settings.badgePaletteSymbolPrimaryColor,
                                settings.badgePaletteSymbolSecondaryColor,
                                settings.badgePaletteSymbolTertiaryColor
                            )
                            .symbolRenderingMode(.palette)
                    }
                }
            )

        case .image:
            if let nsImage = settings.badgeImportedImage?.nsImage {
                let effectiveScale = settings.badgeImportedImageScale
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: badgeSize * 0.65 * effectiveScale,
                        height: badgeSize * 0.65 * effectiveScale
                    )
            }

        case .system:
            EmptyView() // Handled in body — appex image is the complete badge
        }
    }

    @ViewBuilder
    private func applyBadgeSymbolColorRenderingMode<Content: View>(to view: Content) -> some View {
        if #available(macOS 26.0, *) {
            view.symbolColorRenderingMode(settings.badgeSymbolColorRenderingMode.symbolColorRenderingMode)
        } else {
            view
        }
    }
}



