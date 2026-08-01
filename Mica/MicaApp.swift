// MicaApp.swift
import SwiftUI

@main
struct MicaApp: App {
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.iconSettings) private var iconSettings
    @FocusedBinding(\.exportPNG) private var exportPNG


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
                Button("Paste as Icon Background") {
                    guard var settings = iconSettings else { return }
                    do {
                        guard let imported = try ImageImportService.importFromPasteboard() else { return }
                        settings.icon.background.apply(imported)
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
                        settings.badge.background.apply(imported)
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
                        settings.icon.background.apply(imported)
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
                        settings.badge.background.apply(imported)
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
