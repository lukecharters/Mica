// CLISettingsBuilderTests.swift - Unit tests for CLI to IconSettings conversion
import Testing
import SwiftUI
@testable import macOS_Icon_Generator_App

struct CLISettingsBuilderTests {
    
    // MARK: - Basic Settings Builder Tests
    
    @Test
    func buildBasicSettings() throws {
        // Test basic settings conversion
        let command = try createMockCommand(symbolName: "star.fill")
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.symbolName == "star.fill")
        #expect(settings.exportSize == 256)
        #expect(settings.exportRetinaSize == false)
        #expect(settings.exportColorSpace == .sRGB)
        #expect(settings.baseColor == .blue)
        #expect(settings.symbolRenderingMode == .monochrome)
        #expect(settings.symbolColor == .white)
    }
    
    @Test
    func buildCustomSizeSettings() throws {
        let command = try createMockCommand(
            symbolName: "folder.fill",
            size: 512,
            retina: true
        )
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.symbolName == "folder.fill")
        #expect(settings.exportSize == 512)
        #expect(settings.exportRetinaSize == true)
    }
    
    @Test
    func buildColorSpaceSettings() throws {
        let command = try createMockCommand(
            symbolName: "heart.fill",
            colorSpace: "displayP3"
        )
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.exportColorSpace == .displayP3)
    }
    
    // MARK: - Color Configuration Tests
    
    @Test
    func buildCustomColorSettings() throws {
        let command = try createMockCommand(
            symbolName: "app.fill",
            baseColor: "red",
            useCustomColors: true,
            customPrimary: "#FF6B35",
            customSecondary: "#F7931E"
        )
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.baseColor == .red)
        #expect(settings.useCustomColors == true)
        
        // Verify custom colors are parsed correctly
        let expectedPrimary = Color(red: 1.0, green: 0.42, blue: 0.21)
        let expectedSecondary = Color(red: 0.97, green: 0.57, blue: 0.12)
        
        #expect(settings.customPrimaryColor != .clear)
        #expect(settings.customSecondaryColor != .clear)
    }
    
    @Test
    func buildMonochromeRenderingSettings() throws {
        let command = try createMockCommand(
            symbolName: "star.fill",
            renderingMode: "monochrome",
            symbolColor: "yellow"
        )
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.symbolRenderingMode == .monochrome)
        #expect(settings.symbolColor == .yellow)
    }
    
    @Test
    func buildHierarchicalRenderingSettings() throws {
        let command = try createMockCommand(
            symbolName: "folder.fill",
            renderingMode: "hierarchical",
            hierarchicalColor: "white"
        )
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.symbolRenderingMode == .hierarchical)
        #expect(settings.hierarchicalSymbolColor == .white)
    }
    
    @Test
    func buildPaletteRenderingSettings() throws {
        let command = try createMockCommand(
            symbolName: "person.3.fill",
            renderingMode: "palette",
            palettePrimary: "white",
            paletteSecondary: "blue:0.7",
            paletteTertiary: "green:0.3"
        )
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.symbolRenderingMode == .palette)
        #expect(settings.paletteSymbolPrimaryColor == .white)
        // Colors with opacity should be parsed correctly
        #expect(settings.paletteSymbolSecondaryColor != .clear)
        #expect(settings.paletteSymbolTertiaryColor != .clear)
    }
    
    // MARK: - Shadow Configuration Tests
    
    @Test
    func buildShadowSettings() throws {
        // Test shadows enabled (default)
        let enabledCommand = try createMockCommand(symbolName: "star.fill")
        let enabledSettings = try IconGeneratorCLI.buildIconSettings(from: enabledCommand)
        
        #expect(enabledSettings.enableBackgroundShadow == true)
        #expect(enabledSettings.enableSymbolShadow == true)
        
        // Test shadows disabled
        let disabledCommand = try createMockCommand(
            symbolName: "star.fill",
            noBackgroundShadow: true,
            noSymbolShadow: true
        )
        let disabledSettings = try IconGeneratorCLI.buildIconSettings(from: disabledCommand)
        
        #expect(disabledSettings.enableBackgroundShadow == false)
        #expect(disabledSettings.enableSymbolShadow == false)
    }
    
    @Test
    func buildMixedShadowSettings() throws {
        // Test background shadow only
        let bgOnlyCommand = try createMockCommand(
            symbolName: "star.fill",
            noSymbolShadow: true
        )
        let bgOnlySettings = try IconGeneratorCLI.buildIconSettings(from: bgOnlyCommand)
        
        #expect(bgOnlySettings.enableBackgroundShadow == true)
        #expect(bgOnlySettings.enableSymbolShadow == false)
        
        // Test symbol shadow only
        let symbolOnlyCommand = try createMockCommand(
            symbolName: "star.fill",
            noBackgroundShadow: true
        )
        let symbolOnlySettings = try IconGeneratorCLI.buildIconSettings(from: symbolOnlyCommand)
        
        #expect(symbolOnlySettings.enableBackgroundShadow == false)
        #expect(symbolOnlySettings.enableSymbolShadow == true)
    }
    
    // MARK: - Badge Configuration Tests
    
    @Test
    func buildBasicBadgeSettings() throws {
        let command = try createMockCommand(
            symbolName: "star.fill",
            badge: "gearshape.fill",
            badgePosition: "bottom-right",
            badgeColor: "gray"
        )
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.showBadge == true)
        #expect(settings.badgeSymbolName == "gearshape.fill")
        #expect(settings.badgePosition == .bottomRight)
        #expect(settings.badgeBaseColor == .gray)
    }
    
    @Test
    func buildCustomBadgeSettings() throws {
        let command = try createMockCommand(
            symbolName: "star.fill",
            badge: "plus.circle",
            badgePosition: "top-right",
            badgeUseCustom: true,
            badgePrimary: "yellow",
            badgeSecondary: "orange",
            badgeRendering: "hierarchical",
            badgeSymbolColor: "white"
        )
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.showBadge == true)
        #expect(settings.badgeSymbolName == "plus.circle")
        #expect(settings.badgePosition == .topRight)
        #expect(settings.badgeUseCustomColors == true)
        #expect(settings.badgeCustomPrimaryColor == .yellow)
        #expect(settings.badgeCustomSecondaryColor == .orange)
        #expect(settings.badgeSymbolRenderingMode == .hierarchical)
        #expect(settings.badgeHierarchicalSymbolColor == .white)
    }
    
    @Test
    func buildAllBadgePositions() throws {
        let positions = [
            ("top-left", BadgePosition.topLeft),
            ("top-right", BadgePosition.topRight),
            ("bottom-left", BadgePosition.bottomLeft),
            ("bottom-right", BadgePosition.bottomRight)
        ]
        
        for (positionString, expectedPosition) in positions {
            let command = try createMockCommand(
                symbolName: "star.fill",
                badge: "checkmark",
                badgePosition: positionString
            )
            let settings = try IconGeneratorCLI.buildIconSettings(from: command)
            
            #expect(settings.badgePosition == expectedPosition, "Position \(positionString) should map to \(expectedPosition)")
        }
    }
    
    // MARK: - Complex Settings Tests
    
    @Test
    func buildMaximalComplexitySettings() throws {
        let command = try createMockCommand(
            symbolName: "app.fill",
            size: 1024,
            retina: true,
            colorSpace: "displayP3",
            baseColor: "red",
            useCustomColors: true,
            customPrimary: "#FF6B35",
            customSecondary: "#F7931E",
            renderingMode: "palette",
            palettePrimary: "white",
            paletteSecondary: "blue:0.8",
            paletteTertiary: "green:0.4",
            noBackgroundShadow: false,
            noSymbolShadow: false,
            badge: "gearshape.fill",
            badgePosition: "top-right",
            badgeUseCustom: true,
            badgePrimary: "gold",
            badgeSecondary: "orange",
            badgeRendering: "hierarchical",
            badgeSymbolColor: "white"
        )
        
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        // Verify all settings are applied correctly
        #expect(settings.symbolName == "app.fill")
        #expect(settings.exportSize == 1024)
        #expect(settings.exportRetinaSize == true)
        #expect(settings.exportColorSpace == .displayP3)
        #expect(settings.baseColor == .red)
        #expect(settings.useCustomColors == true)
        #expect(settings.symbolRenderingMode == .palette)
        #expect(settings.enableBackgroundShadow == true)
        #expect(settings.enableSymbolShadow == true)
        #expect(settings.showBadge == true)
        #expect(settings.badgePosition == .topRight)
        #expect(settings.badgeUseCustomColors == true)
        #expect(settings.badgeSymbolRenderingMode == .hierarchical)
    }
    
    // MARK: - Default Value Tests
    
    @Test
    func verifyDefaultValues() throws {
        let command = try createMockCommand(symbolName: "star.fill")
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        // Verify defaults match IconSettings defaults
        let defaultSettings = IconSettings()
        
        #expect(settings.exportSize == defaultSettings.exportSize)
        #expect(settings.exportRetinaSize == defaultSettings.exportRetinaSize)
        #expect(settings.exportColorSpace == defaultSettings.exportColorSpace)
        #expect(settings.baseColor == defaultSettings.baseColor)
        #expect(settings.symbolRenderingMode == defaultSettings.symbolRenderingMode)
        #expect(settings.symbolColor == defaultSettings.symbolColor)
        #expect(settings.enableBackgroundShadow == defaultSettings.enableBackgroundShadow)
        #expect(settings.enableSymbolShadow == defaultSettings.enableSymbolShadow)
        #expect(settings.showBadge == defaultSettings.showBadge)
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func invalidColorThrowsError() throws {
        let command = try createMockCommand(
            symbolName: "star.fill",
            baseColor: "invalid-color"
        )
        
        #expect(throws: (any Error).self) {
            try IconGeneratorCLI.buildIconSettings(from: command)
        }
    }
    
    @Test
    func invalidRenderingModeThrowsError() throws {
        let command = try createMockCommand(
            symbolName: "star.fill",
            renderingMode: "invalid-mode"
        )
        
        #expect(throws: (any Error).self) {
            try IconGeneratorCLI.buildIconSettings(from: command)
        }
    }
    
    @Test
    func invalidColorSpaceThrowsError() throws {
        let command = try createMockCommand(
            symbolName: "star.fill",
            colorSpace: "invalid-space"
        )
        
        #expect(throws: (any Error).self) {
            try IconGeneratorCLI.buildIconSettings(from: command)
        }
    }
}

