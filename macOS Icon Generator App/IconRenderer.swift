// IconRenderer.swift - Handles rendering the icon for export
import SwiftUI
import CoreGraphics

@MainActor
struct IconRenderer {
    static func renderIcon(settings: IconSettings) -> NSImage {
        let size = CGSize(width: settings.finalExportSize, height: settings.finalExportSize)
        
        // Create a SwiftUI view for our icon
        let iconView = IconView(settings: settings)
            .frame(width: size.width, height: size.height)
        
        // Use ImageRenderer to render the SwiftUI view
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = 1.0 // We already manage the size in finalExportSize
        renderer.isOpaque = false
        
        // Convert to NSImage
        if let nsImage = renderer.nsImage {
            // Convert to the specified color space
            return convertToColorSpace(image: nsImage, colorSpace: settings.exportColorSpace)
        }
        
        // Fallback if rendering fails
        return NSImage(size: size)
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
            bitsPerComponent: 8,
            bytesPerRow: 0,
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
}

// A SwiftUI view specifically for rendering the icon
private struct IconView: View {
    let settings: IconSettings
    
    // Calculate scaling factor based on preview size (256) to export size
    private var scaleFactor: CGFloat {
        settings.finalExportSize / 256.0
    }
    
    // Calculate the appropriate inset based on export size
    private var insetSize: CGFloat {
        switch settings.finalExportSize {
        case 1024:
            return 100
        case 512:
            return 50
        case 256:
            return 25
        case 128:
            return 10
        default:
            // For any other size, maintain the same proportional inset (about 10%)
            return settings.finalExportSize * 0.1
        }
    }
    
    var body: some View {
        ZStack {
            // Background with rounded corners - matching preview exactly
            if settings.useCustomColors {
                RoundedRectangle(cornerRadius: 70 * scaleFactor, style: .continuous)
                    .inset(by: insetSize)  // Inset to give space for shadows
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: settings.gradientColors),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        //color: .black.opacity(0.25),
                        radius: 2 * scaleFactor,
                        x: 0,
                        y: 2.5 * scaleFactor
                    )
            } else {
                RoundedRectangle(cornerRadius: 70 * scaleFactor, style: .continuous)
                    .inset(by: insetSize)  // Inset to give space for shadows
                    .fill(settings.baseColor.gradient)
                    .shadow(
                        //color: .black.opacity(0.25),
                        radius: 2 * scaleFactor,
                        x: 0,
                        y: 2.5 * scaleFactor
                    )
            }

            // SF Symbol icon with appropriate rendering mode and colors - matching preview
            Group {
                switch settings.symbolRenderingMode {
                case .monochrome:
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + (5.5 * scaleFactor)
                        }
                        .font(.system(size: 120 * scaleFactor, weight: .regular))
                        .foregroundColor(settings.symbolColor)
                        .symbolRenderingMode(.monochrome)
                        .shadow(
                            //color: .black.opacity(0.25),
                            radius: 2 * scaleFactor,
                            x: 0,
                            y: 2.5 * scaleFactor
                        )
                
                case .hierarchical:
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + (5.5 * scaleFactor)
                        }
                        .font(.system(size: 120 * scaleFactor, weight: .regular))
                        .foregroundStyle(settings.hierarchicalSymbolColor)
                        .symbolRenderingMode(.hierarchical)
                        .shadow(
                            //color: .black.opacity(0.25),
                            radius: 2 * scaleFactor,
                            x: 0,
                            y: 2.5 * scaleFactor
                        )
                
                case .multicolor:
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + (5.5 * scaleFactor)
                        }
                        .font(.system(size: 120 * scaleFactor, weight: .regular))
                        .symbolRenderingMode(.multicolor)
                        .shadow(
                            //color: .black.opacity(0.25),
                            radius: 2 * scaleFactor,
                            x: 0,
                            y: 2.5 * scaleFactor
                        )
                
                case .palette:
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + (5.5 * scaleFactor)
                        }
                        .font(.system(size: 120 * scaleFactor, weight: .regular))
                        .foregroundStyle(
                            settings.paletteSymbolPrimaryColor,
                            settings.paletteSymbolSecondaryColor,
                            settings.paletteSymbolTertiaryColor
                        )
                        .symbolRenderingMode(.palette)
                        .shadow(
                            //color: .black.opacity(0.25),
                            radius: 2 * scaleFactor,
                            x: 0,
                            y: 2.5 * scaleFactor
                        )
                }
            }
        }
        .frame(width: settings.finalExportSize, height: settings.finalExportSize)
    }
}
