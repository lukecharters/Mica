// BadgeView.swift - The badge layer of the pure render view
//
// Draws the badge's background and foreground at a resolved diameter, taking
// its footprint from `BadgeGeometry` rather than deriving it again. Same rule as
// `IconContentView`: no gestures, no interactive state.
import SwiftUI

struct BadgeView: View {
    let settings: IconSettings
    let badgeSize: CGFloat
    var badgeAppexImage: NSImage? = nil
    /// Debug-playground hook — see `IconContentView.shadowOverride`.
    var shadowOverride: ResolvedShadow? = nil

    // Badge shadow values are identical across all presets today, so resolving
    // through `settings.icon.background.shadowStyle` is behavior-neutral here; a
    // future `.macOS27` preset is where badge shadows would start to differ.
    private var resolvedShadow: ResolvedShadow {
        shadowOverride ?? .preset(for: settings.icon.background.shadowStyle)
    }

    private var resolvedBadgeSizing: ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: settings.badge.foreground.symbolName)
    }

    private var badgeSymbolSize: CGFloat {
        badgeSize * resolvedBadgeSizing.multiplier * settings.badge.foreground.symbolScale
    }

    private var badgeSymbolWeight: Font.Weight {
        settings.badge.foreground.symbolWeight.fontWeight ?? resolvedBadgeSizing.weight
    }

    /// Whether an imported badge background will actually draw. Shared with
    /// `BadgeGeometry.extents(for:enclosureSize:)`, which sizes the badge's
    /// footprint off the same answer.
    private var showsImportedBackground: Bool {
        settings.badge.background.drawsImage
    }

    var body: some View {
        if settings.badge.foreground.source == .system {
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
                if showsImportedBackground, let nsImage = settings.badge.background.image?.nsImage {
                    let effectiveScale = settings.badge.background.effectiveImageScale
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
                            color: settings.badge.background.drawsShadow ? Color.black.opacity(resolvedShadow.badgeBackground.opacity) : Color.clear,
                            radius: settings.badge.background.drawsShadow ? badgeSize * resolvedShadow.badgeBackground.radiusMultiplier : 0,
                            y: settings.badge.background.drawsShadow ? badgeSize * resolvedShadow.badgeBackground.offsetYMultiplier : 0
                        )
                } else if !settings.badge.background.isHidden, settings.badge.background.usesCustomGradient {
                    Circle()
                        .fill(
                            settings.badge.background.usesGradient
                                ? AnyShapeStyle(LinearGradient(
                                    gradient: Gradient(colors: settings.badge.background.gradientColors),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                : AnyShapeStyle(settings.badge.background.gradientStartColor)
                        )
                        .shadow(
                            color: settings.badge.background.drawsShadow ? Color.black.opacity(resolvedShadow.badgeBackground.opacity) : Color.clear,
                            radius: settings.badge.background.drawsShadow ? badgeSize * resolvedShadow.badgeBackground.radiusMultiplier : 0,
                            y: settings.badge.background.drawsShadow ? badgeSize * resolvedShadow.badgeBackground.offsetYMultiplier : 0
                        )
                } else if !settings.badge.background.isHidden {
                    Circle()
                        .fill(settings.badge.background.usesGradient ? AnyShapeStyle(settings.badge.background.color.gradient) : AnyShapeStyle(settings.badge.background.color))
                        .shadow(
                            color: settings.badge.background.drawsShadow ? Color.black.opacity(resolvedShadow.badgeBackground.opacity) : Color.clear,
                            radius: settings.badge.background.drawsShadow ? badgeSize * resolvedShadow.badgeBackground.radiusMultiplier : 0,
                            y: settings.badge.background.drawsShadow ? badgeSize * resolvedShadow.badgeBackground.offsetYMultiplier : 0
                        )
                }

                // Badge symbol — gated on the foreground visibility toggle, and (preserving the old
                // behavior) suppressed when the badge background is an imported image that is itself visible.
                if !settings.badge.foreground.isHidden, !showsImportedBackground {
                    badgeContent
                        .shadow(
                            color: settings.badge.foreground.drawsShadow ? Color.black.opacity(resolvedShadow.badgeSymbol.opacity) : Color.clear,
                            radius: settings.badge.foreground.drawsShadow ? badgeSize * resolvedShadow.badgeSymbol.radiusMultiplier : 0,
                            y: settings.badge.foreground.drawsShadow ? badgeSize * resolvedShadow.badgeSymbol.offsetYMultiplier : 0
                        )
                }
            }
            .frame(width: badgeSize, height: badgeSize)
        }
    }

    @ViewBuilder
    private var badgeContent: some View {
        switch settings.badge.foreground.source {
        case .symbol:
            applyBadgeSymbolColorRenderingMode(
                to: Group {
                    switch settings.badge.foreground.renderingStyle {
                    case .monochrome:
                        Image(systemName: settings.badge.foreground.symbolName)
                            .font(.system(size: badgeSymbolSize, weight: badgeSymbolWeight))
                            .foregroundColor(settings.badge.foreground.color)
                            .symbolRenderingMode(.monochrome)
                    case .hierarchical:
                        Image(systemName: settings.badge.foreground.symbolName)
                            .font(.system(size: badgeSymbolSize, weight: badgeSymbolWeight))
                            .foregroundStyle(settings.badge.foreground.hierarchicalColor)
                            .symbolRenderingMode(.hierarchical)
                    case .multicolor:
                        Image(systemName: settings.badge.foreground.symbolName)
                            .font(.system(size: badgeSymbolSize, weight: badgeSymbolWeight))
                            .foregroundColor(settings.badge.foreground.color)
                            .symbolRenderingMode(.multicolor)
                    case .palette:
                        Image(systemName: settings.badge.foreground.symbolName)
                            .font(.system(size: badgeSymbolSize, weight: badgeSymbolWeight))
                            .foregroundStyle(
                                settings.badge.foreground.palettePrimaryColor,
                                settings.badge.foreground.paletteSecondaryColor,
                                settings.badge.foreground.paletteTertiaryColor
                            )
                            .symbolRenderingMode(.palette)
                    }
                }
            )

        case .image:
            if let nsImage = settings.badge.foreground.image?.nsImage {
                let effectiveScale = settings.badge.foreground.imageScale
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
            view.symbolColorRenderingMode(settings.badge.foreground.fillStyle.symbolColorRenderingMode)
        } else {
            view
        }
    }
}
