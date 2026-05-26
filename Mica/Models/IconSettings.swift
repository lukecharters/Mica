// IconSettings.swift - Data model for our icon configuration
import SwiftUI

struct IconSettings: Equatable {
    var symbolName: String = "command"
    var baseColor: Color = .blue
    var enableBackgroundGradient: Bool = true
    var useCustomColors: Bool = false
    var customPrimaryColor: Color = .blue
    var customSecondaryColor: Color = .purple
    var exportSize: CGFloat = 512
    var exportRetinaSize: Bool = false
    var symbolRenderingMode: SymbolRenderingMode = .monochrome
    var symbolColorRenderingMode: SymbolColorRenderingMode = .flat
    var backgroundMode: BackgroundMode = .custom
    var preRenderedColorName: String = "Blue"
    var cornerRadiusStyle: IconCornerRadiusStyle = .macOS26
    var exportColorSpace: ExportColorSpace = .sRGB

    var manualSymbolScale: Double = 1.0
    var symbolWeight: SymbolWeight = .auto
    var badgeSymbolWeight: SymbolWeight = .auto

    // Shadow settings
    var backgroundShadowStyle: BackgroundShadowStyle = .macOS26
    var enableSymbolShadow: Bool = true
    
    // Symbol colors
    var symbolColor: Color = .white
    var hierarchicalSymbolColor: Color = .white
    var paletteSymbolPrimaryColor: Color = .white
    var paletteSymbolSecondaryColor: Color = .mint
    var paletteSymbolTertiaryColor: Color = .yellow
    
    // Badge settings
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
    var badgePaletteSymbolSecondaryColor: Color = .mint
    var badgePaletteSymbolTertiaryColor: Color = .yellow
    var badgeEnableBackgroundGradient: Bool = true
    var badgeEnableBackgroundShadow: Bool = true
    var badgeEnableSymbolShadow: Bool = true
    var badgeSymbolScale: Double = 1.0
    var badgeScale: Double = 1.0
    var badgeManualOffsetX: Double = 0.0
    var badgeManualOffsetY: Double = 0.0

    // Badge Symbol Color Rendering Mode (macOS 26+)
    var badgeSymbolColorRenderingMode: SymbolColorRenderingMode = .flat

    // Custom image source (main icon symbol)
    var iconSource: IconSource = .sfSymbol
    var importedImage: ImportedImage? = nil
    var importedImageScale: Double = 1.0

    // Custom image source (main icon background)
    var importedBackground: ImportedImage? = nil
    var importedBackgroundPaddingCompensation: Bool = false
    var importedBackgroundScale: Double = 1.0

    // Custom image source (badge symbol)
    var badgeIconSource: IconSource = .sfSymbol
    var badgeImportedImage: ImportedImage? = nil
    var badgeImportedImageScale: Double = 1.0

    // Custom image source (badge background)
    var badgeUseImportedBackground: Bool = false
    var badgeImportedBackground: ImportedImage? = nil
    var badgeImportedBackgroundPaddingCompensation: Bool = false
    var badgeImportedBackgroundScale: Double = 1.0

    // Per-group generation mode. Icon and Badge are independent — e.g. Custom icon
    // with a System (Apple Reference) badge, or vice versa.
    var iconGenerationMode: GenerationMode = .swiftUI

    /// Badge generation mode derived from `badgeIconSource`. Setting `.appleReference`
    /// locks the badge source to `.appleReference`; setting `.swiftUI` falls back to
    /// `.sfSymbol` when needed. The LayerSidebar keeps a separate UI-state memory of
    /// the previous non-system source so the user's pick is restored on round-trip.
    var badgeGenerationMode: GenerationMode {
        get { badgeIconSource == .appleReference ? .appleReference : .swiftUI }
        set {
            switch newValue {
            case .appleReference:
                badgeIconSource = .appleReference
            case .swiftUI:
                if badgeIconSource == .appleReference {
                    badgeIconSource = .sfSymbol
                }
            }
        }
    }

    // Per-layer visibility (driven by the eye toggles in the layer sidebar).
    // `showBadge` is computed from these so existing call sites still work.
    var iconForegroundHidden: Bool = false
    var iconBackgroundHidden: Bool = false
    var badgeForegroundHidden: Bool = true
    var badgeBackgroundHidden: Bool = true

    /// True when at least one badge layer is visible. Setting this updates both
    /// `badgeForegroundHidden` and `badgeBackgroundHidden` together.
    var showBadge: Bool {
        get { !badgeForegroundHidden || !badgeBackgroundHidden }
        set {
            badgeForegroundHidden = !newValue
            badgeBackgroundHidden = !newValue
        }
    }

    /// Group-level visibility for the Icon (both layers). Setting it mirrors the
    /// value into both `iconForegroundHidden` and `iconBackgroundHidden`.
    var iconHidden: Bool {
        get { iconForegroundHidden && iconBackgroundHidden }
        set {
            iconForegroundHidden = newValue
            iconBackgroundHidden = newValue
        }
    }

    /// Group-level visibility for the Badge (both layers). Inverse of `showBadge`.
    var badgeHidden: Bool {
        get { badgeForegroundHidden && badgeBackgroundHidden }
        set {
            badgeForegroundHidden = newValue
            badgeBackgroundHidden = newValue
        }
    }

    /// Tri-state visibility for use in group header eye toggles.
    func iconVisibility() -> LayerGroupVisibility {
        switch (iconForegroundHidden, iconBackgroundHidden) {
        case (true, true):   return .off
        case (false, false): return .on
        default:             return .mixed
        }
    }

    func badgeVisibility() -> LayerGroupVisibility {
        switch (badgeForegroundHidden, badgeBackgroundHidden) {
        case (true, true):   return .off
        case (false, false): return .on
        default:             return .mixed
        }
    }

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
    case importedImage = "Image"
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

    var cgColorSpace: CGColorSpace {
        switch self {
        case .sRGB:
            return CGColorSpace(name: CGColorSpace.sRGB)!
        case .displayP3:
            return CGColorSpace(name: CGColorSpace.displayP3)!
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

enum SymbolWeight: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case ultraLight = "Ultralight"
    case thin = "Thin"
    case light = "Light"
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    case heavy = "Heavy"
    case black = "Black"

    var id: String { rawValue }

    /// Returns the corresponding `Font.Weight`, or `nil` for `.auto` (caller uses calibration data).
    var fontWeight: Font.Weight? {
        switch self {
        case .auto:       return nil
        case .ultraLight: return .ultraLight
        case .thin:       return .thin
        case .light:      return .light
        case .regular:    return .regular
        case .medium:     return .medium
        case .semibold:   return .semibold
        case .bold:       return .bold
        case .heavy:      return .heavy
        case .black:      return .black
        }
    }
}

/// Tri-state used by group header eye toggles where children may disagree.
enum LayerGroupVisibility {
    case off    // all child layers hidden
    case mixed  // some children hidden, some visible
    case on     // all child layers visible
}

extension IconSettings {
    static let minExportSize: CGFloat = 16
    static let maxExportSize: CGFloat = 1024
    static let defaultExportSize: CGFloat = 512
    static let manualSymbolScaleRange: ClosedRange<Double> = 0.3...2.0
    static let badgeOffsetRange: ClosedRange<Double> = -1.0...1.0
    static let importedImageScaleRange: ClosedRange<Double> = 0.3...2.0

    var isExportSizeValid: Bool {
        (Self.minExportSize...Self.maxExportSize).contains(exportSize)
    }
}
