// CLIIntegrationTests.swift - Integration tests for end-to-end CLI functionality
import Testing
import SwiftUI
import AppKit
@testable import macOS_Icon_Generator_App

@MainActor
struct CLIIntegrationTests {
    
    // MARK: - End-to-End Icon Generation Tests
    
    @Test
    func generateBasicIcon() async throws {
        // Test basic icon generation
        let command = try createCommand([
            "star.fill",
            "--output", "/tmp/cli-test-basic.png"
        ])
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Verify file was created
        let fileExists = FileManager.default.fileExists(atPath: "/tmp/cli-test-basic.png")
        #expect(fileExists, "Icon file should be created")
        
        // Verify file has content
        let attributes = try FileManager.default.attributesOfItem(atPath: "/tmp/cli-test-basic.png")
        let fileSize = attributes[.size] as? NSNumber
        #expect(fileSize?.intValue ?? 0 > 0, "Icon file should have content")
    }
    
    @Test
    func generateIconWithCustomColors() async throws {
        let command = try createCommand([
            "folder.fill",
            "--output", "/tmp/cli-test-colors.png",
            "--base-color", "red",
            "--use-custom-colors",
            "--custom-primary", "#FF6B35",
            "--custom-secondary", "#F7931E"
        ])
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Verify file creation
        let fileExists = FileManager.default.fileExists(atPath: "/tmp/cli-test-colors.png")
        #expect(fileExists, "Icon with custom colors should be created")
    }
    
    @Test
    func generateIconWithPaletteMode() async throws {
        let command = try createCommand([
            "person.3.fill",
            "--output", "/tmp/cli-test-palette.png",
            "--rendering-mode", "palette",
            "--palette-primary", "white",
            "--palette-secondary", "blue:0.7",
            "--palette-tertiary", "green:0.3"
        ])
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Verify file creation
        let fileExists = FileManager.default.fileExists(atPath: "/tmp/cli-test-palette.png")
        #expect(fileExists, "Palette mode icon should be created")
    }
    
    @Test
    func generateIconWithBadge() async throws {
        let command = try createCommand([
            "star.fill",
            "--output", "/tmp/cli-test-badge.png",
            "--badge", "gearshape.fill",
            "--badge-position", "top-right",
            "--badge-color", "red"
        ])
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Verify file creation
        let fileExists = FileManager.default.fileExists(atPath: "/tmp/cli-test-badge.png")
        #expect(fileExists, "Icon with badge should be created")
    }
    
    @Test
    func generateRetinaIcon() async throws {
        let command = try createCommand([
            "heart.fill",
            "--output", "/tmp/cli-test-retina.png",
            "--size", "512",
            "--retina"
        ])
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Verify file creation
        let fileExists = FileManager.default.fileExists(atPath: "/tmp/cli-test-retina.png")
        #expect(fileExists, "Retina icon should be created")
        
        // Load and check image dimensions
        if let image = NSImage(contentsOfFile: "/tmp/cli-test-retina.png") {
            #expect(image.size.width == 512, "Retina icon should have correct logical size")
            #expect(image.size.height == 512, "Retina icon should have correct logical size")
        }
    }
    
    // MARK: - Settings Mapping Tests
    
    @Test
    func iconSettingsMappingIsCorrect() throws {
        let command = try createCommand([
            "app.fill",
            "--size", "1024",
            "--retina",
            "--color-space", "displayP3",
            "--base-color", "purple",
            "--rendering-mode", "hierarchical",
            "--hierarchical-color", "white",
            "--no-background-shadow"
        ])
        
        let generator = IconGeneratorCLI()
        let settings = try generator.buildTestSettings(from: command)
        
        // Verify all settings are mapped correctly
        #expect(settings.symbolName == "app.fill")
        #expect(settings.exportSize == 1024)
        #expect(settings.exportRetinaSize == true)
        #expect(settings.exportColorSpace == .displayP3)
        #expect(settings.symbolRenderingMode == .hierarchical)
        #expect(settings.enableBackgroundShadow == false)
        #expect(settings.enableSymbolShadow == true) // Should remain true
    }
    
