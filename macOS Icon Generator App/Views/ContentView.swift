// ContentView.swift - Main view of our application
import SwiftUI

struct ContentView: View {
    // MVVM: centralize state in a ViewModel (types preserved)
    @StateObject private var viewModel = IconViewModel()

    // Default init keeps local @StateObject creation
    init() {}

    // Convenience initializer to inject a preconfigured view model (for previews/tests)
    init(viewModel: IconViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // Available preset colors (centralized)
    let colorOptions: [(name: String, color: Color)] = OptionsCatalog.colorOptions
    
    // Calculate actual export size including retina multiplier
    private var actualExportSize: CGFloat { viewModel.iconSettings.finalExportSize }
    
    var body: some View {
        NavigationView {
            // Left sidebar with controls
            Form {
                SFSymbolSection(iconSettings: $viewModel.iconSettings)

                BackgroundColorsSection(iconSettings: $viewModel.iconSettings,
                                        colorOptions: colorOptions)

                ShadowSettingsSection(iconSettings: $viewModel.iconSettings)

                BadgeSettingsSection(iconSettings: $viewModel.iconSettings,
                                      colorOptions: colorOptions)

                ExportOptionsSection(iconSettings: $viewModel.iconSettings,
                                     showExportDialog: $viewModel.showExportDialog)
            }
            .formStyle(GroupedFormStyle())
            .padding()
            .frame(minWidth: 400, minHeight: 650)
            
            // Right side with the preview - now scrollable for large icons
            ScrollView([.horizontal, .vertical]) {
                VStack {
                    Spacer()
                    
                        // Show actual export size with scroll capability for large icons
                        ScaledIconPreview(settings: viewModel.iconSettings, displaySize: actualExportSize)
                            .padding()
                    
                    VStack(spacing: 4) {
                        Text("Preview")
                            .font(.headline)
                        
                        // Show the actual export dimensions
                        Text("\(Int(actualExportSize))×\(Int(actualExportSize))px")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if actualExportSize > 400 {
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


struct ContentView_Previews: PreviewProvider {
    @MainActor static var previews: some View {
        Group {
            ContentView()
                .previewDisplayName("Default VM")

            ContentView(viewModel: IconViewModel())
                .previewDisplayName("Injected VM")

            ContentView(viewModel: customVM)
                .previewDisplayName("Custom VM")

            ContentView(viewModel: retinaLargeVM)
                .previewDisplayName("Retina 1024px")
        }
    }

    @MainActor private static var customVM: IconViewModel {
        let vm = IconViewModel()
        // Preconfigure a representative setup
        vm.iconSettings.symbolName = "gearshape.fill"
        vm.iconSettings.useCustomColors = true
        vm.iconSettings.customPrimaryColor = .blue
        vm.iconSettings.customSecondaryColor = .indigo
        vm.iconSettings.symbolRenderingMode = .palette
        vm.iconSettings.paletteSymbolPrimaryColor = .white
        vm.iconSettings.paletteSymbolSecondaryColor = .cyan
        vm.iconSettings.paletteSymbolTertiaryColor = .mint
        vm.iconSettings.showBadge = true
        vm.iconSettings.badgePosition = .bottomRight
        vm.iconSettings.badgeSymbolName = "checkmark.seal.fill"
        vm.iconSettings.badgeSymbolRenderingMode = .hierarchical
        vm.iconSettings.badgeHierarchicalSymbolColor = .white
        vm.iconSettings.exportSize = 256
        vm.iconSettings.exportRetinaSize = false
        return vm
    }

    @MainActor private static var retinaLargeVM: IconViewModel {
        let vm = IconViewModel()
        vm.iconSettings.symbolName = "square"
        vm.iconSettings.useCustomColors = false
        vm.iconSettings.baseColor = .orange
        vm.iconSettings.symbolRenderingMode = .monochrome
        vm.iconSettings.symbolColor = .white
        // Configure for 1024px display in preview (512pt @2x)
        vm.iconSettings.exportSize = 256
        vm.iconSettings.exportRetinaSize = false
        return vm
    }
}

// Side-by-side preview grid to compare rendering modes quickly
struct ContentView_GridPreviews: PreviewProvider {
    @MainActor static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                ContentView(viewModel: monoVM)
                    .previewDisplayName("Monochrome")
                ContentView(viewModel: hierarchicalVM)
                    .previewDisplayName("Hierarchical")
            }
            HStack(spacing: 20) {
                ContentView(viewModel: multicolorVM)
                    .previewDisplayName("Multicolor")
                ContentView(viewModel: paletteVM)
                    .previewDisplayName("Palette")
            }
        }
        .padding()
        .previewDisplayName("Rendering Modes Grid")
    }

    @MainActor private static var monoVM: IconViewModel {
        let vm = IconViewModel()
        vm.iconSettings.symbolName = "app"
        vm.iconSettings.useCustomColors = false
        vm.iconSettings.baseColor = .blue
        vm.iconSettings.symbolRenderingMode = .monochrome
        vm.iconSettings.symbolColor = .white
        vm.iconSettings.exportSize = 512
        vm.iconSettings.exportRetinaSize = false
        return vm
    }

    @MainActor private static var hierarchicalVM: IconViewModel {
        let vm = IconViewModel()
        vm.iconSettings.symbolName = "folder.fill.badge.plus"
        vm.iconSettings.useCustomColors = true
        vm.iconSettings.customPrimaryColor = .green
        vm.iconSettings.customSecondaryColor = .blue
        vm.iconSettings.symbolRenderingMode = .hierarchical
        vm.iconSettings.hierarchicalSymbolColor = .white
        vm.iconSettings.exportSize = 256
        vm.iconSettings.exportRetinaSize = false
        return vm
    }

    @MainActor private static var multicolorVM: IconViewModel {
        let vm = IconViewModel()
        vm.iconSettings.symbolName = "drop.fill"
        vm.iconSettings.useCustomColors = false
        vm.iconSettings.baseColor = .gray
        vm.iconSettings.symbolRenderingMode = .multicolor
        vm.iconSettings.exportSize = 256
        vm.iconSettings.exportRetinaSize = false
        return vm
    }

    @MainActor private static var paletteVM: IconViewModel {
        let vm = IconViewModel()
        vm.iconSettings.symbolName = "paintpalette.fill"
        vm.iconSettings.useCustomColors = true
        vm.iconSettings.customPrimaryColor = .pink
        vm.iconSettings.customSecondaryColor = .purple
        vm.iconSettings.symbolRenderingMode = .palette
        vm.iconSettings.paletteSymbolPrimaryColor = .white
        vm.iconSettings.paletteSymbolSecondaryColor = .blue
        vm.iconSettings.paletteSymbolTertiaryColor = .red
        vm.iconSettings.showBadge = true
        vm.iconSettings.badgeSymbolName = "star.fill"
        vm.iconSettings.badgeSymbolRenderingMode = .monochrome
        vm.iconSettings.badgeSymbolColor = .white
        vm.iconSettings.exportSize = 256
        vm.iconSettings.exportRetinaSize = false
        return vm
    }
}

