// IconRenderer.swift - Handles rendering the icon for export
import SwiftUI
import CoreGraphics

@MainActor
struct IconRenderer {
    static func renderIcon(settings: IconSettings) -> NSImage {
        // Create the IconContentView at the actual export size for proper rendering
        let exportSize = settings.finalExportSize
        let iconView = IconContentView(settings: settings, displaySize: exportSize)
            .frame(width: exportSize, height: exportSize)
        
        // Use ImageRenderer to render the SwiftUI view at actual size
        let renderer = ImageRenderer(content: iconView)
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
struct IconContentView: View {
    let settings: IconSettings
    let displaySize: CGFloat
    
    // Initialize with a default size if not provided
    init(settings: IconSettings, displaySize: CGFloat = 256) {
        self.settings = settings
        self.displaySize = displaySize
    }
    
    // Base layout constants (optimized for 256pt base size)
    private let baseSize: CGFloat = 256
    private let baseCornerRadius: CGFloat = 70
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
    
    var body: some View {
        ZStack {
            // Background with rounded corners - using the squircle shape similar to macOS icons
            if settings.useCustomColors {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .inset(by: backgroundInset)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: settings.gradientColors),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: shadowOffset)
                    .frame(width: iconSize, height: iconSize, alignment: .center)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .inset(by: backgroundInset)
                    .fill(settings.baseColor.gradient)
                    .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowOffset)
                    .frame(width: iconSize, height: iconSize, alignment: .center)
            }
            
            // SF Symbol icon with appropriate rendering mode and colors
            Group {
                switch settings.symbolRenderingMode {
                case .monochrome:
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in 
                            context[VerticalAlignment.center] + verticalAlignmentOffset
                        }
                        .font(.system(size: symbolSize, weight: symbolWeight))
                        .foregroundColor(settings.symbolColor)
                        .symbolRenderingMode(.monochrome)
                        .shadow(color: .black.opacity(symbolShadowOpacity), radius: symbolShadowRadius, x: 0, y: symbolShadowOffset)
                        //.shadow(radius: symbolShadowRadius, x: 0, y: symbolShadowOffset)
                
                case .hierarchical:
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in 
                            context[VerticalAlignment.center] + verticalAlignmentOffset
                        }
                        .font(.system(size: symbolSize, weight: symbolWeight))
                        .foregroundStyle(settings.hierarchicalSymbolColor)
                        .symbolRenderingMode(.hierarchical)
                        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowOffset)
                
                case .multicolor:
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in 
                            context[VerticalAlignment.center] + verticalAlignmentOffset
                        }
                        .font(.system(size: symbolSize, weight: symbolWeight))
                        .foregroundColor(settings.symbolColor)
                        .symbolRenderingMode(.multicolor)
                        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowOffset)
                
                case .palette:
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in 
                            context[VerticalAlignment.center] + verticalAlignmentOffset
                        }
                        .font(.system(size: symbolSize, weight: symbolWeight))
                        .foregroundStyle(
                            settings.paletteSymbolPrimaryColor,
                            settings.paletteSymbolSecondaryColor,
                            settings.paletteSymbolTertiaryColor
                        )
                        .symbolRenderingMode(.palette)
                        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowOffset)
                }
            }
        }
    }
}
