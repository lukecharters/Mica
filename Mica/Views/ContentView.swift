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
    /// the pasteboard with that layer missing. Copy and ⇧⌘E are two faces of one
    /// export and answer to one rule.
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

/// Runs the PNG export panel when the window's export flag goes up, and lowers the
/// flag again.
///
/// A `ViewModifier` for the same mechanical reason `WindowFocusValues` is one: a
/// fifth `.onChange` in `ContentView.body` puts it past the type-checker's time
/// limit. Anything else that has to observe window state should join one of them
/// rather than extend the chain in `body`.
///
/// The panel runs on the *next* turn of the run loop rather than inside the change
/// handler. `runModal()` spins its own loop, and doing that in the middle of a
/// SwiftUI update is how a modal panel ends up presented over a half-applied view
/// tree — the same "dismiss, then present" rule a sheet followed by an exporter
/// needs.
private struct ExportPanelPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let seed: ExportSpec
    let defaultBaseName: String
    let perform: (ExportPanel.Outcome) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: isPresented) { _, presenting in
            guard presenting else { return }
            isPresented = false
            let seed = seed
            let baseName = defaultBaseName
            let perform = perform
            DispatchQueue.main.async {
                guard let outcome = ExportPanel.run(seed: seed, defaultBaseName: baseName) else { return }
                perform(outcome)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = IconViewModel()

    /// The one place Settings ▸ Export is read. A new window opens at the user's
    /// preferred size and colour space; windows already open are untouched, which
    /// is the whole difference between a default and a setting.
    init() {
        _viewModel = StateObject(wrappedValue: IconViewModel(export: .fromPreferences()))
        openingInspectorWidth = PaneWidthPreferences.launchWidth(.inspector)
    }

    init(viewModel: IconViewModel, showInspector: Bool = true) {
        _ = showInspector // kept for source compatibility with existing previews
        _viewModel = StateObject(wrappedValue: viewModel)
        openingInspectorWidth = PaneWidthPreferences.launchWidth(.inspector)
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
    /// The active layer per group, remembered while the app runs so switching
    /// between Icon and Badge returns to where you left off. Not persisted across
    /// launches (matching the sidebar selection, which also resets to Icon).
    ///
    /// Three things write these: the sidebar's child rows, a canvas click
    /// (`select`), and nothing else — the inspector reads them only, since
    /// `LayerTabPicker` was removed on 2026-08-16. They stay here rather than
    /// moving into `LayerSidebar` because the sidebar column can be hidden (⌃⌘S)
    /// while a canvas click is still moving the selection.
    @State private var iconTab: LayerTab = .defaultTab(for: .icon)
    @State private var badgeTab: LayerTab = .defaultTab(for: .badge)
    /// Incremented on every canvas click and (throttled) on pointer motion over the
    /// canvas. The outlines restart their fade when this changes, which is what makes
    /// moving anywhere over the canvas bring the selected outline back, and what makes
    /// clicking the already-selected layer flash it rather than do nothing visible.
    ///
    /// It replaced a `selectionPulse` that only a click bumped. One counter, because
    /// the measurement says both outlines fade together on a single idle timer.
    @State private var outlineWake: Int = 0
    /// Bounds how often pointer motion is allowed to bump `outlineWake`.
    /// `.onContinuousHover` reports every sample, and the fade is a `.task(id:)`.
    @State private var outlineActivity = PreviewOutlineActivity()
    /// The layer under the pointer, or nil. Written by the canvas's hover and (from
    /// Phase 4) by the sidebar's rows, so it is owned here for the same reason the
    /// selection is: two views write it and a third draws it.
    @State private var hoveredRow: LayerSidebarRow? = nil
    /// Whether the pointer is over either canvas or a sidebar row. False is what
    /// makes the outlines fade at once instead of holding for 1.5s first.
    @State private var pointerIsInside: Bool = false
    /// The badge's way back out of System mode. Owned here rather than by whichever
    /// control switches the mode: this view is mounted for the window's whole life,
    /// so the remembered source cannot go stale.
    ///
    /// It stayed here when the mode picker went back to the inspector on 2026-08-16,
    /// deliberately. `InspectorControls` is also mounted across group and tab changes
    /// and held this as inline `@State` before 2026-08-04 — but only out here can the
    /// settings observer below feed it, which is what catches a source arriving from
    /// an import, a paste, a configuration or an undo. Being a plain type rather than
    /// view state is also what makes it testable (`BadgeModeMemoryTests`).
    @State private var badgeModeMemory = BadgeModeMemory()
    @State private var appexService = AppexReferenceService()
    /// NavigationSplitView experiment: drives the sidebar column instead of the old
    /// `showLayerSidebar` flag. `.all` shows the sidebar; `.detailOnly` hides it.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showInspector: Bool = true
    @State private var inspectorTab: InspectorTab = .controls

    /// Read here too: the selection outline is an advanced-controls affordance, so
    /// with them off the preview draws none (see `currentPreviewSelection`).
    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    /// The width this window's inspector opens at, read from the preference once
    /// in `init` and never again.
    ///
    /// **Deliberately not `@AppStorage`.** It feeds `.inspectorColumnWidth`'s
    /// `ideal:`, which is a layout proposal — a value that changed while the user
    /// was dragging would be a value fighting the drag. The write side is
    /// `.reportsPaneWidth`, which goes straight to `UserDefaults`, so the read and
    /// the write never meet within a session. See `PaneWidthPreferences`.
    ///
    /// It was an `@AppStorage` property that was read and never written, under a
    /// comment claiming a divider drag wrote it — item C5 of
    /// the Mac-conventions plan. Its sidebar twin is gone entirely: AppKit
    /// already persists that divider, better than this could.
    private let openingInspectorWidth: Double


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
                selection: $selectedGroup,
                iconTab: $iconTab,
                badgeTab: $badgeTab,
                onPointer: pointerChanged
            )
            // **No `.reportsPaneWidth` here, and that is a finding rather than an
            // omission.** AppKit autosaves this split view's divider and restores
            // it *ahead of* `ideal:`, so the sidebar width already survives a
            // relaunch and a Mica preference for it would be a second mechanism
            // that always loses. Measured 2026-08-07 — see `PaneWidthPreferences`.
            .navigationSplitViewColumnWidth(
                min: PaneWidthPreferences.Pane.sidebar.range.lowerBound,
                ideal: PaneWidthPreferences.Pane.sidebar.defaultWidth,
                max: PaneWidthPreferences.Pane.sidebar.range.upperBound
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
                        onPointer: pointerChanged,
                        selection: currentPreviewSelection,
                        hovered: hoveredPreviewSelection,
                        pointerIsInside: pointerIsInside,
                        outlineWake: outlineWake,
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
            // **No focus ring**, and this is a fix rather than a preference. macOS 27
            // draws a focus effect for a plain `.focusable()` where macOS 26 drew
            // none, and because the ring is painted for a region this size it appears
            // as a stray accent rectangle across the whole window — most visibly
            // *during and after a window resize*, where it is rendered against the
            // frame the column had a pass ago and so no longer lines up with anything
            // on screen. The canvas is not a control: it is `.focusable()` only so the
            // standard Copy, Paste and arrow keys route here (see below), and a ring
            // around the entire preview says nothing a user needs to know.
            // `.focusEffectDisabled()` suppresses the drawing and **not** the focus, so
            // all three commands still resolve.
            .focusEffectDisabled()
            .onCopyCommand(perform: copyIconProviders)
            // Focus-resolved ⌘V, the mirror of the ⌘C above and the replacement for
            // the four ⇧⌘V/I/B/G paste shortcuts C4 removed. `.onPasteCommand` hooks
            // the **standard** Paste for the same reason: a second Edit-menu item
            // bound to ⌘V would lose the key equivalent outright when the menu is
            // built, not per focus.
            //
            // **It lands on the icon background, always** — the same target a canvas
            // drop falls back to when it hits nothing (B4), and for the same reason.
            // A drop can name a group because it has a location; a paste has none, so
            // routing it by the sidebar's selection would make one key mean two
            // things depending on state the user is not looking at. C2 declined that
            // for the context menu's row order and it is declined here too. The other
            // three layers are the Edit menu's and the context menu's.
            //
            // `of:` is `allDropTypes`, which is exactly what `importFromPasteboard`
            // reads — a file URL first, then image data — so the standard Paste is
            // enabled when and only when this can do something. That is C6's question
            // answered for free on this one route, by the pasteboard type check
            // AppKit already runs; the Edit menu's four items are still advisory.
            .onPasteCommand(of: ImageImportService.allDropTypes, perform: pasteAsIconBackground)
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
        // `.inspectorColumnWidth`, seeded from the persisted width and written back
        // by `.reportsPaneWidth` — so a dragged width now survives a *relaunch*, not
        // just a mode switch. See C5 and `PaneWidthPreferences`.
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
                iconTab: iconTab,
                badgeTab: badgeTab,
                iconIsSystem: iconModeBinding,
                badgeIsSystem: badgeModeBinding,
                tab: inspectorTab,
                canExport: viewModel.canExport
            )
            .reportsPaneWidth(.inspector)
            .inspectorColumnWidth(
                min: PaneWidthPreferences.Pane.inspector.range.lowerBound,
                ideal: openingInspectorWidth,
                max: PaneWidthPreferences.Pane.inspector.range.upperBound
            )
        }
        // One `ToolbarContent` type, not an inline block. Building it inline broke
        // the build with "unable to type-check this expression in reasonable time" —
        // `body`'s fourth trip over that ceiling. The two generation-mode menus that
        // caused it are gone, but the type stays; see `IconWindowToolbar`.
        .toolbar {
            IconWindowToolbar(
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
            // imported configuration, an undo — and the mode picker has to remember
            // whichever one, not only the ones it set itself. `observe`
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
        // PNG export. **Not a `.fileExporter`** — the export settings ride in the
        // panel's accessory view, which `.fileExporter` has no hook for, so this is
        // an `NSSavePanel` run by `ExportPanel`. The flag it watches is unchanged,
        // so ⇧⌘E, the inspector's Export button and the canvas menu all still reach
        // it through `canExport`.
        //
        // The presentation is a `ViewModifier` because the `.onChange` driving it
        // would be a fifth in this `body`, and the fourth was already at the
        // type-checker's limit.
        .modifier(ExportPanelPresenter(
            isPresented: $viewModel.showExportDialog,
            seed: viewModel.iconSettings.export,
            defaultBaseName: viewModel.iconSettings.exportBaseName,
            perform: writeExportedPNG
        ))
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
        // item B3 of the Mac-conventions plan. Everything a discrete action
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
    // the inspector call is exactly the shape that has pushed it over four times.
    //
    // They are handed to `InspectorPanel` rather than to the toolbar as of
    // 2026-08-16 — the picker they drive is back at the top of each group's pane —
    // but they stay owned here, because `badgeModeMemory` does. See below.

    /// Drives the icon group's Mica/System picker. The icon stores its mode outright.
    private var iconModeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.iconSettings.icon.mode == .system },
            set: { viewModel.iconSettings.icon.mode = $0 ? .system : .mica }
        )
    }

    /// Drives the badge group's Mica/System picker. The badge has no stored mode — it
    /// is derived from its foreground source — so switching overwrites the source and
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
            case .pasteForeground(let group):
                ImageImportAction.paste(
                    into: &viewModel.iconSettings,
                    reporter: viewModel.messageReporter
                ) { settings, image in
                    ImageImportAction.applyForeground(image, to: group, in: &settings)
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

    /// The standard Paste while the canvas is focused: the pasteboard image becomes
    /// the icon background.
    ///
    /// **The item providers are deliberately ignored.** They are a view of the same
    /// `NSPasteboard.general` that `ImageImportService.importFromPasteboard` reads,
    /// and going through `ImageImportAction` is what keeps this route from becoming
    /// a second paste implementation — which is the whole reason that type exists.
    /// Reading the providers instead would mean this route decided for itself what
    /// an empty pasteboard, a file promise or an un-decodable image meant, and that
    /// difference is invisible until someone hits ⌘V with the wrong thing copied.
    ///
    /// A method rather than a closure in `body`, like `nudgeBadge` above: `body`
    /// sits at the type-checker's ceiling and has been pushed over it four times.
    private func pasteAsIconBackground(_ providers: [NSItemProvider]) {
        _ = providers
        ImageImportAction.paste(
            into: &viewModel.iconSettings,
            reporter: viewModel.messageReporter
        ) { settings, image in
            ImageImportAction.applyBackground(
                image,
                to: .icon,
                in: &settings,
                defaults: .fromPreferences()
            )
        }
    }

    /// Put the rendered icon on the pasteboard as PNG and TIFF.
    ///
    /// Reuses `pngExportDocument`, so Copy and ⇧⌘E both render the same
    /// icon from the same inputs. No symbol name goes with it: ⌘C in the Symbol field
    /// is the standard Copy and already does that better.
    private func copyIconToPasteboard() {
        do {
            try IconPasteboard.write(document: pngExportDocument)
        } catch {
            viewModel.report(.copyFailed(error))
        }
    }

    /// The PNG payload for the export panel.
    ///
    /// Lifted out of `body` because the whole view stopped type-checking in reasonable
    /// time once the configuration dialogs were added — a ternary between two multi-
    /// argument initializers inside a modifier argument is expensive to infer. Keep new
    /// presentation payloads out of `body` for the same reason.
    private var pngExportDocument: PNGExportDocument {
        pngExportDocument(export: viewModel.iconSettings.export)
    }

    /// The same payload rendered at a given export spec, which is how a per-export
    /// override reaches the render.
    ///
    /// Swapping the spec into a *copy* of the window's settings is the whole
    /// mechanism: `viewModel.iconSettings` is untouched, so an override changes one
    /// file and nothing else — not the inspector, not undo, not the next ⇧⌘C.
    /// Both the Mica and the System branch read the copy, or a System-mode export
    /// would quietly ignore the panel while a Mica one honoured it.
    private func pngExportDocument(export: ExportSpec) -> PNGExportDocument {
        var settings = viewModel.iconSettings
        settings.export = export

        guard settings.icon.mode == .system else {
            return PNGExportDocument(
                settings: settings,
                badgeAppexImage: viewModel.badgeAppexRenderedImage
            )
        }
        return PNGExportDocument(
            appexExport: .init(
                symbolName: settings.icon.foreground.symbolName,
                enclosureColor: viewModel.appexEnclosureColor,
                symbolColor: viewModel.appexSymbolColor,
                pointSize: settings.export.size,
                scaleFactor: settings.export.isRetina ? 2 : 1,
                colorSpace: settings.export.colorSpace
            ),
            settings: settings,
            badgeAppexImage: viewModel.badgeAppexRenderedImage
        )
    }

    /// Render the icon at what the panel asked for and write it where it said.
    ///
    /// The failure alert is the one `.fileExporter`'s result closure used to raise.
    /// Success stays silent on purpose — the file is where they asked for it, and an
    /// alert saying so is a dialog to dismiss for no reason.
    private func writeExportedPNG(_ outcome: ExportPanel.Outcome) {
        do {
            let data = try pngExportDocument(export: outcome.export).pngData()
            try data.write(to: outcome.url)
        } catch {
            viewModel.report(.exportFailed(error))
        }
    }

    // MARK: - Canvas selection

    /// What the preview outlines at the selected weight: whichever layer the
    /// inspector is editing, or the whole group in System mode, which has no layers
    /// to distinguish.
    private var currentPreviewSelection: PreviewSelection? {
        previewSelection(for: .layer(selectedGroup, activeTab(for: selectedGroup)))
    }

    /// What it outlines at the hover weight — nil whenever the pointer is over
    /// nothing, over the inspector, or outside the window.
    private var hoveredPreviewSelection: PreviewSelection? {
        previewSelection(for: hoveredRow)
    }

    /// The one place a row becomes something to outline, which is why the selection
    /// and the hover both go through it: **every gate is applied once**, so the
    /// hover cannot outline something the selection could not.
    ///
    /// Only while the Controls tab is showing — on the Export tab there's no layer
    /// being edited, so an outline would just be in the way — and only with the
    /// advanced controls on, which is `PreviewSelection.from`'s call.
    ///
    /// A *group* row (which is what a sidebar group row hover produces) resolves
    /// through that group's active layer, so hovering it previews exactly what
    /// clicking it would select.
    private func previewSelection(for row: LayerSidebarRow?) -> PreviewSelection? {
        guard let row else { return nil }
        guard inspectorTab == .controls, showInspector else { return nil }
        let group = row.group
        let isSystem: Bool
        switch group {
        case .icon:  isSystem = viewModel.iconSettings.icon.mode == .system
        case .badge: isSystem = viewModel.iconSettings.badge.mode == .system
        }
        return PreviewSelection.from(
            group: group,
            tab: row.tab ?? activeTab(for: group),
            isSystem: isSystem,
            advancedControlsEnabled: advancedControlsEnabled
        )
    }

    private func activeTab(for group: IconLayerGroup) -> LayerTab {
        switch group {
        case .icon:  return iconTab
        case .badge: return badgeTab
        }
    }

    /// A pointer sample from either input — either canvas, or a sidebar row.
    ///
    /// **Three jobs, and the split is the point.** Every sample inside is motion, so
    /// every one offers a wake — throttled, or a moving pointer would restart the
    /// fade `Task` sixty times a second. Only a *change* of row is written to
    /// `hoveredRow`, so the hover outline does not invalidate the body while the
    /// pointer travels across one layer. And `pointerIsInside` is what tells the
    /// overlay whether to serve out its hold or fade now.
    ///
    /// One function for both inputs, which is what makes them behave identically:
    /// hovering the sidebar fades on the same timer, revives on the same motion, and
    /// resolves through the same gates as hovering the canvas.
    private func pointerChanged(_ pointer: PreviewPointer) {
        switch pointer {
        case .over(let row):
            if outlineActivity.noteMotion(now: ProcessInfo.processInfo.systemUptime) {
                outlineWake += 1
            }
            if !pointerIsInside { pointerIsInside = true }
            if hoveredRow != row { hoveredRow = row }
        case .away:
            // No wake: leaving is not motion the outlines should answer to, and
            // bumping it here would restart the very hold this is meant to skip.
            if pointerIsInside { pointerIsInside = false }
            if hoveredRow != nil { hoveredRow = nil }
        }
    }

    /// Points the inspector at the layer the user clicked in the preview. The tab
    /// only moves for a group in Mica mode — a System group has no tabs, so
    /// selecting the group is the whole story there. Harmless with the advanced
    /// controls off, where the tab bar is hidden: the tab is simply left pointing
    /// at the clicked layer for when it comes back.
    private func select(_ target: PreviewHitTarget) {
        outlineWake += 1
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
        //
        // **The `GeometryReader` is what centres the icon, and it has to sit
        // *outside* the `ScrollView`.** This was `.frame(maxWidth: .infinity,
        // maxHeight: .infinity)` on a `VStack` inside the scroll view until macOS 27,
        // where it stopped centring anything and left the icon pinned to the top
        // leading corner of the pane. A scroll view proposes `nil` — unbounded — to
        // its content on both scrollable axes, and `.infinity` against an unbounded
        // proposal resolves to the child's own ideal size, so the stretch was always
        // a no-op that macOS 26 happened to paper over. Nothing about it was ever
        // load-bearing, which is why the two `Spacer(minLength: 0)`s it sat between
        // had already been commented out with no visible effect.
        //
        // A minimum measured off the viewport is the standard answer: content smaller
        // than the pane grows to fill it and centres inside that frame, content larger
        // keeps its own size and scrolls. It must go **on the content**, never on the
        // `ScrollView` itself — see the pin below, which is the same measurement
        // read the other way round.
        GeometryReader { viewport in
            ScrollView([.horizontal, .vertical]) {
                ScaledIconPreview(
                    settings: $viewModel.iconSettings,
                    displaySize: previewDisplaySize,
                    badgeAppexImage: viewModel.badgeAppexRenderedImage,
                    badgeAppexError: viewModel.badgeAppexError,
                    onSelect: select,
                    onPointer: pointerChanged,
                    selection: currentPreviewSelection,
                    hovered: hoveredPreviewSelection,
                    pointerIsInside: pointerIsInside,
                    outlineWake: outlineWake,
                    contextActions: previewContextActions
                )
                .frame(
                    minWidth: viewport.size.width,
                    minHeight: viewport.size.height,
                    alignment: .center
                )
            }
            // Pinch and ⌘-scroll. On the `ScrollView`, not the pane, because the zoom
            // is anchored under the pointer and that needs the scroll offset — see
            // `PreviewZoomGesture`. Layout-neutral, so the pin below still holds.
            .previewZoomGestures(zoom: $zoomLevel, viewport: viewport.size,
                                 iconSize: previewDisplaySize)
        }
        // **`minWidth: 0` is load-bearing: without it, dragging the window narrow
        // kills the app on macOS 27.** The pinned minimum is the whole fix; the rest
        // of this frame is the fill it always was.
        //
        // This is a both-axis `ScrollView` whose content — the icon at its display
        // size — is routinely far wider than the pane. Absent an explicit minimum,
        // the minimum `NSHostingView` reports for this split-view child is derived
        // from the width it was last offered, so it *changes as the window resizes*.
        // During a live drag that lands SwiftUI's
        // `SplitViewChildController.hostingView(_:didUpdateMinSize:maxSize:)` on
        // every constraints pass, each one re-invalidating layout from inside
        // `NSHostingView._willUpdateConstraintsForSubtree`, until AppKit throws
        // `NSGenericException` — *"…more Update Constraints in Window passes than
        // there are views in the window"* — and the process dies mid-drag. A
        // constant minimum cannot change per pass, so the loop has nothing to feed
        // on. Measured with the sidebar hidden and the inspector shown: **5/5 crash
        // at 749pt before, 5/5 survive after**, settling at 734pt — the same width
        // an inert `Color` in this column settles at.
        //
        // **It has to be zero.** A non-zero constant is stable too, but a detail
        // minimum is not a dial you can set to a width: `minWidth: 320` here put the
        // window's own minimum at **1334pt in every configuration**, including both
        // panes hidden, which nails the window open. The price of zero is that with
        // both panes hidden (⌃⌘S, ⌃⌘I) the window drags down to ~97pt where it used
        // to stop near 300; a floor there needs `NSWindow.minSize`, not this frame.
        //
        // **The viewport-derived minimum above is not a violation of this**, and the
        // distinction is the whole reason it is where it is: it is applied to the
        // scroll view's *content*, and a scroll view's own minimum does not track its
        // content's — it scrolls instead. What the split view child asks
        // `NSHostingView` for is this frame, and this frame answers a constant. Both
        // configurations were re-run under a live drag after the centring landed and
        // survive; see `.claude/rules/swiftui-presentation.md` for the numbers.
        //
        // `AppexPreviewPane.previewContent` is the same shape and carries the same
        // pin — System mode is the other branch of this column.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
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
