// IconRenderer.swift - Handles rendering the icon for export
import SwiftUI
import CoreGraphics

// Preference key resize struct
//private struct SizePreferenceKey: PreferenceKey {
//    static var defaultValue: CGSize = .zero
//
//    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
//        value = nextValue()
//    }
//}

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
// Preference key resize variable
//    @State private var adaptiveSymbolFontSize: CGFloat? = nil

    // Base layout constants tuned for 256pt reference
    private let baseSize: CGFloat = 256
    private let baseCornerRadius: CGFloat = 46
    private let baseCornerRadiusLG: CGFloat = 54
    private let baseBackgroundInset: CGFloat = 25
    private let baseSymbolSize: CGFloat = 125
    private let baseShadowRadius: CGFloat = 4
    private let baseShadowOffset: CGFloat = 2.5
    private let shadowOpacity: CGFloat = 0.35
    private let baseShadowRadiusSequoia: CGFloat = 2
    private let baseShadowOffsetSequoia: CGFloat = 2.5
    private let shadowOpacitySequoia: CGFloat = 0.31
    private let baseVerticalAlignmentOffset: CGFloat = 5.5
    private let symbolWeight: Font.Weight = .regular
    private let baseSymbolShadowRadius: CGFloat = 2
    private let baseSymbolShadowOffset: CGFloat = 2.5
    private let symbolShadowOpacity: CGFloat = 0.23

    // Badge layout constants
    private let baseBadgeSize: CGFloat = 80
    private let baseBadgeOffset: CGFloat = 4
    private let baseBadgeSymbolSize: CGFloat = 45

//    Preference key resize
//    private var baseBackgroundSize: CGFloat { baseSize * 0.8}
    
    private var scaleFactor: CGFloat { displaySize / baseSize }

    // Scaled layout constants
//    Preference key resize
//    private var backgroundSize: CGFloat { baseBackgroundSize * scaleFactor }
    private var iconSize: CGFloat { displaySize }
    private var cornerRadius: CGFloat {
        let baseRadius = settings.cornerRadiusStyle == .macOS26 ? baseCornerRadiusLG : baseCornerRadius
        return baseRadius * scaleFactor
    }
    private var backgroundInset: CGFloat { baseBackgroundInset * scaleFactor }
    private var symbolSize: CGFloat { baseSymbolSize * scaleFactor }
//    Preference key resize
//    //private var baseSymbolFontSize: CGFloat { (baseBackgroundSize * 0.6) * scaleFactor}
//    private var baseSymbolFontSize: CGFloat { baseSymbolSize * scaleFactor }
//    //private var baseSymbolFontSize: CGFloat { ((iconSize - (backgroundInset * 2)) * 0.6) * scaleFactor }
//    private var manualScaleFactor: CGFloat { settings.useAutomaticSymbolSizing ? 1 : CGFloat(settings.manualSymbolScale) }
//    private var initialSymbolFontSize: CGFloat { baseSymbolFontSize * manualScaleFactor }
//    private var resolvedSymbolFontSize: CGFloat { adaptiveSymbolFontSize ?? initialSymbolFontSize }
//    private var symbolContentBounds: CGFloat { max(iconSize - (backgroundInset * 2), 1) }
//    //private var symbolContentBounds: CGFloat { max(backgroundSize, 1) }
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


            applySymbolColorRenderingMode(
                to: applySymbolColor(
                    to: Image(systemName: settings.symbolName)
                        .font(.system(size: symbolSize, weight: symbolWeight))
                )
                .symbolRenderingMode(settings.symbolRenderingMode.symbolRenderingMode)
            )
            .frame(width: iconSize, height: iconSize)
            .padding(-backgroundInset)
            .shadow(
                color: settings.enableSymbolShadow ? Color.black.opacity(symbolShadowOpacity) : Color.clear,
                radius: settings.enableSymbolShadow ? symbolShadowRadius : 0,
                y: settings.enableSymbolShadow ? symbolShadowOffset : 0
            )
//                .overlay(
//                    Image("CFBundle-folder.fill.badge.plus")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: (iconSize), height: (iconSize))
//                        .opacity(0.61)
//                )

//            Text(String(format: "resolvedSymbolFontSize: %.1f", resolvedSymbolFontSize))
//                .font(.system(size: 9, weight: .medium, design: .monospaced))
//                .padding(3)
//                .background(Color.black.opacity(0.35))
//                .foregroundColor(.white)
//                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
//                .padding(4)
//            Image("App Icon Template 1024")
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .opacity(0.3)
//                .frame(width: (iconSize - backgroundInset*2), height: (iconSize - backgroundInset*2))
//                .allowsHitTesting(false)
        
            
            // Badge
            if settings.showBadge {
                BadgeView(settings: settings, badgeSize: badgeSize, badgeSymbolSize: badgeSymbolSize)
                    .offset(badgeOffset(for: settings.badgePosition))
            }
        }
//        Preference Key Resize
//        .onAppear {
//            resetAdaptiveSymbolFontSize()
//        }
//        .onChange(of: settings.symbolName) { _, _ in
//            resetAdaptiveSymbolFontSize()
//        }
//        .onChange(of: displaySize) { _, _ in
//            resetAdaptiveSymbolFontSize()
//        }
//        .onChange(of: settings.useAutomaticSymbolSizing) { _, _ in
//            resetAdaptiveSymbolFontSize()
//        }
//        .onChange(of: settings.manualSymbolScale) { _, _ in
//            resetAdaptiveSymbolFontSize()
//        }
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


//Preference Key Resize
//    private func updateSymbolFontSizeIfNeeded(measured size: CGSize) {
//        guard size.width > 0, size.height > 0 else { return }
//        let maxDimension = symbolContentBounds
//        guard maxDimension > 0 else { return }
//
//        if size.width <= maxDimension && size.height <= maxDimension {
//            if adaptiveSymbolFontSize == nil {
//                adaptiveSymbolFontSize = initialSymbolFontSize
//            }
//            return
//        }
//
//        let currentSize = adaptiveSymbolFontSize ?? initialSymbolFontSize
//        let scale = min(maxDimension / size.width, maxDimension / size.height) * 0.95
//        let adjustedSize = max(currentSize * scale, 1)
//
//        if adaptiveSymbolFontSize == nil || abs(adjustedSize - currentSize) > 0.5 {
//            adaptiveSymbolFontSize = adjustedSize
//        }
//    }
//
//    private func resetAdaptiveSymbolFontSize() {
//        let targetSize = initialSymbolFontSize
//        if adaptiveSymbolFontSize != targetSize {
//            adaptiveSymbolFontSize = targetSize
//        }
//    }

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
                        color: settings.badgeEnableBackgroundShadow ? Color.black.opacity(shadowOpacity) : Color.clear,
                        radius: settings.badgeEnableBackgroundShadow ? badgeSize * 0.03 : 0,
                        y: settings.badgeEnableBackgroundShadow ? badgeSize * 0.04 : 0
                    )
            } else {
                Circle()
                    .fill(settings.badgeBaseColor.gradient)
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



