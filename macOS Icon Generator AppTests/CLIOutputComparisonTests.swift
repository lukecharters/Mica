// CLIOutputComparisonTests.swift - Tests ensuring CLI output matches GUI output
import Testing
import SwiftUI
import AppKit
@testable import macOS_Icon_Generator_App

@MainActor
struct CLIOutputComparisonTests {
    
    // MARK: - CLI vs GUI Output Comparison Tests
    
    @Test
    func cliOutputMatchesGUIBasicMonochrome() async throws {
        // Generate icon via GUI path
        let guiSettings = CLITestConfigurations.basicMonochromeSettings()
        let guiImage = IconRenderer.renderIconSafely(settings: guiSettings)
        
        // Generate same icon via CLI path
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", "/tmp/cli-gui-comparison-mono.png",
            "--base-color", "blue",
            "--rendering-mode", "monochrome",
            "--symbol-color", "white"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        let cliSettings = try generator.buildTestSettings(from: command)
        let cliImage = IconRenderer.renderIconSafely(settings: cliSettings)
        
        // Compare image properties
        #expect(guiImage.size == cliImage.size, "Image sizes should match")
        #expect(abs(guiImage.size.width - cliImage.size.width) < 0.1, "Image widths should be nearly identical")
        #expect(abs(guiImage.size.height - cliImage.size.height) < 0.1, "Image heights should be nearly identical")
        
        // Verify both images have valid content
        #expect(guiImage.tiffRepresentation != nil, "GUI image should have valid TIFF representation")
        #expect(cliImage.tiffRepresentation != nil, "CLI image should have valid TIFF representation")
    }
    
