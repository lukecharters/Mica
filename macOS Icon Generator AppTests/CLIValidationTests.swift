// CLIValidationTests.swift - Unit tests for CLI argument validation and error handling
import Testing
import ArgumentParser
@testable import macOS_Icon_Generator_App

struct CLIValidationTests {
    
    // MARK: - Symbol Name Validation Tests
    
    @Test
    func validateValidSymbolNames() throws {
        let validSymbols = [
            "star.fill",
            "folder.fill.badge.plus",
            "person.3.fill",
            "app.fill",
            "gearshape.fill",
            "heart.circle",
            "square.and.arrow.up"
        ]
        
        for symbol in validSymbols {
            // Should not throw for valid symbols
            let command = try IconGeneratorCommand.parseAsRoot([symbol])
            #expect((command as! IconGeneratorCommand).symbolName == symbol)
        }
    }
    
    @Test
    func rejectEmptySymbolName() throws {
        #expect(throws: (any Error).self) {
            try IconGeneratorCommand.parseAsRoot([""])
        }
    }
    
    @Test
    func rejectWhitespaceOnlySymbolName() throws {
        #expect(throws: (any Error).self) {
            try IconGeneratorCommand.parseAsRoot(["   "])
        }
    }
    
    // MARK: - Size Validation Tests
    
    @Test
    func acceptValidSizes() throws {
        let validSizes = [128, 256, 512, 1024]
        
        for size in validSizes {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--size", "\(size)"
            ]) as! IconGeneratorCommand
            
            #expect(command.size == size)
        }
    }
    
    @Test
    func rejectInvalidSizes() throws {
        let invalidSizes = [64, 100, 300, 2048, 0, -1]
        
        for size in invalidSizes {
            #expect(throws: (any Error).self) {
                try IconGeneratorCommand.parseAsRoot([
                    "star.fill", "--size", "\(size)"
                ])
            }
        }
    }
    
    @Test
    func rejectNonNumericSize() throws {
        #expect(throws: (any Error).self) {
            try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--size", "large"
            ])
        }
    }
    
    // MARK: - Color Space Validation Tests
    
    @Test
    func acceptValidColorSpaces() throws {
        let validSpaces = ["sRGB", "displayP3"]
        
        for space in validSpaces {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--color-space", space
            ]) as! IconGeneratorCommand
            
            #expect(command.colorSpace == space)
        }
    }
    
    @Test
    func rejectInvalidColorSpaces() throws {
        let invalidSpaces = ["RGB", "P3", "CMYK", "invalid"]
        
        for space in invalidSpaces {
            #expect(throws: (any Error).self) {
                try IconGeneratorCommand.parseAsRoot([
                    "star.fill", "--color-space", space
                ])
            }
        }
    }
    
    @Test
    func acceptCaseInsensitiveColorSpaces() throws {
        let caseVariations = ["srgb", "SRGB", "displayp3", "DISPLAYP3"]
        
        for variation in caseVariations {
            // Should normalize to standard case
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--color-space", variation
            ]) as! IconGeneratorCommand
            
            #expect(command.colorSpace.lowercased() == variation.lowercased())
        }
    }
    
    // MARK: - Rendering Mode Validation Tests
    
    @Test
    func acceptValidRenderingModes() throws {
        let validModes = ["monochrome", "hierarchical", "multicolor", "palette"]
        
        for mode in validModes {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--rendering-mode", mode
            ]) as! IconGeneratorCommand
            
            #expect(command.renderingMode == mode)
        }
    }
    
    @Test
    func rejectInvalidRenderingModes() throws {
        let invalidModes = ["mono", "hierarchy", "multi", "invalid", ""]
        
        for mode in invalidModes {
            #expect(throws: (any Error).self) {
                try IconGeneratorCommand.parseAsRoot([
                    "star.fill", "--rendering-mode", mode
                ])
            }
        }
    }
    
    // MARK: - Badge Position Validation Tests
    
    @Test
    func acceptValidBadgePositions() throws {
        let validPositions = ["top-left", "top-right", "bottom-left", "bottom-right"]
        
        for position in validPositions {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--badge", "gearshape.fill", "--badge-position", position
            ]) as! IconGeneratorCommand
            
            #expect(command.badgePosition == position)
        }
    }
    
    @Test
    func rejectInvalidBadgePositions() throws {
        let invalidPositions = ["left", "right", "top", "bottom", "center", "middle", ""]
        
        for position in invalidPositions {
            #expect(throws: (any Error).self) {
                try IconGeneratorCommand.parseAsRoot([
                    "star.fill", "--badge", "gearshape.fill", "--badge-position", position
                ])
            }
        }
    }
    
    // MARK: - Color Validation Tests
    
    @Test
    func acceptValidColors() throws {
        let validColors = [
            "blue", "red", "green", "white", "black",
            "#FF0000", "#00FF00", "#0000FF",
            "rgb(255,0,0)", "rgba(255,0,0,0.5)",
            "hsl(120,100%,50%)", "hsla(240,100%,50%,0.8)",
            "crimson", "turquoise", "gold"
        ]
        
        for color in validColors {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--base-color", color
            ]) as! IconGeneratorCommand
            
            #expect(command.baseColor == color)
        }
    }
    
    @Test
    func rejectInvalidColors() throws {
        let invalidColors = [
            "#GGG", "#FF", "#FFFFFFF", 
            "rgb(300,0,0)", "rgb(255)",
            "hsl(400,100%,50%)", "hsl(240,150%,50%)",
            "nonexistent-color", ""
        ]
        
        for color in invalidColors {
            // Note: Color validation happens during settings building, not argument parsing
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--base-color", color
            ]) as! IconGeneratorCommand
            
            // The command should parse successfully, but settings building should fail
            #expect(throws: (any Error).self) {
                try IconGeneratorCLI.buildIconSettings(from: command)
            }
        }
    }
    
    // MARK: - Opacity Validation Tests
    
    @Test
    func acceptValidOpacityValues() throws {
        let validOpacities = ["0.0", "0.5", "1.0", "0.25", "0.75"]
        
        for opacity in validOpacities {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--palette-secondary", "blue:\(opacity)"
            ]) as! IconGeneratorCommand
            
            // Should parse successfully and build settings
            let settings = try IconGeneratorCLI.buildIconSettings(from: command)
            #expect(settings.paletteSymbolSecondaryColor != .clear)
        }
    }
    
    @Test
    func rejectInvalidOpacityValues() throws {
        let invalidOpacities = ["1.5", "-0.5", "2.0", "abc", ""]
        
        for opacity in invalidOpacities {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--palette-secondary", "blue:\(opacity)"
            ]) as! IconGeneratorCommand
            
            // Should fail during settings building
            #expect(throws: (any Error).self) {
                try IconGeneratorCLI.buildIconSettings(from: command)
            }
        }
    }
    
    // MARK: - Badge Dependency Validation Tests
    
    @Test
    func requireBadgeForBadgeOptions() throws {
        // Badge position without badge symbol should be ignored or cause validation error
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill", "--badge-position", "top-right"
        ]) as! IconGeneratorCommand
        
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        // Without badge symbol, badge should not be shown
        #expect(settings.showBadge == false)
    }
    
    @Test
    func enableBadgeWithValidSymbol() throws {
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill", "--badge", "gearshape.fill"
        ]) as! IconGeneratorCommand
        
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.showBadge == true)
        #expect(settings.badgeSymbolName == "gearshape.fill")
    }
    
    // MARK: - Custom Color Dependency Validation Tests
    
    @Test
    func ignoreCustomColorsWithoutFlag() throws {
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--custom-primary", "red",
            "--custom-secondary", "blue"
        ]) as! IconGeneratorCommand
        
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        // Custom colors should be ignored without the flag
        #expect(settings.useCustomColors == false)
    }
    
    @Test
    func enableCustomColorsWithFlag() throws {
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--use-custom-colors",
            "--custom-primary", "red",
            "--custom-secondary", "blue"
        ]) as! IconGeneratorCommand
        
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.useCustomColors == true)
        #expect(settings.customPrimaryColor == .red)
        #expect(settings.customSecondaryColor == .blue)
    }
    
    // MARK: - Rendering Mode Context Validation Tests
    
    @Test
    func validateMonochromeContext() throws {
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--rendering-mode", "monochrome",
            "--symbol-color", "white"
        ]) as! IconGeneratorCommand
        
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.symbolRenderingMode == .monochrome)
        #expect(settings.symbolColor == .white)
    }
    
    @Test
    func validateHierarchicalContext() throws {
        let command = try IconGeneratorCommand.parseAsRoot([
            "folder.fill",
            "--rendering-mode", "hierarchical",
            "--hierarchical-color", "white"
        ]) as! IconGeneratorCommand
        
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.symbolRenderingMode == .hierarchical)
        #expect(settings.hierarchicalSymbolColor == .white)
    }
    
    @Test
    func validatePaletteContext() throws {
        let command = try IconGeneratorCommand.parseAsRoot([
            "person.3.fill",
            "--rendering-mode", "palette",
            "--palette-primary", "white",
            "--palette-secondary", "blue:0.7",
            "--palette-tertiary", "green:0.3"
        ]) as! IconGeneratorCommand
        
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        #expect(settings.symbolRenderingMode == .palette)
        #expect(settings.paletteSymbolPrimaryColor == .white)
        #expect(settings.paletteSymbolSecondaryColor != .clear)
        #expect(settings.paletteSymbolTertiaryColor != .clear)
    }
    
    // MARK: - File Path Validation Tests
    
    @Test
    func acceptValidOutputPaths() throws {
        let validPaths = [
            "/tmp/icon.png",
            "./output/icon.png",
            "~/Desktop/icon.png",
            "relative/path/icon.png",
            "../parent/icon.png"
        ]
        
        for path in validPaths {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--output", path
            ]) as! IconGeneratorCommand
            
            #expect(command.outputPath == path)
        }
    }
    
    @Test
    func handleSpecialCharactersInPaths() throws {
        let specialPaths = [
            "/tmp/icon with spaces.png",
            "/tmp/icon-with-dashes.png",
            "/tmp/icon_with_underscores.png",
            "/tmp/icon (with parens).png"
        ]
        
        for path in specialPaths {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill", "--output", path
            ]) as! IconGeneratorCommand
            
            #expect(command.outputPath == path)
        }
    }
    
    // MARK: - Complex Validation Scenarios Tests
    
    @Test
    func validateComplexValidConfiguration() throws {
        let command = try IconGeneratorCommand.parseAsRoot([
            "app.fill",
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
            "--badge-secondary", "orange"
        ]) as! IconGeneratorCommand
        
        // Should parse successfully
        let settings = try IconGeneratorCLI.buildIconSettings(from: command)
        
        // Verify all settings are valid
        #expect(settings.symbolName == "app.fill")
        #expect(settings.exportSize == 1024)
        #expect(settings.exportRetinaSize == true)
        #expect(settings.exportColorSpace == .displayP3)
        #expect(settings.useCustomColors == true)
        #expect(settings.symbolRenderingMode == .palette)
        #expect(settings.showBadge == true)
        #expect(settings.badgeUseCustomColors == true)
    }
    
    @Test
    func rejectConflictingOptions() throws {
        // This should be handled gracefully - last option wins or documented behavior
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--rendering-mode", "monochrome",
            "--rendering-mode", "hierarchical"  // Conflicting
        ]) as! IconGeneratorCommand
        
        // Should use the last specified value
        #expect(command.renderingMode == "hierarchical")
    }
    
    // MARK: - Error Message Quality Tests
    
    @Test
    func providesHelpfulErrorMessages() throws {
        do {
            try IconGeneratorCommand.parseAsRoot(["star.fill", "--size", "999"])
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            let errorMessage = error.localizedDescription
            #expect(errorMessage.contains("size") || errorMessage.contains("999"),
                   "Error message should reference the invalid size")
        }
    }
    
    @Test
    func showsAvailableOptionsInError() throws {
        do {
            try IconGeneratorCommand.parseAsRoot(["star.fill", "--rendering-mode", "invalid"])
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            let errorMessage = error.localizedDescription
            // Should mention valid options
            #expect(errorMessage.contains("monochrome") || 
                   errorMessage.contains("hierarchical") ||
                   errorMessage.contains("palette"),
                   "Error message should show valid options")
        }
    }
    
    // MARK: - Help and Version Validation Tests
    
    @Test
    func showHelpWithoutRequiredArguments() throws {
        // Help should work without symbol name
        let command = try IconGeneratorCommand.parseAsRoot(["--help"])
        #expect(command is HelpCommand)
    }
    
    @Test
    func showVersionWithoutRequiredArguments() throws {
        // Version should work without symbol name
        let command = try IconGeneratorCommand.parseAsRoot(["--version"])
        #expect(command is VersionCommand || (command as? IconGeneratorCommand)?.version == true)
    }
}

// MARK: - Test Helper Extensions

extension CLIValidationTests {
    
    /// Helper to test that validation error contains expected information
    func expectValidationError<T>(
        when executing: @autoclosure () throws -> T,
        contains expectedText: String
    ) {
        do {
            _ = try executing()
            #expect(Bool(false), "Expected validation error but none was thrown")
        } catch {
            let message = error.localizedDescription
            #expect(message.localizedCaseInsensitiveContains(expectedText),
                   "Error message '\(message)' should contain '\(expectedText)'")
        }
    }
}
