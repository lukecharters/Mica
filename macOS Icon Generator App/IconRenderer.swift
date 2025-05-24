// IconRenderer.swift - Handles rendering the icon for export
import SwiftUI

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
            return nsImage
        }
        
        // Fallback if rendering fails
        return NSImage(size: size)
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
            // Background with rounded corners - using the squircle shape similar to macOS icons
            if settings.useCustomColors {
                RoundedRectangle(cornerRadius: settings.finalExportSize * 0.24, style: .continuous)
                    .inset(by: insetSize)  // Use our dynamic inset size
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: settings.gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: .black.opacity(0.15),
                        radius: settings.finalExportSize * 0.03,
                        x: 0,
                        y: settings.finalExportSize * 0.01
                    )
            } else {
                RoundedRectangle(cornerRadius: settings.finalExportSize * 0.24, style: .continuous)
                    .inset(by: insetSize)  // Use our dynamic inset size
                    .fill(settings.baseColor.gradient)
                    .shadow(
                        color: .black.opacity(0.15),
                        radius: settings.finalExportSize * 0.03,
                        x: 0,
                        y: settings.finalExportSize * 0.01
                    )
            }

            // Rest of your existing view code remains the same
            Group {
                switch settings.symbolRenderingMode {
                case .monochrome:
                    Image(systemName: settings.symbolName)
                        .font(.system(size: settings.finalExportSize * 0.42, weight: .light))
                        .foregroundColor(settings.symbolColor)
                        .symbolRenderingMode(.monochrome)
                
                case .hierarchical:
                    Image(systemName: settings.symbolName)
                        .font(.system(size: settings.finalExportSize * 0.42, weight: .light))
                        .foregroundStyle(settings.hierarchicalSymbolColor)
                        .symbolRenderingMode(.hierarchical)
                
                case .multicolor:
                    Image(systemName: settings.symbolName)
                        .font(.system(size: settings.finalExportSize * 0.42, weight: .light))
                        .symbolRenderingMode(.multicolor)
                
                case .palette:
                    Image(systemName: settings.symbolName)
                        .font(.system(size: settings.finalExportSize * 0.42, weight: .light))
                        .foregroundStyle(
                            settings.paletteSymbolPrimaryColor,
                            settings.paletteSymbolSecondaryColor,
                            settings.paletteSymbolTertiaryColor
                        )
                        .symbolRenderingMode(.palette)
                }
            }
            .shadow(
                color: .black.opacity(0.25),
                radius: settings.finalExportSize * 0.005,
                x: 0,
                y: settings.finalExportSize * 0.005
            )
        }
        .frame(width: settings.finalExportSize, height: settings.finalExportSize)
    }
}
