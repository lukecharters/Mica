// CLITestConfigurations.swift - Test configurations reused from IconExportTests
import Testing
import SwiftUI
@testable import macOS_Icon_Generator_App

struct CLITestConfigurations {
    
    // MARK: - Basic Test Configurations
    
    static func basicMonochromeSettings() -> IconSettings {
        var settings = IconSettings()
        settings.symbolName = "star.fill"
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.baseColor = .blue
        settings.symbolRenderingMode = .monochrome
        settings.symbolColor = .white
        return settings
    }
    
    static func hierarchicalRenderingSettings() -> IconSettings {
        var settings = IconSettings()
        settings.symbolName = "folder.fill"
        settings.exportSize = 512
        settings.exportRetinaSize = false
        settings.baseColor = .green
        settings.symbolRenderingMode = .hierarchical
        settings.hierarchicalSymbolColor = .white
        return settings
    }
    
    static func multicolorSymbolSettings() -> IconSettings {
        var settings = IconSettings()
        settings.symbolName = "rainbow"
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.baseColor = .purple
        settings.symbolRenderingMode = .multicolor
        return settings
    }
    
    static func paletteModeSettings() -> IconSettings {
        var settings = IconSettings()
        settings.symbolName = "person.3.fill"
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.baseColor = .orange
        settings.symbolRenderingMode = .palette
        settings.paletteSymbolPrimaryColor = .white
        settings.paletteSymbolSecondaryColor = .blue.opacity(0.7)
        settings.paletteSymbolTertiaryColor = .green.opacity(0.3)
        return settings
    }
    
    // MARK: - Badge Test Configurations
    
    static func basicBadgeSettings() -> IconSettings {
        var settings = basicMonochromeSettings()
        settings.showBadge = true
        settings.badgeSymbolName = "gearshape.fill"
        settings.badgePosition = .bottomRight
        settings.badgeBaseColor = .gray
        settings.badgeSymbolColor = .white
        settings.badgeSymbolRenderingMode = .monochrome
        return settings
    }
    
    static func customBadgeSettings() -> IconSettings {
        var settings = basicMonochromeSettings()
        settings.showBadge = true
        settings.badgeSymbolName = "plus.circle"
        settings.badgePosition = .topRight
        settings.badgeUseCustomColors = true
        settings.badgeCustomPrimaryColor = .yellow
        settings.badgeCustomSecondaryColor = .orange
        settings.badgeSymbolRenderingMode = .hierarchical
        settings.badgeHierarchicalSymbolColor = .white
        return settings
    }
    
    static func badgeAllPositionsSettings() -> [IconSettings] {
        let positions: [BadgePosition] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        return positions.map { position in
            var settings = basicBadgeSettings()
            settings.badgePosition = position
            settings.badgeSymbolName = "checkmark.circle"
            return settings
        }
    }
    
    // MARK: - Shadow Variation Configurations
    
    static func noShadowsSettings() -> IconSettings {
        var settings = basicMonochromeSettings()
        settings.enableBackgroundShadow = false
        settings.enableSymbolShadow = false
        return settings
    }
    
    static func backgroundShadowOnlySettings() -> IconSettings {
        var settings = basicMonochromeSettings()
        settings.enableBackgroundShadow = true
        settings.enableSymbolShadow = false
        return settings
    }
    
    static func symbolShadowOnlySettings() -> IconSettings {
        var settings = basicMonochromeSettings()
        settings.enableBackgroundShadow = false
        settings.enableSymbolShadow = true
        return settings
    }
    
    static func allShadowsSettings() -> IconSettings {
        var settings = basicMonochromeSettings()
        settings.enableBackgroundShadow = true
        settings.enableSymbolShadow = true
        return settings
    }
    
    // MARK: - Color Space and Quality Configurations
    
    static func sRGBSettings() -> IconSettings {
        var settings = basicMonochromeSettings()
        settings.exportColorSpace = .sRGB
        return settings
    }
    
    static func displayP3Settings() -> IconSettings {
        var settings = basicMonochromeSettings()
        settings.exportColorSpace = .displayP3
        return settings
    }
    
    static func retinaSettings() -> IconSettings {
        var settings = basicMonochromeSettings()
        settings.exportRetinaSize = true
        return settings
    }
    
    static func allSizesSettings() -> [IconSettings] {
        let sizes: [CGFloat] = [128, 256, 512, 1024]
        return sizes.map { size in
            var settings = basicMonochromeSettings()
            settings.exportSize = size
            return settings
        }
    }
    
    // MARK: - Custom Color Configurations
    
    static func customGradientSettings() -> IconSettings {
        var settings = basicMonochromeSettings()
        settings.useCustomColors = true
        settings.customPrimaryColor = .red
        settings.customSecondaryColor = .orange
        return settings
    }
    
