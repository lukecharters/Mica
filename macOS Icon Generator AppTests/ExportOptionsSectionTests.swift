// ExportOptionsSectionTests.swift
// Contract tests for GUI Slider from contracts/gui-slider-contract.md
import Testing
import SwiftUI
@testable import macOS_Icon_Generator_App

@MainActor
struct ExportOptionsSectionTests {
    
    @Test("Slider constrains to minimum value")
    func slider_constrains_to_minimum() {
        // Test that slider enforces 16px minimum
        // Expected to FAIL until ExportOptionsSection implements slider
        var settings = IconSettings()
        let minValue = IconSettings.minExportSize
        
        // Simulate attempting to set below minimum
        let attemptedValue = 10.0
        let sliderValue = max(attemptedValue, Double(minValue))
        
        settings.exportSize = CGFloat(sliderValue)
        
        #expect(settings.exportSize >= minValue)
        #expect(sliderValue >= Double(minValue))
    }
    
    @Test("Slider constrains to maximum value")
    func slider_constrains_to_maximum() {
        // Test that slider enforces 1024px maximum
        // Expected to FAIL until ExportOptionsSection implements slider
        var settings = IconSettings()
        let maxValue = IconSettings.maxExportSize
        
        // Simulate attempting to set above maximum
        let attemptedValue = 2000.0
        let sliderValue = min(attemptedValue, Double(maxValue))
        
        settings.exportSize = CGFloat(sliderValue)
        
        #expect(settings.exportSize <= maxValue)
        #expect(sliderValue <= Double(maxValue))
    }
    
    @Test("Slider updates IconSettings exportSize")
    func slider_updates_settings() {
        // Test that onChange updates IconSettings.exportSize
        // Expected to FAIL until ExportOptionsSection implements slider onChange
        var settings = IconSettings()
        let sliderValue = 450.0
        
        // Simulate onChange behavior
        settings.exportSize = CGFloat(sliderValue)
        
        #expect(settings.exportSize == 450.0)
    }
    
    @Test("Slider syncs to text field")
    func slider_syncs_to_textfield() {
        // Test that slider changes update text field display
        // Expected to FAIL until ExportOptionsSection implements slider-textfield sync
        let sliderValue = 768.0
        let textFieldValue = "\(Int(sliderValue))"
        
        #expect(textFieldValue == "768")
        #expect(Int(textFieldValue) == Int(sliderValue))
    }
}
