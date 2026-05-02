//
//  liquid-glass.swift
//  Mica
//
//  Created by Luke Charters on 2/9/2025.
//

import SwiftUI
import CoreGraphics


struct LiquidGlassTests {
    static func renderIcon(settings: IconSettings) -> NSImage {
        // Create the IconContentView at the actual export size for proper rendering
        let exportSize = settings.finalExportSize
        let lgIconView = LiquidGlassView(settings: settings, displaySize: exportSize)
            .frame(width: exportSize, height: exportSize)
        
        // Use ImageRenderer to render the SwiftUI view at actual size
        let renderer = ImageRenderer(content: lgIconView)
        renderer.scale = 1.0 // No scaling needed since we're already at target size
        renderer.isOpaque = false
        
        // Convert to NSImage
        if let nsImage = renderer.nsImage {
            // Convert to the specified color space and set proper DPI
            let colorSpaceConverted = convertToColorSpace(image: nsImage, colorSpace: settings.exportColorSpace)
            return setImageDPI(image: colorSpaceConverted, settings: settings)
        }
        
        // Fallback if rendering fails
        return NSImage(size: CGSize(width: settings.finalExportSize, height: settings.finalExportSize))
    }
    
    // Set the proper DPI for the image based on retina setting
    static func setImageDPI(image: NSImage, settings: IconSettings) -> NSImage {
        guard let originalCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        
        // For retina images, we need to adjust the size to maintain the same visual size
        // but with higher pixel density
        let logicalSize: CGSize
        if settings.exportRetinaSize {
            // For retina, the logical size should be half the pixel size
            logicalSize = CGSize(width: settings.exportSize, height: settings.exportSize)
        } else {
            // For non-retina, logical size matches pixel size
            logicalSize = CGSize(width: settings.exportSize, height: settings.exportSize)
        }
        
        // Create new NSImage with proper size and DPI representation
        let newImage = NSImage(size: logicalSize)
        
        // Create an image representation with the correct DPI
        let bitmapRep = NSBitmapImageRep(cgImage: originalCGImage)
        
        // Set the logical size which effectively sets the DPI
        // For retina: 512px image with 256pt logical size = 144 DPI
        // For normal: 256px image with 256pt logical size = 72 DPI
        bitmapRep.size = logicalSize
        
        newImage.addRepresentation(bitmapRep)
        
        return newImage
    }
    
    // Convert image to specified color space using Core Graphics
    static func convertToColorSpace(image: NSImage, colorSpace: ExportColorSpace) -> NSImage {
        guard let originalCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        
        // Get the CGColorSpace from our enum
        let targetCGColorSpace: CGColorSpace
        switch colorSpace {
        case .sRGB:
            targetCGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        case .displayP3:
            targetCGColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
        }
        
        // Create a bitmap context with the target color space
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: targetCGColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        
        // Draw the image into the new context
        context.draw(originalCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Get the new image from the context
        guard let newCGImage = context.makeImage() else {
            return image
        }
        
        // Create NSImage from the new CGImage
        let newImage = NSImage(cgImage: newCGImage, size: image.size)
        
        return newImage
    }
    
    // A new function that can be called from any thread and guarantees main thread execution
    static func renderIconSafely(settings: IconSettings) -> NSImage {
        // If we're already on the main thread, just call the function directly
        if Thread.isMainThread {
            return renderIcon(settings: settings)
        }
        
        // Otherwise, execute on main thread synchronously and wait for result
        var resultImage: NSImage?
        let group = DispatchGroup()
        group.enter()
        
        DispatchQueue.main.async {
            resultImage = renderIcon(settings: settings)
            group.leave()
        }
        
        group.wait()
        return resultImage ?? NSImage(size: CGSize(width: settings.finalExportSize, height: settings.finalExportSize))
    }
    
    // Core Graphics constants
    private static let bitsPerComponent: Int = 8
    private static let bytesPerRow: Int = 0
}

// Shared icon content view that both preview and export can use
struct LiquidGlassView: View {
    let settings: IconSettings
    let displaySize: CGFloat
    
    // Initialize with a default size if not provided
    init(settings: IconSettings, displaySize: CGFloat = 256) {
        self.settings = settings
        self.displaySize = displaySize
    }
    
    // Base layout constants (optimized for 256pt base size)
    private let baseSize: CGFloat = 256
    private let baseCornerRadius: CGFloat = 46
    private let baseCornerRadiusTahoe: CGFloat = 53
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
    
