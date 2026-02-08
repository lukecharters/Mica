// IconSettings.swift - Data model for our icon configuration
import SwiftUI

struct IconSettings: Equatable {
    var symbolName: String = "folder.fill.badge.plus"
    var baseColor: Color = OptionsCatalog.color(named: "Blue")
    var enableBackgroundGradient: Bool = true
    var useCustomColors: Bool = false
    var customPrimaryColor: Color = OptionsCatalog.color(named: "Blue")
    var customSecondaryColor: Color = OptionsCatalog.color(named: "Purple")
    var exportSize: CGFloat = 256
    var exportRetinaSize: Bool = false
    var symbolRenderingMode: SymbolRenderingMode = .monochrome
    var symbolColorRenderingMode: SymbolColorRenderingMode = .flat
    var backgroundMode: BackgroundMode = .custom
    var preRenderedColorName: String = "Blue"
    var cornerRadiusStyle: IconCornerRadiusStyle = .macOS26
    var exportColorSpace: ExportColorSpace = .sRGB
    
//    Preference Key Resize
//    var useAutomaticSymbolSizing: Bool = true
//    var manualSymbolScale: Double = 1.0
    
    // Shadow settings
    var enableBackgroundShadow: Bool = true
    var enableSymbolShadow: Bool = true
    
    // Symbol colors
    var symbolColor: Color = OptionsCatalog.color(named: "White")
    var hierarchicalSymbolColor: Color = OptionsCatalog.color(named: "White")
    var paletteSymbolPrimaryColor: Color = OptionsCatalog.color(named: "White")
    var paletteSymbolSecondaryColor: Color = OptionsCatalog.color(named: "White").opacity(0.5)
    var paletteSymbolTertiaryColor: Color = OptionsCatalog.color(named: "White").opacity(0.18)
    
    // Badge settings
    var showBadge: Bool = false
    var badgePosition: BadgePosition = .bottomRight
    var badgeSymbolName: String = "gearshape.fill"
    var badgeUseCustomColors: Bool = false
    var badgeBaseColor: Color = OptionsCatalog.color(named: "Gray")
    var badgeCustomPrimaryColor: Color = OptionsCatalog.color(named: "White")
    var badgeCustomSecondaryColor: Color = OptionsCatalog.color(named: "Indigo")
    var badgeSymbolColor: Color = OptionsCatalog.color(named: "White")
    var badgeSymbolRenderingMode: SymbolRenderingMode = .monochrome
    var badgeHierarchicalSymbolColor: Color = OptionsCatalog.color(named: "White")
    var badgePaletteSymbolPrimaryColor: Color = OptionsCatalog.color(named: "White")
    var badgePaletteSymbolSecondaryColor: Color = OptionsCatalog.color(named: "White").opacity(0.5)
    var badgePaletteSymbolTertiaryColor: Color = OptionsCatalog.color(named: "White").opacity(0.18)
    var badgeEnableBackgroundGradient: Bool = true
    var badgeEnableBackgroundShadow: Bool = true
    var badgeEnableSymbolShadow: Bool = true

    // Badge Symbol Color Rendering Mode (macOS 26+)
    var badgeSymbolColorRenderingMode: SymbolColorRenderingMode = .flat

    var gradientColors: [Color] {
        if useCustomColors {
            return [customPrimaryColor, customSecondaryColor]
        } else {
            // We'll create a linear array of colors from the gradient
            // This is just for the renderer that needs explicit colors
            let baseColorNS = NSColor(baseColor)
            let darkerColor = NSColor(hue: baseColorNS.hueComponent,
                                     saturation: baseColorNS.saturationComponent,
                                     brightness: baseColorNS.brightnessComponent * 0.2,
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
                                     brightness: baseColorNS.brightnessComponent * 0.2,
                                     alpha: baseColorNS.alphaComponent)
            return [badgeBaseColor, Color(darkerColor)]
        }
    }
    
    var preRenderedAssetName: String {
        "background-\(preRenderedColorName.lowercased())-\(enableBackgroundGradient ? "gradient" : "solid")"
    }

    var finalExportSize: CGFloat {
        return exportRetinaSize ? exportSize * 2 : exportSize
    }
}

enum SymbolRenderingMode: String, CaseIterable, Identifiable {
    case monochrome = "Monochrome"
    case hierarchical = "Hierarchical"
    case palette = "Palette"
    case multicolor = "Multicolor"
    
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


enum BackgroundMode: String, CaseIterable, Identifiable {
    case custom = "Custom"
    case preRendered = "Pre-rendered"
    var id: String { rawValue }
}

enum SymbolColorRenderingMode: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case gradient = "Gradient"
    
    var id: String { self.rawValue }
    @available(macOS 26.0, *)
    var symbolColorRenderingMode: SwiftUI.SymbolColorRenderingMode {
        switch self {
        case .flat:
            return .flat
        case .gradient:
            return .gradient
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

enum IconCornerRadiusStyle: String, CaseIterable, Identifiable {
    case macOS11 = "macOS 11-15"
    case macOS26 = "macOS 26"

    var id: String { rawValue }
}

extension IconSettings {
    static let minExportSize: CGFloat = 16
    static let maxExportSize: CGFloat = 1024
    static let defaultExportSize: CGFloat = 256
//    Preference key resize
//    static let manualSymbolScaleRange: ClosedRange<Double> = 0.6...1.4
    
    var isExportSizeValid: Bool {
        (Self.minExportSize...Self.maxExportSize).contains(exportSize)
    }
}
