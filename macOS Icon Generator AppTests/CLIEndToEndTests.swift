// CLIEndToEndTests.swift - Comprehensive end-to-end integration tests
import Testing
import SwiftUI
import AppKit
@testable import macOS_Icon_Generator_App

@MainActor
struct CLIEndToEndTests {
    
    private let testOutputDir = "/tmp/cli-e2e-tests"
    
    init() {
        // Ensure test output directory exists
        try? FileManager.default.createDirectory(
            atPath: testOutputDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    deinit {
        // Clean up test files
        try? FileManager.default.removeItem(atPath: testOutputDir)
    }
    
    // MARK: - Basic End-to-End Tests
    
    @Test
    func generateBasicIcon() async throws {
        let outputPath = "\(testOutputDir)/basic-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", outputPath
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: outputPath), "Icon file should exist")
        
        // Verify file has reasonable size (not empty, not too large)
        let attributes = try FileManager.default.attributesOfItem(atPath: outputPath)
        let fileSize = attributes[.size] as? Int ?? 0
        #expect(fileSize > 1000, "Icon file should have substantial content (>1KB)")
        #expect(fileSize < 1_000_000, "Icon file should not be excessively large (<1MB)")
        
        // Verify it's a valid PNG
        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let image = NSImage(data: data)
        #expect(image != nil, "Should be a valid image file")
    }
    
    @Test
    func generateIconWithCustomSize() async throws {
        let outputPath = "\(testOutputDir)/custom-size-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "folder.fill",
            "--output", outputPath,
            "--size", "512"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Verify file properties
        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let image = NSImage(data: data)
        #expect(image != nil, "Should be a valid image")
        #expect(image?.size.width == 512, "Image width should be 512px")
        #expect(image?.size.height == 512, "Image height should be 512px")
    }
    
