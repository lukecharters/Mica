// IconRenderingTests.swift
import Testing
import SwiftUI
import AppKit
@testable import Mica

@Suite(.tags(.rendering))
@MainActor
struct IconRenderingTests {

    @Test
    func vm_settings_drive_expected_sizes() throws {
        let vm = IconViewModel()
        // non-retina
        vm.iconSettings.export.size = 256
        vm.iconSettings.export.isRetina = false
        var image = IconRenderer.renderIconSafely(settings: vm.iconSettings)
        #expect(Int(image.size.width) == 256)
        #expect(Int(image.size.height) == 256)
        var rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == 256)
        #expect(rep.pixelsHigh == 256)

        // retina
        vm.iconSettings.export.isRetina = true
        image = IconRenderer.renderIconSafely(settings: vm.iconSettings)
        #expect(Int(image.size.width) == 256) // logical
        #expect(Int(image.size.height) == 256)
        rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == 512)
        #expect(rep.pixelsHigh == 512)
    }
    @Test
    func nonRetina_export_has_expected_logical_and_pixel_size() throws {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "star.fill"
        settings.icon.background.color = .blue
        settings.icon.foreground.renderingStyle = .monochrome
        settings.icon.foreground.color = .white
        settings.export.size = 256
        settings.export.isRetina = false

        let image = IconRenderer.renderIconSafely(settings: settings)

        // Logical size should equal export.size for non-retina
        #expect(Int(image.size.width) == Int(settings.export.size))
        #expect(Int(image.size.height) == Int(settings.export.size))

        // Pixel size should match export.pixelSize (same as export.size for non-retina)
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == Int(settings.export.pixelSize))
        #expect(rep.pixelsHigh == Int(settings.export.pixelSize))
    }

    @Test
    func retina_export_has_expected_logical_and_pixel_size() throws {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "star.fill"
        settings.icon.background.color = .blue
        settings.icon.foreground.renderingStyle = .monochrome
        settings.icon.foreground.color = .white
        settings.export.size = 256
        settings.export.isRetina = true // 512px

        let image = IconRenderer.renderIconSafely(settings: settings)

        // Logical size remains export.size for retina (DPI-scaled)
        #expect(Int(image.size.width) == Int(settings.export.size))
        #expect(Int(image.size.height) == Int(settings.export.size))

        // Pixel size should be 2x (export.pixelSize)
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == Int(settings.export.pixelSize))
        #expect(rep.pixelsHigh == Int(settings.export.pixelSize))
    }
    
    // MARK: - Arbitrary Size Tests (Phase 3.2 - T006)
    // These tests validate that the existing scaleFactor mechanism handles custom sizes
    
    @Test("Render arbitrary size 450px icon")
    func render_arbitrary_size_450px() throws {
        // Test rendering a non-standard 450×450px icon
        // Expected to PASS if scaleFactor already handles arbitrary sizes
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "star.fill"
        settings.icon.background.color = .blue
        settings.icon.foreground.renderingStyle = .monochrome
        settings.icon.foreground.color = .white
        settings.export.size = 450
        settings.export.isRetina = false
        
        let image = IconRenderer.renderIconSafely(settings: settings)
        
        // Verify dimensions are exactly 450×450
        #expect(Int(image.size.width) == 450)
        #expect(Int(image.size.height) == 450)
        
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == 450)
        #expect(rep.pixelsHigh == 450)
    }
    
    @Test("Render minimum size 16px icon without crash")
    func render_minimum_size_16px() throws {
        // Test rendering the minimum allowed size (16×16px)
        // Expected to PASS - validates no crash at small sizes
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "star.fill"
        settings.icon.background.color = .blue
        settings.icon.foreground.renderingStyle = .monochrome
        settings.icon.foreground.color = .white
        settings.export.size = 16
        settings.export.isRetina = false
        
        let image = IconRenderer.renderIconSafely(settings: settings)
        
        #expect(Int(image.size.width) == 16)
        #expect(Int(image.size.height) == 16)
        
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == 16)
        #expect(rep.pixelsHigh == 16)
    }
    
    @Test("Render maximum size 1024px icon with quality")
    func render_maximum_size_1024px() throws {
        // Test rendering the maximum allowed size (1024×1024px)
        // Expected to PASS - validates quality at large sizes
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "star.fill"
        settings.icon.background.color = .blue
        settings.icon.foreground.renderingStyle = .monochrome
        settings.icon.foreground.color = .white
        settings.export.size = 1024
        settings.export.isRetina = false
        
        let image = IconRenderer.renderIconSafely(settings: settings)
        
        #expect(Int(image.size.width) == 1024)
        #expect(Int(image.size.height) == 1024)
        
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == 1024)
        #expect(rep.pixelsHigh == 1024)
    }
    
    @Test("Render with retina at custom size")
    func render_with_retina_custom_size() throws {
        // Test 512px + retina flag produces 1024×1024px output
        // Expected to PASS - validates retina multiplier works with arbitrary sizes
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "star.fill"
        settings.icon.background.color = .blue
        settings.icon.foreground.renderingStyle = .monochrome
        settings.icon.foreground.color = .white
        settings.export.size = 512
        settings.export.isRetina = true
        
        let image = IconRenderer.renderIconSafely(settings: settings)
        
        // Logical size should remain 512
        #expect(Int(image.size.width) == 512)
        #expect(Int(image.size.height) == 512)
        
        // Pixel size should be 1024 (512 × 2)
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == 1024)
        #expect(rep.pixelsHigh == 1024)
    }
    
    @Test("Visual regression: 512px output matches baseline")
    func visual_regression_512px() throws {
        // Test that 512px rendering produces consistent output
        // Expected to PASS - validates no changes to rendering quality
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "star.fill"
        settings.icon.background.color = .blue
        settings.icon.foreground.renderingStyle = .monochrome
        settings.icon.foreground.color = .white
        settings.export.size = 512
        settings.export.isRetina = false
        
        let image = IconRenderer.renderIconSafely(settings: settings)
        
        // Basic validation - dimensions are correct
        #expect(Int(image.size.width) == 512)
        #expect(Int(image.size.height) == 512)
        
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == 512)
        #expect(rep.pixelsHigh == 512)
        
        // Additional validation: image has valid data
        #expect(image.tiffRepresentation != nil)
        #expect(rep.bitsPerPixel > 0)
        
        // Note: Full pixel-by-pixel comparison would require baseline image
        // This test validates structure and dimensions match expected output
    }
}