    // Calculate scaling factor based on display size
    private var scaleFactor: CGFloat {
        displaySize / baseSize
    }
    
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
//                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                    //.glassEffect(.clear.tint(settings.baseColor), in: RoundedRectangle(cornerRadius: cornerRadius))fil
//                    .fill(.clear)
//                    .strokeBorder(Color.white.opacity(0.90), lineWidth: 10)
//                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
//                    .padding(backgroundInset)
//                .frame(width: iconSize, height: iconSize, alignment: .center)

                
                // Background with rounded corners - using the squircle shape similar to macOS icons
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    //                    .inset(by: backgroundInset)
                        .fill(settings.baseColor.gradient)
                        //.fill(.clear)
                    //.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
                        //.glassEffect(.regular.tint(.blue), in: RoundedRectangle(cornerRadius: cornerRadius))
                        //.glassEffect(.identity, in: RoundedRectangle(cornerRadius: cornerRadius))
                        //.glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
                        .padding(backgroundInset)
//                        .shadow(
//                            color: settings.enableBackgroundShadow ? .black.opacity(shadowOpacity) : .clear,
//                            radius: settings.enableBackgroundShadow ? shadowRadius : 0,
//                            y: settings.enableBackgroundShadow ? shadowOffset : 0
//                        )
                        .frame(width: iconSize, height: iconSize, alignment: .center)
                
                
                
                
                // SF Symbol icon with appropriate rendering mode and colors
                        Image(systemName: settings.symbolName)
                        //                        .alignmentGuide(VerticalAlignment.center) { context in
                        //                            context[VerticalAlignment.center] + verticalAlignmentOffset
                        //                        }
                            .font(.system(size: symbolSize, weight: symbolWeight))
                        
                            .foregroundColor(settings.symbolColor)
                            .symbolRenderingMode(.monochrome)
                            .offset(x: 0, y: -verticalAlignmentOffset)
//                            .shadow(
//                                color: settings.enableSymbolShadow ? .black.opacity(symbolShadowOpacity) : .clear,
//                                radius: settings.enableSymbolShadow ? symbolShadowRadius : 0,
//                                y: settings.enableSymbolShadow ? symbolShadowOffset : 0
//                            )
                            .frame(width: 206, height: 206, alignment: .center)
                            //.padding(-backgroundInset)
                            //.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
                        //.glassEffect(.identity, in: RoundedRectangle(cornerRadius: cornerRadius))
                            //.glassEffect(.regular.tint(settings.baseColor), in: RoundedRectangle(cornerRadius: cornerRadius))
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))

                            //.glassEffect()
                        
                        //.shadow(radius: symbolShadowRadius, x: 0, y: symbolShadowOffset)
//                            .shadow(
//                                color: settings.enableBackgroundShadow ? .black.opacity(shadowOpacity) : .clear,
//                                radius: settings.enableBackgroundShadow ? shadowRadius : 0,
//                                y: settings.enableBackgroundShadow ? shadowOffset : 0
//                            )
                        
                    }
                
                
                // Badge overlay
                if settings.showBadge {
                    BadgeView(settings: settings, badgeSize: badgeSize, badgeSymbolSize: badgeSymbolSize)
                        .offset(Mica.badgeOffset(for: settings.badgePosition))
                }
            }
        }
    
    // Calculate badge position offset
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

// Separate badge view component
struct BadgeView: View {
    let settings: IconSettings
    let badgeSize: CGFloat
    let badgeSymbolSize: CGFloat
    
    private let shadowOpacity: CGFloat = 0.31
    private let symbolShadowOpacity: CGFloat = 0.15
    
    var body: some View {
        ZStack {
            // Badge background
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
                    //.fill(settings.badgeBaseColor.gradient)
                    .fill(.black.opacity(0.35))
                //.fill(.clear)
                .shadow(
                    color: settings.badgeEnableBackgroundShadow ? .black.opacity(shadowOpacity) : .clear,
                    radius: settings.badgeEnableBackgroundShadow ? badgeSize * 0.03 : 0,
                    y: settings.badgeEnableBackgroundShadow ? badgeSize * 0.02 : 0
                    )
                .frame(width: badgeSize, height: badgeSize, alignment: .center)
                .glassEffect(.clear, in: Circle())
            }
            // Badge symbol
            Group {
                switch settings.badgeSymbolRenderingMode {
                case .monochrome:
                    Image(systemName: settings.badgeSymbolName)
                        .font(.system(size: badgeSymbolSize, weight: .regular))
                        .foregroundColor(settings.badgeSymbolColor)
                        .symbolRenderingMode(.monochrome)
                        .frame(width: badgeSize, height: badgeSize, alignment: .center)
                        .glassEffect(.clear, in: Circle())
                
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

//let view = lgIconView()

#Preview {
    LiquidGlassView()
}
