// CLIPathResolutionTests.swift - Unit tests for file path handling and resolution
import Testing
import Foundation
@testable import macOS_Icon_Generator_App

struct CLIPathResolutionTests {
    
    // MARK: - Path Resolution Tests
    
    @Test
    func resolveBasicOutputPath() throws {
        // Test explicit output path
        let result = IconGeneratorCLI.resolveOutputPath(
            symbolName: "star.fill",
            userPath: "/tmp/my-icon.png"
        )
        
        let expected = URL(fileURLWithPath: "/tmp/my-icon.png")
        #expect(result == expected)
    }
    
    @Test
    func resolveDefaultOutputPath() throws {
        // Test default path generation
        let result = IconGeneratorCLI.resolveOutputPath(
            symbolName: "star.fill",
            userPath: nil
        )
        
        // Should generate filename based on symbol name
        #expect(result.path.hasSuffix("star-fill.png"))
        #expect(result.path.hasPrefix("./") || result.isAbsolute)
    }
    
    @Test
    func resolveRelativeOutputPath() throws {
        let result = IconGeneratorCLI.resolveOutputPath(
            symbolName: "folder.fill",
            userPath: "icons/folder-icon.png"
        )
        
        #expect(result.path.contains("icons/folder-icon.png"))
    }
    
    @Test
    func resolveHomePath() throws {
        let result = IconGeneratorCLI.resolveOutputPath(
            symbolName: "heart.fill",
            userPath: "~/Desktop/heart.png"
        )
        
        // Should expand ~ to home directory
        #expect(result.path.contains("/Users/"))
        #expect(result.path.hasSuffix("/Desktop/heart.png"))
    }
    
    // MARK: - Symbol Name Sanitization Tests
    
    @Test
    func sanitizeSymbolNameWithDots() throws {
        let result = IconGeneratorCLI.sanitizeSymbolName("star.fill.badge.plus")
        #expect(result == "star-fill-badge-plus")
    }
    
    @Test
    func sanitizeSymbolNameWithSlashes() throws {
        let result = IconGeneratorCLI.sanitizeSymbolName("arrow/up/circle")
        #expect(result == "arrow-up-circle")
    }
    
    @Test
    func sanitizeSymbolNameWithSpaces() throws {
        let result = IconGeneratorCLI.sanitizeSymbolName("person 3 fill")
        #expect(result == "person-3-fill")
    }
    
    @Test
    func sanitizeSymbolNameWithSpecialCharacters() throws {
        let result = IconGeneratorCLI.sanitizeSymbolName("app.fill@2x:rounded")
        #expect(result == "app-fill-2x-rounded")
    }
    
    @Test
    func sanitizeAlreadyCleanSymbolName() throws {
        let result = IconGeneratorCLI.sanitizeSymbolName("clean-symbol-name")
        #expect(result == "clean-symbol-name")
    }
    
    @Test
    func sanitizeEmptySymbolName() throws {
        let result = IconGeneratorCLI.sanitizeSymbolName("")
        #expect(result == "icon")
    }
    
    @Test
    func sanitizeSymbolNameWithOnlySpecialCharacters() throws {
        let result = IconGeneratorCLI.sanitizeSymbolName("...")
        #expect(result == "icon")
    }
    
    // MARK: - Default Filename Generation Tests
    
    @Test
    func generateDefaultFilenameForBasicSymbol() throws {
        let filename = IconGeneratorCLI.generateDefaultFilename(for: "star.fill")
        #expect(filename == "star-fill.png")
    }
    
    @Test
    func generateDefaultFilenameForComplexSymbol() throws {
        let filename = IconGeneratorCLI.generateDefaultFilename(for: "person.3.fill.badge.plus")
        #expect(filename == "person-3-fill-badge-plus.png")
    }
    
    @Test
    func generateDefaultFilenameForSymbolWithSlashes() throws {
        let filename = IconGeneratorCLI.generateDefaultFilename(for: "arrow/up/circle/fill")
        #expect(filename == "arrow-up-circle-fill.png")
    }
    
    // MARK: - Directory Creation Tests
    
    @Test
    func ensureDirectoryExistsForNewDirectory() throws {
        let testDir = "/tmp/cli-test-dir-\(UUID().uuidString)"
        let testPath = "\(testDir)/nested/path/icon.png"
        let url = URL(fileURLWithPath: testPath)
        
        // Ensure directory doesn't exist initially
        #expect(!FileManager.default.fileExists(atPath: testDir))
        
        // Test directory creation
        try IconGeneratorCLI.ensureDirectoryExists(for: url)
        
        // Verify directory was created
        let dirExists = FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path)
        #expect(dirExists)
        
