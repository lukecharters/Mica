// CLIIntegrationTests.swift
// Integration tests for CLI custom size generation
import Testing
import Foundation
import AppKit
import ArgumentParser
@testable import macOS_Icon_Generator_App
@testable import sfIconGen_CLI

@MainActor
struct CLIIntegrationTests {
    
    @Test("CLI generates icon with custom size")
    func cli_generates_custom_size_icon() throws {
        // Test full CLI execution with --size 450
        // Expected to FAIL until CLI validation updated to accept 16-1024 range
        
        // Parse command with custom size
        let command = try IconGeneratorCommand.parse(["star.fill", "--size", "450"])
        
        // Verify size was parsed correctly
        #expect(command.size == 450)
        
        // Note: Full integration would execute CLI and verify output file
        // For now, we validate the argument parsing which is the first step
        // Full file generation test requires async execution and temp file handling
    }
    
    @Test("CLI respects retina flag with custom size")
    func cli_respects_retina_with_custom_size() throws {
        // Test --size 512 --retina produces 1024×1024px output
        // Expected to FAIL until CLI validation accepts custom sizes
        
        let command = try IconGeneratorCommand.parse([
            "star.fill",
            "--size", "512",
            "--retina"
        ])
        
        #expect(command.size == 512)
        #expect(command.retina == true)
        
        // The final export size calculation should be 512 × 2 = 1024
        // This will be validated when CLI implementation is complete
        let expectedFinalSize = command.retina ? command.size * 2 : command.size
        #expect(expectedFinalSize == 1024)
    }
    
    // Note: Additional integration tests for actual file generation
    // would be added here after CLI implementation is updated.
    // These tests validate the argument parsing layer first.
}
