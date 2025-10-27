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
    private let baseBackgroundInset: CGFloat = 25
    private let baseSymbolSize: CGFloat = 120
    private let baseShadowRadius: CGFloat = 2
    private let baseShadowOffset: CGFloat = 2.5
    private let baseVerticalAlignmentOffset: CGFloat = 5.5
    private let shadowOpacity: CGFloat = 0.31
    private let symbolWeight: Font.Weight = .regular
    private let baseSymbolShadowRadius: CGFloat = 2
    private let baseSymbolShadowOffset: CGFloat = 2.5
    private let symbolShadowOpacity: CGFloat = 0.23

    // Badge layout constants
    private let baseBadgeSize: CGFloat = 80
    private let baseBadgeOffset: CGFloat = 4
    private let baseBadgeSymbolSize: CGFloat = 45

    private var scaleFactor: CGFloat { displaySize / baseSize }

    // Scaled layout constants
    private var iconSize: CGFloat { displaySize }
    private var cornerRadius: CGFloat { baseCornerRadius * scaleFactor }
    private var backgroundInset: CGFloat { baseBackgroundInset * scaleFactor }
    private var symbolSize: CGFloat { baseSymbolSize * scaleFactor }
    private var shadowRadius: CGFloat { baseShadowRadius * scaleFactor }
    private var shadowOffset: CGFloat { baseShadowOffset * scaleFactor }
    private var verticalAlignmentOffset: CGFloat { baseVerticalAlignmentOffset * scaleFactor }
    private var symbolShadowRadius: CGFloat { baseSymbolShadowRadius * scaleFactor }
    private var symbolShadowOffset: CGFloat { baseSymbolShadowOffset * scaleFactor }

    // Badge scaled constants
    private var badgeSize: CGFloat { baseBadgeSize * scaleFactor }
    private var badgeOffset: CGFloat { baseBadgeOffset * scaleFactor }
    private var badgeSymbolSize: CGFloat { baseBadgeSymbolSize * scaleFactor }

    var body: some View {
        ZStack {
            // Had to have a second copy of the entire view for Liquid Glass and new SF Symbols effects

            if settings.useCustomColors {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: settings.gradientColors),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ifAvailableGlassEffect(settings: settings, shape: RoundedRectangle(cornerRadius: cornerRadius))
                    .padding(backgroundInset)
                    .shadow(
                        color: settings.enableBackgroundShadow ? .black.opacity(shadowOpacity) : .clear,
                        radius: settings.enableBackgroundShadow ? shadowRadius : 0,
                        y: settings.enableBackgroundShadow ? shadowOffset : 0
                    )
                    .frame(width: iconSize, height: iconSize)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(settings.baseColor.gradient)
                    .ifAvailableGlassEffect(settings: settings, shape: RoundedRectangle(cornerRadius: cornerRadius))
                    .padding(backgroundInset)
                    .shadow(
                        color: settings.enableBackgroundShadow ? .black.opacity(shadowOpacity) : .clear,
                        radius: settings.enableBackgroundShadow ? shadowRadius : 0,
                        y: settings.enableBackgroundShadow ? shadowOffset : 0
                    )
                    .frame(width: iconSize, height: iconSize)
            }

            // SF Symbol
//            Group {
//                switch settings.symbolRenderingMode {
//                case .monochrome:
//                    Image(systemName: settings.symbolName)
//                        //.resizable()
//                        //.scaledToFit()
//                        //.scaleEffect(x: 0.75, y: 0.75, anchor: .center)
//                        //.frame(width: 206, height: 206, alignment: .center)
//                        .font(.system(size: symbolSize, weight: symbolWeight))
//                        .foregroundColor(settings.symbolColor)
//                        .changeSymbolRenderingMode(settings: settings)
//                        .ifAvailableSymbolColorRenderingMode(settings: settings)
//                        .offset(x: 0, y: -verticalAlignmentOffset)
//                        .shadow(
//                            color: settings.enableSymbolShadow ? .black.opacity(symbolShadowOpacity) : .clear,
//                            radius: settings.enableSymbolShadow ? symbolShadowRadius : 0,
//                            y: settings.enableSymbolShadow ? symbolShadowOffset : 0
//                        )
//                case .hierarchical:
//                    Image(systemName: settings.symbolName)
//                        .font(.system(size: symbolSize, weight: symbolWeight))
//                        .foregroundStyle(settings.hierarchicalSymbolColor)
//                        .symbolRenderingMode(.hierarchical)
//                        .ifAvailableSymbolColorRenderingMode(settings: settings)
//                        .offset(x: 0, y: -verticalAlignmentOffset)
//                        .shadow(
//                            color: settings.enableSymbolShadow ? .black.opacity(shadowOpacity) : .clear,
//                            radius: settings.enableSymbolShadow ? shadowRadius : 0,
//                            y: settings.enableSymbolShadow ? shadowOffset : 0
//                        )
//                case .multicolor:
//                    Image(systemName: settings.symbolName)
//                        .font(.system(size: symbolSize, weight: symbolWeight))
//                        .foregroundColor(settings.symbolColor)
//                        .symbolRenderingMode(.multicolor)
//                        .ifAvailableSymbolColorRenderingMode(settings: settings)
//                        .offset(x: 0, y: -verticalAlignmentOffset)
//                        .shadow(
//                            color: settings.enableSymbolShadow ? .black.opacity(shadowOpacity) : .clear,
//                            radius: settings.enableSymbolShadow ? shadowRadius : 0,
//                            y: settings.enableSymbolShadow ? shadowOffset : 0
//                        )
//                case .palette:
//                    Image(systemName: settings.symbolName)
//                        .font(.system(size: symbolSize, weight: symbolWeight))
//                        .foregroundStyle(
//                            settings.paletteSymbolPrimaryColor,
//                            settings.paletteSymbolSecondaryColor,
//                            settings.paletteSymbolTertiaryColor
//                        )
//                        .symbolRenderingMode(.palette)
//                        .ifAvailableSymbolColorRenderingMode(settings: settings)
//                        .offset(x: 0, y: -verticalAlignmentOffset)
//                        .shadow(
//                            color: settings.enableSymbolShadow ? .black.opacity(shadowOpacity) : .clear,
//                            radius: settings.enableSymbolShadow ? shadowRadius : 0,
//                            y: settings.enableSymbolShadow ? shadowOffset : 0
//                        )
//                }
//            }

            Image(systemName: settings.symbolName)
                //.resizable()
                //.scaledToFit()
                //.scaleEffect(x: 0.75, y: 0.75, anchor: .center)
                //.frame(width: 206, height: 206, alignment: .center)
                .font(.system(size: symbolSize, weight: symbolWeight))
                .foregroundColor(settings.symbolColor)
                .changeSymbolRenderingMode(settings: settings)
                .ifAvailableSymbolColorRenderingMode(settings: settings)
                .ifAvailableGlassEffect(settings: settings, shape: RoundedRectangle(cornerRadius: cornerRadius))
                .frame(width: iconSize, height: iconSize)
                .offset(x: 0, y: -verticalAlignmentOffset)
                .shadow(
                    color: settings.enableSymbolShadow ? .black.opacity(symbolShadowOpacity) : .clear,
                    radius: settings.enableSymbolShadow ? symbolShadowRadius : 0,
                    y: settings.enableSymbolShadow ? symbolShadowOffset : 0
                )
            
            // Badge
            if settings.showBadge {
                BadgeView(settings: settings, badgeSize: badgeSize, badgeSymbolSize: badgeSymbolSize)
                    .offset(badgeOffset(for: settings.badgePosition))
            }
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
    let badgeSymbolSize: CGFloat

    private let shadowOpacity: CGFloat = 0.31
    private let symbolShadowOpacity: CGFloat = 0.15

    var body: some View {
        ZStack {
            if settings.badgeUseCustomColors {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: settings.badgeGradientColors),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: settings.badgeEnableBackgroundShadow ? .black.opacity(shadowOpacity) : .clear,
                        radius: settings.badgeEnableBackgroundShadow ? badgeSize * 0.03 : 0,
                        y: settings.badgeEnableBackgroundShadow ? badgeSize * 0.04 : 0
                    )
            } else {
                Circle()
                    .fill(settings.badgeBaseColor.gradient)
                    .shadow(
                        color: settings.badgeEnableBackgroundShadow ? .black.opacity(shadowOpacity) : .clear,
                        radius: settings.badgeEnableBackgroundShadow ? badgeSize * 0.03 : 0,
                        y: settings.badgeEnableBackgroundShadow ? badgeSize * 0.02 : 0
                    )
            }

            Group {
                switch settings.badgeSymbolRenderingMode {
                case .monochrome:
                    Image(systemName: settings.badgeSymbolName)
                        .font(.system(size: badgeSymbolSize, weight: .regular))
                        .foregroundColor(settings.badgeSymbolColor)
                        .symbolRenderingMode(.monochrome)
                case .hierarchical:
                    Image(systemName: settings.badgeSymbolName)
                        .font(.system(size: badgeSymbolSize, weight: .regular))
                        .foregroundStyle(settings.badgeHierarchicalSymbolColor)
                        .symbolRenderingMode(.hierarchical)
                case .multicolor:
                    Image(systemName: settings.badgeSymbolName)
                        .font(.system(size: badgeSymbolSize, weight: .regular))
                        .foregroundColor(settings.badgeSymbolColor)
                        .symbolRenderingMode(.multicolor)
                case .palette:
                    Image(systemName: settings.badgeSymbolName)
                        .font(.system(size: badgeSymbolSize, weight: .regular))
                        .foregroundStyle(
                            settings.badgePaletteSymbolPrimaryColor,
                            settings.badgePaletteSymbolSecondaryColor,
                            settings.badgePaletteSymbolTertiaryColor
                        )
                        .symbolRenderingMode(.palette)
                }
            }
            .shadow(
                color: settings.badgeEnableSymbolShadow ? .black.opacity(symbolShadowOpacity) : .clear,
                radius: settings.badgeEnableSymbolShadow ? badgeSize * 0.02 : 0,
                y: settings.badgeEnableSymbolShadow ? badgeSize * 0.025 : 0
            )
        }
        .frame(width: badgeSize, height: badgeSize)
    }
}


extension View {
    @ViewBuilder
    func changeSymbolRenderingMode(settings: IconSettings) -> some View {
        self.symbolRenderingMode(settings.symbolRenderingMode.symbolRenderingMode)
    }
}

// MARK: - View extension for conditional symbolColorRenderingMode modifier
extension View {
    @ViewBuilder
    func ifAvailableSymbolColorRenderingMode(settings: IconSettings) -> some View {
        if #available(macOS 26.0, *) {
            self.symbolColorRenderingMode(settings.symbolColorRenderingMode.symbolColorRenderingMode)
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func ifAvailableGlassEffect<S: Shape>(settings: IconSettings, shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(settings.glassEffect.glassEffect, in: shape)
        } else {
            self
        }
    }
}
