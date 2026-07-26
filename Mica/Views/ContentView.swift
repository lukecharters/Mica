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
    /// Read here too: with the advanced controls off the inspector shows no layer
    /// tabs, so the preview outlines the whole selected group instead of a layer.
    @AppStorage(SidebarSettings.advancedControlsKey) private var advancedControlsEnabled = false

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
    /// whole group when the inspector isn't showing its layers separately.
    /// Only while the Controls tab is showing — on the Export tab there's no layer
    /// being edited, so the outline would just be in the way.
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
            exposesLayers: !isSystem && advancedControlsEnabled
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

// Preview component that scales based on export size
struct ScaledIconPreview: View {
    @Binding var settings: IconSettings
    let displaySize: CGFloat
    var badgeAppexImage: NSImage? = nil
    var badgeAppexError: String? = nil
    /// Click-to-select: reports which layer the click landed on so the owner can
    /// point the inspector at it. See `PreviewHitTester`.
    var onSelect: ((PreviewHitTarget) -> Void)? = nil
    /// The layer the inspector is editing, outlined in the preview. nil draws nothing.
    var selection: PreviewSelection? = nil
    /// Bumped on each canvas click so re-clicking the selected layer re-shows the
    /// outline after it has faded.
    var selectionPulse: Int = 0

    @State private var dragStart: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var isHoveringBadge: Bool = false
    /// The single cursor this view currently has on NSCursor's stack, if any.
    @State private var pushedCursor: NSCursor? = nil

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

            // Preview-only spinner/error where the System-mode badge will render.
            // BadgeView itself draws nothing until the appex image exists, so this
            // stand-in never reaches exports.
            if settings.showBadge,
               settings.badgeIconSource == .system,
               badgeAppexImage == nil {
                BadgeAppexStatusView(
                    badgeSize: BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badgeScale),
                    error: badgeAppexError
                )
                .offset(BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize))
                .allowsHitTesting(false)
            }

            // Selection outline sits above the icon but below the badge overlay so
            // it never intercepts a drag.
            if let selection,
               let shape = PreviewHitTester.selectionShape(
                   for: selection,
                   settings: settings,
                   displaySize: displaySize
               ) {
                SelectionOutline(
                    shape: shape,
                    canvasSize: canvasSize,
                    displaySize: displaySize,
                    selection: selection,
                    pulse: selectionPulse
                )
            }

            // Draggable badge overlay
            if settings.showBadge {
                badgeDragOverlay
            }
        }
        .frame(width: canvasSize, height: canvasSize, alignment: .center)
        // Attached after the frame so the tap location is in canvas coordinates,
        // which is what PreviewHitTester expects.
        //
        // simultaneousGesture, not .onTapGesture: the badge overlay is a child with
        // its own DragGesture, and a child's gesture normally wins arbitration
        // against the parent's. Recognizing simultaneously keeps a click on the
        // badge from being swallowed. The two still can't fight — a tap needs the
        // pointer to stay put, so a real drag fails the tap, and a stationary click
        // never reaches the drag's 2pt minimum.
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .local)
                .onEnded { value in
                    guard let target = PreviewHitTester.target(
                        at: value.location,
                        settings: settings,
                        displaySize: displaySize
                    ) else { return }
                    onSelect?(target)
                }
        )
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
            // Only track external offset changes (sliders, reset). Re-seeding on the
            // drag's own writes compounds the offset: DragGesture.translation is
            // cumulative from gesture start, so the baseline must stay fixed mid-drag.
            if !isDragging {
                dragStart = CGSize(width: newValue, height: settings.badgeManualOffsetY)
            }
        }
        .onChange(of: settings.badgeManualOffsetY) { _, newValue in
            if !isDragging {
                dragStart = CGSize(width: settings.badgeManualOffsetX, height: newValue)
            }
        }
    }

    /// Transparent circle at the badge position that captures drag gestures.
    /// Diameter matches the rendered badge, so the hover/drag region doesn't
    /// extend past the visible badge.
    private var badgeDragOverlay: some View {
        let badgeDiameter = BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badgeScale)
        let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize)

        return Circle()
            .fill(Color.clear)
            .frame(width: badgeDiameter, height: badgeDiameter)
            .contentShape(Circle())
            .onHover { hovering in
                isHoveringBadge = hovering
                // Mid-drag the closed hand stays put even when the pointer
                // outruns the moving circle; onEnded restores the right cursor.
                if !isDragging {
                    setPushedCursor(hovering ? .openHand : nil)
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
                            setPushedCursor(.closedHand)
                        }
                        let normalizedDX = value.translation.width / enclosureSize
                        let normalizedDY = value.translation.height / enclosureSize
                        let range = IconSettings.badgeOffsetRange
                        settings.badgeManualOffsetX = min(max(dragStart.width + normalizedDX, range.lowerBound), range.upperBound)
                        settings.badgeManualOffsetY = min(max(dragStart.height + normalizedDY, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                        setPushedCursor(isHoveringBadge ? .openHand : nil)
                        dragStart = CGSize(
                            width: settings.badgeManualOffsetX,
                            height: settings.badgeManualOffsetY
                        )
                    }
            )
            .onDisappear {
                // Badge hidden (or preview unmounted) while hovered/dragging —
                // don't leave our cursor on the global stack.
                isHoveringBadge = false
                isDragging = false
                setPushedCursor(nil)
            }
            .offset(offset)
    }

    /// Replaces whatever cursor this view previously pushed with `cursor`
    /// (nil = pop back to the default). Funneling every cursor change through
    /// here keeps NSCursor's global push/pop stack balanced regardless of the
    /// hover/drag/disappear event order.
    private func setPushedCursor(_ cursor: NSCursor?) {
        guard pushedCursor !== cursor else { return }
        if pushedCursor != nil { NSCursor.pop() }
        cursor?.push()
        pushedCursor = cursor
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

//struct ContentView_Previews: PreviewProvider {
//    @MainActor static var previews: some View {
//        Group {
//            ContentView()
//                .previewDisplayName("Default VM")
//                .previewLayout(.fixed(width: 1200, height: 800))
//            
//            ContentView(viewModel: customVM, showInspector: false)
//                .previewDisplayName("Custom VM")
//                .previewLayout(.fixed(width: 1200, height: 800))
//
//
//            ContentView(viewModel: IconViewModel())
//                .previewDisplayName("Injected VM")
//                .previewLayout(.fixed(width: 1200, height: 800))
//
//            ContentView(viewModel: retinaLargeVM)
//                .previewDisplayName("Retina 1024px")
//                .previewLayout(.fixed(width: 1200, height: 800))
//        }
//    }
//
//    @MainActor private static var customVM: IconViewModel {
//        let vm = IconViewModel()
//        vm.iconSettings.iconGenerationMode = .system
//        vm.iconSettings.symbolName = "gearshape.fill"
//        vm.iconSettings.useCustomColors = true
//        vm.iconSettings.customPrimaryColor = .blue
//        vm.iconSettings.customSecondaryColor = .indigo
//        vm.iconSettings.symbolRenderingMode = .monochrome
//        vm.iconSettings.showBadge = true
//        vm.iconSettings.badgePosition = .bottomRight
//        vm.iconSettings.badgeSymbolName = "checkmark.seal.fill"
//        vm.iconSettings.badgeSymbolRenderingMode = .monochrome
//        vm.iconSettings.badgeHierarchicalSymbolColor = .white
//        vm.iconSettings.exportSize = 256
//        vm.iconSettings.exportRetinaSize = false
//        return vm
//    }
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
//}

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
