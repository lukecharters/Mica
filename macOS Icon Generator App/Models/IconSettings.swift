// IconSettings.swift - Data model for our icon configuration
import SwiftUI

struct IconSettings: Equatable {
    var symbolName: String = "folder.fill.badge.plus"
    var baseColor: Color = .blue
    var useCustomColors: Bool = false
    var customPrimaryColor: Color = .blue
    var customSecondaryColor: Color = .purple
    var exportSize: CGFloat = 256
    var exportRetinaSize: Bool = false
    var symbolRenderingMode: SymbolRenderingMode = .monochrome
    var exportColorSpace: ExportColorSpace = .sRGB
    
    // Shadow settings
    var enableBackgroundShadow: Bool = true
    var enableSymbolShadow: Bool = true
    
    // Symbol colors
    var symbolColor: Color = .white
    var hierarchicalSymbolColor: Color = .white
    var paletteSymbolPrimaryColor: Color = .white
    var paletteSymbolSecondaryColor: Color = .white.opacity(0.5)
    var paletteSymbolTertiaryColor: Color = .white.opacity(0.26)
    
    // Badge settings
    var showBadge: Bool = false
    var badgePosition: BadgePosition = .bottomRight
    var badgeSymbolName: String = "gearshape.fill"
    var badgeUseCustomColors: Bool = false
    var badgeBaseColor: Color = .gray
    var badgeCustomPrimaryColor: Color = .white
    var badgeCustomSecondaryColor: Color = .indigo
    var badgeSymbolColor: Color = .white
    var badgeSymbolRenderingMode: SymbolRenderingMode = .monochrome
    var badgeHierarchicalSymbolColor: Color = .white
    var badgePaletteSymbolPrimaryColor: Color = .white
    var badgePaletteSymbolSecondaryColor: Color = .white.opacity(0.5)
    var badgePaletteSymbolTertiaryColor: Color = .white.opacity(0.26)
    var badgeEnableBackgroundShadow: Bool = true
    var badgeEnableSymbolShadow: Bool = true
    
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
    
    var badgeGradientColors: [Color] {
        if badgeUseCustomColors {
            return [badgeCustomPrimaryColor, badgeCustomSecondaryColor]
        } else {
            let baseColorNS = NSColor(badgeBaseColor)
            let darkerColor = NSColor(hue: baseColorNS.hueComponent,
                                     saturation: baseColorNS.saturationComponent,
                                     brightness: baseColorNS.brightnessComponent * 0.7,
                                     alpha: baseColorNS.alphaComponent)
            return [badgeBaseColor, Color(darkerColor)]
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

enum ExportColorSpace: String, CaseIterable, Identifiable {
    case sRGB = "sRGB"
    case displayP3 = "Display P3"
    
    var id: String { self.rawValue }
    
    var nsColorSpace: NSColorSpace {
        switch self {
        case .sRGB:
            return NSColorSpace.sRGB
        case .displayP3:
            return NSColorSpace.displayP3
        }
    }
}

enum BadgePosition: String, CaseIterable, Identifiable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    
    var id: String { rawValue }
}

extension IconSettings {
    static let minExportSize: CGFloat = 16
    static let maxExportSize: CGFloat = 1024
    static let defaultExportSize: CGFloat = 256
    
    var isExportSizeValid: Bool {
        (Self.minExportSize...Self.maxExportSize).contains(exportSize)
    }
}
