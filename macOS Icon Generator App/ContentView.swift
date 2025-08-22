// ContentView.swift - Main view of our application
import SwiftUI

struct ContentView: View {
    // MVVM: centralize state in a ViewModel (types preserved)
    @StateObject private var viewModel = IconViewModel()
    
    // Available preset colors (centralized)
    let colorOptions: [(name: String, color: Color)] = OptionsCatalog.colorOptions
    
    // Predefined size options (centralized)
    let sizeOptions: [(label: String, size: CGFloat)] = OptionsCatalog.sizeOptions
    
    // Calculate actual export size including retina multiplier
    private var actualExportSize: CGFloat { viewModel.iconSettings.finalExportSize }
    
    var body: some View {
        NavigationView {
            // Left sidebar with controls
            Form {
                Section(header: Text("Testing Mode")) {
                    Toggle("Enable Testing Mode", isOn: $viewModel.testingMode)
                        .help("Enable to adjust layout constants in real-time")
                }

                SFSymbolSection(iconSettings: $viewModel.iconSettings)

                BackgroundColorsSection(iconSettings: $viewModel.iconSettings,
                                        colorOptions: colorOptions)

                ShadowSettingsSection(iconSettings: $viewModel.iconSettings)

                BadgeSettingsSection(iconSettings: $viewModel.iconSettings,
                                      colorOptions: colorOptions)

                if viewModel.testingMode {
                    LayoutSettingsSection(layoutSettings: $viewModel.layoutSettings)
                    Button("Reset to Defaults") { viewModel.layoutSettings = LayoutSettings() }
                        .padding(.top, 5)
                }

                ExportOptionsSection(iconSettings: $viewModel.iconSettings,
                                     showExportDialog: $viewModel.showExportDialog,
                                     sizeOptions: sizeOptions)
            }
            .formStyle(GroupedFormStyle())
            .padding()
            .frame(minWidth: viewModel.testingMode ? 400 : 300)
            
            // Right side with the preview - now scrollable for large icons
            ScrollView([.horizontal, .vertical]) {
                VStack {
                    Spacer()
                    
                    if viewModel.testingMode {
                        ZoomableIconPreview(settings: viewModel.iconSettings, layoutSettings: viewModel.layoutSettings)
                            .padding()
                    } else {
                        // Show actual export size with scroll capability for large icons
                        ScaledIconPreview(settings: viewModel.iconSettings, displaySize: actualExportSize)
                            .padding()
                    }
                    
                    VStack(spacing: 4) {
                        Text("Preview")
                            .font(.headline)
                        
                        // Show the actual export dimensions
                        Text("\(Int(actualExportSize))×\(Int(actualExportSize))px")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if viewModel.testingMode {
                            Text("Testing Mode Active")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Drag to pan • Scroll to zoom • Double-click to reset")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if actualExportSize > 400 {
                            Text("Scroll to see full icon")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))
        }
        .fileExporter(
            isPresented: $viewModel.showExportDialog,
            document: IconDocument(settings: viewModel.iconSettings),
            contentType: .png,
            defaultFilename: "CustomIcon"
        ) { result in
            switch result {
            case .success(let url):
                print("Icon saved to: \(url.path)")
            case .failure(let error):
                print("Failed to save icon: \(error.localizedDescription)")
            }
        }
    }
}

// New preview component that scales based on export size
struct ScaledIconPreview: View {
    let settings: IconSettings
    let displaySize: CGFloat
    
    var body: some View {
        IconContentView(settings: settings, displaySize: displaySize)
            .frame(width: displaySize, height: displaySize, alignment: .center)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

// LayoutSettings moved to Models/LayoutSettings.swift (type unchanged)

// Zoomable and draggable version of the icon preview for testing mode
struct ZoomableIconPreview: View {
    let settings: IconSettings
    let layoutSettings: LayoutSettings
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 4.0
    private let previewFrameSize: CGFloat = 400
    
    var body: some View {
        GeometryReader { geometry in
            TestableIconPreview(settings: settings, layoutSettings: layoutSettings)
                .frame(width: layoutSettings.iconSize, height: layoutSettings.iconSize)
                .scaleEffect(scale)
                .offset(offset)
                .clipped()
                .frame(width: previewFrameSize, height: previewFrameSize)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.controlBackgroundColor))
                        .shadow(radius: 1)
                )
                .onTapGesture(count: 2) {
                    // Double-tap to reset zoom and position
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scale = 1.0
                        offset = .zero
                        lastScale = 1.0
                        lastOffset = .zero
                    }
                }
                .gesture(
                    // Drag gesture for panning
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                        .simultaneously(with:
                            // Magnification gesture for zooming
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value
                                    scale = min(max(newScale, minScale), maxScale)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                )
                .onScrollWheel { event in
                    // Scroll wheel support for zooming
                    let deltaY = event.scrollingDeltaY
                    let zoomFactor = deltaY > 0 ? 0.9 : 1.1
                    let newScale = scale * zoomFactor
                    
                    withAnimation(.easeOut(duration: 0.1)) {
                        scale = min(max(newScale, minScale), maxScale)
                        lastScale = scale
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(height: previewFrameSize)
    }
}

// Extension to handle scroll wheel events
extension View {
    func onScrollWheel(perform action: @escaping (NSEvent) -> Void) -> some View {
        self.background(
            ScrollWheelHandler(onScrollWheel: action)
        )
    }
}

// NSViewRepresentable to capture scroll wheel events
struct ScrollWheelHandler: NSViewRepresentable {
    let onScrollWheel: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollWheelView()
        view.onScrollWheel = onScrollWheel
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class ScrollWheelView: NSView {
    var onScrollWheel: ((NSEvent) -> Void)?
    
    override func scrollWheel(with event: NSEvent) {
        onScrollWheel?(event)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

// Testable version of IconPreview with configurable layout
struct TestableIconPreview: View {
    let settings: IconSettings
    let layoutSettings: LayoutSettings
    
    var body: some View {
        ZStack {
            // Background with rounded corners - using the squircle shape similar to macOS icons
            if settings.useCustomColors {
                RoundedRectangle(cornerRadius: layoutSettings.cornerRadius, style: .continuous)
                    //.inset(by: layoutSettings.backgroundInset)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: settings.gradientColors),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: settings.enableBackgroundShadow ? .black.opacity(0.31) : .clear,
                        radius: settings.enableBackgroundShadow ? layoutSettings.shadowRadius : 0,
                        y: settings.enableBackgroundShadow ? layoutSettings.shadowOffset : 0
                    )
                    .frame(width: layoutSettings.iconSize, height: layoutSettings.iconSize, alignment: .center)
            } else {
                RoundedRectangle(cornerRadius: layoutSettings.cornerRadius, style: .continuous)
                    //.inset(by: layoutSettings.backgroundInset)
                    .fill(settings.baseColor.gradient)
                    .shadow(
                        color: settings.enableBackgroundShadow ? .black.opacity(0.31) : .clear,
                        radius: settings.enableBackgroundShadow ? layoutSettings.shadowRadius : 0,
                        x: 0,
                        y: settings.enableBackgroundShadow ? layoutSettings.shadowOffset : 0
                    )
                    .frame(width: layoutSettings.iconSize, height: layoutSettings.iconSize, alignment: .center)
            }
            
            // SF Symbol icon with appropriate rendering mode and colors
            symbolView
        }
    }
    
    @ViewBuilder
    private var symbolView: some View {
        switch settings.symbolRenderingMode {
        case .monochrome:
            Image(systemName: settings.symbolName)
                .alignmentGuide(VerticalAlignment.center) { context in
                    context[VerticalAlignment.center] + layoutSettings.verticalAlignmentOffset
                }
                .font(.system(size: layoutSettings.symbolSize, weight: layoutSettings.symbolWeight))
                .foregroundColor(settings.symbolColor)
                .symbolRenderingMode(.monochrome)
                .shadow(
                    color: settings.enableSymbolShadow ? .black.opacity(0.35) : .clear,
                    radius: settings.enableSymbolShadow ? layoutSettings.shadowRadius : 0,
                    x: 0,
                    y: settings.enableSymbolShadow ? layoutSettings.shadowOffset : 0
                )
                .frame(width: layoutSettings.symbolFrameSize, height: layoutSettings.symbolFrameSize, alignment: .center)
        
        case .hierarchical:
            Image(systemName: settings.symbolName)
                .alignmentGuide(VerticalAlignment.center) { context in
                    context[VerticalAlignment.center] + layoutSettings.verticalAlignmentOffset
                }
                .font(.system(size: layoutSettings.symbolSize, weight: layoutSettings.symbolWeight))
                .foregroundStyle(settings.hierarchicalSymbolColor)
                .symbolRenderingMode(.hierarchical)
                .shadow(
                    color: settings.enableSymbolShadow ? .black.opacity(0.23) : .clear,
                    radius: settings.enableSymbolShadow ? layoutSettings.shadowRadius : 0,
                    x: 0,
                    y: settings.enableSymbolShadow ? layoutSettings.shadowOffset : 0
                )
        
        case .multicolor:
            Image(systemName: settings.symbolName)
                .alignmentGuide(VerticalAlignment.center) { context in
                    context[VerticalAlignment.center] + layoutSettings.verticalAlignmentOffset
                }
                .font(.system(size: layoutSettings.symbolSize, weight: layoutSettings.symbolWeight))
                .symbolRenderingMode(.multicolor)
                .shadow(
                    color: settings.enableSymbolShadow ? .black.opacity(0.23) : .clear,
                    radius: settings.enableSymbolShadow ? layoutSettings.shadowRadius : 0,
                    x: 0,
                    y: settings.enableSymbolShadow ? layoutSettings.shadowOffset : 0
                )
        
        case .palette:
            Image(systemName: settings.symbolName)
                .alignmentGuide(VerticalAlignment.center) { context in
                    context[VerticalAlignment.center] + layoutSettings.verticalAlignmentOffset
                }
                .font(.system(size: layoutSettings.symbolSize, weight: layoutSettings.symbolWeight))
                .foregroundStyle(
                    settings.paletteSymbolPrimaryColor,
                    settings.paletteSymbolSecondaryColor,
                    settings.paletteSymbolTertiaryColor
                )
                .symbolRenderingMode(.palette)
                .shadow(
                    color: settings.enableSymbolShadow ? .black.opacity(0.23) : .clear,
                    radius: settings.enableSymbolShadow ? layoutSettings.shadowRadius : 0,
                    x: 0,
                    y: settings.enableSymbolShadow ? layoutSettings.shadowOffset : 0
                )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
