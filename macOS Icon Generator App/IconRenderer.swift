// IconRenderer.swift - Handles rendering the icon for export
import SwiftUI

struct IconRenderer {
    static func renderIcon(settings: IconSettings) -> NSImage {
        let size = settings.finalExportSize
        let hasAlpha = true
        
        let bytesPerRow = 4 * Int(size)
        
        let offscreenRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size),
            pixelsHigh: Int(size),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: hasAlpha,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: bytesPerRow,
            bitsPerPixel: 32
        )
        
        guard let context = NSGraphicsContext(bitmapImageRep: offscreenRep!) else {
            return NSImage(size: NSSize(width: size, height: size))
        }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        
        // Create the icon in the context
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        
        // Background with rounded corners - more squircle-like for macOS icons
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.03, dy: size * 0.03),
                               xRadius: size * 0.24,
                               yRadius: size * 0.24)
        
        // Apply shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
        shadow.shadowOffset = NSSize(width: 0, height: -size * 0.01)
        shadow.shadowBlurRadius = size * 0.03
        shadow.set()
        
        // Fill background with gradient
        if settings.useCustomColors {
            // Create custom gradient
            let gradient = NSGradient(
                colors: settings.gradientColors.map { NSColor($0) },
                atLocations: [0.0, 1.0],
                colorSpace: .deviceRGB
            )
            gradient?.draw(in: path, angle: 315)
        } else {
            // Use SwiftUI standard color gradient
            let baseColor = NSColor(settings.baseColor)
            // Create lighter and darker variants that aren't optionals
            let lighterColor = baseColor.withAlphaComponent(1.0)
            let darkerColor = NSColor(
                hue: baseColor.hueComponent,
                saturation: baseColor.saturationComponent,
                brightness: max(0.1, baseColor.brightnessComponent * 0.7),
                alpha: 1.0
            )
            
            let gradient = NSGradient(
                colors: [lighterColor, darkerColor],
                atLocations: [0.0, 1.0],
                colorSpace: .deviceRGB
            )
            gradient?.draw(in: path, angle: 315)
        }
        
        // Create symbol with appropriate configuration and rendering mode
        var configuration: NSImage.SymbolConfiguration
        
        switch settings.symbolRenderingMode {
        case .hierarchical:
            configuration = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .light)
                .applying(NSImage.SymbolConfiguration(hierarchicalColor: NSColor(settings.hierarchicalSymbolColor)))
        case .monochrome:
            configuration = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .light)
                .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(settings.symbolColor)]))
        case .multicolor:
            configuration = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .light)
        case .palette:
            configuration = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .light)
                .applying(NSImage.SymbolConfiguration(paletteColors: [
                    NSColor(settings.paletteSymbolPrimaryColor),
                    NSColor(settings.paletteSymbolSecondaryColor),
                    NSColor(settings.paletteSymbolTertiaryColor)
                ]))
        }
        
        guard let symbolImage = NSImage(systemSymbolName: settings.symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            NSGraphicsContext.restoreGraphicsState()
            let image = NSImage(size: NSSize(width: size, height: size))
            image.addRepresentation(offscreenRep!)
            return image
        }
        
        // Apply shadow to symbol
        let symbolShadow = NSShadow()
        symbolShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        symbolShadow.shadowOffset = NSSize(width: 0, height: -size * 0.005)
        symbolShadow.shadowBlurRadius = size * 0.005
        symbolShadow.set()
        
        // Draw symbol
        let symbolRect = NSRect(
            x: (size - symbolImage.size.width) / 2,
            y: (size - symbolImage.size.height) / 2,
            width: symbolImage.size.width,
            height: symbolImage.size.height
        )
        
        NSColor.white.set()
        symbolImage.draw(in: symbolRect)
        
        NSGraphicsContext.restoreGraphicsState()
        
        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(offscreenRep!)
        
        return image
    }
}
