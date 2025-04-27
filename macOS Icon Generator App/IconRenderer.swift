// IconRenderer.swift - Handles rendering the icon for export
import SwiftUI

struct IconRenderer {
    static func renderIcon(settings: IconSettings) -> NSImage {
        let size = settings.finalExportSize
        let format = NSBitmapImageRep.Format.RGBA
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
        
        // Background with rounded corners
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.05, dy: size * 0.05), 
                               xRadius: size * 0.2, 
                               yRadius: size * 0.2)
        
        // Create gradient
        let gradient = NSGradient(
            colors: settings.gradientColors.map { NSColor($0) },
            atLocations: [0.0, 1.0],
            colorSpace: .deviceRGB
        )
        
        // Apply shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -size * 0.02)
        shadow.shadowBlurRadius = size * 0.04
        shadow.set()
        
        // Fill background with gradient
        gradient?.draw(in: path, angle: 315)
        
        // Create symbol with appropriate configuration
        let configuration = NSImage.SymbolConfiguration(pointSize: size * 0.4, weight: .light)
        guard let symbolImage = NSImage(systemSymbolName: settings.symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            NSGraphicsContext.restoreGraphicsState()
            let image = NSImage(size: NSSize(width: size, height: size))
            image.addRepresentation(offscreenRep!)
            return image
        }
        
        // Apply shadow to symbol
        let symbolShadow = NSShadow()
        symbolShadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        symbolShadow.shadowOffset = NSSize(width: 0, height: -size * 0.01)
        symbolShadow.shadowBlurRadius = size * 0.01
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