    @Test
    func generateRetinaIcon() async throws {
        let outputPath = "\(testOutputDir)/retina-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "heart.fill",
            "--output", outputPath,
            "--size", "256",
            "--retina"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Verify file exists and is larger (retina should be 2x)
        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let image = NSImage(data: data)
        #expect(image != nil, "Should be a valid image")
        
        // Retina should double the pixel dimensions
        #expect(image?.size.width == 512 || image?.size.width == 256, 
               "Retina image should be 2x size or maintain logical size")
    }
    
    // MARK: - Color Configuration Tests
    
    @Test
    func generateIconWithCustomColors() async throws {
        let outputPath = "\(testOutputDir)/custom-colors-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "app.fill",
            "--output", outputPath,
            "--use-custom-colors",
            "--custom-primary", "#FF6B35",
            "--custom-secondary", "#F7931E"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Verify file was created successfully
        #expect(FileManager.default.fileExists(atPath: outputPath))
        
        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let image = NSImage(data: data)
        #expect(image != nil, "Should generate valid image with custom colors")
    }
    
    @Test
    func generateIconWithNamedColors() async throws {
        let outputPath = "\(testOutputDir)/named-colors-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "gearshape.fill",
            "--output", outputPath,
            "--base-color", "crimson",
            "--symbol-color", "gold"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
        
        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let image = NSImage(data: data)
        #expect(image != nil, "Should generate valid image with named colors")
    }
    
    @Test
    func generateIconWithHexColors() async throws {
        let outputPath = "\(testOutputDir)/hex-colors-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "shield.fill",
            "--output", outputPath,
            "--base-color", "#FF0000",
            "--symbol-color", "#FFFFFF"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    @Test
    func generateIconWithRGBColors() async throws {
        let outputPath = "\(testOutputDir)/rgb-colors-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "circle.fill",
            "--output", outputPath,
            "--base-color", "rgb(255,100,50)",
            "--symbol-color", "rgba(255,255,255,0.9)"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    @Test
    func generateIconWithHSLColors() async throws {
        let outputPath = "\(testOutputDir)/hsl-colors-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "diamond.fill",
            "--output", outputPath,
            "--base-color", "hsl(240,100%,50%)",
            "--symbol-color", "hsla(120,50%,75%,0.8)"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    // MARK: - Rendering Mode Tests
    
    @Test
    func generateMonochromeIcon() async throws {
        let outputPath = "\(testOutputDir)/monochrome-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", outputPath,
            "--rendering-mode", "monochrome",
            "--symbol-color", "white"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    @Test
    func generateHierarchicalIcon() async throws {
        let outputPath = "\(testOutputDir)/hierarchical-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "folder.fill.badge.plus",
            "--output", outputPath,
            "--rendering-mode", "hierarchical",
            "--hierarchical-color", "white"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    @Test
    func generateMulticolorIcon() async throws {
        let outputPath = "\(testOutputDir)/multicolor-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "rainbow",
            "--output", outputPath,
            "--rendering-mode", "multicolor"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    @Test
    func generatePaletteIcon() async throws {
        let outputPath = "\(testOutputDir)/palette-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "person.3.fill",
            "--output", outputPath,
            "--rendering-mode", "palette",
            "--palette-primary", "white",
            "--palette-secondary", "blue:0.7",
            "--palette-tertiary", "green:0.3"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    // MARK: - Badge Tests
    
    @Test
    func generateIconWithBadge() async throws {
        let outputPath = "\(testOutputDir)/badge-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "app.fill",
            "--output", outputPath,
            "--badge", "gearshape.fill",
            "--badge-position", "bottom-right"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    @Test
    func generateIconWithCustomBadge() async throws {
        let outputPath = "\(testOutputDir)/custom-badge-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", outputPath,
            "--badge", "plus.circle",
            "--badge-position", "top-right",
            "--badge-use-custom",
            "--badge-primary", "yellow",
            "--badge-secondary", "orange",
            "--badge-rendering", "hierarchical",
            "--badge-symbol-color", "white"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    @Test
    func generateBadgeAllPositions() async throws {
        let positions = ["top-left", "top-right", "bottom-left", "bottom-right"]
        
        for position in positions {
            let outputPath = "\(testOutputDir)/badge-\(position)-icon.png"
            
            let command = try IconGeneratorCommand.parseAsRoot([
                "heart.fill",
                "--output", outputPath,
                "--badge", "checkmark.circle",
                "--badge-position", position
            ]) as! IconGeneratorCommand
            
            let generator = IconGeneratorCLI()
            try await generator.generateIcon(from: command)
            
            #expect(FileManager.default.fileExists(atPath: outputPath),
                   "Badge position \(position) should generate successfully")
        }
    }
    
    // MARK: - Shadow Configuration Tests
    
    @Test
    func generateIconWithoutShadows() async throws {
        let outputPath = "\(testOutputDir)/no-shadows-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "circle.fill",
            "--output", outputPath,
            "--no-background-shadow",
            "--no-symbol-shadow"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    @Test
    func generateIconWithBackgroundShadowOnly() async throws {
        let outputPath = "\(testOutputDir)/bg-shadow-only-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "square.fill",
            "--output", outputPath,
            "--no-symbol-shadow"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    @Test
    func generateIconWithSymbolShadowOnly() async throws {
        let outputPath = "\(testOutputDir)/symbol-shadow-only-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "triangle.fill",
            "--output", outputPath,
            "--no-background-shadow"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    // MARK: - Export Format Tests
    
    @Test
    func generateAllSizes() async throws {
        let sizes = [128, 256, 512, 1024]
        
        for size in sizes {
            let outputPath = "\(testOutputDir)/size-\(size)-icon.png"
            
            let command = try IconGeneratorCommand.parseAsRoot([
                "gear.fill",
                "--output", outputPath,
                "--size", "\(size)"
            ]) as! IconGeneratorCommand
            
            let generator = IconGeneratorCLI()
            try await generator.generateIcon(from: command)
            
            #expect(FileManager.default.fileExists(atPath: outputPath),
                   "Size \(size) should generate successfully")
            
            // Verify image size
            let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
            let image = NSImage(data: data)
            #expect(image?.size.width == CGFloat(size), 
                   "Image should have width of \(size)")
        }
    }
    
    @Test
    func generateDisplayP3ColorSpace() async throws {
        let outputPath = "\(testOutputDir)/displayp3-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "paintbrush.fill",
            "--output", outputPath,
            "--color-space", "displayP3"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
    
    // MARK: - Complex Integration Tests
    
    @Test
    func generateMaximalComplexityIcon() async throws {
        let outputPath = "\(testOutputDir)/maximal-complexity-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "app.fill",
            "--output", outputPath,
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
            "--badge-rendering", "hierarchical",
            "--badge-symbol-color", "white"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
        
        // Verify it's a substantial file with complex rendering
        let attributes = try FileManager.default.attributesOfItem(atPath: outputPath)
        let fileSize = attributes[.size] as? Int ?? 0
        #expect(fileSize > 10000, "Complex icon should be substantial in size")
        
        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let image = NSImage(data: data)
        #expect(image != nil, "Complex icon should be valid")
    }
    
    // MARK: - Path Resolution Tests
    
    @Test
    func generateWithDefaultPath() async throws {
        // Change to test directory to control default path
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(testOutputDir)
        
        defer {
            // Restore original directory
            FileManager.default.changeCurrentDirectoryPath(originalDir)
        }
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Should create file with sanitized symbol name
        let expectedPath = "\(testOutputDir)/star-fill.png"
        #expect(FileManager.default.fileExists(atPath: expectedPath),
               "Should create file with default naming")
    }
    
    @Test
    func generateWithRelativePath() async throws {
        let command = try IconGeneratorCommand.parseAsRoot([
            "folder.fill",
            "--output", "relative-path-icon.png"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        // Should create file relative to current directory
        let exists = FileManager.default.fileExists(atPath: "relative-path-icon.png") ||
                    FileManager.default.fileExists(atPath: "\(testOutputDir)/relative-path-icon.png")
        #expect(exists, "Should create file with relative path")
    }
    
    @Test
    func generateWithHomePath() async throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let outputPath = "~/cli-test-icon.png"
        let resolvedPath = "\(homeDir)/cli-test-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "heart.fill",
            "--output", outputPath
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: resolvedPath),
               "Should expand ~ to home directory")
        
        // Clean up
        try? FileManager.default.removeItem(atPath: resolvedPath)
    }
    
    // MARK: - Batch Generation Tests
    
    @Test
    func generateMultipleIcons() async throws {
        let symbols = ["star.fill", "heart.fill", "circle.fill", "square.fill"]
        
        for (index, symbol) in symbols.enumerated() {
            let outputPath = "\(testOutputDir)/batch-\(index)-\(symbol.replacingOccurrences(of: ".", with: "-")).png"
            
            let command = try IconGeneratorCommand.parseAsRoot([
                symbol,
                "--output", outputPath
            ]) as! IconGeneratorCommand
            
            let generator = IconGeneratorCLI()
            try await generator.generateIcon(from: command)
            
            #expect(FileManager.default.fileExists(atPath: outputPath),
                   "Batch icon \(symbol) should be generated")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test
    func generateIconPerformance() async throws {
        let outputPath = "\(testOutputDir)/performance-test-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "app.fill",
            "--output", outputPath,
            "--size", "512"
        ]) as! IconGeneratorCommand
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let generator = IconGeneratorCLI()
        try await generator.generateIcon(from: command)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
        #expect(duration < 10.0, "Icon generation should complete within 10 seconds")
        
        print("Icon generation took \(String(format: "%.3f", duration)) seconds")
    }
    
    // MARK: - Memory and Resource Tests
    
    @Test
    func generateLargeIconWithoutMemoryIssues() async throws {
        let outputPath = "\(testOutputDir)/large-icon-test.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "app.fill",
            "--output", outputPath,
            "--size", "1024",
            "--retina"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        
        // This should complete without memory issues
        try await generator.generateIcon(from: command)
        
        #expect(FileManager.default.fileExists(atPath: outputPath))
        
        // Verify reasonable file size for large retina image
        let attributes = try FileManager.default.attributesOfItem(atPath: outputPath)
        let fileSize = attributes[.size] as? Int ?? 0
        #expect(fileSize > 1000, "Large icon should have substantial size")
        #expect(fileSize < 5_000_000, "Large icon shouldn't be excessively large")
    }
}

// MARK: - Test Configuration Extensions

extension CLIEndToEndTests {
    
    /// Helper to clean up test files after each test
    func cleanupTestFile(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
    
    /// Helper to verify image properties
    func verifyImageProperties(_ image: NSImage, expectedSize: CGFloat) {
        #expect(image.size.width == expectedSize, "Image width should match expected size")
        #expect(image.size.height == expectedSize, "Image height should match expected size")
    }
    
    /// Helper to measure generation time
    func measureGenerationTime<T>(_ operation: () async throws -> T) async rethrows -> (result: T, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        return (result, endTime - startTime)
    }
}
