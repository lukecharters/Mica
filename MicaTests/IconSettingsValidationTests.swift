// IconSettingsValidationTests.swift
// Unit tests for IconSettings validation constants and computed properties
// Task T015: Add Unit Tests for Edge Cases
import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct IconSettingsValidationTests {
    
    @Test("Minimum size constant is 16")
    func min_size_constant() {
        // Verify minExportSize = 16
        let minSize = ExportSpec.minSize
        #expect(minSize == 16)
    }
    
    @Test("Maximum size constant is 1024")
    func max_size_constant() {
        // Verify maxExportSize = 1024
        let maxSize = ExportSpec.maxSize
        #expect(maxSize == 1024)
    }
    
    @Test("Default size constant is 512")
    func default_size_constant() {
        // Verify defaultExportSize = 512
        let defaultSize = ExportSpec.defaultSize
        #expect(defaultSize == 512)
    }
    
    @Test("export.isSizeValid returns true for valid range")
    func isExportSizeValid_returns_true_for_valid_range() {
        // Test 16, 256, 1024 are all valid
        var settings = IconSettings()
        
        // Test minimum (16)
        settings.export.size = 16
        #expect(settings.export.isSizeValid == true, "16 should be valid")
        
        // Test default/middle (256)
        settings.export.size = 256
        #expect(settings.export.isSizeValid == true, "256 should be valid")
        
        // Test maximum (1024)
        settings.export.size = 1024
        #expect(settings.export.isSizeValid == true, "1024 should be valid")
        
        // Test arbitrary valid value (450)
        settings.export.size = 450
        #expect(settings.export.isSizeValid == true, "450 should be valid")
        
        // Test another arbitrary valid value (128)
        settings.export.size = 128
        #expect(settings.export.isSizeValid == true, "128 should be valid")
    }
    
    @Test("export.isSizeValid returns false for invalid range")
    func isExportSizeValid_returns_false_for_invalid_range() {
        // Test 15, 2000 are invalid
        var settings = IconSettings()
        
        // Test below minimum (15)
        settings.export.size = 15
        #expect(settings.export.isSizeValid == false, "15 should be invalid (below minimum)")
        
        // Test way below minimum (5)
        settings.export.size = 5
        #expect(settings.export.isSizeValid == false, "5 should be invalid (below minimum)")
        
        // Test above maximum (2000)
        settings.export.size = 2000
        #expect(settings.export.isSizeValid == false, "2000 should be invalid (above maximum)")
        
        // Test way above maximum (5000)
        settings.export.size = 5000
        #expect(settings.export.isSizeValid == false, "5000 should be invalid (above maximum)")
        
        // Test slightly above maximum (1025)
        settings.export.size = 1025
        #expect(settings.export.isSizeValid == false, "1025 should be invalid (above maximum)")
    }
    
    @Test("export.pixelSize with retina mode doubles size")
    func finalExportSize_with_retina() {
        // Verify 512 * 2 = 1024 when retina is enabled
        var settings = IconSettings()
        
        // Test with retina disabled
        settings.export.size = 512
        settings.export.isRetina = false
        #expect(settings.export.pixelSize == 512, "Without retina, size should be 512")
        
        // Test with retina enabled
        settings.export.isRetina = true
        #expect(settings.export.pixelSize == 1024, "With retina, 512 should double to 1024")
        
        // Test another size with retina
        settings.export.size = 256
        settings.export.isRetina = true
        #expect(settings.export.pixelSize == 512, "With retina, 256 should double to 512")
        
        // Test minimum size with retina
        settings.export.size = 16
        settings.export.isRetina = true
        #expect(settings.export.pixelSize == 32, "With retina, 16 should double to 32")
        
        // Test maximum size with retina
        settings.export.size = 1024
        settings.export.isRetina = true
        #expect(settings.export.pixelSize == 2048, "With retina, 1024 should double to 2048")
    }
    
    @Test("IconSettings initializes with default values")
    func iconSettings_default_initialization() {
        // Verify default initialization uses defaultExportSize
        let settings = IconSettings()
        #expect(settings.export.size == ExportSpec.defaultSize, "Should initialize with default size")
        #expect(settings.export.size == 512, "Default size should be 512")
        #expect(settings.export.isSizeValid == true, "Default size should be valid")
    }
    
    @Test("Size constants maintain correct relationships")
    func size_constants_relationships() {
        // Verify min < default < max
        let min = ExportSpec.minSize
        let def = ExportSpec.defaultSize
        let max = ExportSpec.maxSize
        
        #expect(min < def, "Minimum should be less than default")
        #expect(def < max, "Default should be less than maximum")
        #expect(min < max, "Minimum should be less than maximum")
        
        // Verify specific values
        #expect(min == 16 && def == 512 && max == 1024, "Constants should have expected values")
    }
    
    @Test("Boundary values are inclusive")
    func boundary_values_are_inclusive() {
        // Verify that min and max are inclusive (not exclusive)
        var settings = IconSettings()
        
        // Test exact minimum is valid
        settings.export.size = ExportSpec.minSize
        #expect(settings.export.isSizeValid == true, "Minimum boundary should be inclusive")
        
        // Test exact maximum is valid
        settings.export.size = ExportSpec.maxSize
        #expect(settings.export.isSizeValid == true, "Maximum boundary should be inclusive")
    }
}
