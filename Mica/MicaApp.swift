// MicaApp.swift
import SwiftUI

@main
struct MicaApp: App {
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.iconSettings) private var iconSettings
    @FocusedBinding(\.exportPNG) private var exportPNG
    @FocusedValue(\.exportConfiguration) private var exportConfiguration
    @FocusedValue(\.importConfiguration) private var importConfiguration
    @FocusedValue(\.copyIcon) private var copyIcon
    /// Where these commands' failures go — the focused window's one alert. The
    /// menu route of `UserMessage`, and the reason `print()` is gone from the
    /// eight import commands below. Nil only when nothing has focus, in which
    /// case every one of them is already disabled.
    @FocusedValue(\.userMessageReporter) private var messageReporter

    // The View menu. Window state, so all four are focused values and each item
    // disables itself when its own is nil.
    @FocusedBinding(\.sidebarVisible) private var sidebarVisible
    @FocusedBinding(\.inspectorVisible) private var inspectorVisible
    @FocusedBinding(\.previewZoom) private var previewZoom
    @FocusedValue(\.previewPointSize) private var previewPointSize

    /// App-wide, so it is read here rather than published by the focused window —
    /// View ▸ Show Advanced Controls stays enabled with no window open, which is
    /// what a preference should do. Settings ▸ General reads the same key.
    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    /// The rung View ▸ Zoom In would move to, or nil if there is no window or the
    /// preview is already at the top of the ladder. Computed once and used for both
    /// the item's action guard and its enabled state, so the menu cannot offer a
    /// step it will not take.
    private var nextZoomIn: Double? {
        previewZoom.flatMap(PreviewZoom.zoomedIn(from:))
    }

    private var nextZoomOut: Double? {
        previewZoom.flatMap(PreviewZoom.zoomedOut(from:))
    }

    // MARK: - The eight image-import commands
    //
    // Four Paste as… and four Import as…, each of which was an eight-line closure
    // repeated with one line changed — and, until 2026-08-05, with its own error
    // handling: the pastes `print()`d where the user could not see, the imports ran
    // an app-modal `NSAlert`. Item B3 could have replaced eight copies with eight
    // other copies; these two helpers mean the next import command cannot be
    // written with a ninth.

    /// Apply a pasted image to the focused window's settings.
    ///
    /// `apply` is the only thing that differs between the four Paste as… items.
    ///
    /// The reading, the empty-pasteboard advisory and the failure report moved to
    /// `ImageImportAction.paste` when the canvas context menu became a second
    /// caller (item C2). What is left here is the focused-window part: unwrap the
    /// binding, write it back. An unchanged value produces no `onChange`, so the
    /// unconditional write-back costs no undo entry when nothing was pasted.
    private func pasteImage(_ apply: (inout IconSettings, ImportedImage) -> Void) {
        guard var settings = iconSettings else { return }
        ImageImportAction.paste(
            into: &settings,
            reporter: messageReporter ?? .unattached,
            apply: apply
        )
        iconSettings = settings
    }

    /// Run an open panel and apply the chosen file to the focused window's settings.
    ///
    /// `prompt` is the panel's message; `apply` is the one line that differs between
    /// the four Import as… items.
    private func importImage(
        prompt: String,
        _ apply: (inout IconSettings, ImportedImage) -> Void
    ) {
        guard var settings = iconSettings else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.message = prompt
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            apply(&settings, try ImageImportService.importFromURL(url))
            iconSettings = settings
        } catch {
            messageReporter?.report(.imageImportFailed(error))
        }
    }


    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, idealWidth: 1200, minHeight: 500, idealHeight: 800)
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.automatic)
//        .windowToolbarLabelStyle(fixed: .titleAndIcon)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .pasteboard) {
                Divider()

                // ⇧⌘C, because ⌘C is **taken** — by the standard Copy that SwiftUI puts
                // in this menu. (An earlier comment here claimed Mica had no pasteboard
                // command group at all. That was wrong: Cut/Copy/Paste/Delete/Select All
                // are all present — which is why this group is `after: .pasteboard` —
                // and ⌘C copies text in the Symbol field today.)
                //
                // ⌘C was measured on 2026-08-04 and **cannot** be shared. Two menu items
                // with one key equivalent are deduplicated when the menu is *built*, not
                // resolved at dispatch, and the later item loses outright: binding ⌘C
                // here left this item with `AXMenuItemCmdChar = missing value` and no
                // shortcut in any focus state, while Copy kept ⌘C. So it is not a
                // question of which one wins per focus — the icon simply became
                // unreachable from the keyboard.
                //
                // Focus-resolved ⌘C is still possible, but only through the *standard*
                // Copy command (`.onCopyCommand` on the canvas), never a second item.
                Button("Copy Icon") {
                    copyIcon?.perform()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(copyIcon == nil)

                Divider()

                // **None of the four carries a key equivalent, and the standard
                // Paste covers the common one.** Item C4 of
                // the Mac-conventions plan, 2026-08-07.
                //
                // They were ⇧⌘V / ⇧⌘I / ⇧⌘B / ⇧⌘G. ⇧⌘V is Paste and Match Style
                // system-wide, which is the review's finding; the other three were
                // arbitrary — I, B and G are not mnemonics for "icon symbol",
                // "badge background" and "badge symbol", they are the letters that
                // happened to be free. Any replacement would be equally arbitrary,
                // so the answer is not four different keys but *none*, plus one
                // real one on the standard command.
                //
                // What replaces them, in order of how a user actually gets an image
                // in: a drop on the canvas (B4), which is the only route that can
                // say *which* group; the canvas context menu (C2); this menu; and
                // **⌘V while the canvas is focused**, which lands on the icon
                // background — `.onPasteCommand` in `ContentView`, hooking the
                // *standard* Paste for exactly the reason ⌘C hooks the standard
                // Copy above. The four Import as… items in File have never carried
                // shortcuts either, and they are the same action from a file.
                Button("Paste as Icon Background") {
                    pasteImage { $0.icon.applyBackgroundImage($1, defaults: .fromPreferences()) }
                }
                .disabled(iconSettings == nil)

                Button("Paste as Icon Symbol") {
                    pasteImage { $0.icon.foreground.apply($1) }
                }
                .disabled(iconSettings == nil)

                Button("Paste as Badge Background") {
                    pasteImage { $0.badge.applyBackgroundImage($1, defaults: .fromPreferences()) }
                }
                .disabled(iconSettings == nil)

                Button("Paste as Badge Symbol") {
                    pasteImage { $0.badge.foreground.apply($1) }
                }
                .disabled(iconSettings == nil)
            }
            CommandGroup(before: .saveItem) {
                Divider()
                Button("Import as Icon Background…") {
                    importImage(prompt: "Choose an image or app to use as the icon background") {
                        $0.icon.applyBackgroundImage($1, defaults: .fromPreferences())
                    }
                }
                .disabled(iconSettings == nil)

                Button("Import as Icon Symbol…") {
                    importImage(prompt: "Choose an image or app to use as the icon symbol") {
                        $0.icon.foreground.apply($1)
                    }
                }
                .disabled(iconSettings == nil)

                Button("Import as Badge Background…") {
                    importImage(prompt: "Choose an image or app to use as the badge background") {
                        $0.badge.applyBackgroundImage($1, defaults: .fromPreferences())
                    }
                }
                .disabled(iconSettings == nil)

                Button("Import as Badge Symbol…") {
                    importImage(prompt: "Choose an image or app to use as the badge symbol") {
                        $0.badge.foreground.apply($1)
                    }
                }
                .disabled(iconSettings == nil)
                Divider()
            }

            // Replaces the empty stock Import/Export slot rather than adding a group,
            // so the item lands where macOS already puts export commands in File.
            // Cmd-Shift-E is free: only C belongs to Copy Icon above, and K/L/M/A/S
            // to the DevTools windows in Debug builds. (This note used to add
            // "Cmd-Shift-G is Paste as Icon Background" — C4 freed V, I, B and G.)
            CommandGroup(replacing: .importExport) {
                Button("Export as PNG…") {
                    exportPNG = true
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(exportPNG == nil)

                Divider()

                // Cmd-S, blessed by the user on 2026-08-01 over Opt-Cmd-S. Mica has
                // no document and saves nothing between launches, so this is the only
                // save-shaped action there is; the plan's worry was that Cmd-S might
                // over-promise persistence, and the ruling was that being the obvious
                // shortcut for the obvious action matters more.
                Button("Export Configuration…") {
                    exportConfiguration?.perform()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(exportConfiguration == nil)

                Button("Import Configuration…") {
                    importConfiguration?.perform()
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(importConfiguration == nil)
            }

            // The View menu. Until 2026-08-04 it held only what AppKit puts there —
            // Show Tab Bar, Show All Tabs, Enter Full Screen — while the sidebar,
            // the inspector and the zoom were reachable from the toolbar alone, and
            // ⌘+ / ⌘− / ⌘0 did nothing. Item B1 of the Mac-conventions plan.
            //
            // `before: .sidebar` rather than a `CommandMenu("View")`: a second menu
            // of that name would sit beside AppKit's rather than merge with it.
            //
            // **Show Tab Bar / Show All Tabs cannot be pushed below this group.**
            // Measured 2026-08-04: `before: .sidebar` and `before: .toolbar` produce
            // a byte-identical View menu, both landing under the tab-bar pair. Those
            // two come from AppKit's window tabbing rather than a SwiftUI command
            // group, so no placement reaches above them. Don't spend a build on it
            // again.
            CommandGroup(before: .sidebar) {
                // Flipping titles, not checkmarks — that is how the platform writes
                // a pane toggle (Finder, Mail, Xcode), and it is what SwiftUI's own
                // sidebar command would have said had `NavigationSplitView` supplied
                // one here. It does not; measured 2026-08-04, the View menu had no
                // sidebar item at all.
                Button(sidebarVisible == true ? "Hide Sidebar" : "Show Sidebar") {
                    sidebarVisible?.toggle()
                }
                .keyboardShortcut("s", modifiers: [.control, .command])
                .disabled(sidebarVisible == nil)

                // ⌃⌘I pairs with the sidebar's ⌃⌘S. macOS has no settled shortcut
                // for an inspector — Xcode uses ⌥⌘0, the iWork apps ⌥⌘I — and ⌥⌘0
                // would read oddly next to ⌘0 for Actual Size below.
                Button(inspectorVisible == true ? "Hide Inspector" : "Show Inspector") {
                    inspectorVisible?.toggle()
                }
                .keyboardShortcut("i", modifiers: [.control, .command])
                .disabled(inspectorVisible == nil)

                Divider()

                // Zoom In / Zoom Out walk `PreviewZoom.levels`, the same nine rungs
                // the toolbar's ZoomMenu lists, so the keyboard cannot land on a
                // percentage that menu does not offer. Each disables at its end.
                Button("Zoom In") {
                    guard let current = previewZoom,
                          let next = PreviewZoom.zoomedIn(from: current) else { return }
                    previewZoom = next
                }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(nextZoomIn == nil)

                Button("Zoom Out") {
                    guard let current = previewZoom,
                          let next = PreviewZoom.zoomedOut(from: current) else { return }
                    previewZoom = next
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(nextZoomOut == nil)

                Button("Actual Size") {
                    previewZoom = PreviewZoom.actualSize
                }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(previewZoom == nil || previewZoom == PreviewZoom.actualSize)

                // The same rows as the toolbar's PreviewSizeMenu, from one view.
                //
                // **The `.disabled` goes on the content, not on the `Menu`.**
                // Measured 2026-08-04: `Menu(…) { }.disabled(true)` in a
                // `CommandGroup` renders fully enabled — with no window focused the
                // submenu still opened, onto rows bound to `.constant(nil)` that
                // silently did nothing. Disabling the content instead greys every
                // row, so the one case the binding is missing cannot be clicked.
                Menu("Preview Size") {
                    PreviewSizeMenuContent(
                        previewPointSize: previewPointSize ?? .constant(nil)
                    )
                    .disabled(previewPointSize == nil)
                }

                Divider()

                // B2 moved this out of the inspector and into ⌘, alone, which left
                // the flag two clicks and a window away from the panel it changes.
                //
                // A checkmark `Toggle`, not a flipping title like the two above: the
                // wiki names it "Show Advanced Controls" in two pages, and a title
                // that reads "Hide Advanced Controls" half the time strands both.
                Toggle("Show Advanced Controls", isOn: $advancedControlsEnabled)

                // Not decoration. A checkmark item gives its *visual group* a gutter
                // and indents everything in it — without this divider, AppKit's
                // Enter Full Screen sat indented under the Toggle as though it were
                // a second preference.
                Divider()
            }

            #if DEBUG
            CommandGroup(after: .newItem) {
                Divider()
                Button("Generate Symbol Metrics") {
                    openWindow(id: "metrics-generator")
                }
                .keyboardShortcut("M", modifiers: [.command, .shift])

                Button("Symbol Calibration") {
                    openWindow(id: "symbol-calibration")
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])

                Button("Auto Sizing Review") {
                    openWindow(id: "auto-sizing-review")
                }
                .keyboardShortcut("A", modifiers: [.command, .shift])

                Button("Reference Comparison") {
                    openWindow(id: "reference-comparison")
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
            }
            #endif
            // The Help menu. Item B5 of the Mac-conventions plan.
            //
            // Until 2026-08-04 it held one item — "Mica Help", which AppKit supplies
            // for every app whether or not it has a help book. **Measured, not
            // inferred: clicking it opened an alert reading "Help isn't available for
            // Mica."** That is worse than an empty menu, and it is why this is
            // `replacing: .help` rather than `after: .help`: the stock item has to go,
            // not be pushed down by better ones.
            //
            // The review claimed there was no "Mica Help" item at all. There was —
            // the third such stale claim after the pasteboard group (§2.5) and the
            // window style, and the same lesson: an item that does nothing useful
            // reads as absent.
            //
            // `Link` throughout: it opens its own destination, so there is no action
            // closure to get wrong and the URL is visible in the declaration. Every
            // item was verified on screen by reading the browser's address bar back,
            // not by watching for a window — Edge opens these as *tabs*, so a window
            // count does not move.
            CommandGroup(replacing: .help) {
                // **No ⌘? here, deliberately — a Help item does not carry one.**
                //
                // ⌘? looked free (the stock item's `AXMenuItemCmdChar` was
                // `missing value`) and binding it "worked" in the sense that AX then
                // reported cmdchar `?` with modifiers `0`. It was still wrong, and
                // three measurements on 2026-08-04 say so:
                //
                // - **The menu never drew it.** Screenshotted with the menu open:
                //   "Mica Help" and empty space where a shortcut renders.
                // - **Nothing triggered it** — `keystroke "?" using {command down}`,
                //   `key code 44` with ⇧⌘ and with ⌘, and `peekaboo hotkey`, as a
                //   `Link` and as a `Button`, with Mica confirmed frontmost.
                // - **Finder's Help items carry no shortcut either** (Mac User Guide,
                //   Tips for Your Mac). Neither does Safari's or Preview's.
                //
                // That is the explanation: ⇧⌘/ is a *system* key that opens the Help
                // menu, not an accelerator an item may claim. AppKit accepts the key
                // equivalent into its metadata and then neither displays nor honours
                // it. So the binding was invisible, inert and non-standard at once —
                // and removing it costs nothing, because macOS's own ⌘? still opens
                // this menu. **Don't put it back.**
                Link("Mica Help", destination: MicaLinks.help)

                Divider()

                Link("Settings Index", destination: MicaLinks.settingsIndex)
                Link("Command Line Tool Reference", destination: MicaLinks.cliReference)

                Divider()

                Link("Release Notes", destination: MicaLinks.releaseNotes)

                // Ellipsis because the form needs information from the user before
                // the command completes, which is the HIG's actual test — not
                // because it opens a window.
                Link("Report an Issue…", destination: MicaLinks.reportIssue)
            }

            #if DEBUG
            CommandGroup(after: .help) {
                Divider()
                Button("Export Shadow Variations…") {
                    Task {
                        do {
                            try await ShadowVariationHarness.runShadowTestsWithSavePanel()
                        } catch {
                            print("Shadow test failed: \(error)")
                        }
                    }
                }
            }
            #endif
        }

        // ⌘, and the Mica ▸ Settings… item come with the scene; there is deliberately
        // nothing for them in the `.commands` block above.
        Settings {
            SettingsView()
        }

        #if DEBUG
        // Every tool goes through DeferredWindowContent — a tool's `init` would
        // otherwise run on every App-body evaluation, i.e. on every settings edit.
        // See that file's header for the measurements.
        Window("Symbol Metrics Generator", id: "metrics-generator") {
            DeferredWindowContent { SymbolMetricsGeneratorView() }
        }
        .defaultSize(width: 420, height: 220)

        Window("Symbol Calibration", id: "symbol-calibration") {
            DeferredWindowContent { SymbolCalibrationTool() }
        }
        .defaultSize(width: 1200, height: 800)

        Window("Auto Sizing Review", id: "auto-sizing-review") {
            DeferredWindowContent { AutoSizingReviewTool() }
        }
        .defaultSize(width: 1250, height: 850)

        Window("Reference Comparison", id: "reference-comparison") {
            DeferredWindowContent { ReferenceComparisonTool() }
        }
        .defaultSize(width: 1400, height: 900)
        #endif
    }
}

#Preview("With toolbar") {
    NavigationStack {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
