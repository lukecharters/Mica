// ShadowVariationHarness.swift - Test shadow variations at 1024px with fixed values
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ShadowVariationHarness {
    
    // Generate test configurations for shadow variations
    static func generateShadowTestConfigurations() -> [(name: String, settings: IconSettings, shadowMods: ShadowModifications)] {
        var configs: [(String, IconSettings, ShadowModifications)] = []
        
        // Fixed size: 1024px
        let size: CGFloat = 512  // with retina = 1024
        let retina = true
        
        // Define shadow variations with different focus areas
        let shadowVariations: [(name: String, description: String, backgroundOpacity: CGFloat, backgroundRadius: CGFloat, backgroundYOffset: CGFloat, symbolOpacity: CGFloat, symbolRadius: CGFloat, symbolYOffset: CGFloat)] = [
            // Background shadow variations (symbol shadow kept minimal)
            ("bg_subtle", "Subtle Background Shadow", 0.15, 4.0, 5.0, 0.1, 2.0, 2.0),
            ("bg_normal", "Normal Background Shadow", 0.31, 8.0, 10.0, 0.1, 2.0, 2.0),
            ("bg_strong", "Strong Background Shadow", 0.4, 12.0, 15.0, 0.1, 2.0, 2.0),
            ("bg_dramatic", "Dramatic Background Shadow", 0.6, 20.0, 25.0, 0.1, 2.0, 2.0),
            
            // Symbol shadow variations (background shadow kept moderate)
            ("sym_none", "No Symbol Shadow", 0.31, 8.0, 10.0, 0.23, 8.0, 10.0),
            ("sym_subtle", "Subtle Symbol Shadow", 0.31, 8.0, 10.0, 0.2, 8.0, 10.0),
            ("sym_normal", "Normal Symbol Shadow", 0.31, 8.0, 10.0, 0.35, 8.0, 10.0),
            ("sym_strong", "Strong Symbol Shadow", 0.31, 8.0, 10.0, 0.5, 8.0, 10.0),
            ("sym_dramatic", "Dramatic Symbol Shadow", 0.31, 8.0, 10.0, 0.7, 8.0, 10.0),
            
            // Combined variations
            ("both_subtle", "Both Subtle", 0.15, 4.0, 5.0, 0.2, 3.0, 3.0),
            ("both_normal", "Both Normal", 0.31, 8.0, 10.0, 0.35, 6.0, 6.0),
            ("both_strong", "Both Strong", 0.4, 12.0, 15.0, 0.5, 10.0, 10.0),
            
            // Offset variations (normal shadows with different offsets)
            ("offset_close", "Close Shadow", 0.31, 8.0, 3.0, 0.35, 6.0, 2.0),
            ("offset_far", "Far Shadow", 0.31, 8.0, 20.0, 0.35, 6.0, 15.0),
            
            // Radius variations (normal opacity with different blur)
            ("blur_sharp", "Sharp Shadows", 0.31, 2.0, 10.0, 0.35, 1.0, 6.0),
            ("blur_soft", "Soft Shadows", 0.31, 20.0, 10.0, 0.35, 15.0, 6.0)
        ]
        
        // Generate configurations
        for (shadowName, description, bgOpacity, bgRadius, bgYOffset, symOpacity, symRadius, symYOffset) in shadowVariations {
            var settings = IconSettings()
            // Keep defaults for icon and background
            settings.icon.foreground.symbolName = "folder.fill.badge.plus"
            settings.icon.background.color = .blue
            settings.icon.foreground.renderingStyle = .monochrome
            settings.icon.foreground.color = .white
            settings.export.size = size
            settings.export.isRetina = retina
            
            let shadowMods = ShadowModifications(
                description: description,
                backgroundOpacity: bgOpacity,
                backgroundRadius: bgRadius,
                backgroundYOffset: bgYOffset,
                symbolOpacity: symOpacity,
                symbolRadius: symRadius,
                symbolYOffset: symYOffset
            )
            
            configs.append((shadowName, settings, shadowMods))
        }
        
        return configs
    }
    
    // Export all shadow variation test icons
    static func exportShadowTestIcons(to directory: URL) async throws {
        let configs = generateShadowTestConfigurations()
        
        // Create test directory if it doesn't exist
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Create a summary HTML file with better visualization
        var htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Icon Shadow Variation Test - 1024px</title>
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif; 
                    margin: 20px; 
                    background: #f5f5f5; 
                }
                h1 { color: #333; margin-bottom: 10px; }
                p { color: #666; margin-bottom: 30px; }
                .grid { 
                    display: grid; 
                    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); 
                    gap: 20px; 
                    margin-bottom: 40px;
                }
                .icon-card { 
                    background: white; 
                    border-radius: 12px; 
                    padding: 20px; 
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1); 
                    text-align: center;
                }
                .icon-preview { 
                    width: 100%; 
                    height: 240px; 
                    display: flex; 
                    align-items: center; 
                    justify-content: center; 
                    background: #fafafa; 
                    border-radius: 8px; 
                    margin-bottom: 15px; 
                    position: relative;
                }
                .icon-preview img { 
                    max-width: 90%; 
                    max-height: 90%; 
                    image-rendering: -webkit-optimize-contrast;
                }
                .icon-info { 
                    font-size: 13px; 
                    color: #666; 
                    line-height: 1.6;
                }
                .icon-info strong { 
                    color: #333; 
                    display: block;
                    margin-bottom: 4px;
                    font-size: 15px;
                }
                .shadow-params {
                    font-family: 'SF Mono', Monaco, monospace;
                    font-size: 12px;
                    color: #555;
                    margin-top: 8px;
                    background: #f5f5f5;
                    padding: 8px;
                    border-radius: 6px;
                }
                .param-label {
                    color: #888;
                    display: inline-block;
                    width: 80px;
                }
                .comparison-note {
                    background: #e3f2fd;
                    padding: 15px;
                    border-radius: 8px;
                    margin-bottom: 30px;
                    color: #1976d2;
                }
            </style>
        </head>
        <body>
            <h1>Icon Shadow Variation Test - 1024×1024 pixels</h1>
            <p>Generated on \(Date().formatted())</p>
            
            <div class="comparison-note">
                <strong>💡 Fixed Values Test:</strong> All shadows use fixed pixel values at 1024px resolution.
                This helps determine the exact shadow settings that look best at this specific size.
            </div>
            
            <div class="grid">
        """
        
        print("Starting shadow variation export tests (1024px only)...")
        print("Exporting to: \(directory.path)")
        print("Total variations: \(configs.count)")
        
        for (index, (name, settings, shadowMods)) in configs.enumerated() {
            print("[\(index + 1)/\(configs.count)] Exporting: \(name)")
            
            // Create a custom renderer that applies shadow modifications
            let icon = renderIconWithShadowMods(settings: settings, shadowMods: shadowMods)
            
            // Create filename
            let filename = "\(name)_1024px.png"
            let fileURL = directory.appendingPathComponent(filename)
            
            // Export as PNG
            if let tiffData = icon.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                try pngData.write(to: fileURL)
                
                // Extract shadow variation name
                let shadowType = name.replacingOccurrences(of: "shadow_", with: "")
                
                // Add to HTML
                htmlContent += """
                <div class="icon-card">
                    <div class="icon-preview">
                        <img src="\(filename)" alt="\(name)">
                    </div>
                    <div class="icon-info">
                        <strong>\(shadowType)</strong>
                        <div class="shadow-params">
                            <div><span class="param-label">BG Radius:</span> \(String(format: "%.0f", shadowMods.backgroundRadius))px</div>
                            <div><span class="param-label">BG Y-Offset:</span> \(String(format: "%.0f", shadowMods.backgroundYOffset))px</div>
                            <div><span class="param-label">Icon Radius:</span> \(String(format: "%.0f", shadowMods.symbolRadius))px</div>
                            <div><span class="param-label">Icon Y-Offset:</span> \(String(format: "%.0f", shadowMods.symbolYOffset))px</div>
                        </div>
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
        let htmlURL = directory.appendingPathComponent("shadow_test_results_1024px.html")
        try htmlContent.write(to: htmlURL, atomically: true, encoding: .utf8)
        
        print("\n✅ Shadow variation export complete!")
        print("📁 Icons saved to: \(directory.path)")
        print("🌐 Open shadow_test_results_1024px.html to view all shadow variations")
        
        // Open the directory in Finder
        NSWorkspace.shared.selectFile(htmlURL.path, inFileViewerRootedAtPath: directory.path)
    }
    
    // Custom render function that applies shadow modifications
    static func renderIconWithShadowMods(settings: IconSettings, shadowMods: ShadowModifications) -> NSImage {
        let size = CGSize(width: settings.export.pixelSize, height: settings.export.pixelSize)
        
        // Create a modified icon view with custom shadows
        let iconView = ModifiedShadowIconView(settings: settings, shadowMods: shadowMods)
            .frame(width: size.width, height: size.height)
        
        // Use ImageRenderer to render the SwiftUI view
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = 1.0
        renderer.isOpaque = false
        
        // Convert to NSImage
        if let nsImage = renderer.nsImage {
            return IconRenderer.convertToColorSpace(image: nsImage, colorSpace: settings.export.colorSpace)
        }
        
        // Fallback if rendering fails
        return NSImage(size: size)
    }
    
    // Run tests with save panel
    static func runShadowTestsWithSavePanel() async throws {
        let savePanel = NSOpenPanel()
        savePanel.title = "Choose Location for Shadow Test Icons"
        savePanel.message = "Select where to save the shadow variation test exports"
        savePanel.prompt = "Select Folder"
        savePanel.canChooseFiles = false
        savePanel.canChooseDirectories = true
        savePanel.canCreateDirectories = true
        savePanel.allowsMultipleSelection = false
        
        let response = await savePanel.begin()
        
        if response == .OK, let url = savePanel.url {
            let testDirectory = url.appendingPathComponent("IconShadowTests_1024px_\(Date().timeIntervalSince1970)")
            try await exportShadowTestIcons(to: testDirectory)
        }
    }
}

