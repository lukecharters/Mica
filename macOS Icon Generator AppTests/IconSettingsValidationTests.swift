// IconSettingsValidationTests.swift
// Unit tests for IconSettings validation constants and computed properties
// Task T015: Add Unit Tests for Edge Cases
import Testing
import SwiftUI
@testable import macOS_Icon_Generator_App

@Suite(.tags(.unit))
@MainActor
struct IconSettingsValidationTests {
    
    @Test("Minimum size constant is 16")
    func min_size_constant() {
        // Verify minExportSize = 16
        let minSize = IconSettings.minExportSize
        #expect(minSize == 16)
    }
    
    @Test("Maximum size constant is 1024")
    func max_size_constant() {
        // Verify maxExportSize = 1024
        let maxSize = IconSettings.maxExportSize
        #expect(maxSize == 1024)
    }
    
    @Test("Default size constant is 256")
    func default_size_constant() {
        // Verify defaultExportSize = 256
        let defaultSize = IconSettings.defaultExportSize
        #expect(defaultSize == 256)
    }
    
    @Test("isExportSizeValid returns true for valid range")
    func isExportSizeValid_returns_true_for_valid_range() {
        // Test 16, 256, 1024 are all valid
        var settings = IconSettings()
        
        // Test minimum (16)
        settings.exportSize = 16
        #expect(settings.isExportSizeValid == true, "16 should be valid")
        
        // Test default/middle (256)
        settings.exportSize = 256
        #expect(settings.isExportSizeValid == true, "256 should be valid")
        
        // Test maximum (1024)
        settings.exportSize = 1024
        #expect(settings.isExportSizeValid == true, "1024 should be valid")
        
        // Test arbitrary valid value (450)
        settings.exportSize = 450
        #expect(settings.isExportSizeValid == true, "450 should be valid")
        
        // Test another arbitrary valid value (128)
        settings.exportSize = 128
        #expect(settings.isExportSizeValid == true, "128 should be valid")
    }
    
    @Test("isExportSizeValid returns false for invalid range")
    func isExportSizeValid_returns_false_for_invalid_range() {
        // Test 15, 2000 are invalid
        var settings = IconSettings()
        
        // Test below minimum (15)
        settings.exportSize = 15
        #expect(settings.isExportSizeValid == false, "15 should be invalid (below minimum)")
        
        // Test way below minimum (5)
        settings.exportSize = 5
        #expect(settings.isExportSizeValid == false, "5 should be invalid (below minimum)")
        
        // Test above maximum (2000)
        settings.exportSize = 2000
        #expect(settings.isExportSizeValid == false, "2000 should be invalid (above maximum)")
        
        // Test way above maximum (5000)
        settings.exportSize = 5000
        #expect(settings.isExportSizeValid == false, "5000 should be invalid (above maximum)")
        
        // Test slightly above maximum (1025)
        settings.exportSize = 1025
        #expect(settings.isExportSizeValid == false, "1025 should be invalid (above maximum)")
    }
    
    @Test("finalExportSize with retina mode doubles size")
    func finalExportSize_with_retina() {
        // Verify 512 * 2 = 1024 when retina is enabled
        var settings = IconSettings()
        
        // Test with retina disabled
        settings.exportSize = 512
        settings.exportRetinaSize = false
        #expect(settings.finalExportSize == 512, "Without retina, size should be 512")
        
        // Test with retina enabled
        settings.exportRetinaSize = true
        #expect(settings.finalExportSize == 1024, "With retina, 512 should double to 1024")
        
        // Test another size with retina
        settings.exportSize = 256
        settings.exportRetinaSize = true
        #expect(settings.finalExportSize == 512, "With retina, 256 should double to 512")
        
        // Test minimum size with retina
        settings.exportSize = 16
        settings.exportRetinaSize = true
        #expect(settings.finalExportSize == 32, "With retina, 16 should double to 32")
        
        // Test maximum size with retina
        settings.exportSize = 1024
        settings.exportRetinaSize = true
        #expect(settings.finalExportSize == 2048, "With retina, 1024 should double to 2048")
    }
    
    @Test("IconSettings initializes with default values")
    func iconSettings_default_initialization() {
        // Verify default initialization uses defaultExportSize
        let settings = IconSettings()
        #expect(settings.exportSize == IconSettings.defaultExportSize, "Should initialize with default size")
        #expect(settings.exportSize == 256, "Default size should be 256")
        #expect(settings.isExportSizeValid == true, "Default size should be valid")
    }
    
    @Test("Size constants maintain correct relationships")
    func size_constants_relationships() {
        // Verify min < default < max
        let min = IconSettings.minExportSize
        let def = IconSettings.defaultExportSize
        let max = IconSettings.maxExportSize
        
        #expect(min < def, "Minimum should be less than default")
        #expect(def < max, "Default should be less than maximum")
        #expect(min < max, "Minimum should be less than maximum")
        
        // Verify specific values
        #expect(min == 16 && def == 256 && max == 1024, "Constants should have expected values")
    }
    
    @Test("Boundary values are inclusive")
    func boundary_values_are_inclusive() {
        // Verify that min and max are inclusive (not exclusive)
        var settings = IconSettings()
        
        // Test exact minimum is valid
        settings.exportSize = IconSettings.minExportSize
        #expect(settings.isExportSizeValid == true, "Minimum boundary should be inclusive")
        
        // Test exact maximum is valid
        settings.exportSize = IconSettings.maxExportSize
        #expect(settings.isExportSizeValid == true, "Maximum boundary should be inclusive")
    }
}