    @Test
    func cliOutputMatchesGUIHierarchical() async throws {
        // Generate icon via GUI path
        let guiSettings = CLITestConfigurations.hierarchicalRenderingSettings()
        let guiImage = IconRenderer.renderIconSafely(settings: guiSettings)
        
        // Generate same icon via CLI path
        let command = try IconGeneratorCommand.parseAsRoot([
            "folder.fill",
            "--output", "/tmp/cli-gui-comparison-hier.png",
            "--size", "512",
            "--base-color", "green",
            "--rendering-mode", "hierarchical",
            "--hierarchical-color", "white"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        let cliSettings = try generator.buildTestSettings(from: command)
        let cliImage = IconRenderer.renderIconSafely(settings: cliSettings)
        
        // Compare settings
        #expect(guiSettings.symbolName == cliSettings.symbolName)
        #expect(guiSettings.exportSize == cliSettings.exportSize)
        #expect(guiSettings.symbolRenderingMode == cliSettings.symbolRenderingMode)
        
        // Compare image properties
        #expect(guiImage.size == cliImage.size, "Hierarchical rendering should produce same size images")
    }
    
    @Test
    func cliOutputMatchesGUIPaletteMode() async throws {
        // Generate icon via GUI path
        let guiSettings = CLITestConfigurations.paletteModeSettings()
        let guiImage = IconRenderer.renderIconSafely(settings: guiSettings)
        
        // Generate same icon via CLI path
        let command = try IconGeneratorCommand.parseAsRoot([
            "person.3.fill",
            "--output", "/tmp/cli-gui-comparison-palette.png",
            "--base-color", "orange",
            "--rendering-mode", "palette",
            "--palette-primary", "white",
            "--palette-secondary", "blue:0.7",
            "--palette-tertiary", "green:0.3"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        let cliSettings = try generator.buildTestSettings(from: command)
        let cliImage = IconRenderer.renderIconSafely(settings: cliSettings)
        
        // Verify palette colors are parsed correctly
        #expect(cliSettings.symbolRenderingMode == .palette)
        #expect(cliSettings.paletteSymbolPrimaryColor != .clear)
        #expect(cliSettings.paletteSymbolSecondaryColor != .clear)
        #expect(cliSettings.paletteSymbolTertiaryColor != .clear)
        
        // Compare image outputs
        #expect(guiImage.size == cliImage.size)
    }
    
    @Test
    func cliOutputMatchesGUIWithBadge() async throws {
        // Generate icon with badge via GUI path
        let guiSettings = CLITestConfigurations.basicBadgeSettings()
        let guiImage = IconRenderer.renderIconSafely(settings: guiSettings)
        
        // Generate same icon via CLI path
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", "/tmp/cli-gui-comparison-badge.png",
            "--base-color", "blue",
            "--badge", "gearshape.fill",
            "--badge-position", "bottom-right",
            "--badge-color", "gray",
            "--badge-symbol-color", "white"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        let cliSettings = try generator.buildTestSettings(from: command)
        let cliImage = IconRenderer.renderIconSafely(settings: cliSettings)
        
        // Verify badge settings
        #expect(cliSettings.showBadge == guiSettings.showBadge)
        #expect(cliSettings.badgeSymbolName == guiSettings.badgeSymbolName)
        #expect(cliSettings.badgePosition == guiSettings.badgePosition)
        
        // Compare outputs
        #expect(guiImage.size == cliImage.size, "Badge icons should have same dimensions")
    }
    
    @Test
    func cliOutputMatchesGUICustomColors() async throws {
        // Generate icon with custom colors via GUI path
        let guiSettings = CLITestConfigurations.customGradientSettings()
        let guiImage = IconRenderer.renderIconSafely(settings: guiSettings)
        
        // Generate same icon via CLI path
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", "/tmp/cli-gui-comparison-custom.png",
            "--use-custom-colors",
            "--custom-primary", "red",
            "--custom-secondary", "orange"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        let cliSettings = try generator.buildTestSettings(from: command)
        let cliImage = IconRenderer.renderIconSafely(settings: cliSettings)
        
        // Verify custom color settings
        #expect(cliSettings.useCustomColors == true)
        #expect(cliSettings.useCustomColors == guiSettings.useCustomColors)
        
        // Compare outputs
        #expect(guiImage.size == cliImage.size)
    }
    
    @Test
    func cliOutputMatchesGUIShadowVariations() async throws {
        let shadowConfigs = [
            (gui: CLITestConfigurations.noShadowsSettings(), 
             cli: ["star.fill", "--no-background-shadow", "--no-symbol-shadow"]),
            (gui: CLITestConfigurations.backgroundShadowOnlySettings(),
             cli: ["star.fill", "--no-symbol-shadow"]),
            (gui: CLITestConfigurations.allShadowsSettings(),
             cli: ["star.fill"]) // Default has all shadows
        ]
        
        for (index, config) in shadowConfigs.enumerated() {
            // Generate via GUI
            let guiImage = IconRenderer.renderIconSafely(settings: config.gui)
            
            // Generate via CLI
            var cliArgs = config.cli
            cliArgs.append("--output")
            cliArgs.append("/tmp/cli-gui-shadow-\(index).png")
            
            let command = try IconGeneratorCommand.parseAsRoot(cliArgs) as! IconGeneratorCommand
            let generator = IconGeneratorCLI()
            let cliSettings = try generator.buildTestSettings(from: command)
            let cliImage = IconRenderer.renderIconSafely(settings: cliSettings)
            
            // Verify shadow settings match
            #expect(cliSettings.enableBackgroundShadow == config.gui.enableBackgroundShadow,
                   "Background shadow setting should match for config \(index)")
            #expect(cliSettings.enableSymbolShadow == config.gui.enableSymbolShadow,
                   "Symbol shadow setting should match for config \(index)")
            
            // Verify output dimensions match
            #expect(guiImage.size == cliImage.size, "Shadow config \(index) should produce same size")
        }
    }
    
    @Test
    func cliOutputMatchesGUIAllSizes() async throws {
        let sizes = [128, 256, 512, 1024]
        
        for size in sizes {
            // Generate via GUI
            var guiSettings = CLITestConfigurations.basicMonochromeSettings()
            guiSettings.exportSize = CGFloat(size)
            let guiImage = IconRenderer.renderIconSafely(settings: guiSettings)
            
            // Generate via CLI
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill",
                "--output", "/tmp/cli-gui-size-\(size).png",
                "--size", "\(size)"
            ]) as! IconGeneratorCommand
            
            let generator = IconGeneratorCLI()
            let cliSettings = try generator.buildTestSettings(from: command)
            let cliImage = IconRenderer.renderIconSafely(settings: cliSettings)
            
            // Verify size settings
            #expect(cliSettings.exportSize == guiSettings.exportSize, "Size \(size) should match")
            #expect(Int(guiImage.size.width) == size, "GUI image should be \(size)x\(size)")
            #expect(Int(cliImage.size.width) == size, "CLI image should be \(size)x\(size)")
            #expect(guiImage.size == cliImage.size, "GUI and CLI sizes should match for \(size)")
        }
    }
    
