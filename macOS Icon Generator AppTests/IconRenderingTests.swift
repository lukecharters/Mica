// IconRenderingTests.swift
import Testing
import SwiftUI
import AppKit
@testable import macOS_Icon_Generator_App

@MainActor
struct IconRenderingTests {

    @Test
    func vm_settings_drive_expected_sizes() throws {
        let vm = IconViewModel()
        // non-retina
        vm.iconSettings.exportSize = 256
        vm.iconSettings.exportRetinaSize = false
        var image = IconRenderer.renderIconSafely(settings: vm.iconSettings)
        #expect(Int(image.size.width) == 256)
        #expect(Int(image.size.height) == 256)
        var rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == 256)
        #expect(rep.pixelsHigh == 256)

        // retina
        vm.iconSettings.exportRetinaSize = true
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
        settings.symbolName = "star.fill"
        settings.baseColor = .blue
        settings.symbolRenderingMode = .monochrome
        settings.symbolColor = .white
        settings.exportSize = 256
        settings.exportRetinaSize = false

        let image = IconRenderer.renderIconSafely(settings: settings)

        // Logical size should equal exportSize for non-retina
        #expect(Int(image.size.width) == Int(settings.exportSize))
        #expect(Int(image.size.height) == Int(settings.exportSize))

        // Pixel size should match finalExportSize (same as exportSize for non-retina)
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == Int(settings.finalExportSize))
        #expect(rep.pixelsHigh == Int(settings.finalExportSize))
    }

    @Test
    func retina_export_has_expected_logical_and_pixel_size() throws {
        var settings = IconSettings()
        settings.symbolName = "star.fill"
        settings.baseColor = .blue
        settings.symbolRenderingMode = .monochrome
        settings.symbolColor = .white
        settings.exportSize = 256
        settings.exportRetinaSize = true // 512px

        let image = IconRenderer.renderIconSafely(settings: settings)

        // Logical size remains exportSize for retina (DPI-scaled)
        #expect(Int(image.size.width) == Int(settings.exportSize))
        #expect(Int(image.size.height) == Int(settings.exportSize))

        // Pixel size should be 2x (finalExportSize)
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        #expect(rep.pixelsWide == Int(settings.finalExportSize))
        #expect(rep.pixelsHigh == Int(settings.finalExportSize))
    }
}
