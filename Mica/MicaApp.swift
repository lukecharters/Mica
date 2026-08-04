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

                Button("Paste as Icon Background") {
                    guard var settings = iconSettings else { return }
                    do {
                        guard let imported = try ImageImportService.importFromPasteboard() else { return }
                        settings.icon.applyBackgroundImage(imported, defaults: .fromPreferences())
                        iconSettings = settings
                    } catch {
                        print("Paste import failed: \(error.localizedDescription)")
                    }
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(iconSettings == nil)

                Button("Paste as Icon Symbol") {
                    guard var settings = iconSettings else { return }
                    do {
                        guard let imported = try ImageImportService.importFromPasteboard() else { return }
                        settings.icon.foreground.apply(imported)
                        iconSettings = settings
                    } catch {
                        print("Paste import failed: \(error.localizedDescription)")
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(iconSettings == nil)

                Button("Paste as Badge Background") {
                    guard var settings = iconSettings else { return }
                    do {
                        guard let imported = try ImageImportService.importFromPasteboard() else { return }
                        settings.badge.applyBackgroundImage(imported, defaults: .fromPreferences())
                        iconSettings = settings
                    } catch {
                        print("Paste import failed: \(error.localizedDescription)")
                    }
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(iconSettings == nil)

                Button("Paste as Badge Symbol") {
                    guard var settings = iconSettings else { return }
                    do {
                        guard let imported = try ImageImportService.importFromPasteboard() else { return }
                        settings.badge.foreground.apply(imported)
                        iconSettings = settings
                    } catch {
                        print("Paste import failed: \(error.localizedDescription)")
                    }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(iconSettings == nil)
            }
            CommandGroup(before: .saveItem) {
                Divider()
                Button("Import as Icon Background…") {
                    guard var settings = iconSettings else { return }
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.treatsFilePackagesAsDirectories = false
                    panel.message = "Choose an image or app to use as the icon background"
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    do {
                        let imported = try ImageImportService.importFromURL(url)
                        settings.icon.applyBackgroundImage(imported, defaults: .fromPreferences())
                        iconSettings = settings
                    } catch {
                        NSAlert(error: error).runModal()
                    }
                }
                .disabled(iconSettings == nil)

                Button("Import as Icon Symbol…") {
                    guard var settings = iconSettings else { return }
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.treatsFilePackagesAsDirectories = false
                    panel.message = "Choose an image or app to use as the icon symbol"
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    do {
                        let imported = try ImageImportService.importFromURL(url)
                        settings.icon.foreground.apply(imported)
                        iconSettings = settings
                    } catch {
                        NSAlert(error: error).runModal()
                    }
                }
                .disabled(iconSettings == nil)

                Button("Import as Badge Background…") {
                    guard var settings = iconSettings else { return }
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.treatsFilePackagesAsDirectories = false
                    panel.message = "Choose an image or app to use as the badge background"
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    do {
                        let imported = try ImageImportService.importFromURL(url)
                        settings.badge.applyBackgroundImage(imported, defaults: .fromPreferences())
                        iconSettings = settings
                    } catch {
                        NSAlert(error: error).runModal()
                    }
                }
                .disabled(iconSettings == nil)

                Button("Import as Badge Symbol…") {
                    guard var settings = iconSettings else { return }
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.treatsFilePackagesAsDirectories = false
                    panel.message = "Choose an image or app to use as the badge symbol"
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    do {
                        let imported = try ImageImportService.importFromURL(url)
                        settings.badge.foreground.apply(imported)
                        iconSettings = settings
                    } catch {
                        NSAlert(error: error).runModal()
                    }
                }
                .disabled(iconSettings == nil)
                Divider()
            }

            // Replaces the empty stock Import/Export slot rather than adding a group,
            // so the item lands where macOS already puts export commands in File.
            // Cmd-Shift-E is free: Cmd-Shift-G is Paste as Icon Background above, and
            // K/L/M/A/S belong to the DevTools windows in Debug builds.
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
            // ⌘+ / ⌘− / ⌘0 did nothing. Item B1 of `docs/plans/mac-conventions.md`.
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
                Button("Apple Reference Calibration") {
                    openWindow(id: "apple-reference-calibration")
                }
                .keyboardShortcut("K", modifiers: [.command, .shift])

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
            #if DEBUG
            CommandGroup(after: .help) {
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
        Window("Apple Reference Calibration", id: "apple-reference-calibration") {
            DeferredWindowContent { AppleReferenceCalibrationTool() }
        }
        .defaultSize(width: 1200, height: 800)

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