        // Clean up
        try? FileManager.default.removeItem(atPath: testDir)
    }
    
    @Test
    func ensureDirectoryExistsForExistingDirectory() throws {
        // Use /tmp which should always exist
        let testPath = "/tmp/existing-test-icon.png"
        let url = URL(fileURLWithPath: testPath)
        
        // Should not throw error for existing directory
        try IconGeneratorCLI.ensureDirectoryExists(for: url)
    }
    
    @Test
    func ensureDirectoryExistsForCurrentDirectory() throws {
        let testPath = "./test-icon.png"
        let url = URL(fileURLWithPath: testPath)
        
        // Should handle current directory correctly
        try IconGeneratorCLI.ensureDirectoryExists(for: url)
    }
    
    // MARK: - Path Validation Tests
    
    @Test
    func validateWritableDirectory() throws {
        let testPath = "/tmp/test-icon.png"
        let url = URL(fileURLWithPath: testPath)
        
        let isWritable = IconGeneratorCLI.isPathWritable(url)
        #expect(isWritable == true, "/tmp should be writable")
    }
    
    @Test
    func validateNonWritableDirectory() throws {
        // Test system directory (should not be writable by user)
        let testPath = "/System/Library/test-icon.png"
        let url = URL(fileURLWithPath: testPath)
        
        let isWritable = IconGeneratorCLI.isPathWritable(url)
        #expect(isWritable == false, "/System/Library should not be writable")
    }
    
    @Test
    func validatePathWithNonExistentDirectory() throws {
        let testPath = "/nonexistent/directory/icon.png"
        let url = URL(fileURLWithPath: testPath)
        
        let isWritable = IconGeneratorCLI.isPathWritable(url)
        #expect(isWritable == false, "Nonexistent directory should not be writable")
    }
    
    // MARK: - File Extension Tests
    
    @Test
    func ensurePNGExtension() throws {
        let tests = [
            ("test", "test.png"),
            ("test.png", "test.png"),
            ("test.jpg", "test.jpg.png"),
            ("test.PNG", "test.PNG.png"),
            ("test.", "test..png")
        ]
        
        for (input, expected) in tests {
            let result = IconGeneratorCLI.ensurePNGExtension(input)
            #expect(result == expected, "Input '\(input)' should become '\(expected)' but got '\(result)'")
        }
    }
    
    // MARK: - Complex Path Resolution Tests
    
    @Test
    func resolveComplexPathScenarios() throws {
        let scenarios = [
            (
                symbolName: "star.fill.badge.plus",
                userPath: "~/Desktop/MyIcons/Custom Icons/star-badge.png",
                expectedContains: ["/Users/", "/Desktop/MyIcons/Custom Icons/star-badge.png"]
            ),
            (
                symbolName: "folder/fill",
                userPath: "./output/icons/",
                expectedContains: ["./output/icons/"]
            ),
            (
                symbolName: "app.fill@2x",
                userPath: nil,
                expectedContains: ["app-fill-2x.png"]
            )
        ]
        
        for scenario in scenarios {
            let result = IconGeneratorCLI.resolveOutputPath(
                symbolName: scenario.symbolName,
                userPath: scenario.userPath
            )
            
            for expectedPart in scenario.expectedContains {
                #expect(result.path.contains(expectedPart),
                       "Path '\(result.path)' should contain '\(expectedPart)'")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func handleInvalidPathCharacters() throws {
        // Test handling of paths with invalid characters
        let invalidPaths = [
            "/tmp/icon\0.png",  // Null character
            "/tmp/icon|pipe.png",  // Pipe character (invalid on some systems)
        ]
        
        for invalidPath in invalidPaths {
            let url = URL(fileURLWithPath: invalidPath)
            
            // Should handle gracefully without crashing
            let sanitized = IconGeneratorCLI.sanitizePath(url.path)
            #expect(!sanitized.isEmpty, "Sanitized path should not be empty")
        }
    }
    
    @Test
    func handleVeryLongPaths() throws {
        let longName = String(repeating: "a", count: 300)
        let longPath = "/tmp/\(longName).png"
        
        let url = IconGeneratorCLI.resolveOutputPath(
            symbolName: "star.fill",
            userPath: longPath
        )
        
        // Should handle long paths without error
        #expect(url.path.count > 0)
    }
    
    // MARK: - Cross-Platform Compatibility Tests
    
    @Test
    func handleBackslashesInPaths() throws {
        // Test Windows-style paths (should be converted to forward slashes on macOS)
        let windowsPath = "C:\\Users\\Test\\icon.png"
        let sanitized = IconGeneratorCLI.sanitizePath(windowsPath)
        
        #expect(!sanitized.contains("\\"), "Backslashes should be converted")
        #expect(sanitized.contains("/"), "Should contain forward slashes")
    }
    
    @Test
    func handleMixedSeparators() throws {
        let mixedPath = "/tmp\\mixed/path\\icon.png"
        let sanitized = IconGeneratorCLI.sanitizePath(mixedPath)
        
        #expect(!sanitized.contains("\\"), "Should normalize path separators")
    }
}

// MARK: - Test Helper Extensions

extension IconGeneratorCLI {
    
    /// Test helper: Expose path sanitization for testing
    static func sanitizePath(_ path: String) -> String {
        return path
            .replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Test helper: Expose PNG extension logic for testing
    static func ensurePNGExtension(_ filename: String) -> String {
        if filename.lowercased().hasSuffix(".png") {
            return filename
        }
        return "\(filename).png"
    }
    
    /// Test helper: Expose path writability check for testing
    static func isPathWritable(_ url: URL) -> Bool {
        let directory = url.deletingLastPathComponent()
        return FileManager.default.isWritableFile(atPath: directory.path) ||
               FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
    }
}
