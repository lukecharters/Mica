// ContentView.swift - Main view of our application
import SwiftUI

struct ContentView: View {
    @State private var iconSettings = IconSettings()
    @State private var showSymbolPicker = false
    @State private var showExportDialog = false
    @State private var exportPath: URL?
    
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
            .frame(minWidth: 300)
            
            // Right side with the preview
            VStack {
                Spacer()
                
                IconPreview(settings: iconSettings)
                    .frame(width: 256, height: 256)
                    .padding()
                    //.shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                
                Text("Preview")
                    .font(.headline)
                    .padding(.top)
                
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
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
