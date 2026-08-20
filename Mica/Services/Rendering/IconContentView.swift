// IconContentView.swift - The pure render view, used for preview and export
//
// Never add gestures or interactive state here: this view is what an export
// rasterises, so anything interactive would either be invisible or would reach
// the PNG. Interaction belongs in `Views/Preview/ScaledIconPreview.swift`.
//
// A SwiftUI view under `Services/` because the render pipeline *is* SwiftUI —
// `ImageRenderer` rasterises this view — and because `mica-cli` needs it. It is
// one of the twelve paths named in both `membershipExceptions` lists.
import SwiftUI

struct IconContentView: View {
    let settings: IconSettings
    let displaySize: CGFloat
    var badgeAppexImage: NSImage? = nil
    /// Debug-playground hook: when non-nil, replaces the preset derived from
    /// `settings.icon.background.shadowStyle`. Production paths leave this nil.
    var shadowOverride: ResolvedShadow? = nil
    /// Debug-playground hook: when true, the custom-colour icon background is
    /// filled with SwiftUI's automatic `Color.gradient` (top-light → bottom-dark),
    /// matching the gradient macOS/IconServices bakes onto appex enclosures by
    /// default. Lets the calibration playground's "Ours" render match the
    /// System Icon reference. Production paths leave this false.
    var forceAutoBackgroundGradient: Bool = false

    // Base layout constants tuned for 256pt reference
    private let baseSize: CGFloat = 256
    private let baseCornerRadiusMacOS15: CGFloat = 46
    private let baseCornerRadius: CGFloat = 54
    private let baseBackgroundInset: CGFloat = 25

    // Badge layout ratios live in BadgeGeometry (shared with the previews).

    private var scaleFactor: CGFloat { displaySize / baseSize }

    // Scaled layout constants
    private var iconSize: CGFloat { displaySize }
    private var cornerRadius: CGFloat {
        let baseRadius: CGFloat
        switch settings.icon.background.cornerRadiusStyle {
        case .off: baseRadius = 0
        case .macOS15: baseRadius = baseCornerRadiusMacOS15
        case .macOS26: baseRadius = baseCornerRadius
        }
        return baseRadius * scaleFactor
    }
    private var backgroundInset: CGFloat { baseBackgroundInset * scaleFactor }

    /// The chiclet dimension (background rect size, excluding outer padding)
    private var enclosureSize: CGFloat {
        iconSize - (2 * backgroundInset)
    }

