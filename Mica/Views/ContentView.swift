// ContentView.swift - Main view of our application
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Focused Values

/// What the menu commands in `MicaApp` reach for: the focused window's settings (the
/// Paste as… and Import as… items) and its export trigger (File ▸ Export as PNG…).
///
/// Both use `@Entry`, the same idiom `ContinuousEditScope` uses for the environment.
/// `iconSettings` predates `@Entry` and was written as an explicit `FocusedValueKey`;
/// it was converted when `exportPNG` arrived rather than leave two spellings of one
/// concept side by side in the same extension.
extension FocusedValues {
    @Entry var iconSettings: Binding<IconSettings>?

    /// Set to `true` to open the PNG export dialog.
    ///
    /// Published only while the focused window can actually export — see
    /// `IconViewModel.canExport` — so the File menu item is driven by one rule: it is
    /// disabled whenever this is nil, whether that is because no window has focus or
    /// because a System-mode layer is still waiting on its appex render. A menu item
    /// that stayed enabled in the second case would write a PNG missing that layer.
    @Entry var exportPNG: Binding<Bool>?

    /// Run the focused window's Export Configuration… flow.
    ///
    /// An action rather than a `Binding<Bool>` like `exportPNG`, because this menu item
    /// has work to do before a panel can open: the configuration has to be encoded to
    /// know whether it is writing a `.json` file or a `.folder`, and that answer is the
    /// content type `fileExporter` needs up front. The rule for which to use is that
    /// simple: a binding when the menu only flips a flag, an action when it must run
    /// something first.
    @Entry var exportConfiguration: FocusedAction?
}

/// A menu-invokable action published by the focused window.
///
/// `FocusedValues` entries have to be plain values, and a bare `(() -> Void)?` entry
/// reads as a double optional at the use site. Wrapping it keeps `MicaApp`'s call
/// `exportConfiguration?.perform()` and its `disabled(exportConfiguration == nil)`
/// symmetric with every other command there.
struct FocusedAction {
    let perform: () -> Void
}

struct ContentView: View {
    @StateObject private var viewModel = IconViewModel()

    init() {}

