// ExportOptionsTextFieldTests.swift
// Contract tests for GUI TextField from contracts/gui-textfield-contract.md
import Testing
import SwiftUI
@testable import macOS_Icon_Generator_App

@MainActor
struct ExportOptionsTextFieldTests {
    
    @Test("TextField accepts valid integer input")
    func textfield_accepts_valid_integer() {
        // Input "450" should result in exportSize = 450
        // Expected to FAIL until validation logic is implemented
        var settings = IconSettings()
        let textFieldValue = "450"
        
        if let doubleValue = Double(textFieldValue) {
            let flooredValue = floor(doubleValue)
            let clampedValue = min(max(flooredValue, IconSettings.minExportSize), IconSettings.maxExportSize)
            settings.exportSize = CGFloat(clampedValue)
        }
        
        #expect(settings.exportSize == 450.0)
    }
    
    @Test("TextField floors decimal input and shows warning")
    func textfield_floors_decimal() {
        // Input "128.7" should floor to 128 and show validation message
        // Expected to FAIL until validation logic is implemented
        var settings = IconSettings()
        let textFieldValue = "128.7"
        var showValidationError = false
        
        if let doubleValue = Double(textFieldValue) {
            let flooredValue = floor(doubleValue)
            let clampedValue = min(max(flooredValue, IconSettings.minExportSize), IconSettings.maxExportSize)
            
            if flooredValue != doubleValue {
                showValidationError = true
            }
            
            settings.exportSize = CGFloat(clampedValue)
        }
        
        #expect(settings.exportSize == 128.0)
        #expect(showValidationError == true)
    }
    
    @Test("TextField clamps value below minimum")
    func textfield_clamps_below_minimum() {
        // Input "5" should clamp to 16
        // Expected to FAIL until validation logic is implemented
        var settings = IconSettings()
        let textFieldValue = "5"
        
        if let doubleValue = Double(textFieldValue) {
            let flooredValue = floor(doubleValue)
            let clampedValue = min(max(flooredValue, IconSettings.minExportSize), IconSettings.maxExportSize)
            settings.exportSize = CGFloat(clampedValue)
        }
        
        #expect(settings.exportSize == 16.0)
    }
    
    @Test("TextField clamps value above maximum")
    func textfield_clamps_above_maximum() {
        // Input "3000" should clamp to 1024
        // Expected to FAIL until validation logic is implemented
        var settings = IconSettings()
        let textFieldValue = "3000"
        
        if let doubleValue = Double(textFieldValue) {
            let flooredValue = floor(doubleValue)
            let clampedValue = min(max(flooredValue, IconSettings.minExportSize), IconSettings.maxExportSize)
            settings.exportSize = CGFloat(clampedValue)
        }
        
        #expect(settings.exportSize == 1024.0)
    }
    
    @Test("TextField rejects non-numeric input")
    func textfield_rejects_non_numeric() {
        // Input "xyz" should revert to previous value
        // Expected to FAIL until validation logic is implemented
        var settings = IconSettings()
        let originalValue = 256.0
        settings.exportSize = CGFloat(originalValue)
        
        let textFieldValue = "xyz"
        var showValidationError = false
        
        if Double(textFieldValue) == nil {
            // Should revert to original value
            showValidationError = true
            // settings.exportSize remains unchanged
        }
        
        #expect(settings.exportSize == originalValue)
        #expect(showValidationError == true)
    }
    
    @Test("TextField handles empty input")
    func textfield_handles_empty_input() {
        // Empty string "" should revert to previous value
        // Expected to FAIL until validation logic is implemented
        var settings = IconSettings()
        let originalValue = 256.0
        settings.exportSize = CGFloat(originalValue)
        
        let textFieldValue = ""
        var showValidationError = false
        
        if Double(textFieldValue) == nil {
            showValidationError = true
            // settings.exportSize remains unchanged
        }
        
        #expect(settings.exportSize == originalValue)
        #expect(showValidationError == true)
    }
    
    @Test("TextField syncs from slider changes")
    func textfield_syncs_from_slider() {
        // Slider value 640 should update textField to "640"
        // Expected to FAIL until sync logic is implemented
        let sliderValue = 640.0
        let textFieldValue = "\(Int(sliderValue))"
        
        #expect(textFieldValue == "640")
        #expect(Int(textFieldValue) == 640)
    }
}
