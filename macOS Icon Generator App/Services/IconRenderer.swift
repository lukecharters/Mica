// IconRenderer.swift - Handles rendering the icon for export
import SwiftUI
import CoreGraphics

struct IconRenderer {
    // Public entry – must run on MainActor due to SwiftUI/ImageRenderer isolation
    @MainActor
    static func renderIcon(settings: IconSettings) -> NSImage {
        let exportSize = settings.finalExportSize
        let iconView = IconContentView(settings: settings, displaySize: exportSize)
            .frame(width: exportSize, height: exportSize)

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
    private let baseCornerRadius: CGFloat = 46
    private let baseCornerRadiusLG: CGFloat = 54
    private let baseBackgroundInset: CGFloat = 25
    private let baseShadowRadius: CGFloat = 4
    private let baseShadowOffset: CGFloat = 2.5
    private let shadowOpacity: CGFloat = 0.35
    private let baseShadowRadiusSequoia: CGFloat = 2
    private let baseShadowOffsetSequoia: CGFloat = 2.5
    private let shadowOpacitySequoia: CGFloat = 0.31
    private let baseSymbolShadowRadius: CGFloat = 2
    private let baseSymbolShadowOffset: CGFloat = 2.5
    private let symbolShadowOpacity: CGFloat = 0.23

    // Badge layout constants
    private let baseBadgeSize: CGFloat = 80
    private let baseBadgeOffset: CGFloat = 4

    private var scaleFactor: CGFloat { displaySize / baseSize }

    // Scaled layout constants
    private var iconSize: CGFloat { displaySize }
    private var cornerRadius: CGFloat {
        let baseRadius = settings.cornerRadiusStyle == .macOS26 ? baseCornerRadiusLG : baseCornerRadius
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

    private var shadowRadius: CGFloat { baseShadowRadius * scaleFactor }
    private var shadowOffset: CGFloat { baseShadowOffset * scaleFactor }
    private var symbolShadowRadius: CGFloat { baseSymbolShadowRadius * scaleFactor }
    private var symbolShadowOffset: CGFloat { baseSymbolShadowOffset * scaleFactor }

    // Badge scaled constants
    private var badgeSize: CGFloat { baseBadgeSize * scaleFactor }
    private var badgeOffset: CGFloat { baseBadgeOffset * scaleFactor }

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
                        color: settings.enableBackgroundShadow ? Color.black.opacity(shadowOpacity) : Color.clear,
                        radius: settings.enableBackgroundShadow ? shadowRadius : 0,
                        y: settings.enableBackgroundShadow ? shadowOffset : 0
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
                            color: settings.enableBackgroundShadow ? Color.black.opacity(shadowOpacity) : Color.clear,
                            radius: settings.enableBackgroundShadow ? shadowRadius : 0,
                            y: settings.enableBackgroundShadow ? shadowOffset : 0
                        )
                        .frame(width: iconSize, height: iconSize)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(settings.enableBackgroundGradient ? AnyShapeStyle(settings.baseColor.gradient) : AnyShapeStyle(settings.baseColor))
                        .shadow(
                            color: settings.enableBackgroundShadow ? Color.black.opacity(shadowOpacity) : Color.clear,
                            radius: settings.enableBackgroundShadow ? shadowRadius : 0,
                            y: settings.enableBackgroundShadow ? shadowOffset : 0
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
        let iconRadius = iconSize / 2
        let badgeRadius = badgeSize / 2
        let offsetDistance = iconRadius - badgeRadius - badgeOffset
        switch position {
        case .topRight:
            return CGSize(width: offsetDistance, height: -offsetDistance)
        case .topLeft:
            return CGSize(width: -offsetDistance, height: -offsetDistance)
        case .bottomRight:
            return CGSize(width: offsetDistance, height: offsetDistance)
        case .bottomLeft:
            return CGSize(width: -offsetDistance, height: offsetDistance)
        }
    }
}

struct BadgeView: View {
    let settings: IconSettings
    let badgeSize: CGFloat

    private let shadowOpacity: CGFloat = 0.31
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