    static func complexCustomColorsSettings() -> IconSettings {
        var settings = IconSettings()
        settings.symbolName = "app.fill"
        settings.exportSize = 512
        settings.useCustomColors = true
        settings.customPrimaryColor = Color(red: 1.0, green: 0.42, blue: 0.21) // #FF6B35
        settings.customSecondaryColor = Color(red: 0.97, green: 0.57, blue: 0.12) // #F7931E
        settings.symbolRenderingMode = .palette
        settings.paletteSymbolPrimaryColor = .white
        settings.paletteSymbolSecondaryColor = Color.blue.opacity(0.8)
        settings.paletteSymbolTertiaryColor = Color.green.opacity(0.4)
        return settings
    }
    
    // MARK: - Complex Integration Configurations
    
    static func maximalComplexitySettings() -> IconSettings {
        var settings = IconSettings()
        settings.symbolName = "app.fill"
        settings.exportSize = 1024
        settings.exportRetinaSize = true
        settings.exportColorSpace = .displayP3
        settings.useCustomColors = true
        settings.customPrimaryColor = Color(red: 1.0, green: 0.42, blue: 0.21)
        settings.customSecondaryColor = Color(hue: 0.55, saturation: 0.8, brightness: 0.6)
        settings.symbolRenderingMode = .palette
        settings.paletteSymbolPrimaryColor = .white
        settings.paletteSymbolSecondaryColor = Color(red: 0.25, green: 0.88, blue: 0.82).opacity(0.8)
        settings.paletteSymbolTertiaryColor = Color(red: 1.0, green: 0.5, blue: 0.31).opacity(0.4)
        settings.enableBackgroundShadow = true
        settings.enableSymbolShadow = true
        settings.showBadge = true
        settings.badgeSymbolName = "gearshape.fill"
        settings.badgePosition = .topRight
        settings.badgeUseCustomColors = true
        settings.badgeCustomPrimaryColor = Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        settings.badgeCustomSecondaryColor = Color(red: 1.0, green: 0.5, blue: 0.0) // Orange
        settings.badgeSymbolRenderingMode = .hierarchical
        settings.badgeHierarchicalSymbolColor = .white
        return settings
    }
    
    // MARK: - CLI-Specific Test Cases
    
    static func cliTestCases() -> [(name: String, command: [String], expectedSettings: IconSettings)] {
        return [
            (
                name: "Basic CLI",
                command: ["star.fill", "--output", "/tmp/test.png"],
                expectedSettings: basicMonochromeSettings()
            ),
            (
                name: "Custom Colors CLI",
                command: [
                    "folder.fill",
                    "--base-color", "red",
                    "--use-custom-colors",
                    "--custom-primary", "#FF6B35",
                    "--custom-secondary", "#F7931E"
                ],
                expectedSettings: {
                    var settings = IconSettings()
                    settings.symbolName = "folder.fill"
                    settings.baseColor = .red
                    settings.useCustomColors = true
                    settings.customPrimaryColor = Color(red: 1.0, green: 0.42, blue: 0.21)
                    settings.customSecondaryColor = Color(red: 0.97, green: 0.57, blue: 0.12)
                    return settings
                }()
            ),
            (
                name: "Palette Mode CLI",
                command: [
                    "person.3.fill",
                    "--rendering-mode", "palette",
                    "--palette-primary", "white",
                    "--palette-secondary", "blue:0.7",
                    "--palette-tertiary", "green:0.3"
                ],
                expectedSettings: paletteModeSettings()
            ),
            (
                name: "Badge CLI",
                command: [
                    "star.fill",
                    "--badge", "gearshape.fill",
                    "--badge-position", "bottom-right",
                    "--badge-color", "gray"
                ],
                expectedSettings: basicBadgeSettings()
            ),
            (
                name: "No Shadows CLI",
                command: [
                    "star.fill",
                    "--no-background-shadow",
                    "--no-symbol-shadow"
                ],
                expectedSettings: noShadowsSettings()
            )
        ]
    }
    
    // MARK: - Error Test Cases
    
    static func errorTestCases() -> [(name: String, command: [String], expectedError: Any.Type)] {
        return [
            (
                name: "Invalid Size",
                command: ["star.fill", "--size", "999"],
                expectedError: ValidationError.self
            ),
            (
                name: "Invalid Color Space",
                command: ["star.fill", "--color-space", "invalid"],
                expectedError: ValidationError.self
            ),
            (
                name: "Invalid Rendering Mode",
                command: ["star.fill", "--rendering-mode", "invalid"],
                expectedError: ValidationError.self
            ),
            (
                name: "Invalid Badge Position",
                command: ["star.fill", "--badge", "plus", "--badge-position", "invalid"],
                expectedError: ValidationError.self
            )
        ]
    }
}
