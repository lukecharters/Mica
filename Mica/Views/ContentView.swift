// ContentView.swift - Main view of our application
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Focused Value for Paste

struct FocusedIconSettingsKey: FocusedValueKey {
    typealias Value = Binding<IconSettings>
}

extension FocusedValues {
    var iconSettings: Binding<IconSettings>? {
        get { self[FocusedIconSettingsKey.self] }
        set { self[FocusedIconSettingsKey.self] = newValue }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = IconViewModel()

    init() {}

    init(viewModel: IconViewModel, showInspector: Bool = true) {
        _ = showInspector // kept for source compatibility with existing previews
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    let colorOptions: [(name: String, color: Color)] = OptionsCatalog.colorOptions

    private var actualExportSize: CGFloat { viewModel.iconSettings.finalExportSize }

    @State private var zoomLevel: Double = 1.0
    /// Optional preview-only override of the icon's display point size, used to
    /// simulate how the icon reads in an MDM self service portal. `nil` = export size.
    @State private var previewPointSize: CGFloat? = nil
    @State private var selection: LayerSelection = .group(.icon)
    @State private var appexService = AppexReferenceService()
    @State private var showLayerSidebar: Bool = true
    @State private var showInspector: Bool = true
    @State private var inspectorTab: InspectorTab = .controls

    var body: some View {
        HSplitView {
            if showLayerSidebar {
                LayerSidebar(
                    iconSettings: $viewModel.iconSettings,
                    selection: $selection,
                    appexEnclosureColor: viewModel.appexEnclosureColor,
                    appexSymbolColor: viewModel.appexSymbolColor,
                    badgeAppexEnclosureColor: viewModel.badgeAppexEnclosureColor,
                    badgeAppexSymbolColor: viewModel.badgeAppexSymbolColor
                )
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 340)
            }

            if viewModel.iconSettings.iconGenerationMode == .swiftUI {
                previewPane
                    .task(id: viewModel.badgeAppexGenerationKey) {
                        guard viewModel.iconSettings.showBadge,
                              viewModel.iconSettings.badgeGenerationMode == .appleReference else {
                            return
                        }
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        await viewModel.generateBadgeAppexIcon(service: appexService)
                    }
            } else {
                AppexPreviewPane(
                    viewModel: viewModel,
                    appexService: appexService,
                    zoomLevel: $zoomLevel,
                    previewPointSize: $previewPointSize
                )
            }

            if showInspector {
                InspectorPanel(
                    iconSettings: $viewModel.iconSettings,
                    appexEnclosureColor: $viewModel.appexEnclosureColor,
                    appexSymbolColor: $viewModel.appexSymbolColor,
                    badgeAppexEnclosureColor: $viewModel.badgeAppexEnclosureColor,
                    badgeAppexSymbolColor: $viewModel.badgeAppexSymbolColor,
                    showExportDialog: $viewModel.showExportDialog,
                    selection: selection,
                    tab: inspectorTab,
                    colorOptions: colorOptions,
                    appexHasImage: viewModel.appexRenderedImage != nil
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation { showLayerSidebar.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Layer Sidebar")
            }
            ToolbarItemGroup(placement: .principal) {
                ZoomMenu(zoomLevel: $zoomLevel)
                PreviewSizeMenu(previewPointSize: $previewPointSize)
            }
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    if !showInspector { showInspector = true }
                    inspectorTab = .controls
                } label: {
                    Image(systemName: InspectorTab.controls.systemImage)
                        .symbolVariant(showInspector && inspectorTab == .controls ? .fill : .none)
                }
                .help("Layer Controls")
                
                Button {
                    if !showInspector { showInspector = true }
                    inspectorTab = .export
                } label: {
                    Image(systemName: InspectorTab.export.systemImage)
                }
                .help("Export")
            }
            if #available(macOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation { showInspector.toggle() }
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help("Toggle Inspector")
            }
        }
        .focusedSceneValue(\.iconSettings, $viewModel.iconSettings)
        .fileExporter(
            isPresented: $viewModel.showExportDialog,
            document: viewModel.iconSettings.iconGenerationMode == .appleReference
                ? IconDocument(appexExport: .init(
                    symbolName: viewModel.iconSettings.symbolName,
                    enclosureColor: viewModel.appexEnclosureColor.plistValue,
                    symbolColor: viewModel.appexSymbolColor.plistValue,
                    pointSize: viewModel.iconSettings.exportSize,
                    scaleFactor: viewModel.iconSettings.exportRetinaSize ? 2 : 1,
                    colorSpace: viewModel.iconSettings.exportColorSpace
                  ),
                  settings: viewModel.iconSettings,
                  badgeAppexImage: viewModel.badgeAppexRenderedImage)
                : IconDocument(settings: viewModel.iconSettings, badgeAppexImage: viewModel.badgeAppexRenderedImage),
            contentType: .png,
            defaultFilename: viewModel.iconSettings.iconGenerationMode == .appleReference
                ? "\(viewModel.iconSettings.symbolName)-apple-reference"
                : "CustomIcon"
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
        // Size + zoom controls live in the window toolbar (see `.toolbar`).
        ScrollView([.horizontal, .vertical]) {
            VStack {
                Spacer(minLength: 0)

                ScaledIconPreview(
                    settings: $viewModel.iconSettings,
                    displaySize: previewDisplaySize,
                    badgeAppexImage: viewModel.badgeAppexRenderedImage
                )
                .padding()

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }

    /// Calculates the preview display size based on zoom level
    private var previewDisplaySize: CGFloat {
        if zoomLevel == 0 {
            // "Fit" mode - use a reasonable fixed size
            return 256
        }
        // A selected portal preview size becomes the base that zoom scales;
        // otherwise fall back to the export size (existing behavior).
        let baseSize = previewPointSize ?? actualExportSize
        return baseSize * zoomLevel
    }
}

// Preview component that scales based on export size
struct ScaledIconPreview: View {
    @Binding var settings: IconSettings
    let displaySize: CGFloat
    var badgeAppexImage: NSImage? = nil

    @State private var dragStart: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var isDropTargeted: Bool = false

    private var canvasSize: CGFloat {
        IconContentView.totalCanvasSize(for: settings, displaySize: displaySize)
    }

    /// Enclosure size at the current display scale
    private var enclosureSize: CGFloat {
        displaySize - 2 * (25 * displaySize / 256) // backgroundInset * scaleFactor
    }

    var body: some View {
        ZStack {
            IconContentView(settings: settings, displaySize: displaySize, badgeAppexImage: badgeAppexImage)

            // Draggable badge overlay
            if settings.showBadge {
                badgeDragOverlay
            }
        }
        .frame(width: canvasSize, height: canvasSize, alignment: .center)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: isDropTargeted ? 2 : 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onChange(of: settings.badgeManualOffsetX) { _, newValue in
            dragStart = CGSize(width: newValue, height: settings.badgeManualOffsetY)
        }
        .onChange(of: settings.badgeManualOffsetY) { _, newValue in
            dragStart = CGSize(width: settings.badgeManualOffsetX, height: newValue)
        }
    }

    /// Transparent circle at the badge position that captures drag gestures
    private var badgeDragOverlay: some View {
        let badgeDiameter = enclosureSize * (100.0 / 208.0) * settings.badgeScale
        let offset = computeBadgeOffset()

        return Circle()
            .fill(Color.clear)
            .frame(width: badgeDiameter, height: badgeDiameter)
            .contentShape(Circle())
            .onHover { hovering in
                if hovering && settings.showBadge {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStart = CGSize(
                                width: settings.badgeManualOffsetX,
                                height: settings.badgeManualOffsetY
                            )
                            NSCursor.closedHand.push()
                        }
                        let normalizedDX = value.translation.width / enclosureSize
                        let normalizedDY = value.translation.height / enclosureSize
                        let range = IconSettings.badgeOffsetRange
                        settings.badgeManualOffsetX = min(max(dragStart.width + normalizedDX, range.lowerBound), range.upperBound)
                        settings.badgeManualOffsetY = min(max(dragStart.height + normalizedDY, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                        NSCursor.pop()
                        dragStart = CGSize(
                            width: settings.badgeManualOffsetX,
                            height: settings.badgeManualOffsetY
                        )
                    }
            )
            .offset(offset)
    }

    /// Compute badge offset matching IconContentView's logic
    private func computeBadgeOffset() -> CGSize {
        let anchorX = enclosureSize * (76.0 / 208.0)
        let anchorY = enclosureSize * (80.0 / 208.0)
        let manualX = enclosureSize * settings.badgeManualOffsetX
        let manualY = enclosureSize * settings.badgeManualOffsetY
        switch settings.badgePosition {
        case .topRight:    return CGSize(width: anchorX + manualX, height: -anchorY + manualY)
        case .topLeft:     return CGSize(width: -anchorX + manualX, height: -anchorY + manualY)
        case .bottomRight: return CGSize(width: anchorX + manualX, height: anchorY + manualY)
        case .bottomLeft:  return CGSize(width: -anchorX + manualX, height: anchorY + manualY)
        }
    }

    // MARK: - Drag and Drop

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let urlData = data as? Data,
                          let url = URL(dataRepresentation: urlData, relativeTo: nil)
                    else { return }
                    Task { @MainActor in
                        do {
                            let imported = try ImageImportService.importFromURL(url)
                            // Dropped files → icon background, padding compensation on
                            // (fill the frame) and shadow off by default.
                            settings.applyImportedIconBackground(imported)
                        } catch {
                            print("Drop import failed: \(error.localizedDescription)")
                        }
                    }
                }
                return // Only process first item
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    @MainActor static var previews: some View {
        Group {
            ContentView()
                .previewDisplayName("Default VM")
                .previewLayout(.fixed(width: 1200, height: 800))
            
            ContentView(viewModel: customVM, showInspector: false)
                .previewDisplayName("Custom VM")
                .previewLayout(.fixed(width: 1200, height: 800))


            ContentView(viewModel: IconViewModel())
                .previewDisplayName("Injected VM")
                .previewLayout(.fixed(width: 1200, height: 800))

            ContentView(viewModel: retinaLargeVM)
                .previewDisplayName("Retina 1024px")
                .previewLayout(.fixed(width: 1200, height: 800))
        }
    }

    @MainActor private static var customVM: IconViewModel {
        let vm = IconViewModel()
        vm.iconSettings.iconGenerationMode = .appleReference
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
                ContentView(viewModel: monoVM, showInspector: false)
                    .previewDisplayName("Monochrome")
                ContentView(viewModel: hierarchicalVM, showInspector: false)
                    .previewDisplayName("Hierarchical")
            }
            HStack(spacing: 20) {
                ContentView(viewModel: multicolorVM, showInspector: false)
                    .previewDisplayName("Multicolor")
                ContentView(viewModel: paletteVM, showInspector: false)
                    .previewDisplayName("Palette")
            }
        }
        .padding()
        .previewDisplayName("Rendering Modes Grid")
        .previewLayout(.fixed(width: 1500, height: 800))
    }

    @MainActor private static var monoVM: IconViewModel {
        let vm = IconViewModel()
        vm.iconSettings.symbolName = "app"
        vm.iconSettings.useCustomColors = false
        vm.iconSettings.baseColor = .blue
        vm.iconSettings.symbolRenderingMode = .monochrome
        vm.iconSettings.symbolColor = .white
        vm.iconSettings.exportSize = 256
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

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