    init(viewModel: IconViewModel, showInspector: Bool = true) {
        _ = showInspector // kept for source compatibility with existing previews
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    let colorOptions: [(name: String, color: Color)] = OptionsCatalog.colorOptions

    private var actualExportSize: CGFloat { viewModel.iconSettings.export.pixelSize }

    /// The window's own undo manager, which is what `@Environment(\.undoManager)` gives
    /// a plain `WindowGroup` — verified `===` the window's `NSUndoManager` in the running
    /// app. Drives the observers below; see `IconViewModel+Undo.swift`.
    @Environment(\.undoManager) private var undoManager

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
                if viewModel.iconSettings.icon.mode == .mica {
                    previewPane
                        .task(id: viewModel.badgeAppexGenerationKey) {
                            guard viewModel.iconSettings.badge.isVisible,
                                  viewModel.iconSettings.badge.mode == .system else {
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
                canExport: viewModel.canExport
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
        .focusedSceneValue(\.exportPNG, viewModel.canExport ? $viewModel.showExportDialog : nil)
        // Always available: a configuration is just the settings, so unlike a PNG
        // export there is nothing it can be waiting on.
        .focusedSceneValue(\.exportConfiguration, FocusedAction { viewModel.beginConfigurationExport() })
        // Undo. Every change to the two pieces of editable state is observed here —
        // centrally, rather than at the many bindings that write them.
        //
        // Both handlers are deliberately thin: the policy (what came from an undo, what
        // belongs to a gesture, what the action is called) is in IconViewModel+Undo.swift
        // so it can be tested in the order SwiftUI actually calls it — mutate, then
        // observe. A previous version decided that policy here and got redo wrong in a
        // way no unit test could reach.
        .onChange(of: viewModel.iconSettings) { previous, _ in
            viewModel.settingsDidChange(from: previous, undoManager: undoManager)
        }
        .onChange(of: viewModel.micaAppexColors) { previous, _ in
            viewModel.appexColorsDidChange(from: previous, undoManager: undoManager)
        }
        // Lets a slider or the badge drag group its frames into one undo action.
        .environment(\.continuousEdit, viewModel.continuousEditScope)
        .fileExporter(
            isPresented: $viewModel.showExportDialog,
            document: viewModel.iconSettings.icon.mode == .system
                ? PNGExportDocument(appexExport: .init(
                    symbolName: viewModel.iconSettings.icon.foreground.symbolName,
                    enclosureColor: viewModel.appexEnclosureColor.plistValue,
                    symbolColor: viewModel.appexSymbolColor.plistValue,
                    pointSize: viewModel.iconSettings.export.size,
                    scaleFactor: viewModel.iconSettings.export.isRetina ? 2 : 1,
                    colorSpace: viewModel.iconSettings.export.colorSpace
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
        // The configuration export, deliberately hosted on its own view.
        //
        // **A view gets one `fileExporter`.** Stacking a second directly on this one
        // does not add a presentation — the outer modifier wins and the inner is
        // silently ignored, with no warning at build or run time. Written that way, the
        // configuration exporter above swallowed the PNG exporter below it: Cmd-S
        // worked, Cmd-Shift-E did nothing at all, and no test could see it because the
        // failure is in view composition rather than in any value. Found in manual
        // testing on 2026-08-01, having passed every automated gate.
        //
        // An empty background view is its own presentation host, so each exporter gets
        // one. Anything else presenting from this view — the Phase 8 importer — needs
        // the same treatment.
        .background {
            Color.clear
                // `contentType` follows the prepared document: a configuration with
                // imported images is written as a folder, because the sandbox grants
                // only what the user picked in the save panel and a chosen file does
                // not cover its siblings. See ConfigurationExportDocument.
                .fileExporter(
                    isPresented: $viewModel.showConfigExportDialog,
                    document: viewModel.configExportDocument,
                    contentType: viewModel.configExportDocument?.contentType ?? .json,
                    defaultFilename: viewModel.iconSettings.exportBaseName
                ) { result in
                    switch result {
                    case .success(let url):
                        print("Configuration saved to: \(url.path)")
                    case .failure(let error):
                        viewModel.configExportError = error.localizedDescription
                    }
                    viewModel.configExportDocument = nil
                }
        }
        .alert(
            "Couldn’t Export the Configuration",
            isPresented: Binding(
                get: { viewModel.configExportError != nil },
                set: { if !$0 { viewModel.configExportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.configExportError = nil }
        } message: {
            Text(viewModel.configExportError ?? "")
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
        case .icon:  isSystem = viewModel.iconSettings.icon.mode == .system
        case .badge: isSystem = viewModel.iconSettings.badge.mode == .system
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
        case .icon where viewModel.iconSettings.icon.mode == .mica:
            iconTab = target.tab
        case .badge where viewModel.iconSettings.badge.mode == .mica:
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
        vm.iconSettings.icon.mode = .mica
        vm.iconSettings.icon.foreground.symbolName = "gearshape.fill"
//        vm.iconSettings.icon.background.usesCustomGradient = true
//        vm.iconSettings.icon.background.gradientStartColor = .blue
//        vm.iconSettings.icon.background.gradientEndColor = .indigo
        vm.iconSettings.icon.foreground.renderingStyle = .monochrome
        vm.iconSettings.badge.isVisible = true
        vm.iconSettings.badge.position = .bottomRight
        vm.iconSettings.badge.foreground.symbolName = "checkmark.seal.fill"
        vm.iconSettings.badge.foreground.renderingStyle = .monochrome
        vm.iconSettings.badge.foreground.hierarchicalColor = .white
        vm.iconSettings.export.size = 512
        vm.iconSettings.export.isRetina = false
        return vm
    }
//
//    @MainActor private static var retinaLargeVM: IconViewModel {
//        let vm = IconViewModel()
//        vm.iconSettings.icon.foreground.symbolName = "square"
//        vm.iconSettings.icon.background.usesCustomGradient = false
//        vm.iconSettings.icon.background.color = .orange
//        vm.iconSettings.icon.foreground.renderingStyle = .monochrome
//        vm.iconSettings.icon.foreground.color = .white
//        vm.iconSettings.export.size = 256
//        vm.iconSettings.export.isRetina = false
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
//        vm.iconSettings.icon.foreground.symbolName = "app"
//        vm.iconSettings.icon.background.usesCustomGradient = false
//        vm.iconSettings.icon.background.color = .blue
//        vm.iconSettings.icon.foreground.renderingStyle = .monochrome
//        vm.iconSettings.icon.foreground.color = .white
//        vm.iconSettings.export.size = 256
//        vm.iconSettings.export.isRetina = false
//        return vm
//    }
//
//    @MainActor private static var hierarchicalVM: IconViewModel {
//        let vm = IconViewModel()
//        vm.iconSettings.icon.foreground.symbolName = "folder.fill.badge.plus"
//        vm.iconSettings.icon.background.usesCustomGradient = true
//        vm.iconSettings.icon.background.gradientStartColor = .green
//        vm.iconSettings.icon.background.gradientEndColor = .blue
//        vm.iconSettings.icon.foreground.renderingStyle = .hierarchical
//        vm.iconSettings.icon.foreground.hierarchicalColor = .white
//        vm.iconSettings.export.size = 256
//        vm.iconSettings.export.isRetina = false
//        return vm
//    }
//
//    @MainActor private static var multicolorVM: IconViewModel {
//        let vm = IconViewModel()
//        vm.iconSettings.icon.foreground.symbolName = "drop.fill"
//        vm.iconSettings.icon.background.usesCustomGradient = false
//        vm.iconSettings.icon.background.color = .gray
//        vm.iconSettings.icon.foreground.renderingStyle = .multicolor
//        vm.iconSettings.export.size = 256
//        vm.iconSettings.export.isRetina = false
//        return vm
//    }
//
//    @MainActor private static var paletteVM: IconViewModel {
//        let vm = IconViewModel()
//        vm.iconSettings.icon.foreground.symbolName = "paintpalette.fill"
//        vm.iconSettings.icon.background.usesCustomGradient = true
//        vm.iconSettings.icon.background.gradientStartColor = .pink
//        vm.iconSettings.icon.background.gradientEndColor = .purple
//        vm.iconSettings.icon.foreground.renderingStyle = .palette
//        vm.iconSettings.icon.foreground.palettePrimaryColor = .white
//        vm.iconSettings.icon.foreground.paletteSecondaryColor = .blue
//        vm.iconSettings.icon.foreground.paletteTertiaryColor = .red
//        vm.iconSettings.badge.isVisible = true
//        vm.iconSettings.badge.foreground.symbolName = "star.fill"
//        vm.iconSettings.badge.foreground.renderingStyle = .monochrome
//        vm.iconSettings.badge.foreground.color = .white
//        vm.iconSettings.export.size = 256
//        vm.iconSettings.export.isRetina = false
//        return vm
//    }
}

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