// MARK: - Test Helpers

extension CLISettingsBuilderTests {
    
    /// Creates a mock command for testing
    func createMockCommand(
        symbolName: String,
        size: Int? = nil,
        retina: Bool? = nil,
        colorSpace: String? = nil,
        baseColor: String? = nil,
        useCustomColors: Bool? = nil,
        customPrimary: String? = nil,
        customSecondary: String? = nil,
        renderingMode: String? = nil,
        symbolColor: String? = nil,
        hierarchicalColor: String? = nil,
        palettePrimary: String? = nil,
        paletteSecondary: String? = nil,
        paletteTertiary: String? = nil,
        noBackgroundShadow: Bool? = nil,
        noSymbolShadow: Bool? = nil,
        badge: String? = nil,
        badgePosition: String? = nil,
        badgeColor: String? = nil,
        badgeUseCustom: Bool? = nil,
        badgePrimary: String? = nil,
        badgeSecondary: String? = nil,
        badgeRendering: String? = nil,
        badgeSymbolColor: String? = nil
    ) throws -> IconGeneratorCommand {
        
        var args = [symbolName]
        
        if let size = size { args.append(contentsOf: ["--size", "\(size)"]) }
        if retina == true { args.append("--retina") }
        if let colorSpace = colorSpace { args.append(contentsOf: ["--color-space", colorSpace]) }
        if let baseColor = baseColor { args.append(contentsOf: ["--base-color", baseColor]) }
        if useCustomColors == true { args.append("--use-custom-colors") }
        if let customPrimary = customPrimary { args.append(contentsOf: ["--custom-primary", customPrimary]) }
        if let customSecondary = customSecondary { args.append(contentsOf: ["--custom-secondary", customSecondary]) }
        if let renderingMode = renderingMode { args.append(contentsOf: ["--rendering-mode", renderingMode]) }
        if let symbolColor = symbolColor { args.append(contentsOf: ["--symbol-color", symbolColor]) }
        if let hierarchicalColor = hierarchicalColor { args.append(contentsOf: ["--hierarchical-color", hierarchicalColor]) }
        if let palettePrimary = palettePrimary { args.append(contentsOf: ["--palette-primary", palettePrimary]) }
        if let paletteSecondary = paletteSecondary { args.append(contentsOf: ["--palette-secondary", paletteSecondary]) }
        if let paletteTertiary = paletteTertiary { args.append(contentsOf: ["--palette-tertiary", paletteTertiary]) }
        if noBackgroundShadow == true { args.append("--no-background-shadow") }
        if noSymbolShadow == true { args.append("--no-symbol-shadow") }
        if let badge = badge { args.append(contentsOf: ["--badge", badge]) }
        if let badgePosition = badgePosition { args.append(contentsOf: ["--badge-position", badgePosition]) }
        if let badgeColor = badgeColor { args.append(contentsOf: ["--badge-color", badgeColor]) }
        if badgeUseCustom == true { args.append("--badge-use-custom") }
        if let badgePrimary = badgePrimary { args.append(contentsOf: ["--badge-primary", badgePrimary]) }
        if let badgeSecondary = badgeSecondary { args.append(contentsOf: ["--badge-secondary", badgeSecondary]) }
        if let badgeRendering = badgeRendering { args.append(contentsOf: ["--badge-rendering", badgeRendering]) }
        if let badgeSymbolColor = badgeSymbolColor { args.append(contentsOf: ["--badge-symbol-color", badgeSymbolColor]) }
        
        return try IconGeneratorCommand.parseAsRoot(args) as! IconGeneratorCommand
    }
}
