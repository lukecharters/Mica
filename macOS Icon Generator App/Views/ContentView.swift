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
            .frame(minWidth: 340, maxWidth: 400)

            // Right: Preview pane
            ScrollView([.horizontal, .vertical]) {
                VStack {
                    Spacer()

                    ScaledIconPreview(settings: viewModel.iconSettings, displaySize: actualExportSize)
                        .padding()

                    VStack(spacing: 4) {
                        Text("Preview")
                            .font(.headline)

                        Text("\(Int(actualExportSize))x\(Int(actualExportSize))px")
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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ExportToolbarContent(
                    iconSettings: $viewModel.iconSettings,
                    showExportDialog: $viewModel.showExportDialog
                )
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
}

// Preview component that scales based on export size
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