    /// Resolved sizing from family calibration data (always used as baseline)
    private var resolvedSizing: ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: settings.icon.foreground.symbolName)
    }

    private var symbolSize: CGFloat {
        enclosureSize * resolvedSizing.multiplier * settings.icon.foreground.symbolScale
    }

    private var symbolFontWeight: Font.Weight {
        settings.icon.foreground.symbolWeight.fontWeight ?? resolvedSizing.weight
    }

    private var symbolXOffset: CGFloat {
        enclosureSize * resolvedSizing.xOffset
    }

    private var symbolYOffset: CGFloat {
        enclosureSize * resolvedSizing.yOffset
    }

    /// The user's manual nudge of the whole foreground layer, in points.
    ///
    /// Separate from `symbolXOffset`/`symbolYOffset`, which are the *calibration*
    /// offsets that centre a particular symbol's ink: those describe the symbol,
    /// this describes the user's choice, and only the second one applies to an
    /// imported-image foreground as well. Applied to `iconContent` as a whole so
    /// both source branches move the same way.
    private var foregroundOffset: CGSize {
        CGSize(
            width: enclosureSize * settings.icon.foreground.offsetX,
            height: enclosureSize * settings.icon.foreground.offsetY
        )
    }

    private var resolvedShadow: ResolvedShadow {
        shadowOverride ?? .preset(for: settings.icon.background.shadowStyle)
    }

    private var backgroundShadowRadius: CGFloat { resolvedShadow.background.radius * scaleFactor }
    private var backgroundShadowOffset: CGFloat { resolvedShadow.background.offsetY * scaleFactor }
    private var backgroundShadowOpacity: CGFloat { resolvedShadow.background.opacity }
    private var symbolShadowRadius: CGFloat { resolvedShadow.symbol.radius * scaleFactor }
    private var symbolShadowOffset: CGFloat { resolvedShadow.symbol.offsetY * scaleFactor }

    // Badge scaled values — all derived from enclosure size
    private var badgeSize: CGFloat {
        BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badge.scale)
    }

    var body: some View {
        ZStack {
            if !settings.icon.background.isHidden {
                backgroundLayer
            }

            // Icon content (SF Symbol or custom image) — gated on the foreground's
            // own visibility and nothing else.
            //
            // This used to also require `background.source != .image`, which made an
            // imported background *replace* the foreground with no way to get it
            // back. Importing one now merely switches the foreground's visibility
            // off (`IconSpec.applyBackgroundImage(_:defaults:)`), which the user can
            // switch on again — and doing so has to draw both layers, so this
            // condition must stay a single term. `PreviewHitTester` mirrors it.
            if !settings.icon.foreground.isHidden {
                iconContent
                    .shadow(
                        color: settings.icon.foreground.drawsShadow ? Color.black.opacity(resolvedShadow.symbol.opacity) : Color.clear,
                        radius: settings.icon.foreground.drawsShadow ? symbolShadowRadius : 0,
                        y: settings.icon.foreground.drawsShadow ? symbolShadowOffset : 0
                    )
                    // Outside the shadow, so the shadow travels with the layer
                    // rather than staying behind where it used to be. Deliberately
                    // unclamped: a nudged foreground may bleed off the chiclet, and
                    // past the canvas the render crops it. `PreviewHitTester`
                    // mirrors this.
                    .offset(foregroundOffset)
            }

            if settings.badge.isVisible {
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
            switch settings.icon.background.source {
            case .color:
                if settings.icon.background.usesCustomGradient {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            forceAutoBackgroundGradient
                                ? AnyShapeStyle(settings.icon.background.gradientStartColor.resolved.gradient)
                                : settings.icon.background.usesGradient
                                    ? AnyShapeStyle(LinearGradient(
                                        gradient: Gradient(colors: settings.icon.background.gradientColors),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    : AnyShapeStyle(settings.icon.background.gradientStartColor.resolved)
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
                        .fill(settings.icon.background.usesGradient ? AnyShapeStyle(settings.icon.background.color.resolved.gradient) : AnyShapeStyle(settings.icon.background.color.resolved))
                        .shadow(
                            color: Color.black.opacity(backgroundShadowOpacity),
                            radius: backgroundShadowRadius,
                            y: backgroundShadowOffset
                        )
                        .padding(backgroundInset)
                        .frame(width: iconSize, height: iconSize)
                }

            case .image:
                if let nsImage = settings.icon.background.image?.nsImage {
                    let effectiveScale = settings.icon.background.imageScale
                        * (settings.icon.background.compensatesForPadding
                            ? ImportedImageGeometry.paddingCompensationFactor : 1.0)
                    let artwork = Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: enclosureSize * effectiveScale,
                            height: enclosureSize * effectiveScale
                        )

                    // `.off` skips the clip entirely — not `clipShape` at radius 0,
                    // and not a `Rectangle()` either. Unclipped, the artwork defines
                    // its own shape through its alpha and the shadow follows that
                    // shape, which is the rule an imported badge background already
                    // follows. Clipping to bounds would square the shadow off even
                    // at radius 0.
                    if settings.icon.background.cornerRadiusStyle == .off {
                        backgroundShadowed(artwork)
                    } else {
                        backgroundShadowed(
                            artwork.clipShape(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            )
                        )
                    }
                }
            }
        }
    }

    /// The icon background's shadow, so the clipped and unclipped imported-artwork
    /// branches cannot drift apart.
    private func backgroundShadowed<Content: View>(_ view: Content) -> some View {
        view.shadow(
            color: Color.black.opacity(backgroundShadowOpacity),
            radius: backgroundShadowRadius,
            y: backgroundShadowOffset
        )
    }

    @ViewBuilder
    private func applySymbolColor<Content: View>(to view: Content) -> some View {
        switch settings.icon.foreground.renderingStyle {
        case .monochrome, .multicolor:
            view.foregroundColor(settings.icon.foreground.color.resolved)
        case .hierarchical:
            view.foregroundStyle(settings.icon.foreground.hierarchicalColor.resolved)
        case .palette:
            view.foregroundStyle(
                settings.icon.foreground.palettePrimaryColor.resolved,
                settings.icon.foreground.paletteSecondaryColor.resolved,
                settings.icon.foreground.paletteTertiaryColor.resolved
            )
        }
    }

    @ViewBuilder
    private func applySymbolColorRenderingMode<Content: View>(to view: Content) -> some View {
        if #available(macOS 26.0, *) {
            view.symbolColorRenderingMode(settings.icon.foreground.fillStyle.symbolColorRenderingMode)
        } else {
            view
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch settings.icon.foreground.source {
        case .symbol:
            applySymbolColorRenderingMode(
                to: applySymbolColor(
                    to: Image(systemName: settings.icon.foreground.symbolName)
                        .font(.system(size: symbolSize, weight: symbolFontWeight))
                )
                .symbolRenderingMode(settings.icon.foreground.renderingStyle.symbolRenderingMode)
            )
            .offset(x: symbolXOffset, y: symbolYOffset)
            .frame(width: iconSize, height: iconSize)
            .padding(-backgroundInset)

        case .image:
            if let nsImage = settings.icon.foreground.image?.nsImage {
                let effectiveScale = settings.icon.foreground.imageScale
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