// Structure to hold shadow modifications with fixed values
struct ShadowModifications {
    let description: String
    let backgroundOpacity: CGFloat
    let backgroundRadius: CGFloat
    let backgroundYOffset: CGFloat
    let symbolOpacity: CGFloat
    let symbolRadius: CGFloat
    let symbolYOffset: CGFloat
}

// Modified icon view that applies custom shadow parameters with fixed values
struct ModifiedShadowIconView: View {
    let settings: IconSettings
    let shadowMods: ShadowModifications
    
    // Fixed inset for 1024px
    private let insetSize: CGFloat = 100
    
    // Fixed corner radius for 1024px
    private let cornerRadius: CGFloat = 280
    
    // Fixed font size for 1024px
    private let fontSize: CGFloat = 480
    
    var body: some View {
        ZStack {
            // Background with fixed shadow values
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: insetSize)
                .fill(settings.icon.background.color.gradient)
                .shadow(
                    color: .black.opacity(shadowMods.backgroundOpacity),
                    radius: shadowMods.backgroundRadius,
                    x: 0,
                    y: shadowMods.backgroundYOffset
                )
            
            // Symbol with fixed shadow values
            Image(systemName: settings.icon.foreground.symbolName)
                .font(.system(size: fontSize, weight: .light))
                .foregroundColor(settings.icon.foreground.color)
                .symbolRenderingMode(.monochrome)
                .shadow(
                    color: .black.opacity(shadowMods.symbolOpacity),
                    radius: shadowMods.symbolRadius,
                    x: 0,
                    y: shadowMods.symbolYOffset
                )
        }
        .frame(width: settings.export.pixelSize, height: settings.export.pixelSize)
    }
}

// Extension to make it easy to call from your app
extension MicaApp {
    func runShadowVariationTests() {
        Task {
            do {
                try await ShadowVariationHarness.runShadowTestsWithSavePanel()
            } catch {
                print("Shadow variation test failed: \(error)")
            }
        }
    }
}
