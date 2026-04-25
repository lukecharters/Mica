// IconExportTests.swift - Comprehensive test for exporting icons with various settings
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct IconExportTests {
    
    // Test configurations covering all major options
    static func generateTestConfigurations() -> [(name: String, settings: IconSettings)] {
        var configs: [(String, IconSettings)] = []
        
        // Test 1: Basic monochrome icon
        var basic = IconSettings()
        basic.symbolName = "star.fill"
        basic.baseColor = .blue
        basic.symbolRenderingMode = .monochrome
        basic.symbolColor = .white
        basic.exportSize = 256
        basic.exportRetinaSize = false
        configs.append(("01_basic_monochrome", basic))
        
        // Test 2: Hierarchical rendering
        var hierarchical = IconSettings()
        hierarchical.symbolName = "folder.fill.badge.plus"
        hierarchical.baseColor = .green
        hierarchical.symbolRenderingMode = .hierarchical
        hierarchical.hierarchicalSymbolColor = .white
        hierarchical.exportSize = 256
        hierarchical.exportRetinaSize = false
        configs.append(("02_hierarchical", hierarchical))
        
        // Test 3: Multicolor rendering
        var multicolor = IconSettings()
        multicolor.symbolName = "drop.fill"
        multicolor.baseColor = .gray
        multicolor.symbolRenderingMode = .multicolor
        multicolor.exportSize = 256
        multicolor.exportRetinaSize = false
        configs.append(("03_multicolor", multicolor))
        
        // Test 4: Palette rendering
        var palette = IconSettings()
        palette.symbolName = "shield.lefthalf.filled.slash"
        palette.baseColor = .purple
        palette.symbolRenderingMode = .palette
        palette.paletteSymbolPrimaryColor = .white
        palette.paletteSymbolSecondaryColor = .yellow
        palette.paletteSymbolTertiaryColor = .orange
        palette.exportSize = 256
        palette.exportRetinaSize = false
        configs.append(("04_palette", palette))
        
        // Test 5: Custom gradient colors
        var customGradient = IconSettings()
        customGradient.symbolName = "flame.fill"
        customGradient.useCustomColors = true
        customGradient.customPrimaryColor = .orange
        customGradient.customSecondaryColor = .red
        customGradient.symbolRenderingMode = .monochrome
        customGradient.symbolColor = .yellow
        customGradient.exportSize = 256
        customGradient.exportRetinaSize = false
        configs.append(("05_custom_gradient", customGradient))
        
        // Test 6: Retina export (512x512)
        var retina = IconSettings()
        retina.symbolName = "display"
        retina.baseColor = .indigo
        retina.symbolRenderingMode = .monochrome
        retina.symbolColor = .white
        retina.exportSize = 256
        retina.exportRetinaSize = true  // This will make it 512x512
        configs.append(("06_retina_512", retina))
        
        // Test 7: Large size (1024x1024)
        var large = IconSettings()
        large.symbolName = "app.gift.fill"
        large.baseColor = .pink
        large.symbolRenderingMode = .monochrome
        large.symbolColor = .white
        large.exportSize = 512
        large.exportRetinaSize = true  // This will make it 1024x1024
        configs.append(("07_large_1024", large))
        
        // Test 8: Small size (128x128)
        var small = IconSettings()
        small.symbolName = "heart.fill"
        small.baseColor = .red
        small.symbolRenderingMode = .monochrome
        small.symbolColor = .white
        small.exportSize = 128
        small.exportRetinaSize = false
        configs.append(("08_small_128", small))
        
        // Test 9: Complex hierarchical with custom gradient
        var complexHierarchical = IconSettings()
        complexHierarchical.symbolName = "person.crop.circle.badge.checkmark"
        complexHierarchical.useCustomColors = true
        complexHierarchical.customPrimaryColor = .mint
        complexHierarchical.customSecondaryColor = .teal
        complexHierarchical.symbolRenderingMode = .hierarchical
        complexHierarchical.hierarchicalSymbolColor = .white
        complexHierarchical.exportSize = 256
        complexHierarchical.exportRetinaSize = false
        configs.append(("09_complex_hierarchical", complexHierarchical))
        
        // Test 10: Dark background with light symbol
        var darkBackground = IconSettings()
        darkBackground.symbolName = "moon.stars.fill"
        darkBackground.baseColor = Color(NSColor(white: 0.1, alpha: 1.0))
        darkBackground.symbolRenderingMode = .monochrome
        darkBackground.symbolColor = .yellow
        darkBackground.exportSize = 256
        darkBackground.exportRetinaSize = false
        configs.append(("10_dark_background", darkBackground))
        
        // Test 11: Palette with transparency
        var paletteTransparency = IconSettings()
        paletteTransparency.symbolName = "cloud.sun.rain.fill"
        paletteTransparency.baseColor = .blue
        paletteTransparency.symbolRenderingMode = .palette
        paletteTransparency.paletteSymbolPrimaryColor = .white
        paletteTransparency.paletteSymbolSecondaryColor = .yellow.opacity(0.8)
        paletteTransparency.paletteSymbolTertiaryColor = .blue.opacity(0.6)
        paletteTransparency.exportSize = 256
        paletteTransparency.exportRetinaSize = false
        configs.append(("11_palette_transparency", paletteTransparency))
        
        // Test 12: Edge case - very light colors
        var lightColors = IconSettings()
        lightColors.symbolName = "sun.max.fill"
        lightColors.useCustomColors = true
        lightColors.customPrimaryColor = Color(NSColor(white: 0.95, alpha: 1.0))
        lightColors.customSecondaryColor = Color(NSColor(white: 0.85, alpha: 1.0))
        lightColors.symbolRenderingMode = .monochrome
        lightColors.symbolColor = .orange
        lightColors.exportSize = 256
        lightColors.exportRetinaSize = false
        configs.append(("12_light_colors", lightColors))
        
        // Test 13: Display P3 with vibrant colors
        var displayP3 = IconSettings()
        displayP3.symbolName = "paintpalette.fill"
        displayP3.useCustomColors = true
        displayP3.customPrimaryColor = Color(red: 1.0, green: 0.0, blue: 0.5)
        displayP3.customSecondaryColor = Color(red: 0.0, green: 0.8, blue: 1.0)
        displayP3.symbolRenderingMode = .monochrome
        displayP3.symbolColor = .white
        displayP3.exportSize = 256
        displayP3.exportRetinaSize = false
        displayP3.exportColorSpace = .displayP3
        configs.append(("13_display_p3_vibrant", displayP3))
        
        // Test 14: Compare sRGB vs Display P3
        var srgbCompare = IconSettings()
        srgbCompare.symbolName = "camera.filters"
        srgbCompare.useCustomColors = true
        srgbCompare.customPrimaryColor = Color(red: 1.0, green: 0.2, blue: 0.4)
        srgbCompare.customSecondaryColor = Color(red: 0.2, green: 0.8, blue: 1.0)
        srgbCompare.symbolRenderingMode = .monochrome
        srgbCompare.symbolColor = .white
        srgbCompare.exportSize = 256
        srgbCompare.exportRetinaSize = false
        srgbCompare.exportColorSpace = .sRGB
        configs.append(("14_srgb_comparison", srgbCompare))
        
        // Test 15: Same as above but in Display P3
        var p3Compare = srgbCompare
        p3Compare.exportColorSpace = .displayP3
        configs.append(("15_display_p3_comparison", p3Compare))
        
        return configs
    }
    
    // Export all test icons to a specified directory
    static func exportTestIcons(to directory: URL) async throws {
        let configs = generateTestConfigurations()
        
        // Create test directory if it doesn't exist
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Create a summary HTML file
        var htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Icon Export Test Results</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; background: #f5f5f5; }
                h1 { color: #333; }
                .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
                .icon-card { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
                .icon-preview { width: 100%; height: 256px; display: flex; align-items: center; justify-content: center; background: #f0f0f0; border-radius: 8px; margin-bottom: 15px; }
                .icon-preview img { max-width: 100%; max-height: 100%; }
                .icon-info { font-size: 14px; color: #666; }
                .icon-info strong { color: #333; }
                .icon-name { font-size: 18px; font-weight: 600; margin-bottom: 10px; }
            </style>
        </head>
        <body>
            <h1>Icon Export Test Results</h1>
            <p>Generated on \(Date().formatted())</p>
            <div class="grid">
        """
        
        print("Starting icon export tests...")
        print("Exporting to: \(directory.path)")
        
        for (index, (name, settings)) in configs.enumerated() {
            print("[\(index + 1)/\(configs.count)] Exporting: \(name)")
            
            // Render the icon
            let icon = IconRenderer.renderIcon(settings: settings)
            
            // Create filename
            let filename = "\(name)_\(Int(settings.finalExportSize))x\(Int(settings.finalExportSize)).png"
            let fileURL = directory.appendingPathComponent(filename)
            
            // Export as PNG
            if let tiffData = icon.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                try pngData.write(to: fileURL)
                
                // Add to HTML
                htmlContent += """
                <div class="icon-card">
                    <div class="icon-name">\(name)</div>
                    <div class="icon-preview">
                        <img src="\(filename)" alt="\(name)">
                    </div>
                    <div class="icon-info">
                        <strong>Symbol:</strong> \(settings.symbolName)<br>
                        <strong>Size:</strong> \(Int(settings.finalExportSize))×\(Int(settings.finalExportSize))<br>
                        <strong>Rendering:</strong> \(settings.symbolRenderingMode.rawValue)<br>
                        <strong>Custom Colors:</strong> \(settings.useCustomColors ? "Yes" : "No")<br>
                        <strong>Color Space:</strong> \(settings.exportColorSpace.rawValue)
                    </div>
                </div>
                """
            } else {
                print("  ⚠️  Failed to export: \(name)")
            }
        }
        
        htmlContent += """
            </div>
        </body>
        </html>
        """
        
        // Save HTML summary
        let htmlURL = directory.appendingPathComponent("test_results.html")
        try htmlContent.write(to: htmlURL, atomically: true, encoding: .utf8)
        
        print("\n✅ Export complete!")
        print("📁 Icons saved to: \(directory.path)")
        print("🌐 Open test_results.html to view all icons")
        
        // Open the directory in Finder
        NSWorkspace.shared.selectFile(htmlURL.path, inFileViewerRootedAtPath: directory.path)
    }
    
    // Run tests with save panel (better for sandboxed apps)
    static func runTestsWithSavePanel() async throws {
        let savePanel = NSOpenPanel()
        savePanel.title = "Choose Location for Test Icons"
        savePanel.message = "Select where to save the test icon exports"
        savePanel.prompt = "Select Folder"
        savePanel.canChooseFiles = false
        savePanel.canChooseDirectories = true
        savePanel.canCreateDirectories = true
        savePanel.allowsMultipleSelection = false
        
        let response = await savePanel.begin()
        
        if response == .OK, let url = savePanel.url {
            let testDirectory = url.appendingPathComponent("IconExportTests_\(Date().timeIntervalSince1970)")
            try await exportTestIcons(to: testDirectory)
        }
    }
    
    // Convenience method to run tests with default desktop location (requires entitlement)
    static func runTests() async throws {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let testDirectory = desktop.appendingPathComponent("IconExportTests_\(Date().timeIntervalSince1970)")
        try await exportTestIcons(to: testDirectory)
    }
}

// Extension to make it easy to call from your app
extension IconGeneratorApp {
    func runExportTests() {
        Task {
            do {
                // Use save panel version for better compatibility
                try await IconExportTests.runTestsWithSavePanel()
            } catch {
                print("Export test failed: \(error)")
            }
        }
    }
}
