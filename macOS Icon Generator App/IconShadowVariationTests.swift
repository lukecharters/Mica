// IconShadowVariationTests.swift - Test shadow variations across different sizes
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct IconShadowVariationTests {
    
    // Generate test configurations for shadow variations
    static func generateShadowTestConfigurations() -> [(name: String, settings: IconSettings, shadowMods: ShadowModifications)] {
        var configs: [(String, IconSettings, ShadowModifications)] = []
        
        // Define size options
        let sizes: [(name: String, size: CGFloat, retina: Bool)] = [
            ("256", 256, false),
            ("1024", 1024, false)    // 512 with retina = 1024
        ]
        
        // Define shadow variations
        let shadowVariations: [(name: String, opacity: Double, radiusMultiplier: Double, yMultiplier: Double)] = [
            ("default", 0.25, 1.0, 1.0),           // Default values
            ("subtle", 0.15, 0.8, 0.8),            // More subtle shadow
            ("strong", 0.35, 1.2, 1.2),            // Stronger shadow
            ("soft", 0.20, 1.5, 1.0),              // Softer/more diffuse shadow
            ("sharp", 0.30, 0.5, 1.0),             // Sharper shadow
            ("lifted", 0.25, 1.0, 1.5),            // More Y offset (appears more lifted)
            ("close", 0.25, 1.0, 0.5),             // Less Y offset (appears closer)
            ("diffuse", 0.18, 2.0, 1.3),           // Very soft and spread out
            ("minimal", 0.10, 0.3, 0.3),           // Barely visible
            ("dramatic", 0.40, 1.5, 2.0),          // Very prominent shadow
        ]
        
        // Generate combinations
        for (sizeName, size, retina) in sizes {
            for (shadowName, opacity, radiusMultiplier, yMultiplier) in shadowVariations {
                var settings = IconSettings()
                // Keep defaults for icon and background
                settings.symbolName = "folder.fill.badge.plus"
                settings.baseColor = .blue
                settings.symbolRenderingMode = .monochrome
                settings.symbolColor = .white
                settings.exportSize = size
                settings.exportRetinaSize = retina
                
                let shadowMods = ShadowModifications(
                    opacity: opacity,
                    radiusMultiplier: radiusMultiplier,
                    yMultiplier: yMultiplier
                )
                
                let name = "\(sizeName)px_shadow_\(shadowName)"
                configs.append((name, settings, shadowMods))
            }
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
            <title>Icon Shadow Variation Test Results</title>
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif; 
                    margin: 20px; 
                    background: #f5f5f5; 
                }
                h1 { color: #333; margin-bottom: 10px; }
                h2 { color: #555; margin-top: 40px; margin-bottom: 20px; }
                p { color: #666; margin-bottom: 30px; }
                .size-section { margin-bottom: 60px; }
                .grid { 
                    display: grid; 
                    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); 
                    gap: 15px; 
                    margin-bottom: 40px;
                }
                .icon-card { 
                    background: white; 
                    border-radius: 12px; 
                    padding: 15px; 
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1); 
                    text-align: center;
                }
                .icon-preview { 
                    width: 100%; 
                    height: 150px; 
                    display: flex; 
                    align-items: center; 
                    justify-content: center; 
                    background: #fafafa; 
                    border-radius: 8px; 
                    margin-bottom: 10px; 
                    position: relative;
                }
                .icon-preview img { 
                    max-width: 90%; 
                    max-height: 90%; 
                    image-rendering: -webkit-optimize-contrast;
                }
                .icon-info { 
                    font-size: 12px; 
                    color: #666; 
                    line-height: 1.5;
                }
                .icon-info strong { 
                    color: #333; 
                    display: block;
                    margin-bottom: 2px;
                }
                .shadow-params {
                    font-family: 'SF Mono', Monaco, monospace;
                    font-size: 11px;
                    color: #888;
                    margin-top: 5px;
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
            <h1>Icon Shadow Variation Test Results</h1>
            <p>Generated on \(Date().formatted())</p>
            
            <div class="comparison-note">
                <strong>💡 Tip:</strong> Compare shadows across each row to see how the same effect scales at different sizes.
                The first icon in each size group shows the default shadow settings.
            </div>
        """
        
        print("Starting shadow variation export tests...")
        print("Exporting to: \(directory.path)")
        
        // Group by size for better organization
        let sizeGroups = Dictionary(grouping: configs) { config -> String in
            let size = Int(config.1.finalExportSize)
            return "\(size)"
        }
        
        let sortedSizes = ["128", "256", "512", "1024"]
        
        for sizeStr in sortedSizes {
            guard let sizeConfigs = sizeGroups[sizeStr] else { continue }
            
            htmlContent += """
            <div class="size-section">
                <h2>\(sizeStr)×\(sizeStr) pixels</h2>
                <div class="grid">
            """
            
            // Sort configs by shadow name for consistent ordering
            let sortedConfigs = sizeConfigs.sorted { $0.0 < $1.0 }
            
            for (index, (name, settings, shadowMods)) in sortedConfigs.enumerated() {
                print("[\(index + 1)/\(sizeConfigs.count)] Exporting: \(name)")
                
                // Create a custom renderer that applies shadow modifications
                let icon = renderIconWithShadowMods(settings: settings, shadowMods: shadowMods)
                
                // Create filename
                let filename = "\(name).png"
                let fileURL = directory.appendingPathComponent(filename)
                
                // Export as PNG
                if let tiffData = icon.tiffRepresentation,
                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try pngData.write(to: fileURL)
                    
                    // Extract shadow variation name
                    let shadowType = name.components(separatedBy: "_shadow_").last ?? "unknown"
                    
                    // Add to HTML
                    htmlContent += """
                    <div class="icon-card">
                        <div class="icon-preview">
                            <img src="\(filename)" alt="\(name)">
                        </div>
                        <div class="icon-info">
                            <strong>\(shadowType)</strong>
                            <div class="shadow-params">
                                opacity: \(String(format: "%.2f", shadowMods.opacity))<br>
                                radius: ×\(String(format: "%.1f", shadowMods.radiusMultiplier))<br>
                                y-offset: ×\(String(format: "%.1f", shadowMods.yMultiplier))
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
            </div>
            """
        }
        
        htmlContent += """
        </body>
        </html>
        """
        
        // Save HTML summary
        let htmlURL = directory.appendingPathComponent("shadow_test_results.html")
        try htmlContent.write(to: htmlURL, atomically: true, encoding: .utf8)
        
        print("\n✅ Shadow variation export complete!")
        print("📁 Icons saved to: \(directory.path)")
        print("🌐 Open shadow_test_results.html to view all shadow variations")
        
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
            let testDirectory = url.appendingPathComponent("IconShadowTests_\(Date().timeIntervalSince1970)")
            try await exportShadowTestIcons(to: testDirectory)
        }
    }
}

// Structure to hold shadow modifications
struct ShadowModifications {
    let opacity: Double
    let radiusMultiplier: Double
    let yMultiplier: Double
}

// Modified icon view that applies custom shadow parameters
struct ModifiedShadowIconView: View {
    let settings: IconSettings
    let shadowMods: ShadowModifications
    
    // Calculate scaling factor based on preview size (256) to export size
    private var scaleFactor: CGFloat {
        settings.finalExportSize / 256.0
    }
    
    // Calculate the appropriate inset based on export size
    private var insetSize: CGFloat {
        switch settings.finalExportSize {
        case 1024:
            return 100
        case 512:
            return 50
        case 256:
            return 25
        case 128:
            return 10
        default:
            return settings.finalExportSize * 0.1
        }
    }
    
    var body: some View {
        ZStack {
            // Background with modified shadow
            RoundedRectangle(cornerRadius: 70 * scaleFactor, style: .continuous)
                .inset(by: insetSize)
                .fill(settings.baseColor.gradient)
                .shadow(
                    color: .black.opacity(shadowMods.opacity),
                    radius: 2 * scaleFactor * shadowMods.radiusMultiplier,
                    x: 0,
                    y: 3 * scaleFactor * shadowMods.yMultiplier
                )
            
            // Symbol with modified shadow
            Image(systemName: settings.symbolName)
                .font(.system(size: 120 * scaleFactor, weight: .light))
                .foregroundColor(settings.symbolColor)
                .symbolRenderingMode(.monochrome)
                .shadow(
                    color: .black.opacity(shadowMods.opacity),
                    radius: 2 * scaleFactor * shadowMods.radiusMultiplier,
                    x: 0,
                    y: 3 * scaleFactor * shadowMods.yMultiplier
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
