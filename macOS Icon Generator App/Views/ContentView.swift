// ContentView.swift - Main view of our application
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = IconViewModel()

    init() {}

    init(viewModel: IconViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    let colorOptions: [(name: String, color: Color)] = OptionsCatalog.colorOptions

    private var actualExportSize: CGFloat { viewModel.iconSettings.finalExportSize }

    @State private var selectedTab: Int = 0
    @State private var zoomLevel: Double = 1.0
    @State private var showInspector: Bool = true

    var body: some View {
        HSplitView {
            // Left: TabView with settings
            TabView(selection: $selectedTab) {
                IconTabContent(iconSettings: $viewModel.iconSettings, colorOptions: colorOptions)
                    .tabItem { Label("Icon", systemImage: "app") }
                    .tag(0)
                BadgeTabContent(iconSettings: $viewModel.iconSettings, colorOptions: colorOptions)
                    .tabItem { Label("Badge", systemImage: "seal") }
                    .tag(1)
            }
            .tabViewStyle(GroupedTabViewStyle())
            .frame(minWidth: 350, maxWidth: 600)

            // Center: Preview pane with overlay controls
            previewPane

            // Right: Export settings sidebar (inspector)
            if showInspector {
                ExportSettingsSidebar(
                    iconSettings: $viewModel.iconSettings,
                    showExportDialog: $viewModel.showExportDialog
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation {
                        showInspector.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help("Toggle Inspector")
            }
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

    // MARK: - Preview Pane

    private var previewPane: some View {
        ZStack(alignment: .topTrailing) {
            // Scrollable preview area
            ScrollView([.horizontal, .vertical]) {
                VStack {
                    Spacer(minLength: 60) // Space for controls overlay

                    ScaledIconPreview(
                        settings: viewModel.iconSettings,
                        displaySize: previewDisplaySize
                    )
                    .padding()

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))

            // Overlay controls (top-right)
            PreviewControls(
                iconSettings: $viewModel.iconSettings,
                zoomLevel: $zoomLevel
            )
            .padding(12)
        }
    }

    /// Calculates the preview display size based on zoom level
    private var previewDisplaySize: CGFloat {
        if zoomLevel == 0 {
            // "Fit" mode - use a reasonable fixed size
            return 256
        }
        return actualExportSize * zoomLevel
    }
}

// Preview component that scales based on export size
struct ScaledIconPreview: View {
    let settings: IconSettings
    let displaySize: CGFloat

    private var canvasSize: CGFloat {
        IconContentView.totalCanvasSize(for: settings, displaySize: displaySize)
    }

    var body: some View {
        IconContentView(settings: settings, displaySize: displaySize)
            .frame(width: canvasSize, height: canvasSize, alignment: .center)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

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
        vm.iconSettings.symbolName = "gearshape.fill"
        vm.iconSettings.useCustomColors = true
        vm.iconSettings.customPrimaryColor = .blue
        vm.iconSettings.customSecondaryColor = .indigo
        vm.iconSettings.symbolRenderingMode = .monochrome
        vm.iconSettings.showBadge = true
        vm.iconSettings.badgePosition = .bottomRight
        vm.iconSettings.badgeSymbolName = "checkmark.seal.fill"
        vm.iconSettings.badgeSymbolRenderingMode = .monochrome
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
        vm.iconSettings.exportSize = 256
        vm.iconSettings.exportRetinaSize = false
        return vm
    }
}

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
