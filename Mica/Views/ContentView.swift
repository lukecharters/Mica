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

    /// Open the focused window's Import Configuration… panel. An action for symmetry
    /// with `exportConfiguration`, since the pair is one feature in the File menu.
    @Entry var importConfiguration: FocusedAction?

    /// Copy the focused window's rendered icon to the pasteboard.
    ///
    /// Gated on `canExport` exactly as `exportPNG` is, and for the same reason: a copy
    /// made while a System-mode layer's appex raster is pending would put an icon on
    /// the pasteboard with that layer missing. Copy, drag-out and ⇧⌘E are three faces
    /// of one export and answer to one rule.
    @Entry var copyIcon: FocusedAction?

    // MARK: The View menu
    //
    // Four entries, all plain window state — the View menu shows the window you are
    // looking at, so each is nil when nothing has focus and the menu item disables
    // itself on that alone. None of them is gated on `canExport`: unlike Copy or
    // Export, hiding the inspector while a System-mode raster is pending is a
    // perfectly good thing to do.
    //
    // "Show Advanced Controls" is deliberately **not** here. It is an app-wide
    // preference, so `MicaApp` reads it with `@AppStorage` directly and the item
    // stays enabled with no window open, exactly as Settings ▸ General does.

    /// The sidebar column's visibility. A `Bool` rather than the
    /// `NavigationSplitViewVisibility` it really is, because a menu item can only
    /// show or hide — the `.doubleColumn` case has no meaning in a two-column app.
    @Entry var sidebarVisible: Binding<Bool>?

    /// The trailing `.inspector` column's visibility.
    @Entry var inspectorVisible: Binding<Bool>?

    /// The preview's zoom level, walked by View ▸ Zoom In / Zoom Out along
    /// `PreviewZoom.levels`.
    @Entry var previewZoom: Binding<Double>?

    /// The preview's point-size override, or nil to follow the export size. A
    /// `Binding` to an `Optional` rather than a `@FocusedBinding`, which would make
    /// the use site a double optional and lose the difference between "no window"
    /// and "Match Export Size".
    @Entry var previewPointSize: Binding<CGFloat?>?
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

