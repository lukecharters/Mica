// CLIArgumentParsingTests.swift - Unit tests for argument parsing
import Testing
import ArgumentParser
@testable import macOS_Icon_Generator_App

struct CLIArgumentParsingTests {
    
    // MARK: - Basic Argument Tests
    
    @Test
    func parseBasicArguments() throws {
        // Test basic argument parsing
        let args = ["star.fill", "--output", "/tmp/test.png", "--size", "512", "--retina"]
        let command = try IconGeneratorCommand.parseAsRoot(args) as! IconGeneratorCommand
        
        #expect(command.symbolName == "star.fill")
        #expect(command.outputPath == "/tmp/test.png")
        #expect(command.size == 512)
        #expect(command.retina == true)
    }
    
    @Test
    func parseShortOptions() throws {
        // Test short option parsing
        let args = ["folder.fill", "-o", "/tmp/icon.png", "-s", "256"]
        let command = try IconGeneratorCommand.parseAsRoot(args) as! IconGeneratorCommand
        
        #expect(command.symbolName == "folder.fill")
        #expect(command.outputPath == "/tmp/icon.png")
        #expect(command.size == 256)
    }
    
    @Test
    func parseDefaultValues() throws {
        // Test that default values are properly set
        let args = ["heart.fill"]
        let command = try IconGeneratorCommand.parseAsRoot(args) as! IconGeneratorCommand
        
        #expect(command.symbolName == "heart.fill")
        #expect(command.outputPath == nil)
        #expect(command.size == 256)
        #expect(command.retina == false)
        #expect(command.colorSpace == "sRGB")
        #expect(command.baseColor == "blue")
        #expect(command.renderingMode == "monochrome")
    }
    
    // MARK: - Color Configuration Tests
    
    @Test
    func parseColorConfiguration() throws {
        let args = [
            "app.fill",
            "--base-color", "red",
            "--use-custom-colors",
            "--custom-primary", "#FF5733",
            "--custom-secondary", "blue"
        ]
        let command = try IconGeneratorCommand.parseAsRoot(args) as! IconGeneratorCommand
        
        #expect(command.baseColor == "red")
        #expect(command.useCustomColors == true)
        #expect(command.customPrimary == "#FF5733")
        #expect(command.customSecondary == "blue")
    }
    
    @Test
    func parseRenderingModes() throws {
        // Test monochrome mode
        let monoArgs = ["star.fill", "--rendering-mode", "monochrome", "--symbol-color", "white"]
        let monoCommand = try IconGeneratorCommand.parseAsRoot(monoArgs) as! IconGeneratorCommand
        #expect(monoCommand.renderingMode == "monochrome")
        #expect(monoCommand.symbolColor == "white")
        
        // Test palette mode
        let paletteArgs = [
            "person.3.fill",
            "--rendering-mode", "palette",
            "--palette-primary", "white",
            "--palette-secondary", "blue:0.7",
            "--palette-tertiary", "green:0.3"
        ]
        let paletteCommand = try IconGeneratorCommand.parseAsRoot(paletteArgs) as! IconGeneratorCommand
        #expect(paletteCommand.renderingMode == "palette")
        #expect(paletteCommand.palettePrimary == "white")
        #expect(paletteCommand.paletteSecondary == "blue:0.7")
        #expect(paletteCommand.paletteTertiary == "green:0.3")
    }
    
    @Test
    func parseShadowConfiguration() throws {
        let args = ["circle", "--no-background-shadow", "--no-symbol-shadow"]
        let command = try IconGeneratorCommand.parseAsRoot(args) as! IconGeneratorCommand
        
        #expect(command.noBackgroundShadow == true)
        #expect(command.noSymbolShadow == true)
    }
    
    @Test
    func parseBadgeConfiguration() throws {
        let args = [
            "star.fill",
            "--badge", "gearshape.fill",
            "--badge-position", "top-right",
            "--badge-color", "red",
            "--badge-use-custom",
            "--badge-primary", "yellow",
            "--badge-secondary", "orange",
            "--badge-rendering", "hierarchical",
            "--badge-symbol-color", "white"
        ]
        let command = try IconGeneratorCommand.parseAsRoot(args) as! IconGeneratorCommand
        
        #expect(command.badge == "gearshape.fill")
        #expect(command.badgePosition == "top-right")
        #expect(command.badgeColor == "red")
        #expect(command.badgeUseCustom == true)
        #expect(command.badgePrimary == "yellow")
        #expect(command.badgeSecondary == "orange")
        #expect(command.badgeRendering == "hierarchical")
        #expect(command.badgeSymbolColor == "white")
    }
    
    // MARK: - Validation Tests
    
    @Test
    func validateInvalidSize() throws {
        let args = ["star.fill", "--size", "999"]
        
        #expect(throws: (any Error).self) {
            try IconGeneratorCommand.parseAsRoot(args)
        }
    }
    
    @Test
    func validateInvalidColorSpace() throws {
        let args = ["star.fill", "--color-space", "invalid"]
        
        #expect(throws: (any Error).self) {
            try IconGeneratorCommand.parseAsRoot(args)
        }
    }
    
    @Test
    func validateInvalidRenderingMode() throws {
        let args = ["star.fill", "--rendering-mode", "invalid"]
        
        #expect(throws: (any Error).self) {
            try IconGeneratorCommand.parseAsRoot(args)
        }
    }
    
    @Test
    func validateInvalidBadgePosition() throws {
        let args = ["star.fill", "--badge", "plus", "--badge-position", "invalid"]
        
        #expect(throws: (any Error).self) {
            try IconGeneratorCommand.parseAsRoot(args)
        }
    }
    
    // MARK: - Complex Configuration Tests
    
    @Test
    func parseComplexConfiguration() throws {
        let args = [
            "app.fill",
            "--output", "/tmp/complex-icon.png",
            "--size", "1024",
            "--retina",
            "--color-space", "displayP3",
            "--use-custom-colors",
            "--custom-primary", "#FF6B35",
            "--custom-secondary", "hsl(200,80%,60%)",
            "--rendering-mode", "palette",
            "--palette-primary", "white",
            "--palette-secondary", "blue:0.8",
            "--palette-tertiary", "green:0.4",
            "--badge", "gearshape.fill",
            "--badge-position", "bottom-right",
            "--badge-use-custom",
            "--badge-primary", "gold",
            "--badge-secondary", "orange",
            "--no-background-shadow"
        ]
        
        let command = try IconGeneratorCommand.parseAsRoot(args) as! IconGeneratorCommand
        
        // Verify all arguments are parsed correctly
        #expect(command.symbolName == "app.fill")
        #expect(command.outputPath == "/tmp/complex-icon.png")
        #expect(command.size == 1024)
        #expect(command.retina == true)
        #expect(command.colorSpace == "displayP3")
        #expect(command.useCustomColors == true)
        #expect(command.customPrimary == "#FF6B35")
        #expect(command.customSecondary == "hsl(200,80%,60%)")
        #expect(command.renderingMode == "palette")
        #expect(command.badge == "gearshape.fill")
        #expect(command.badgePosition == "bottom-right")
        #expect(command.noBackgroundShadow == true)
        #expect(command.noSymbolShadow == false)
    }
}
