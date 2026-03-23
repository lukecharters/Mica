// IconSettings.swift - Data model for our icon configuration
import SwiftUI

struct IconSettings: Equatable {
    var symbolName: String = "folder.fill.badge.plus"
    var baseColor: Color = .blue
    var enableBackgroundGradient: Bool = true
    var useCustomColors: Bool = false
    var customPrimaryColor: Color = .blue
    var customSecondaryColor: Color = .purple
    var exportSize: CGFloat = 256
    var exportRetinaSize: Bool = false
    var symbolRenderingMode: SymbolRenderingMode = .monochrome
    var symbolColorRenderingMode: SymbolColorRenderingMode = .flat
    var backgroundMode: BackgroundMode = .custom
    var preRenderedColorName: String = "Blue"
    var cornerRadiusStyle: IconCornerRadiusStyle = .macOS26
    var exportColorSpace: ExportColorSpace = .sRGB

    var manualSymbolScale: Double = 1.0

    // Shadow settings
    var backgroundShadowStyle: BackgroundShadowStyle = .macOS26
    var enableSymbolShadow: Bool = true
    
    // Symbol colors
    var symbolColor: Color = .white
    var hierarchicalSymbolColor: Color = .white
    var paletteSymbolPrimaryColor: Color = .white
    var paletteSymbolSecondaryColor: Color = .white.opacity(0.5)
    var paletteSymbolTertiaryColor: Color = .white.opacity(0.18)
    
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
    var badgePaletteSymbolTertiaryColor: Color = .white.opacity(0.18)
    var badgeEnableBackgroundGradient: Bool = true
    var badgeEnableBackgroundShadow: Bool = true
    var badgeEnableSymbolShadow: Bool = true
    var badgeSymbolScale: Double = 1.0
    var badgeScale: Double = 0.8
    var badgeManualOffsetX: Double = 0.0
    var badgeManualOffsetY: Double = 0.0

    // Badge Symbol Color Rendering Mode (macOS 26+)
    var badgeSymbolColorRenderingMode: SymbolColorRenderingMode = .flat

    var gradientColors: [Color] {
        [customPrimaryColor, customSecondaryColor]
    }
    
    var badgeGradientColors: [Color] {
        [badgeCustomPrimaryColor, badgeCustomSecondaryColor]
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

enum BackgroundShadowStyle: String, CaseIterable, Identifiable {
    case off = "Off"
    case sequoia = "macOS 11-15"
    case macOS26 = "macOS 26"

    var id: String { rawValue }
}

extension IconSettings {
    static let minExportSize: CGFloat = 16
    static let maxExportSize: CGFloat = 1024
    static let defaultExportSize: CGFloat = 256
    static let manualSymbolScaleRange: ClosedRange<Double> = 0.3...2.0
    static let badgeOffsetRange: ClosedRange<Double> = -1.0...1.0

    var isExportSizeValid: Bool {
        (Self.minExportSize...Self.maxExportSize).contains(exportSize)
    }
}