/// Publishes the window state the View menu drives, plus the reporter the Edit
/// and File menus tell their failures to.
///
/// A `ViewModifier` for a mechanical reason, not an architectural one: applying
/// these `.focusedSceneValue`s directly in `ContentView.body` puts it past the
/// type-checker's time limit. Here they are their own expression, and anything
/// else the window publishes should join them rather than extend the chain in
/// `body` — the reporter did, when B3 needed a fifth.
private struct WindowFocusValues: ViewModifier {
    let sidebarVisible: Binding<Bool>
    let inspectorVisible: Binding<Bool>
    let previewZoom: Binding<Double>
    let previewPointSize: Binding<CGFloat?>
    let messageReporter: UserMessageReporter

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.sidebarVisible, sidebarVisible)
            .focusedSceneValue(\.inspectorVisible, inspectorVisible)
            .focusedSceneValue(\.previewZoom, previewZoom)
            .focusedSceneValue(\.previewPointSize, previewPointSize)
            .focusedSceneValue(\.userMessageReporter, messageReporter)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = IconViewModel()

    /// The one place Settings ▸ Export is read. A new window opens at the user's
    /// preferred size and colour space; windows already open are untouched, which
    /// is the whole difference between a default and a setting.
    init() {
        _viewModel = StateObject(wrappedValue: IconViewModel(export: .fromPreferences()))
    }

    init(viewModel: IconViewModel, showInspector: Bool = true) {
        _ = showInspector // kept for source compatibility with existing previews
        _viewModel = StateObject(wrappedValue: viewModel)
    }


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
    /// The badge's way back out of System mode. Owned here, not by the toolbar menu:
    /// this view is mounted for the window's whole life, so the remembered source
    /// cannot go stale. (It lived in `InspectorControls` for the same reason until
    /// the mode picker moved to the toolbar on 2026-08-04.)
    @State private var badgeModeMemory = BadgeModeMemory()
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
                        selectionPulse: selectionPulse,
                        makeDragPayload: makeDragPayload,
                        contextActions: previewContextActions
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Focus-resolved ⌘C. `.onCopyCommand` hooks the **standard** Copy, which is
            // the only way the icon can answer to ⌘C at all: two menu items sharing one
            // key equivalent are deduplicated when the menu is built and the later one
            // silently loses its shortcut (measured 2026-08-04, see MicaApp.swift).
            //
            // `.focusable()` is what makes it reachable — the command routes to the
            // focused view, so without it the canvas is never asked. A text field with a
            // selection keeps its own Copy, which is the behaviour we want.
            .focusable()
            .onCopyCommand(perform: copyIconProviders)
            // Arrow keys nudge the badge — the keyboard equivalent of the canvas
            // drag, which was mouse-only. Attached beside `.onCopyCommand` and
            // not inside either preview because both commands mean "the canvas
            // has focus", and `.focusable()` above is the one thing that makes
            // either reachable. It therefore works in System mode too, where the
            // canvas is `AppexPreviewPane` and there is no drag overlay at all.
            //
            // `perform:` takes a method rather than a closure deliberately:
            // `body` sits at the type-checker's ceiling and has been pushed over
            // it four times, most recently by a fifth `.onChange`.
            .onMoveCommand(perform: nudgeBadge)
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
                canExport: viewModel.canExport
            )
            .inspectorColumnWidth(
                min: inspectorRange.lowerBound,
                ideal: inspectorWidth,
                max: inspectorRange.upperBound
            )
        }
        // One `ToolbarContent` type, not an inline block. Adding the two
        // generation-mode menus inline broke the build with "unable to type-check
        // this expression in reasonable time" — `body`'s fourth trip over that
        // ceiling. See `IconWindowToolbar`.
        .toolbar {
            IconWindowToolbar(
                iconIsSystem: iconModeBinding,
                badgeIsSystem: badgeModeBinding,
                zoomLevel: $zoomLevel,
                previewPointSize: $previewPointSize,
                inspectorTab: $inspectorTab,
                showInspector: $showInspector
            )
        }
        .focusedSceneValue(\.iconSettings, $viewModel.iconSettings)
        .focusedSceneValue(\.exportPNG, viewModel.canExport ? $viewModel.showExportDialog : nil)
        // Always available: a configuration is just the settings, so unlike a PNG
        // export there is nothing it can be waiting on.
        .focusedSceneValue(\.exportConfiguration, FocusedAction { viewModel.beginConfigurationExport() })
        .focusedSceneValue(\.importConfiguration, FocusedAction { viewModel.showConfigImportDialog = true })
        .focusedSceneValue(\.copyIcon, copyIconAction)
        // The View menu's four plus the message reporter, as one modifier.
        //
        // **Four more `.focusedSceneValue` calls on `body` do not compile** — the
        // build failed with "unable to type-check this expression in reasonable
        // time", the same wall the configuration dialogs and the fourth alert hit.
        // `WindowFocusValues` is a `ViewModifier` purely so its applications are
        // type-checked in their own body. Anything else this view publishes should
        // join it rather than extend the chain here.
        .modifier(WindowFocusValues(
            sidebarVisible: sidebarVisibleBinding,
            inspectorVisible: $showInspector,
            previewZoom: $zoomLevel,
            previewPointSize: $previewPointSize,
            messageReporter: viewModel.messageReporter
        ))
        // The in-window route to the same alert: the canvas drop and the
        // inspector's Choose File… buttons, both too deep to hand a closure to.
        // See `UserMessage`.
        .environment(\.reportUserMessage, viewModel.messageReporter)
        // Undo. Every change to the two pieces of editable state is observed here —
        // centrally, rather than at the many bindings that write them.
        //
        // Both handlers are deliberately thin: the policy (what came from an undo, what
        // belongs to a gesture, what the action is called) is in IconViewModel+Undo.swift
        // so it can be tested in the order SwiftUI actually calls it — mutate, then
        // observe. A previous version decided that policy here and got redo wrong in a
        // way no unit test could reach.
        .onChange(of: viewModel.iconSettings) { previous, current in
            viewModel.settingsDidChange(from: previous, undoManager: undoManager)
            // Piggy-backing rather than taking a fifth `.onChange`: the badge can
            // reach a new source from anywhere — the inspector, a pasted image, an
            // imported configuration, an undo — and the toolbar's mode menu has to
            // remember whichever one, not only the ones it set itself. `observe`
            // ignores `.system` and is a no-op on an unchanged value, so running it
            // on every settings change costs nothing. A dedicated `.onChange` here
            // put `body` over the type-checker's ceiling; see the `.toolbar` note.
            badgeModeMemory.observe(current.badge.foreground.source)
        }
        .onChange(of: viewModel.micaAppexColors) { previous, _ in
            viewModel.appexColorsDidChange(from: previous, undoManager: undoManager)
        }
        // Lets a slider or the badge drag group its frames into one undo action.
        .environment(\.continuousEdit, viewModel.continuousEditScope)
        .fileExporter(
            isPresented: $viewModel.showExportDialog,
            document: pngExportDocument,
            contentType: .png,
            defaultFilename: viewModel.iconSettings.exportBaseName
        ) { result in
            // **This was the review's worst case**: both branches were a `print()`,
            // so a PNG export that failed told the user nothing whatever. Success
            // stays silent on purpose — the file is where they asked for it, and an
            // alert saying so is a dialog to dismiss for no reason.
            if case .failure(let error) = result {
                viewModel.report(.exportFailed(error))
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
                    if case .failure(let error) = result {
                        viewModel.report(.configurationExportFailed(error))
                    }
                    viewModel.configExportDocument = nil
                }
        }
        // Its own host again — a view gets one `fileImporter` just as it gets one
        // `fileExporter`, and stacking them on the shared view is what silently killed
        // Cmd-Shift-E. `.folder` is offered alongside `.json` because an exported
        // configuration with images is a folder.
        .background {
            Color.clear
                .fileImporter(
                    isPresented: $viewModel.showConfigImportDialog,
                    allowedContentTypes: [.json, .folder]
                ) { result in
                    switch result {
                    case .success(let url):
                        viewModel.importConfiguration(from: url, undoManager: undoManager)
                    case .failure(let error):
                        viewModel.report(.configurationImportFailed(error))
                    }
                }
        }
        // **The** alert. There were four here until 2026-08-05 — one per error
        // property — beside seven `print()`s that told the user nothing at all;
        // item B3 of `docs/plans/mac-conventions.md`. Everything a discrete action
        // can fail at now arrives as a `UserMessage`, from the menus through a
        // focused value and from the views through the environment.
        //
        // `presenting:` rather than reading the property in the message closure, so
        // the text is the message that was reported and cannot be the *next* one:
        // SwiftUI keeps the presented value while the alert dismisses, where a
        // fresh read would blank it mid-animation.
        //
        // `isPresented:` is a computed property rather than an inline
        // `Binding(get:set:)` — four inline ones is what pushed `body` past the
        // type-checker's time limit, and one is not an invitation to go back.
        .alert(
            viewModel.userMessage?.title ?? "",
            isPresented: userMessageIsPresented,
            presenting: viewModel.userMessage
        ) { _ in
            Button("OK", role: .cancel) { viewModel.userMessage = nil }
        } message: { message in
            Text(message.message)
        }
    }

    // MARK: - Alert presentation
    //
    // The alert's `Binding<Bool>` lives out here because inline
    // `Binding(get:set:)` arguments inside `body` exceed the type-checker's time
    // limit; see the note at the alert itself.

    private var userMessageIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.userMessage != nil },
            set: { if !$0 { viewModel.userMessage = nil } }
        )
    }

    /// `columnVisibility` as the show/hide a menu item can drive.
    ///
    /// Reading it as "not `.detailOnly`" rather than "== `.all`" so the transient
    /// `.doubleColumn` a drag can leave behind still reads as shown; writing goes
    /// to the two cases the sidebar toggle has always used.
    ///
    /// Out here rather than inline in `body` for the reason the alerts are — an
    /// extra `Binding(get:set:)` argument inside `body` is what pushed this view
    /// past the type-checker's time limit twice already.
    private var sidebarVisibleBinding: Binding<Bool> {
        Binding(
            get: { columnVisibility != .detailOnly },
            set: { columnVisibility = $0 ? .all : .detailOnly }
        )
    }

    // MARK: - Generation mode
    //
    // Out here for the same reason as the bindings above: `body` already sits at the
    // type-checker's ceiling, and two more inline `Binding(get:set:)` arguments in
    // the toolbar is exactly the shape that has pushed it over three times.

    /// Drives the icon's toolbar mode menu. The icon stores its mode outright.
    private var iconModeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.iconSettings.icon.mode == .system },
            set: { viewModel.iconSettings.icon.mode = $0 ? .system : .mica }
        )
    }

    /// Drives the badge's toolbar mode menu. The badge has no stored mode — it is
    /// derived from its foreground source — so switching overwrites the source and
    /// `badgeModeMemory` is what brings the user's choice back. See `BadgeModeMemory`.
    private var badgeModeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.iconSettings.badge.mode == .system },
            set: { badgeModeMemory.setSystem($0, in: &viewModel.iconSettings) }
        )
    }

    /// The Copy Icon command, or nil while copying would produce the wrong icon.
    ///
    /// Lifted out of `body` for the same type-checking reason as the alert above.
    private var copyIconAction: FocusedAction? {
        guard viewModel.canExport else { return nil }
        return FocusedAction { copyIconToPasteboard() }
    }

    /// The standard Copy's payload while the canvas is focused, or nil to leave ⌘C to
    /// whatever else can handle it.
    ///
    /// Gated on `canExport` exactly as `copyIconAction` is — and returning nil here does
    /// more than skip the work: it leaves the standard Copy *disabled*, so ⌘C cannot
    /// quietly copy an icon with a System-mode layer still pending.
    ///
    /// Lifted out of `body` for the same type-checking reason as the alerts.
    private var copyIconProviders: (() -> [NSItemProvider])? {
        guard viewModel.canExport else { return nil }
        return {
            do {
                return [try IconPasteboard.itemProvider(document: pngExportDocument)]
            } catch {
                viewModel.report(.copyFailed(error))
                return []
            }
        }
    }

    /// What the canvas context menu's three command rows do, and whether the two
    /// export-shaped ones are offered at all. See `IconContextMenu` for which rows
    /// exist; this is only the part the settings cannot perform.
    ///
    /// One value rather than three or four arguments on both preview views: this
    /// `body` has been pushed past the type-checker's time limit four times, and
    /// every extra argument in those two initializers is a step back toward it.
    ///
    /// Each command routes to the *same* call its menu item makes — the copy
    /// helper below, the export flag ⇧⌘E sets, and the shared paste action the
    /// Edit menu's four Paste as… items use. A context menu is a second route to
    /// a command and must never become a second implementation of it.
    private var previewContextActions: PreviewContextActions {
        PreviewContextActions(canExport: viewModel.canExport) { command in
            switch command {
            case .copyIcon:
                copyIconToPasteboard()
            case .exportPNG:
                viewModel.showExportDialog = true
            case .pasteBackground(let group):
                ImageImportAction.paste(
                    into: &viewModel.iconSettings,
                    reporter: viewModel.messageReporter
                ) { settings, image in
                    ImageImportAction.applyBackground(
                        image,
                        to: group,
                        in: &settings,
                        defaults: .fromPreferences()
                    )
                }
            }
        }
    }

    /// Move the badge by one arrow press. See `BadgeNudge`, which owns the step,
    /// the clamp and the "is there a badge to move?" question — this is the wiring
    /// only, so the decision can be tested without a view.
    private func nudgeBadge(_ direction: MoveCommandDirection) {
        BadgeNudge.apply(direction, to: &viewModel.iconSettings)
    }

    /// Put the rendered icon on the pasteboard as PNG and TIFF.
    ///
    /// Reuses `pngExportDocument`, so Copy, the drag-out and ⇧⌘E all render the same
    /// icon from the same inputs. No symbol name goes with it: ⌘C in the Symbol field
    /// is the standard Copy and already does that better.
    private func copyIconToPasteboard() {
        do {
            try IconPasteboard.write(document: pngExportDocument)
        } catch {
            viewModel.report(.copyFailed(error))
        }
    }

    /// Builds the drag-out payload, or nil while dragging one out would be wrong.
    ///
    /// Returning nil withdraws the drag entirely, on the same rule that withdraws
    /// ⇧⌘E: `canExport` is false while a System-mode layer's appex raster is still
    /// rendering, and a PNG written in that window silently omits the pending layer.
    /// A drag-out *is* an export, so it cannot be the one caller that ignores that.
    ///
    /// The payload wraps `pngExportDocument` rather than rebuilding one, so a dragged
    /// file and a ⇧⌘E export of the same icon are the same bytes under the same name.
    /// Nothing here renders — see `DraggableIcon`, which is a promise.
    private var makeDragPayload: (() -> DraggableIcon)? {
        guard viewModel.canExport else { return nil }
        return {
            DraggableIcon(
                document: pngExportDocument,
                baseName: viewModel.iconSettings.exportBaseName
            )
        }
    }

    /// The PNG payload for the export panel.
    ///
    /// Lifted out of `body` because the whole view stopped type-checking in reasonable
    /// time once the configuration dialogs were added — a ternary between two multi-
    /// argument initializers inside a modifier argument is expensive to infer. Keep new
    /// presentation payloads out of `body` for the same reason.
    private var pngExportDocument: PNGExportDocument {
        guard viewModel.iconSettings.icon.mode == .system else {
            return PNGExportDocument(
                settings: viewModel.iconSettings,
                badgeAppexImage: viewModel.badgeAppexRenderedImage
            )
        }
        return PNGExportDocument(
            appexExport: .init(
                symbolName: viewModel.iconSettings.icon.foreground.symbolName,
                enclosureColor: viewModel.appexEnclosureColor,
                symbolColor: viewModel.appexSymbolColor,
                pointSize: viewModel.iconSettings.export.size,
                scaleFactor: viewModel.iconSettings.export.isRetina ? 2 : 1,
                colorSpace: viewModel.iconSettings.export.colorSpace
            ),
            settings: viewModel.iconSettings,
            badgeAppexImage: viewModel.badgeAppexRenderedImage
        )
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
                    selectionPulse: selectionPulse,
                    makeDragPayload: makeDragPayload,
                    contextActions: previewContextActions
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
