// IconShadowVariationTests.swift - Test shadow variations at 1024px with fixed values
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct IconShadowVariationTests {
    
    // Generate test configurations for shadow variations
    static func generateShadowTestConfigurations() -> [(name: String, settings: IconSettings, shadowMods: ShadowModifications)] {
        var configs: [(String, IconSettings, ShadowModifications)] = []
        
        // Fixed size: 1024px
        let size: CGFloat = 512  // with retina = 1024
        let retina = true
        
        // Define shadow variations with fixed values
        let shadowVariations: [(name: String, radius: CGFloat, yOffset: CGFloat)] = [
            ("r7_y8", 7.0, 10.0),          // Default values at 1024px
            ("r6_y8", 6.0, 10.0),           // More subtle shadow
            ("r8_y8", 8.0, 10.0),          // Stronger shadow
            ("r12_y8", 12.0, 10.0),            // Softer/more diffuse shadow
            ("r10_y8", 10.0, 10.0),            // Sharper shadow
        ]
        
        // Generate configurations
        for (shadowName, radius, yOffset) in shadowVariations {
            var settings = IconSettings()
            // Keep defaults for icon and background
            settings.symbolName = "folder.fill.badge.plus"
            settings.baseColor = .blue
            settings.symbolRenderingMode = .monochrome
            settings.symbolColor = .white
            settings.exportSize = size
            settings.exportRetinaSize = retina
            
            let shadowMods = ShadowModifications(
                backgroundRadius: radius,
                backgroundYOffset: yOffset,
                symbolRadius: radius, //* 0.75,  // Symbol shadow slightly smaller
                symbolYOffset: yOffset //* 0.75
            )
            
            let name = "shadow_\(shadowName)"
            configs.append((name, settings, shadowMods))
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
        let size = CGSize(width: settings.finalExportSize, height: settings.finalExportSize)
        
        // Create a modified icon view with custom shadows
        let iconView = ModifiedShadowIconView(settings: settings, shadowMods: shadowMods)
            .frame(width: size.width, height: size.height)
        
        // Use ImageRenderer to render the SwiftUI view
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = 1.0
        renderer.isOpaque = false
        
        // Convert to NSImage
        if let nsImage = renderer.nsImage {
            return IconRenderer.convertToColorSpace(image: nsImage, colorSpace: settings.exportColorSpace)
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
    let backgroundRadius: CGFloat
    let backgroundYOffset: CGFloat
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
                .fill(settings.baseColor.gradient)
                .shadow(
                    radius: shadowMods.backgroundRadius,
                    x: 0,
                    y: shadowMods.backgroundYOffset
                )
            
            // Symbol with fixed shadow values
            Image(systemName: settings.symbolName)
                .font(.system(size: fontSize, weight: .light))
                .foregroundColor(settings.symbolColor)
                .symbolRenderingMode(.monochrome)
                .shadow(
                    radius: shadowMods.symbolRadius,
                    x: 0,
                    y: shadowMods.symbolYOffset
                )
        }
        .frame(width: settings.finalExportSize, height: settings.finalExportSize)
    }
}

// Extension to make it easy to call from your app
extension IconGeneratorApp {
    func runShadowVariationTests() {
        Task {
            do {
                try await IconShadowVariationTests.runShadowTestsWithSavePanel()
            } catch {
                print("Shadow variation test failed: \(error)")
            }
        }
    }
}
