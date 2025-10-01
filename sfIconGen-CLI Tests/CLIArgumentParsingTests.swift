// CLIArgumentParsingTests.swift
// Contract tests for CLI Size Argument from contracts/cli-size-contract.md
import Testing
import ArgumentParser
@testable import sfIconGen_CLI

struct CLIArgumentParsingTests {
    
    @Test("CLI accepts arbitrary size within valid range")
    func cli_accepts_arbitrary_size() throws {
        // Test --size 450 is accepted
        // Expected to FAIL until validation updated to accept 16-1024 range
        let command = try IconGeneratorCommand.parse(["star.fill", "--size", "450"])
        #expect(command.size == 450)
    }
    
    @Test("CLI accepts minimum size boundary")
    func cli_accepts_minimum_size() throws {
        // Test --size 16 is accepted
        // Expected to FAIL until validation updated
        let command = try IconGeneratorCommand.parse(["star.fill", "--size", "16"])
        #expect(command.size == 16)
    }
    
    @Test("CLI accepts maximum size boundary")
    func cli_accepts_maximum_size() throws {
        // Test --size 1024 is accepted
        // Should PASS as 1024 is already in valid sizes
        let command = try IconGeneratorCommand.parse(["star.fill", "--size", "1024"])
        #expect(command.size == 1024)
    }
    
    @Test("CLI rejects size below minimum")
    func cli_rejects_below_minimum() throws {
        // Test --size 15 throws ValidationError
        // Expected to FAIL until new validation range implemented
        #expect(throws: ValidationError.self) {
            try IconGeneratorCommand.parse(["star.fill", "--size", "15"])
        }
    }
    
    @Test("CLI rejects size above maximum")
    func cli_rejects_above_maximum() throws {
        // Test --size 2000 throws ValidationError
        // Expected to FAIL until new validation range implemented
        #expect(throws: ValidationError.self) {
            try IconGeneratorCommand.parse(["star.fill", "--size", "2000"])
        }
    }
    
    @Test("CLI rejects decimal size values")
    func cli_rejects_decimal() throws {
        // Test --size 128.5 throws ValidationError
        // Expected to FAIL until decimal rejection implemented
        #expect(throws: ValidationError.self) {
            try IconGeneratorCommand.parse(["star.fill", "--size", "128.5"])
        }
    }
    
    @Test("CLI rejects non-numeric size values")
    func cli_rejects_non_numeric() throws {
        // Test --size abc throws ValidationError
        // Should PASS as current validation already rejects non-numeric
        #expect(throws: ValidationError.self) {
            try IconGeneratorCommand.parse(["star.fill", "--size", "abc"])
        }
    }
    
    @Test("CLI uses default size when omitted")
    func cli_uses_default_when_omitted() throws {
        // Test no --size flag defaults to 256
        // Should PASS as default already exists
        let command = try IconGeneratorCommand.parse(["star.fill"])
        #expect(command.size == 256)
    }
    
    @Test("CLI short flag works equivalently to long flag")
    func cli_short_flag_works() throws {
        // Test -s 450 same as --size 450
        // Expected to FAIL until validation accepts arbitrary sizes
        let command = try IconGeneratorCommand.parse(["star.fill", "-s", "450"])
        #expect(command.size == 450)
    }
}