    @Test
    func badgeSettingsMappingIsCorrect() throws {
        let command = try createCommand([
            "star.fill",
            "--badge", "plus.circle",
            "--badge-position", "bottom-left",
            "--badge-use-custom",
            "--badge-primary", "gold",
            "--badge-secondary", "orange",
            "--badge-rendering", "palette"
        ])
        
        let generator = IconGeneratorCLI()
        let settings = try generator.buildTestSettings(from: command)
        
        // Verify badge settings are mapped correctly
        #expect(settings.showBadge == true)
        #expect(settings.badgeSymbolName == "plus.circle")
        #expect(settings.badgePosition == .bottomLeft)
        #expect(settings.badgeUseCustomColors == true)
        #expect(settings.badgeSymbolRenderingMode == .palette)
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func invalidSymbolNameThrows() async throws {
        let command = try createCommand([
            "invalid.symbol.that.does.not.exist",
            "--output", "/tmp/test.png"
        ])
        
        let generator = IconGeneratorCLI()
        
        #expect(throws: CLIError.self) {
            try await generator.generateIcon(from: command)
        }
    }
    
    @Test
    func invalidColorFormatThrows() throws {
        #expect(throws: (any Error).self) {
            _ = try createCommand([
                "star.fill",
                "--base-color", "invalid-color-format"
            ])
        }
    }
    
    @Test
    func invalidOutputPathThrows() async throws {
        let command = try createCommand([
            "star.fill",
            "--output", "/root/cannot-write-here.png"
        ])
        
        let generator = IconGeneratorCLI()
        
        #expect(throws: CLIError.self) {
            try await generator.generateIcon(from: command)
        }
    }
    
    // MARK: - File Operations Tests
    
    @Test
    func outputPathSanitization() throws {
        let generator = IconGeneratorCLI()
        
        // Test various symbol names that need sanitization
        let testCases = [
            ("star.fill", "star-fill.png"),
            ("folder.badge.plus", "folder-badge-plus.png"),
            ("person.3.fill", "person-3-fill.png"),
            ("app/bundle", "app-bundle.png")
        ]
        
        for (symbolName, expectedFilename) in testCases {
            let url = generator.testResolveOutputPath(symbolName: symbolName, userPath: nil)
            #expect(url.lastPathComponent == expectedFilename)
        }
    }
    
    @Test
    func customOutputPathValidation() throws {
        let generator = IconGeneratorCLI()
        
        // Test valid PNG path
        let validPath = generator.testResolveOutputPath(symbolName: "star.fill", userPath: "/tmp/custom.png")
        #expect(validPath.path == "/tmp/custom.png")
        
        // Test non-PNG extension should throw
        #expect(throws: CLIError.self) {
            _ = generator.testResolveOutputPath(symbolName: "star.fill", userPath: "/tmp/custom.jpg")
        }
    }
    
    // MARK: - Complex Integration Tests
    
    @Test
    func generateComplexIcon() async throws {
        // Test most complex possible configuration
        let command = try createCommand([
            "app.fill",
            "--output", "/tmp/cli-test-complex.png",
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
            "--badge-rendering", "hierarchical",
            "--no-background-shadow"
        ])
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Verify complex icon creation
        let fileExists = FileManager.default.fileExists(atPath: "/tmp/cli-test-complex.png")
        #expect(fileExists, "Complex icon should be created")
        
        // Verify file size is reasonable for 1024x1024@2x
        let attributes = try FileManager.default.attributesOfItem(atPath: "/tmp/cli-test-complex.png")
        let fileSize = attributes[.size] as? NSNumber
        #expect(fileSize?.intValue ?? 0 > 10000, "Complex icon should have substantial file size")
    }
    
    @Test
    func multipleIconGeneration() async throws {
        // Test generating multiple icons in sequence
        let testCases = [
            (symbol: "star.fill", color: "blue", output: "/tmp/cli-test-multi-1.png"),
            (symbol: "heart.fill", color: "red", output: "/tmp/cli-test-multi-2.png"),
            (symbol: "folder.fill", color: "green", output: "/tmp/cli-test-multi-3.png")
        ]
        
        let generator = IconGeneratorCLI()
        
        for testCase in testCases {
            let command = try createCommand([
                testCase.symbol,
                "--output", testCase.output,
                "--base-color", testCase.color
            ])
            
            try await generator.generateIcon(from: command)
            
            let fileExists = FileManager.default.fileExists(atPath: testCase.output)
            #expect(fileExists, "Icon \(testCase.symbol) should be created")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createCommand(_ args: [String]) throws -> IconGeneratorCommand {
        return try IconGeneratorCommand.parseAsRoot(args) as! IconGeneratorCommand
    }
}

// MARK: - Test Extensions for IconGeneratorCLI

extension IconGeneratorCLI {
    // Expose internal methods for testing
    func buildTestSettings(from command: IconGeneratorCommand) throws -> IconSettings {
        return try buildIconSettings(from: command)
    }
    
    func testResolveOutputPath(symbolName: String, userPath: String?) throws -> URL {
        return try resolveOutputPath(symbolName: symbolName, userPath: userPath)
    }
}
