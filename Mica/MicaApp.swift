// MicaApp.swift
import SwiftUI

@main
struct MicaApp: App {
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.iconSettings) private var iconSettings


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

            #if DEBUG
            CommandGroup(after: .newItem) {
                Divider()
                Button("Calibration Playground") {
                    openWindow(id: "calibration")
                }
                .keyboardShortcut("K", modifiers: [.command, .shift])

                Button("Generate Symbol Metrics") {
                    openWindow(id: "metrics-generator")
                }
                .keyboardShortcut("M", modifiers: [.command, .shift])

                Button("Dimension Calibration Playground") {
                    openWindow(id: "dim-calibration")
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])

                Button("Auto Calibration Playground") {
                    openWindow(id: "auto-calibration")
                }
                .keyboardShortcut("A", modifiers: [.command, .shift])

                Button("Icon Comparison Playground") {
                    openWindow(id: "icon-comparison")
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
            }
            #endif
            #if DEBUG
            CommandGroup(after: .help) {
                Button("Run Shadow Variation Tests") {
                    Task {
                        do {
                            try await IconShadowVariationTests.runShadowTestsWithSavePanel()
                        } catch {
                            print("Shadow test failed: \(error)")
                        }
                    }
                }
            }
            #endif
        }

        #if DEBUG
        Window("Calibration Playground", id: "calibration") {
            AppleReferenceCalibrationPlayground()
        }
        .defaultSize(width: 1200, height: 800)

        Window("Symbol Metrics Generator", id: "metrics-generator") {
            SymbolMetricsGeneratorView()
        }
        .defaultSize(width: 420, height: 220)

        Window("Dimension Calibration Playground", id: "dim-calibration") {
            DimensionCalibrationPlayground()
        }
        .defaultSize(width: 1200, height: 800)

        Window("Auto Calibration Playground", id: "auto-calibration") {
            AutoCalibrationPlayground()
        }
        .defaultSize(width: 1250, height: 850)

        Window("Icon Comparison Playground", id: "icon-comparison") {
            IconComparisonPlayground()
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
