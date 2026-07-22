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
    /// Badge anchor from enclosure center — asymmetric, matches native macOS.
    static let anchorXRatio: CGFloat = 76.0 / 208.0     // ≈ 0.3654
    static let anchorYRatio: CGFloat = 80.0 / 208.0     // ≈ 0.3846
    /// Shadow buffer beyond the badge edge (proportional to the 80px badge).
    static let shadowBufferRatio: CGFloat = 5.6 / 208.0 // ≈ 0.0269

    /// Badge diameter for a given enclosure and user badge scale.
    static func diameter(enclosureSize: CGFloat, badgeScale: CGFloat) -> CGFloat {
        enclosureSize * diameterRatio * badgeScale
    }

    /// Offset of the badge center from the icon center, including the
    /// normalized manual offset (stored as fractions of enclosure size).
    static func offset(for settings: IconSettings, enclosureSize: CGFloat) -> CGSize {
        let ax = enclosureSize * anchorXRatio
        let ay = enclosureSize * anchorYRatio
        let mx = enclosureSize * settings.badgeManualOffsetX
        let my = enclosureSize * settings.badgeManualOffsetY
        switch settings.badgePosition {
        case .topRight:    return CGSize(width: ax + mx, height: -ay + my)
        case .topLeft:     return CGSize(width: -ax + mx, height: -ay + my)
        case .bottomRight: return CGSize(width: ax + mx, height: ay + my)
        case .bottomLeft:  return CGSize(width: -ax + mx, height: ay + my)
        }
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
        let canvasSize = IconContentView.totalCanvasSize(for: settings, displaySize: exportSize)
        let iconView = IconContentView(settings: settings, displaySize: exportSize, badgeAppexImage: badgeAppexImage)
            .frame(width: canvasSize, height: canvasSize)

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
        let canvasSize = IconContentView.totalCanvasSize(for: settings, displaySize: exportSize)
        let scaleFactor = exportSize / 256.0
        let backgroundInset = 25 * scaleFactor
        let enclosureSize = exportSize - 2 * backgroundInset
        let badgeSize = BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badgeScale)

        let compositeView = ZStack {
            Image(nsImage: appexImage)
                .resizable()
                .interpolation(.high)
                .frame(width: exportSize, height: exportSize)

            if settings.showBadge {
                BadgeView(
                    settings: settings,
                    badgeSize: badgeSize,
                    badgeAppexImage: badgeAppexImage
                )
                .offset(BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize))
            }
        }
        .frame(width: canvasSize, height: canvasSize)

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
        // Logical size derives from the actual raster and the export scale — the
        // canvas exceeds exportSize when a badge overflows, so hardcoding
        // settings.exportSize would misstate the image's point size.
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
        // Use the bitmap's own pixel dimensions. The logical size can be
        // fractional (badge overflow yields fractional canvases), and truncating
        // it would resample the whole image into a context up to 1px smaller.
        // A supersampled render is the exception: it is deliberately reduced by
        // its integer factor here, so conversion and downsample are one pass.
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

    // Base layout constants tuned for 256pt reference
    private let baseSize: CGFloat = 256
    private let baseCornerRadiusSequoia: CGFloat = 46
    private let baseCornerRadius: CGFloat = 54
    private let baseBackgroundInset: CGFloat = 25
    private let baseShadowRadius: CGFloat = 3.6
    private let baseShadowOffset: CGFloat = 2.5
    private let shadowOpacity: CGFloat = 0.30
    private let baseShadowRadiusSequoia: CGFloat = 2
    private let baseShadowOffsetSequoia: CGFloat = 2.5
    private let shadowOpacitySequoia: CGFloat = 0.31
    private let baseSymbolShadowRadius: CGFloat = 2
    private let baseSymbolShadowOffset: CGFloat = 2.5
    private let symbolShadowOpacity: CGFloat = 0.23

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

    private var backgroundShadowRadius: CGFloat {
        switch settings.backgroundShadowStyle {
        case .off: return 0
        case .sequoia: return baseShadowRadiusSequoia * scaleFactor
        case .macOS26: return baseShadowRadius * scaleFactor
        }
    }
    private var backgroundShadowOffset: CGFloat {
        switch settings.backgroundShadowStyle {
        case .off: return 0
        case .sequoia: return baseShadowOffsetSequoia * scaleFactor
        case .macOS26: return baseShadowOffset * scaleFactor
        }
    }
    private var backgroundShadowOpacity: CGFloat {
        switch settings.backgroundShadowStyle {
        case .off: return 0
        case .sequoia: return shadowOpacitySequoia
        case .macOS26: return shadowOpacity
        }
    }
    private var symbolShadowRadius: CGFloat { baseSymbolShadowRadius * scaleFactor }
    private var symbolShadowOffset: CGFloat { baseSymbolShadowOffset * scaleFactor }

    // Badge scaled values — all derived from enclosure size
    private var badgeSize: CGFloat {
        BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badgeScale)
    }
    private var badgeShadowBuffer: CGFloat { enclosureSize * BadgeGeometry.shadowBufferRatio }

    /// How far the badge (including shadow) extends beyond the original canvas bounds
    private var badgeOverflow: CGFloat {
        guard settings.showBadge else { return 0 }
        let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize)
        let badgeRadius = badgeSize / 2
        let buffer = badgeShadowBuffer
        let halfCanvas = iconSize / 2
        let overflowRight  =  offset.width  + badgeRadius + buffer - halfCanvas
        let overflowLeft   = -offset.width  + badgeRadius + buffer - halfCanvas
        let overflowBottom =  offset.height + badgeRadius + buffer - halfCanvas
        let overflowTop    = -offset.height + badgeRadius + buffer - halfCanvas
        return max(0, overflowRight, overflowLeft, overflowBottom, overflowTop)
    }

    /// Total canvas size including badge overflow margin
    var totalCanvasSize: CGFloat {
        displaySize + 2 * badgeOverflow
    }

    /// Computes total canvas size without creating the full view (for export/preview sizing).
    /// Mirrors the instance `badgeOverflow`/`totalCanvasSize` pair; both draw all
    /// badge geometry from `BadgeGeometry`, so only the inset/overflow framing here
    /// must be kept in sync with the instance properties.
    static func totalCanvasSize(for settings: IconSettings, displaySize: CGFloat) -> CGFloat {
        guard settings.showBadge else { return displaySize }
        let backgroundInset = 25 * (displaySize / 256) // baseBackgroundInset * scaleFactor
        let enclosureSize = displaySize - 2 * backgroundInset
        let center = BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize)
        let extent = BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badgeScale) / 2
            + enclosureSize * BadgeGeometry.shadowBufferRatio

        let halfCanvas = displaySize / 2
        let overflow = max(0,
            center.width + extent - halfCanvas,
            -center.width + extent - halfCanvas,
            center.height + extent - halfCanvas,
            -center.height + extent - halfCanvas
        )
        return displaySize + 2 * overflow
    }

    var body: some View {
        ZStack {
            if !settings.iconBackgroundHidden {
                backgroundLayer
            }

            // Icon content (SF Symbol or custom image) — hidden when background is an imported image,
            // or when the foreground layer is explicitly hidden via the layer sidebar's eye toggle.
            if !settings.iconForegroundHidden, settings.backgroundMode != .importedImage {
                iconContent
                    .shadow(
                        color: settings.enableSymbolShadow ? Color.black.opacity(symbolShadowOpacity) : Color.clear,
                        radius: settings.enableSymbolShadow ? symbolShadowRadius : 0,
                        y: settings.enableSymbolShadow ? symbolShadowOffset : 0
                    )
            }

            if settings.showBadge {
                BadgeView(settings: settings, badgeSize: badgeSize, badgeAppexImage: badgeAppexImage)
                    .offset(BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize))
            }
        }
        .frame(width: totalCanvasSize, height: totalCanvasSize)
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

            case .custom:
                if settings.useCustomColors {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            settings.enableBackgroundGradient
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

            case .importedImage:
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
        case .sfSymbol:
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

        case .customImage:
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

    private let shadowOpacity: CGFloat = 0.23
    private let symbolShadowOpacity: CGFloat = 0.15

    private var resolvedBadgeSizing: ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: settings.badgeSymbolName)
    }

    private var badgeSymbolSize: CGFloat {
        badgeSize * resolvedBadgeSizing.multiplier * settings.badgeSymbolScale
    }

    private var badgeSymbolWeight: Font.Weight {
        settings.badgeSymbolWeight.fontWeight ?? resolvedBadgeSizing.weight
    }

    /// True only when an imported badge background will actually draw. The
    /// "use imported" flag can be set before any image is chosen (the Type picker
    /// writes it directly); in that state the badge falls back to its color
    /// background and keeps its symbol instead of rendering nothing.
    private var showsImportedBackground: Bool {
        !settings.badgeBackgroundHidden
            && settings.badgeUseImportedBackground
            && settings.badgeImportedBackground != nil
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
                    let effectiveScale = settings.badgeImportedBackgroundScale
                        * (settings.badgeImportedBackgroundPaddingCompensation
                            ? ImportedImageGeometry.paddingCompensationFactor : 1.0)
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: badgeSize * effectiveScale,
                            height: badgeSize * effectiveScale
                        )
                        .clipShape(Circle())
                        .shadow(
                            color: settings.badgeEnableBackgroundShadow ? Color.black.opacity(shadowOpacity) : Color.clear,
                            radius: settings.badgeEnableBackgroundShadow ? badgeSize * 0.03 : 0,
                            y: settings.badgeEnableBackgroundShadow ? badgeSize * 0.04 : 0
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
                            color: settings.badgeEnableBackgroundShadow ? Color.black.opacity(shadowOpacity) : Color.clear,
                            radius: settings.badgeEnableBackgroundShadow ? badgeSize * 0.03 : 0,
                            y: settings.badgeEnableBackgroundShadow ? badgeSize * 0.04 : 0
                        )
                } else if !settings.badgeBackgroundHidden {
                    Circle()
                        .fill(settings.badgeEnableBackgroundGradient ? AnyShapeStyle(settings.badgeBaseColor.gradient) : AnyShapeStyle(settings.badgeBaseColor))
                        .shadow(
                            color: settings.badgeEnableBackgroundShadow ? Color.black.opacity(shadowOpacity) : Color.clear,
                            radius: settings.badgeEnableBackgroundShadow ? badgeSize * 0.03 : 0,
                            y: settings.badgeEnableBackgroundShadow ? badgeSize * 0.04 : 0
                        )
                }

                // Badge symbol — gated on the foreground visibility toggle, and (preserving the old
                // behavior) suppressed when the badge background is an imported image that is itself visible.
                if !settings.badgeForegroundHidden, !showsImportedBackground {
                    badgeContent
                        .shadow(
                            color: settings.badgeEnableSymbolShadow ? Color.black.opacity(symbolShadowOpacity) : Color.clear,
                            radius: settings.badgeEnableSymbolShadow ? badgeSize * 0.02 : 0,
                            y: settings.badgeEnableSymbolShadow ? badgeSize * 0.025 : 0
                        )
                }
            }
            .frame(width: badgeSize, height: badgeSize)
        }
    }

    @ViewBuilder
    private var badgeContent: some View {
        switch settings.badgeIconSource {
        case .sfSymbol:
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

        case .customImage:
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



