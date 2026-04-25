// IconGeneratorApp.swift
import SwiftUI

@main
struct IconGeneratorApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.iconSettings) private var iconSettings

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, minHeight: 520)
                .environmentObject(appViewModel)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Paste as Icon Background") {
                    guard var settings = iconSettings else { return }
                    do {
                        guard let imported = try ImageImportService.importFromPasteboard() else { return }
                        settings.importedBackground = imported
                        settings.importedBackgroundPaddingCompensation = imported.isAppIcon
                        settings.backgroundMode = .importedImage
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
                        settings.importedImage = imported
                        settings.iconSource = .customImage
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
                        settings.badgeImportedBackground = imported
                        settings.badgeImportedBackgroundPaddingCompensation = imported.isAppIcon
                        settings.badgeUseImportedBackground = true
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
                        settings.badgeImportedImage = imported
                        settings.badgeIconSource = .customImage
                        iconSettings = settings
                    } catch {
                        print("Paste import failed: \(error.localizedDescription)")
                    }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(iconSettings == nil)
            }
            CommandGroup(after: .saveItem) {
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
                        settings.importedBackground = imported
                        settings.importedBackgroundPaddingCompensation = imported.isAppIcon
                        settings.backgroundMode = .importedImage
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
                        settings.importedImage = imported
                        settings.iconSource = .customImage
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
                        settings.badgeImportedBackground = imported
                        settings.badgeImportedBackgroundPaddingCompensation = imported.isAppIcon
                        settings.badgeUseImportedBackground = true
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
                        settings.badgeImportedImage = imported
                        settings.badgeIconSource = .customImage
                        iconSettings = settings
                    } catch {
                        NSAlert(error: error).runModal()
                    }
                }
                .disabled(iconSettings == nil)
            }

            #if DEBUG
            CommandGroup(after: .newItem) {
                Button("Calibration Playground") {
                    openWindow(id: "calibration")
                }
                .keyboardShortcut("K", modifiers: [.command, .shift])

                Button("Generate Symbol Metrics") {
                    openWindow(id: "metrics-generator")
                }
                .keyboardShortcut("M", modifiers: [.command, .shift])

                Button("Metrics Sizing Playground") {
                    openWindow(id: "metrics-sizing")
                }
                .keyboardShortcut("J", modifiers: [.command, .shift])

                Button("Dimension Calibration Playground") {
                    openWindow(id: "dim-calibration")
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])

                Button("Resizable Dim-Cal Playground") {
                    openWindow(id: "resizable-dim-cal")
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])

                Button("Shadow Comparison Playground") {
                    openWindow(id: "shadow-comparison")
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
            }
            #endif
            #if DEBUG
            CommandGroup(after: .help) {
                Button("Run Export Tests") {
                    runExportTests()
                }
                .keyboardShortcut("T", modifiers: [.command, .shift])
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

        Window("Metrics Sizing Playground", id: "metrics-sizing") {
            MetricsSizingPlayground()
        }
        .defaultSize(width: 1200, height: 800)

        Window("Dimension Calibration Playground", id: "dim-calibration") {
            DimensionCalibrationPlayground()
        }
        .defaultSize(width: 1200, height: 800)

        Window("Resizable Dim-Cal Playground", id: "resizable-dim-cal") {
            ResizableDimCalPlayground()
        }
        .defaultSize(width: 1200, height: 800)

        Window("Shadow Comparison Playground", id: "shadow-comparison") {
            ShadowComparisonPlayground()
        }
        .defaultSize(width: 1400, height: 900)
        #endif
    }
}
