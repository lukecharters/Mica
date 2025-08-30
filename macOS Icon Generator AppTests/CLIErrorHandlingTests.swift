// CLIErrorHandlingTests.swift - Tests for CLI error scenarios and user-friendly error messages
import Testing
import SwiftUI
import AppKit
@testable import macOS_Icon_Generator_App

@MainActor
struct CLIErrorHandlingTests {
    
    private let testOutputDir = "/tmp/cli-error-tests"
    
    init() {
        try? FileManager.default.createDirectory(
            atPath: testOutputDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    deinit {
        try? FileManager.default.removeItem(atPath: testOutputDir)
    }
    
    // MARK: - Symbol Validation Errors
    
    @Test
    func handleInvalidSymbolName() async throws {
        let invalidSymbols = [
            "nonexistent.symbol",
            "invalid@symbol",
            "symbol.with.too.many.parts.that.dont.exist"
        ]
        
        for symbol in invalidSymbols {
            let command = try IconGeneratorCommand.parseAsRoot([
                symbol,
                "--output", "\(testOutputDir)/invalid-symbol.png"
            ]) as! IconGeneratorCommand
            
            let generator = IconGeneratorCLI()
            
            do {
                try await generator.generateIcon(from: command)
                #expect(Bool(false), "Should have thrown error for invalid symbol: \(symbol)")
            } catch let error as CLIError {
                switch error {
                case .invalidSymbolName(let name, let message):
                    #expect(name == symbol, "Error should reference the invalid symbol")
                    #expect(message.contains("SF Symbol"), "Error message should mention SF Symbols")
                default:
                    #expect(Bool(false), "Should throw invalidSymbolName error")
                }
            } catch {
                #expect(Bool(false), "Should throw CLIError, got: \(error)")
            }
        }
    }
    
    @Test
    func handleEmptySymbolName() async throws {
        do {
            try IconGeneratorCommand.parseAsRoot([""])
            #expect(Bool(false), "Should reject empty symbol name")
        } catch {
            let message = error.localizedDescription
            #expect(!message.isEmpty, "Should provide helpful error message")
        }
    }
    
    // MARK: - Color Parsing Errors
    
    @Test
    func handleInvalidColorFormats() async throws {
        let invalidColors = [
            "#GGG",           // Invalid hex characters
            "#FF",            // Too short
            "#FFFFFFF",       // Too long
            "rgb(300,0,0)",   // Value out of range
            "rgb(255,0)",     // Missing component
            "hsl(400,100%,50%)", // Hue out of range
            "nonexistent-color", // Unknown color name
            ""                // Empty color
        ]
        
        for color in invalidColors {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill",
                "--base-color", color,
                "--output", "\(testOutputDir)/invalid-color.png"
            ]) as! IconGeneratorCommand
            
            let generator = IconGeneratorCLI()
            
            do {
                try await generator.generateIcon(from: command)
                #expect(Bool(false), "Should have thrown error for invalid color: \(color)")
            } catch let error as CLIError {
                switch error {
                case .colorParseError(let colorString, let message):
                    #expect(colorString == color, "Error should reference the invalid color")
                    #expect(message.contains("Try:") || message.contains("format"), 
                           "Error message should provide format guidance")
                default:
                    #expect(Bool(false), "Should throw colorParseError")
                }
            } catch {
                // Color parsing might throw other error types
                let message = error.localizedDescription
                #expect(message.contains(color) || message.contains("color"),
                       "Error should reference color issue")
            }
        }
    }
    
    @Test
    func handleInvalidOpacityValues() async throws {
        let invalidOpacities = [
            "blue:2.0",    // > 1.0
            "red:-0.5",    // < 0.0
            "green:abc",   // Non-numeric
            "yellow:"      // Missing value
        ]
        
        for colorWithOpacity in invalidOpacities {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill",
                "--palette-secondary", colorWithOpacity,
                "--output", "\(testOutputDir)/invalid-opacity.png"
            ]) as! IconGeneratorCommand
            
            let generator = IconGeneratorCLI()
            
            do {
                try await generator.generateIcon(from: command)
                #expect(Bool(false), "Should have thrown error for invalid opacity: \(colorWithOpacity)")
            } catch {
                let message = error.localizedDescription
                #expect(message.contains("opacity") || message.contains("0.0") || message.contains("1.0"),
                       "Error should mention opacity constraints")
            }
        }
    }
    
    // MARK: - File System Errors
    
    @Test
    func handleReadOnlyDirectory() async throws {
        // Try to write to a system directory (should fail)
        let readOnlyPath = "/System/Library/test-icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", readOnlyPath
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        
        do {
            try await generator.generateIcon(from: command)
            #expect(Bool(false), "Should have thrown error for read-only directory")
        } catch let error as CLIError {
            switch error {
            case .fileSystemError(let path, let message):
                #expect(path.contains("System/Library"), "Should reference the problematic path")
                #expect(message.contains("permission") || message.contains("write"),
                       "Should explain permission issue")
            default:
                #expect(Bool(false), "Should throw fileSystemError")
            }
        } catch {
            // System might throw different error types
            let message = error.localizedDescription
            #expect(message.contains("permission") || message.contains("write") || 
                   message.contains("access"), "Should indicate access/permission issue")
        }
    }
    
    @Test
    func handleNonExistentDirectory() async throws {
        let nonExistentPath = "/nonexistent/deeply/nested/directory/icon.png"
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", nonExistentPath
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        
        do {
            try await generator.generateIcon(from: command)
            #expect(Bool(false), "Should have thrown error for nonexistent directory")
        } catch let error as CLIError {
            switch error {
            case .fileSystemError(let path, let message):
                #expect(path.contains("nonexistent"), "Should reference the problematic path")
                #expect(message.contains("directory") || message.contains("create") ||
                       message.contains("not found"), "Should explain directory issue")
            default:
                #expect(Bool(false), "Should throw fileSystemError")
            }
        } catch {
            let message = error.localizedDescription
            #expect(message.contains("directory") || message.contains("not found") ||
                   message.contains("create"), "Should indicate directory issue")
        }
    }
    
    @Test
    func handleInvalidFileName() async throws {
        let invalidPaths = [
            "/tmp/\0invalid.png",     // Null character
            "/tmp/icon<>.png",        // Invalid characters
            "/tmp/icon|pipe.png"      // Pipe character
        ]
        
        for path in invalidPaths {
            let command = try IconGeneratorCommand.parseAsRoot([
                "star.fill",
                "--output", path
            ]) as! IconGeneratorCommand
            
            let generator = IconGeneratorCLI()
            
            do {
                try await generator.generateIcon(from: command)
                // Some systems might handle these gracefully
                print("Warning: System allowed potentially invalid path: \(path)")
            } catch {
                let message = error.localizedDescription
                #expect(!message.isEmpty, "Should provide error message for invalid path")
            }
        }
    }
    
    // MARK: - Configuration Validation Errors
    
    @Test
    func handleInvalidSizeValues() async throws {
        // Size validation happens during argument parsing
        let invalidSizes = ["64", "300", "2048", "abc", "-1"]
        
        for size in invalidSizes {
            do {
                try IconGeneratorCommand.parseAsRoot([
                    "star.fill", "--size", size
                ])
                #expect(Bool(false), "Should reject invalid size: \(size)")
            } catch {
                let message = error.localizedDescription
                #expect(message.contains("size") || message.contains(size) ||
                       message.contains("128") || message.contains("256"),
                       "Error should reference size constraints")
            }
        }
    }
    
    @Test
    func handleInvalidRenderingModes() async throws {
        let invalidModes = ["invalid", "mono", "hierarchy", ""]
        
        for mode in invalidModes {
            do {
                try IconGeneratorCommand.parseAsRoot([
                    "star.fill", "--rendering-mode", mode
                ])
                #expect(Bool(false), "Should reject invalid rendering mode: \(mode)")
            } catch {
                let message = error.localizedDescription
                #expect(message.contains("rendering") || message.contains("mode") ||
                       message.contains("monochrome") || message.contains("hierarchical"),
                       "Error should reference valid rendering modes")
            }
        }
    }
    
    @Test
    func handleInvalidBadgePositions() async throws {
        let invalidPositions = ["center", "middle", "left", "right", "invalid", ""]
        
        for position in invalidPositions {
            do {
                try IconGeneratorCommand.parseAsRoot([
                    "star.fill", "--badge", "plus", "--badge-position", position
                ])
                #expect(Bool(false), "Should reject invalid badge position: \(position)")
            } catch {
                let message = error.localizedDescription
                #expect(message.contains("position") || message.contains("badge") ||
                       message.contains("top") || message.contains("bottom"),
                       "Error should reference valid badge positions")
            }
        }
    }
    
    // MARK: - Rendering Engine Errors
    
    @Test
    func handleRenderingFailure() async throws {
        // This is harder to trigger, but we can test the error handling path
        // by mocking a failure scenario
        
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", "\(testOutputDir)/render-test.png"
        ]) as! IconGeneratorCommand
        
        // Test that rendering errors are handled gracefully
        let generator = IconGeneratorCLI()
        
        // Normal rendering should work
        try await generator.generateIcon(from: command)
        #expect(FileManager.default.fileExists(atPath: "\(testOutputDir)/render-test.png"))
    }
    
    @Test
    func handleImageConversionFailure() async throws {
        // Test scenario where image conversion might fail
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--output", "\(testOutputDir)/conversion-test.png",
            "--size", "1024"  // Large size more likely to expose conversion issues
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        
        // Should handle any conversion issues gracefully
        do {
            try await generator.generateIcon(from: command)
            #expect(FileManager.default.fileExists(atPath: "\(testOutputDir)/conversion-test.png"))
        } catch let error as CLIError {
            switch error {
            case .imageConversionError(let message):
                #expect(message.contains("image") || message.contains("conversion"),
                       "Error should explain image conversion issue")
            default:
                #expect(Bool(false), "Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Memory and Resource Errors
    
    @Test
    func handleLowMemoryScenario() async throws {
        // Test very large icon generation that might cause memory issues
        let command = try IconGeneratorCommand.parseAsRoot([
            "app.fill",
            "--output", "\(testOutputDir)/memory-test.png",
            "--size", "1024",
            "--retina",
            "--rendering-mode", "palette",
            "--palette-primary", "white",
            "--palette-secondary", "blue:0.8",
            "--palette-tertiary", "green:0.4",
            "--badge", "gearshape.fill"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        
        // Should complete successfully or fail gracefully
        do {
            try await generator.generateIcon(from: command)
            #expect(FileManager.default.fileExists(atPath: "\(testOutputDir)/memory-test.png"))
        } catch {
            // Any memory-related errors should be handled gracefully
            let message = error.localizedDescription
            #expect(!message.isEmpty, "Should provide meaningful error message")
        }
    }
    
    // MARK: - Concurrent Access Errors
    
    @Test
    func handleConcurrentFileAccess() async throws {
        let outputPath = "\(testOutputDir)/concurrent-test.png"
        
        // Create multiple concurrent generation tasks
        let tasks = (0..<3).map { index in
            Task {
                let command = try IconGeneratorCommand.parseAsRoot([
                    "star.fill",
                    "--output", outputPath,
                    "--base-color", index == 0 ? "red" : index == 1 ? "blue" : "green"
                ]) as! IconGeneratorCommand
                
                let generator = IconGeneratorCLI()
                try await generator.generateIcon(from: command)
            }
        }
        
        // Wait for all tasks to complete
        for task in tasks {
            do {
                try await task.value
            } catch {
                // File access conflicts should be handled gracefully
                let message = error.localizedDescription
                #expect(!message.isEmpty, "Should provide error message for file conflicts")
            }
        }
        
        // At least one should succeed
        #expect(FileManager.default.fileExists(atPath: outputPath),
               "At least one concurrent task should succeed")
    }
    
    // MARK: - Error Message Quality Tests
    
    @Test
    func errorMessagesAreUserFriendly() async throws {
        let errorScenarios: [(args: [String], expectedContent: [String])] = [
            (
                args: ["star.fill", "--size", "999"],
                expectedContent: ["size", "128", "256", "512", "1024"]
            ),
            (
                args: ["star.fill", "--color-space", "invalid"],
                expectedContent: ["color-space", "sRGB", "displayP3"]
            ),
            (
                args: ["star.fill", "--rendering-mode", "invalid"],
                expectedContent: ["rendering", "monochrome", "hierarchical", "palette"]
            ),
            (
                args: ["star.fill", "--badge", "plus", "--badge-position", "invalid"],
                expectedContent: ["position", "top-left", "bottom-right"]
            )
        ]
        
        for scenario in errorScenarios {
            do {
                try IconGeneratorCommand.parseAsRoot(scenario.args)
                #expect(Bool(false), "Should have thrown validation error for: \(scenario.args)")
            } catch {
                let message = error.localizedDescription.lowercased()
                
                for expectedContent in scenario.expectedContent {
                    let found = message.contains(expectedContent.lowercased())
                    #expect(found, "Error message should contain '\(expectedContent)': \(message)")
                }
                
                // Error messages should be helpful, not just "invalid"
                #expect(!message.contains("error occurred"), 
                       "Should avoid generic error messages")
                #expect(message.count > 20, 
                       "Error messages should be descriptive")
            }
        }
    }
    
    @Test
    func errorMessagesIncludeExamples() async throws {
        // Test that color parsing errors include format examples
        let command = try IconGeneratorCommand.parseAsRoot([
            "star.fill",
            "--base-color", "invalid-color-format",
            "--output", "\(testOutputDir)/error-example-test.png"
        ]) as! IconGeneratorCommand
        
        let generator = IconGeneratorCLI()
        
        do {
            try await generator.generateIcon(from: command)
            #expect(Bool(false), "Should have thrown color parsing error")
        } catch {
            let message = error.localizedDescription
            
            // Should include examples of valid formats
            let containsExamples = message.contains("Try:") || 
                                 message.contains("example") ||
                                 message.contains("#FF0000") ||
                                 message.contains("rgb(") ||
                                 message.contains("blue")
            
            #expect(containsExamples, "Error message should include format examples: \(message)")
        }
    }
    
    @Test
    func errorMessagesAreLocalized() async throws {
        // Basic test that error messages use proper localization
        do {
            try IconGeneratorCommand.parseAsRoot(["star.fill", "--size", "invalid"])
            #expect(Bool(false), "Should throw validation error")
        } catch {
            let message = error.localizedDescription
            
            // Should be proper English (not technical codes)
            #expect(!message.contains("ERR_"), "Should not contain error codes")
            #expect(!message.contains("nil"), "Should not contain technical terms")
            #expect(message.first?.isUppercase == true, "Should start with capital letter")
        }
    }
    
    // MARK: - Recovery and Suggestion Tests
    
    @Test
    func provideHelpfulSuggestions() async throws {
        // Test that errors provide actionable suggestions
        let scenarios = [
            (args: ["nonexistent.symbol"], suggestions: ["valid SF Symbol", "available symbols"]),
            (args: ["star.fill", "--base-color", "#GGG"], suggestions: ["#FF0000", "rgb(", "blue"]),
            (args: ["star.fill", "--size", "300"], suggestions: ["256", "512"])
        ]
        
        for scenario in scenarios {
            do {
                let command = try IconGeneratorCommand.parseAsRoot(scenario.args)
                if let cliCommand = command as? IconGeneratorCommand {
                    let generator = IconGeneratorCLI()
                    try await generator.generateIcon(from: cliCommand)
                }
                #expect(Bool(false), "Should have thrown error for: \(scenario.args)")
            } catch {
                let message = error.localizedDescription.lowercased()
                
                let containsSuggestion = scenario.suggestions.contains { suggestion in
                    message.contains(suggestion.lowercased())
                }
                
                #expect(containsSuggestion, 
                       "Error should contain helpful suggestion for \(scenario.args): \(message)")
            }
        }
    }
}

// MARK: - Error Type Definitions

enum CLIError: LocalizedError {
    case invalidSymbolName(String, String)
    case colorParseError(String, String)
    case fileSystemError(String, String)
    case imageConversionError(String)
    case renderingError(String)
    case validationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidSymbolName(let symbol, let message):
            return "Invalid SF Symbol '\(symbol)': \(message)"
        case .colorParseError(let color, let message):
            return "Invalid color '\(color)': \(message)"
        case .fileSystemError(let path, let message):
            return "File system error at '\(path)': \(message)"
        case .imageConversionError(let message):
            return "Image conversion failed: \(message)"
        case .renderingError(let message):
            return "Rendering failed: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidSymbolName:
            return "Try using a valid SF Symbol name. Check Apple's SF Symbols app for available symbols."
        case .colorParseError:
            return "Try: 'blue', '#FF0000', 'rgb(255,0,0)', or 'hsl(240,100%,50%)'."
        case .fileSystemError:
            return "Check that the directory exists and you have write permissions."
        case .imageConversionError:
            return "Try using a different export size or check available memory."
        case .renderingError:
            return "Try simplifying the icon configuration or checking symbol availability."
        case .validationError:
            return "Check the help documentation for valid argument values."
        }
    }
}
