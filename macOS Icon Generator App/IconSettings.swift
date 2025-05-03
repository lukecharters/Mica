// IconSettings.swift - Data model for our icon configuration
import SwiftUI

struct IconSettings: Equatable {
    var symbolName: String = "gearshape.fill"
    var baseColor: Color = .blue
    var useCustomColors: Bool = false
    var customPrimaryColor: Color = .blue
    var customSecondaryColor: Color = .purple
    var exportSize: CGFloat = 256
    var exportRetinaSize: Bool = true
    var symbolRenderingMode: SymbolRenderingMode = .monochrome
    
    // Symbol colors
    var symbolColor: Color = .white
    var hierarchicalSymbolColor: Color = .white
    var paletteSymbolPrimaryColor: Color = .white
    var paletteSymbolSecondaryColor: Color = .white.opacity(0.8)
    var paletteSymbolTertiaryColor: Color = .white.opacity(0.6)
    
    var gradientColors: [Color] {
        if useCustomColors {
            return [customPrimaryColor, customSecondaryColor]
        } else {
            // We'll create a linear array of colors from the gradient
            // This is just for the renderer that needs explicit colors
            let baseColorNS = NSColor(baseColor)
            let darkerColor = NSColor(hue: baseColorNS.hueComponent,
                                     saturation: baseColorNS.saturationComponent,
                                     brightness: baseColorNS.brightnessComponent * 0.7,
                                     alpha: baseColorNS.alphaComponent)
            return [baseColor, Color(darkerColor)]
        }
    }
    
    var finalExportSize: CGFloat {
        return exportRetinaSize ? exportSize * 2 : exportSize
    }
}

enum SymbolRenderingMode: String, CaseIterable, Identifiable {
    case hierarchical = "Hierarchical"
    case monochrome = "Monochrome"
    case multicolor = "Multicolor"
    case palette = "Palette"
    
    var id: String { self.rawValue }
    
    var symbolRenderingMode: SwiftUI.SymbolRenderingMode {
        switch self {
        case .hierarchical:
            return .hierarchical
        case .monochrome:
            return .monochrome
        case .multicolor:
            return .multicolor
        case .palette:
            return .palette
        }
    }
}
