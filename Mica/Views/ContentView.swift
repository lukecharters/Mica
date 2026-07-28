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
    @State private var selectedGroup: IconLayerGroup = .icon
    /// Active inspector tab per group, remembered while the app runs so switching
    /// between Icon and Badge returns to where you left off. Not persisted across
    /// launches (matching the sidebar selection, which also resets to Icon).
    @State private var iconTab: LayerTab = .defaultTab(for: .icon)
    @State private var badgeTab: LayerTab = .defaultTab(for: .badge)
    /// Incremented on every canvas click. The selection outline restarts its fade
    /// when this changes, so clicking the already-selected layer still flashes it.
    @State private var selectionPulse: Int = 0
    @State private var appexService = AppexReferenceService()
    /// NavigationSplitView experiment: drives the sidebar column instead of the old
    /// `showLayerSidebar` flag. `.all` shows the sidebar; `.detailOnly` hides it.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showInspector: Bool = true
    @State private var inspectorTab: InspectorTab = .controls

    /// User-adjustable panel widths, persisted across launches. Dragging a divider
    /// writes here; the values are clamped to `sidebarRange` / `inspectorRange`.
    @AppStorage("layout.sidebarWidth") private var sidebarWidth: Double = 280
    @AppStorage("layout.inspectorWidth") private var inspectorWidth: Double = 380
    /// Read here too: the selection outline is an advanced-controls affordance, so
    /// with them off the preview draws none (see `currentPreviewSelection`).
    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    private let sidebarRange: ClosedRange<Double> = 220...360
    private let inspectorRange: ClosedRange<Double> = 330...460


    var body: some View {
        // EXPERIMENT: the left sidebar is now the sidebar column of a NavigationSplitView
        // instead of a hand-rolled panel inside a plain HStack. NavigationSplitView owns
        // the sidebar's translucent material, native drag-resize, and show/hide animation
        // (driven by `columnVisibility`). The preview + inspector remain a plain HStack in
        // the detail column — the inspector keeps its custom `ResizeHandle` and `.move`
        // transition, unchanged, so only the left sidebar's behavior differs.
        NavigationSplitView(columnVisibility: $columnVisibility) {
            LayerSidebar(
                iconSettings: $viewModel.iconSettings,
                selection: $selectedGroup
            )
            .navigationSplitViewColumnWidth(
                min: sidebarRange.lowerBound,
                ideal: sidebarWidth,
                max: sidebarRange.upperBound
            )
        } detail: {
            Group {
                if viewModel.iconSettings.iconGenerationMode == .mica {
                    previewPane
                        .task(id: viewModel.badgeAppexGenerationKey) {
                            guard viewModel.iconSettings.showBadge,
                                  viewModel.iconSettings.badgeGenerationMode == .system else {
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
                        previewPointSize: $previewPointSize,
                        onSelect: select,
                        selection: currentPreviewSelection,
                        selectionPulse: selectionPulse
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // EXPERIMENT: the right panel is now a native `.inspector` trailing column
        // instead of a hand-rolled panel + `ResizeHandle`. `.inspector` owns the
        // material, show/hide animation, and native drag-resize; width is a hint via
        // `.inspectorColumnWidth` (seeded from the old persisted value).
        //
        // It's attached to the whole NavigationSplitView (not to the detail content) on
        // purpose: the detail swaps preview panes between Mica (`previewPane`) and System
        // (`AppexPreviewPane`) modes. `Group` is a transparent container, so decorating
        // it made the inspector's host identity change with the active branch — SwiftUI
        // then rebuilt the inspector and snapped any user-dragged width back to `ideal`.
        // The NavigationSplitView is a stable host, so the dragged width now survives a
        // mode switch (within a session).
        .inspector(isPresented: $showInspector) {
            InspectorPanel(
                iconSettings: $viewModel.iconSettings,
                appexEnclosureColor: $viewModel.appexEnclosureColor,
                appexSymbolColor: $viewModel.appexSymbolColor,
                badgeAppexEnclosureColor: $viewModel.badgeAppexEnclosureColor,
                badgeAppexSymbolColor: $viewModel.badgeAppexSymbolColor,
                showExportDialog: $viewModel.showExportDialog,
                group: selectedGroup,
                iconTab: $iconTab,
                badgeTab: $badgeTab,
                tab: inspectorTab,
                colorOptions: colorOptions,
                appexHasImage: viewModel.appexRenderedImage != nil,
                badgeAppexHasImage: viewModel.badgeAppexRenderedImage != nil
            )
            .inspectorColumnWidth(
                min: inspectorRange.lowerBound,
                ideal: inspectorWidth,
                max: inspectorRange.upperBound
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                ZoomMenu(zoomLevel: $zoomLevel)
                PreviewSizeMenu(previewPointSize: $previewPointSize)
            }
            ToolbarItem(placement: .automatic) {
                Picker("Styling/Export", selection: $inspectorTab) {
                    Label("Controls", systemImage: InspectorTab.controls.systemImage)
                        .tag(InspectorTab.controls)
                    Label("Export", systemImage: InspectorTab.export.systemImage)
                        .tag(InspectorTab.export)
                }
                .pickerStyle(.segmented)
                .help("Inspector tab")
                // Selecting a tab reveals the inspector if it's hidden.
                .onChange(of: inspectorTab) {
                    if !showInspector { showInspector = true }
                }
            }
            if #available(macOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Show Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle Inspector")
            }
        }
        .focusedSceneValue(\.iconSettings, $viewModel.iconSettings)
        .fileExporter(
            isPresented: $viewModel.showExportDialog,
            document: viewModel.iconSettings.iconGenerationMode == .system
                ? PNGExportDocument(appexExport: .init(
                    symbolName: viewModel.iconSettings.symbolName,
                    enclosureColor: viewModel.appexEnclosureColor.plistValue,
                    symbolColor: viewModel.appexSymbolColor.plistValue,
                    pointSize: viewModel.iconSettings.exportSize,
                    scaleFactor: viewModel.iconSettings.exportRetinaSize ? 2 : 1,
                    colorSpace: viewModel.iconSettings.exportColorSpace
                  ),
                  settings: viewModel.iconSettings,
                  badgeAppexImage: viewModel.badgeAppexRenderedImage)
                : PNGExportDocument(settings: viewModel.iconSettings, badgeAppexImage: viewModel.badgeAppexRenderedImage),
            contentType: .png,
            defaultFilename: viewModel.iconSettings.exportBaseName
        ) { result in
            switch result {
            case .success(let url):
                print("Icon saved to: \(url.path)")
            case .failure(let error):
                print("Failed to save icon: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Canvas selection

    /// What the preview outlines: whichever layer the inspector is editing, or the
    /// whole group in System mode, which has no layers to distinguish.
    /// Only while the Controls tab is showing — on the Export tab there's no layer
    /// being edited, so the outline would just be in the way — and only with the
    /// advanced controls on, which is `PreviewSelection.from`'s call.
    private var currentPreviewSelection: PreviewSelection? {
        guard inspectorTab == .controls, showInspector else { return nil }
        let isSystem: Bool
        switch selectedGroup {
        case .icon:  isSystem = viewModel.iconSettings.iconGenerationMode == .system
        case .badge: isSystem = viewModel.iconSettings.badgeGenerationMode == .system
        }
        return PreviewSelection.from(
            group: selectedGroup,
            tab: selectedGroup == .icon ? iconTab : badgeTab,
            isSystem: isSystem,
            advancedControlsEnabled: advancedControlsEnabled
        )
    }

    /// Points the inspector at the layer the user clicked in the preview. The tab
    /// only moves for a group in Mica mode — a System group has no tabs, so
    /// selecting the group is the whole story there. Harmless with the advanced
    /// controls off, where the tab bar is hidden: the tab is simply left pointing
    /// at the clicked layer for when it comes back.
    private func select(_ target: PreviewHitTarget) {
        selectionPulse += 1
        selectedGroup = target.group
        switch target.group {
        case .icon where viewModel.iconSettings.iconGenerationMode == .mica:
            iconTab = target.tab
        case .badge where viewModel.iconSettings.badgeGenerationMode == .mica:
            badgeTab = target.tab
        default:
            break
        }
        // Show the controls that were just targeted, even if the user was on the
        // Export tab or had the inspector closed.
        inspectorTab = .controls
        if !showInspector { showInspector = true }
    }

    // MARK: - Preview Pane

    private var previewPane: some View {
        // Size + zoom controls live in the window toolbar (see `.toolbar`).
        ScrollView([.horizontal, .vertical]) {
            VStack {
//                Spacer(minLength: 0)

                ScaledIconPreview(
                    settings: $viewModel.iconSettings,
                    displaySize: previewDisplaySize,
                    badgeAppexImage: viewModel.badgeAppexRenderedImage,
                    badgeAppexError: viewModel.badgeAppexError,
                    onSelect: select,
                    selection: currentPreviewSelection,
                    selectionPulse: selectionPulse
                )
//                .padding()

//                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

struct ContentView_Previews: PreviewProvider {
    @MainActor static var previews: some View {
        Group {
//            ContentView()
//                .previewDisplayName("Default VM")
//                .previewLayout(.fixed(width: 1200, height: 800))
//            
            ContentView(viewModel: customVM, showInspector: false)
                .previewDisplayName("Custom VM")
                .previewLayout(.fixed(width: 1200, height: 800))


//            ContentView(viewModel: IconViewModel())
//                .previewDisplayName("Injected VM")
//                .previewLayout(.fixed(width: 1200, height: 800))
//
//            ContentView(viewModel: retinaLargeVM)
//                .previewDisplayName("Retina 1024px")
//                .previewLayout(.fixed(width: 1200, height: 800))
        }
    }

    @MainActor private static var customVM: IconViewModel {
        let vm = IconViewModel()
        vm.iconSettings.iconGenerationMode = .mica
        vm.iconSettings.symbolName = "gearshape.fill"
//        vm.iconSettings.useCustomColors = true
//        vm.iconSettings.customPrimaryColor = .blue
//        vm.iconSettings.customSecondaryColor = .indigo
        vm.iconSettings.symbolRenderingMode = .monochrome
        vm.iconSettings.showBadge = true
        vm.iconSettings.badgePosition = .bottomRight
        vm.iconSettings.badgeSymbolName = "checkmark.seal.fill"
        vm.iconSettings.badgeSymbolRenderingMode = .monochrome
        vm.iconSettings.badgeHierarchicalSymbolColor = .white
        vm.iconSettings.exportSize = 512
        vm.iconSettings.exportRetinaSize = false
        return vm
    }
//
//    @MainActor private static var retinaLargeVM: IconViewModel {
//        let vm = IconViewModel()
//        vm.iconSettings.symbolName = "square"
//        vm.iconSettings.useCustomColors = false
//        vm.iconSettings.baseColor = .orange
//        vm.iconSettings.symbolRenderingMode = .monochrome
//        vm.iconSettings.symbolColor = .white
//        vm.iconSettings.exportSize = 256
//        vm.iconSettings.exportRetinaSize = false
//        return vm
//    }
//}
//
//struct ContentView_GridPreviews: PreviewProvider {
//    @MainActor static var previews: some View {
//        VStack(spacing: 20) {
//            HStack(spacing: 20) {
//                ContentView(viewModel: monoVM, showInspector: false)
//                    .previewDisplayName("Monochrome")
//                ContentView(viewModel: hierarchicalVM, showInspector: false)
//                    .previewDisplayName("Hierarchical")
//            }
//            HStack(spacing: 20) {
//                ContentView(viewModel: multicolorVM, showInspector: false)
//                    .previewDisplayName("Multicolor")
//                ContentView(viewModel: paletteVM, showInspector: false)
//                    .previewDisplayName("Palette")
//            }
//        }
//        .padding()
//        .previewDisplayName("Rendering Modes Grid")
//        .previewLayout(.fixed(width: 1500, height: 800))
//    }
//
//    @MainActor private static var monoVM: IconViewModel {
//        let vm = IconViewModel()
//        vm.iconSettings.symbolName = "app"
//        vm.iconSettings.useCustomColors = false
//        vm.iconSettings.baseColor = .blue
//        vm.iconSettings.symbolRenderingMode = .monochrome
//        vm.iconSettings.symbolColor = .white
//        vm.iconSettings.exportSize = 256
//        vm.iconSettings.exportRetinaSize = false
//        return vm
//    }
//
//    @MainActor private static var hierarchicalVM: IconViewModel {
//        let vm = IconViewModel()
//        vm.iconSettings.symbolName = "folder.fill.badge.plus"
//        vm.iconSettings.useCustomColors = true
//        vm.iconSettings.customPrimaryColor = .green
//        vm.iconSettings.customSecondaryColor = .blue
//        vm.iconSettings.symbolRenderingMode = .hierarchical
//        vm.iconSettings.hierarchicalSymbolColor = .white
//        vm.iconSettings.exportSize = 256
//        vm.iconSettings.exportRetinaSize = false
//        return vm
//    }
//
//    @MainActor private static var multicolorVM: IconViewModel {
//        let vm = IconViewModel()
//        vm.iconSettings.symbolName = "drop.fill"
//        vm.iconSettings.useCustomColors = false
//        vm.iconSettings.baseColor = .gray
//        vm.iconSettings.symbolRenderingMode = .multicolor
//        vm.iconSettings.exportSize = 256
//        vm.iconSettings.exportRetinaSize = false
//        return vm
//    }
//
//    @MainActor private static var paletteVM: IconViewModel {
//        let vm = IconViewModel()
//        vm.iconSettings.symbolName = "paintpalette.fill"
//        vm.iconSettings.useCustomColors = true
//        vm.iconSettings.customPrimaryColor = .pink
//        vm.iconSettings.customSecondaryColor = .purple
//        vm.iconSettings.symbolRenderingMode = .palette
//        vm.iconSettings.paletteSymbolPrimaryColor = .white
//        vm.iconSettings.paletteSymbolSecondaryColor = .blue
//        vm.iconSettings.paletteSymbolTertiaryColor = .red
//        vm.iconSettings.showBadge = true
//        vm.iconSettings.badgeSymbolName = "star.fill"
//        vm.iconSettings.badgeSymbolRenderingMode = .monochrome
//        vm.iconSettings.badgeSymbolColor = .white
//        vm.iconSettings.exportSize = 256
//        vm.iconSettings.exportRetinaSize = false
//        return vm
//    }
}

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