    @Test
    func cliOutputMatchesGUIRetinaExport() async throws {
        // Generate retina via GUI
        var guiSettings = CLITestConfigurations.basicMonochromeSettings()
        guiSettings.exportSize = 512
        guiSettings.exportRetinaSize = true
        let guiImage = IconRenderer.renderIconSafely(settings: guiSettings)
        
        // Generate retina via CLI
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", "/tmp/cli-gui-retina.png",
            "--size", "512",
            "--retina"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        let cliSettings = try generator.buildTestSettings(from: command)
        let cliImage = IconRenderer.renderIconSafely(settings: cliSettings)
        
        // Verify retina settings
        #expect(cliSettings.exportRetinaSize == true)
        #expect(cliSettings.exportRetinaSize == guiSettings.exportRetinaSize)
        
        // Verify logical size is same but pixel dimensions should be 2x
        #expect(guiImage.size == cliImage.size, "Logical size should match")
        #expect(guiImage.size.width == 512, "Logical width should be 512")
        
        // Verify actual pixel dimensions for retina
        if let guiTiff = guiImage.tiffRepresentation,
           let guiRep = NSBitmapImageRep(data: guiTiff),
           let cliTiff = cliImage.tiffRepresentation,
           let cliRep = NSBitmapImageRep(data: cliTiff) {
            #expect(guiRep.pixelsWide == 1024, "GUI retina should have 1024 pixel width")
            #expect(cliRep.pixelsWide == 1024, "CLI retina should have 1024 pixel width")
            #expect(guiRep.pixelsWide == cliRep.pixelsWide, "Pixel widths should match")
        }
    }
    
    @Test
    func cliOutputMatchesGUIMaximalComplexity() async throws {
        // Generate maximal complexity via GUI
        let guiSettings = CLITestConfigurations.maximalComplexitySettings()
        let guiImage = IconRenderer.renderIconSafely(settings: guiSettings)
        
        // Generate maximal complexity via CLI
        let command = try IconGeneratorCommand.parseAsRoot([
            "app.fill",
            "--output", "/tmp/cli-gui-maximal.png",
            "--size", "1024",
            "--retina",
            "--color-space", "displayP3",
            "--use-custom-colors",
            "--custom-primary", "#FF6B35",
            "--custom-secondary", "hsl(200,80%,60%)",
            "--rendering-mode", "palette",
            "--palette-primary", "white",
            "--palette-secondary", "turquoise:0.8",
            "--palette-tertiary", "coral:0.4",
            "--badge", "gearshape.fill",
            "--badge-position", "top-right",
            "--badge-use-custom",
            "--badge-primary", "gold",
            "--badge-secondary", "orange",
            "--badge-rendering", "hierarchical"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        let cliSettings = try generator.buildTestSettings(from: command)
        let cliImage = IconRenderer.renderIconSafely(settings: cliSettings)
        
        // Verify all complex settings match
        #expect(cliSettings.symbolName == guiSettings.symbolName)
        #expect(cliSettings.exportSize == guiSettings.exportSize)
        #expect(cliSettings.exportRetinaSize == guiSettings.exportRetinaSize)
        #expect(cliSettings.exportColorSpace == guiSettings.exportColorSpace)
        #expect(cliSettings.useCustomColors == guiSettings.useCustomColors)
        #expect(cliSettings.symbolRenderingMode == guiSettings.symbolRenderingMode)
        #expect(cliSettings.showBadge == guiSettings.showBadge)
        #expect(cliSettings.badgePosition == guiSettings.badgePosition)
        #expect(cliSettings.badgeUseCustomColors == guiSettings.badgeUseCustomColors)
        #expect(cliSettings.badgeSymbolRenderingMode == guiSettings.badgeSymbolRenderingMode)
        
        // Verify output dimensions
        #expect(guiImage.size == cliImage.size, "Complex icons should have matching dimensions")
        #expect(guiImage.size.width == 1024, "Complex icon should be 1024x1024 logical size")
    }
}
