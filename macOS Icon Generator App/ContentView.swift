// ContentView.swift - Main view of our application
import SwiftUI

struct ContentView: View {
    @State private var iconSettings = IconSettings()
    @State private var showSymbolPicker = false
    @State private var showExportDialog = false
    @State private var exportPath: URL?
    @State private var testingMode = false
    @State private var layoutSettings = LayoutSettings()
    
    // Available preset colors
    let colorOptions: [(name: String, color: Color)] = [
        ("Black", .black),
        ("Blue", .blue),
        ("Brown", .brown),
        ("Cyan", .cyan),
        ("Gray", .gray),
        ("Green", .green),
        ("Indigo", .indigo),
        ("Mint", .mint),
        ("Orange", .orange),
        ("Pink", .pink),
        ("Purple", .purple),
        ("Red", .red),
        ("Teal", .teal),
        ("White", .white),
        ("Yellow", .yellow)
    ]
    
    // Predefined size options
    let sizeOptions: [(label: String, size: CGFloat)] = [
        ("128px", 128),
        ("256px", 256),
        ("512px", 512),
        ("1024px", 1024)
    ]
    
    var body: some View {
        NavigationView {
            // Left sidebar with controls
            Form {
                Section(header: Text("Testing Mode")) {
                    Toggle("Enable Testing Mode", isOn: $testingMode)
                        .help("Enable to adjust layout constants in real-time")
                }
                
                Section(header: Text("Icon Symbol")) {
                    HStack {
                        Button(action: { showSymbolPicker.toggle() }) {
                            Label("Choose Symbol", systemImage: "square.grid.2x2")
                        }
                        
                        Spacer()
                        
                        Text(iconSettings.symbolName)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    Picker("Symbol Rendering Mode", selection: $iconSettings.symbolRenderingMode) {
                        ForEach(SymbolRenderingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    switch iconSettings.symbolRenderingMode {
                    case .monochrome:
                        ColorPicker("Symbol Color", selection: $iconSettings.symbolColor)
                    case .hierarchical:
                        ColorPicker("Base Color", selection: $iconSettings.hierarchicalSymbolColor)
                    case .multicolor:
                        Text("Uses system-defined colors")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    case .palette:
                        ColorPicker("Primary Color", selection: $iconSettings.paletteSymbolPrimaryColor)
                        ColorPicker("Secondary Color", selection: $iconSettings.paletteSymbolSecondaryColor)
                        ColorPicker("Tertiary Color", selection: $iconSettings.paletteSymbolTertiaryColor)
                    }
                }
                
                Section(header: Text("Background Colors")) {
                    Toggle("Use Custom Colors", isOn: $iconSettings.useCustomColors)
                    
                    if iconSettings.useCustomColors {
                        ColorPicker("Primary Color", selection: $iconSettings.customPrimaryColor)
                        ColorPicker("Secondary Color", selection: $iconSettings.customSecondaryColor)
                    } else {
                        Picker("Color Preset", selection: Binding(
                            get: {
                                colorOptions.firstIndex { $0.color == iconSettings.baseColor } ?? 0
                            },
                            set: { newValue in
                                let selectedColor = colorOptions[newValue]
                                iconSettings.baseColor = selectedColor.color
                            }
                        )) {
                            ForEach(0..<colorOptions.count, id: \.self) { index in
                                Text(colorOptions[index].name)
                            }
                        }
                    }
                }
                
                if testingMode {
                    Section(header: Text("Layout Settings")) {
                        VStack(alignment: .leading) {
                            Text("Icon Size: \(Int(layoutSettings.iconSize))")
                            Slider(value: $layoutSettings.iconSize, in: 128...512, step: 1)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Corner Radius: \(Int(layoutSettings.cornerRadius))")
                            Slider(value: $layoutSettings.cornerRadius, in: 10...100, step: 1)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Background Inset: \(Int(layoutSettings.backgroundInset))")
                            Slider(value: $layoutSettings.backgroundInset, in: 0...50, step: 1)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Symbol Size: \(Int(layoutSettings.symbolSize))")
                            Slider(value: $layoutSettings.symbolSize, in: 50...200, step: 1)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Symbol Frame Size: \(Int(layoutSettings.symbolFrameSize))")
                            Slider(value: $layoutSettings.symbolFrameSize, in: 100...300, step: 1)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Shadow Radius: \(layoutSettings.shadowRadius, specifier: "%.1f")")
                            Slider(value: $layoutSettings.shadowRadius, in: 0...10, step: 0.1)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Shadow Offset: \(layoutSettings.shadowOffset, specifier: "%.1f")")
                            Slider(value: $layoutSettings.shadowOffset, in: 0...10, step: 0.1)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Vertical Alignment Offset: \(layoutSettings.verticalAlignmentOffset, specifier: "%.1f")")
                            Slider(value: $layoutSettings.verticalAlignmentOffset, in: -10...10, step: 0.1)
                        }
                        
                        Picker("Symbol Weight", selection: $layoutSettings.symbolWeight) {
                            Text("Ultra Light").tag(Font.Weight.ultraLight)
                            Text("Thin").tag(Font.Weight.thin)
                            Text("Light").tag(Font.Weight.light)
                            Text("Regular").tag(Font.Weight.regular)
                            Text("Medium").tag(Font.Weight.medium)
                            Text("Semibold").tag(Font.Weight.semibold)
                            Text("Bold").tag(Font.Weight.bold)
                            Text("Heavy").tag(Font.Weight.heavy)
                            Text("Black").tag(Font.Weight.black)
                        }
                        
                        Button("Reset to Defaults") {
                            layoutSettings = LayoutSettings()
                        }
                        .padding(.top, 5)
                    }
                }
                
                Section(header: Text("Export Options")) {
                    Picker("Size", selection: Binding(
                        get: {
                            sizeOptions.firstIndex { $0.size == iconSettings.exportSize } ?? 1
                        },
                        set: { newValue in
                            iconSettings.exportSize = sizeOptions[newValue].size
                        }
                    )) {
                        ForEach(0..<sizeOptions.count, id: \.self) { index in
                            Text(sizeOptions[index].label)
                        }
                    }
                    
                    Toggle("2× Resolution for Retina", isOn: $iconSettings.exportRetinaSize)
                    
                    Picker("Color Space", selection: $iconSettings.exportColorSpace) {
                        ForEach(ExportColorSpace.allCases) { colorSpace in
                            Text(colorSpace.rawValue).tag(colorSpace)
                        }
                    }
                    .help("sRGB: Standard color space for web and most displays\nDisplay P3: Wider color gamut for modern Apple displays")
                    
                    Button("Export Icon...") {
                        showExportDialog = true
                    }
                    .padding(.top, 5)
                }
            }
            .formStyle(GroupedFormStyle())
            .padding()
            .frame(minWidth: testingMode ? 400 : 300)
            
            // Right side with the preview
            VStack {
                Spacer()
                
                if testingMode {
                    ZoomableIconPreview(settings: iconSettings, layoutSettings: layoutSettings)
                        .padding()
                } else {
                    IconPreview(settings: iconSettings)
                        .frame(width: 256, height: 256, alignment: .center)
                        .padding()
                }
                
                Text("Preview")
                    .font(.headline)
                    .padding(.top)
                
                if testingMode {
                    VStack(spacing: 4) {
                        Text("Testing Mode Active")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Drag to pan • Scroll to zoom • Double-click to reset")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: $iconSettings.symbolName)
        }
        .fileExporter(
            isPresented: $showExportDialog,
            document: IconDocument(settings: iconSettings),
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

// Layout settings for testing mode
struct LayoutSettings {
    var iconSize: CGFloat = 256
    var cornerRadius: CGFloat = 70
    var backgroundInset: CGFloat = 25
    var symbolSize: CGFloat = 120
    var symbolFrameSize: CGFloat = 178
    var shadowRadius: CGFloat = 2
    var shadowOffset: CGFloat = 2.5
    var verticalAlignmentOffset: CGFloat = 5.5
    var symbolWeight: Font.Weight = .regular
}

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
                    .inset(by: layoutSettings.backgroundInset)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: settings.gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(radius: layoutSettings.shadowRadius, y: layoutSettings.shadowOffset)
                    .frame(width: layoutSettings.iconSize, height: layoutSettings.iconSize, alignment: .center)
            } else {
                RoundedRectangle(cornerRadius: layoutSettings.cornerRadius, style: .continuous)
                    .inset(by: layoutSettings.backgroundInset)
                    .fill(settings.baseColor.gradient)
                    .shadow(radius: layoutSettings.shadowRadius, x: 0, y: layoutSettings.shadowOffset)
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
                .shadow(radius: layoutSettings.shadowRadius, x: 0, y: layoutSettings.shadowOffset)
                .frame(width: layoutSettings.symbolFrameSize, height: layoutSettings.symbolFrameSize, alignment: .center)
        
        case .hierarchical:
            Image(systemName: settings.symbolName)
                .alignmentGuide(VerticalAlignment.center) { context in
                    context[VerticalAlignment.center] + layoutSettings.verticalAlignmentOffset
                }
                .font(.system(size: layoutSettings.symbolSize, weight: layoutSettings.symbolWeight))
                .foregroundStyle(settings.hierarchicalSymbolColor)
                .symbolRenderingMode(.hierarchical)
                .shadow(radius: layoutSettings.shadowRadius, x: 0, y: layoutSettings.shadowOffset)
        
        case .multicolor:
            Image(systemName: settings.symbolName)
                .alignmentGuide(VerticalAlignment.center) { context in
                    context[VerticalAlignment.center] + layoutSettings.verticalAlignmentOffset
                }
                .font(.system(size: layoutSettings.symbolSize, weight: layoutSettings.symbolWeight))
                .symbolRenderingMode(.multicolor)
                .shadow(radius: layoutSettings.shadowRadius, x: 0, y: layoutSettings.shadowOffset)
        
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
                .shadow(radius: layoutSettings.shadowRadius, x: 0, y: layoutSettings.shadowOffset)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
