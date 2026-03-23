// IconRenderer.swift - Handles rendering the icon for export
import SwiftUI
import CoreGraphics

struct IconRenderer {
    // Public entry – must run on MainActor due to SwiftUI/ImageRenderer isolation
    @MainActor
    static func renderIcon(settings: IconSettings) -> NSImage {
        let exportSize = settings.finalExportSize
        let canvasSize = IconContentView.totalCanvasSize(for: settings, displaySize: exportSize)
        let iconView = IconContentView(settings: settings, displaySize: exportSize)
            .frame(width: canvasSize, height: canvasSize)

        let renderer = ImageRenderer(content: iconView)
        renderer.scale = 1.0
        renderer.isOpaque = false

        if let nsImage = renderer.nsImage {
            let colorSpaceConverted = convertToColorSpace(image: nsImage, colorSpace: settings.exportColorSpace)
            return setImageDPI(image: colorSpaceConverted, settings: settings)
        }
        return NSImage(size: CGSize(width: exportSize, height: exportSize))
    }

    // Thread-safe wrapper that hops to the main queue when needed
    static func renderIconSafely(settings: IconSettings) -> NSImage {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { renderIcon(settings: settings) }
        }
        var output = NSImage(size: CGSize(width: settings.finalExportSize, height: settings.finalExportSize))
        DispatchQueue.main.sync {
            output = MainActor.assumeIsolated { renderIcon(settings: settings) }
        }
        return output
    }

    // MARK: - Color space and DPI helpers
    static func setImageDPI(image: NSImage, settings: IconSettings) -> NSImage {
        guard let originalCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        let logicalSize = CGSize(width: settings.exportSize, height: settings.exportSize)
        let newImage = NSImage(size: logicalSize)
        let bitmapRep = NSBitmapImageRep(cgImage: originalCGImage)
        bitmapRep.size = logicalSize
        newImage.addRepresentation(bitmapRep)
        return newImage
    }

    static func convertToColorSpace(image: NSImage, colorSpace: ExportColorSpace) -> NSImage {
        guard let originalCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        let width = Int(image.size.width)
        let height = Int(image.size.height)

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

        context.draw(originalCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let newCGImage = context.makeImage() else { return image }
        return NSImage(cgImage: newCGImage, size: image.size)
    }
}

// MARK: - Icon View used for rendering and previews
struct IconContentView: View {
    let settings: IconSettings
    let displaySize: CGFloat

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

    // Badge layout constants
    private let baseBadgeSize: CGFloat = 80
    private let badgeOffset: CGFloat = 4

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
        resolvedSizing.weight
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

    // Badge scaled constants
    private var badgeSize: CGFloat { baseBadgeSize * scaleFactor * settings.badgeScale }

    /// Distance from canvas center to the badge anchor point (45° on the chiclet's continuous corner curve)
    private var cornerAnchorDistance: CGFloat {
        let chicletEdge = iconSize / 2 - backgroundInset
        let cornerInset = cornerRadius * 0.293 // ≈ 1 - cos(45°) for continuous curve
        return chicletEdge - cornerInset
    }

    /// How far the badge extends beyond the original canvas bounds
    private var badgeOverflow: CGFloat {
        guard settings.showBadge else { return 0 }
        let badgeRadius = badgeSize / 2
        return max(0, cornerAnchorDistance + badgeRadius - iconSize / 2)
    }

    /// Total canvas size including badge overflow margin
    var totalCanvasSize: CGFloat {
        displaySize + 2 * badgeOverflow
    }

    /// Computes total canvas size without creating the full view (for export/preview sizing)
    static func totalCanvasSize(for settings: IconSettings, displaySize: CGFloat) -> CGFloat {
        guard settings.showBadge else { return displaySize }
        let scaleFactor = displaySize / 256 // baseSize
        let backgroundInset = 25 * scaleFactor // baseBackgroundInset
        let baseRadius = settings.cornerRadiusStyle == .macOS26 ? 54.0 : 46.0
        let cornerRadius = baseRadius * scaleFactor
        let iconSize = displaySize
        let chicletEdge = iconSize / 2 - backgroundInset
        let cornerInset = cornerRadius * 0.293
        let anchorDistance = chicletEdge - cornerInset
        let badgeRadius = (80 * scaleFactor * settings.badgeScale) / 2 // baseBadgeSize
        let overflow = max(0, anchorDistance + badgeRadius - iconSize / 2)
        return displaySize + 2 * overflow
    }

    var body: some View {
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
            }

            // SF Symbol
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
            .shadow(
                color: settings.enableSymbolShadow ? Color.black.opacity(symbolShadowOpacity) : Color.clear,
                radius: settings.enableSymbolShadow ? symbolShadowRadius : 0,
                y: settings.enableSymbolShadow ? symbolShadowOffset : 0
            )
        
            
            // Badge
            if settings.showBadge {
                BadgeView(settings: settings, badgeSize: badgeSize)
                    .offset(badgeOffset(for: settings.badgePosition))
            }
        }
        .frame(width: totalCanvasSize, height: totalCanvasSize)
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

    private func badgeOffset(for position: BadgePosition) -> CGSize {
        let anchor = cornerAnchorDistance
        switch position {
        case .topRight:    return CGSize(width: anchor, height: -anchor)
        case .topLeft:     return CGSize(width: -anchor, height: -anchor)
        case .bottomRight: return CGSize(width: anchor, height: anchor)
        case .bottomLeft:  return CGSize(width: -anchor, height: anchor)
        }
    }
}

struct BadgeView: View {
    let settings: IconSettings
    let badgeSize: CGFloat

    private let shadowOpacity: CGFloat = 0.17
    private let symbolShadowOpacity: CGFloat = 0.15

    private var resolvedBadgeSizing: ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: settings.badgeSymbolName)
    }

    private var badgeSymbolSize: CGFloat {
        badgeSize * resolvedBadgeSizing.multiplier * settings.badgeSymbolScale
    }

    private var badgeSymbolWeight: Font.Weight {
        resolvedBadgeSizing.weight
    }

    var body: some View {
        ZStack {
            if settings.badgeUseCustomColors {
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
            } else {
                Circle()
                    .fill(settings.badgeEnableBackgroundGradient ? AnyShapeStyle(settings.badgeBaseColor.gradient) : AnyShapeStyle(settings.badgeBaseColor))
                    .shadow(
                        color: settings.badgeEnableBackgroundShadow ? Color.black.opacity(shadowOpacity) : Color.clear,
                        radius: settings.badgeEnableBackgroundShadow ? badgeSize * 0.03 : 0,
                        y: settings.badgeEnableBackgroundShadow ? badgeSize * 0.02 : 0
                    )
            }

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
            .shadow(
                color: settings.badgeEnableSymbolShadow ? Color.black.opacity(symbolShadowOpacity) : Color.clear,
                radius: settings.badgeEnableSymbolShadow ? badgeSize * 0.02 : 0,
                y: settings.badgeEnableSymbolShadow ? badgeSize * 0.025 : 0
            )
        }
        .frame(width: badgeSize, height: badgeSize)
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



