// IconGeneratorApp.swift
import SwiftUI

@main
struct IconGeneratorApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 750, minHeight: 550)
                .environmentObject(appViewModel)
        }
        .windowStyle(.titleBar)
        .commands {
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

                Button("Resizable Sizing Playground") {
                    openWindow(id: "resizable-sizing")
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])

                Button("Resizable Dim-Cal Playground") {
                    openWindow(id: "resizable-dim-cal")
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])

                Button("Recipe Calibration Playground") {
                    openWindow(id: "recipe-calibration")
                }
                .keyboardShortcut("P", modifiers: [.command, .shift])
            }
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
        }

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

        Window("Resizable Sizing Playground", id: "resizable-sizing") {
            ResizableSizingPlayground()
        }
        .defaultSize(width: 1400, height: 800)

        Window("Resizable Dim-Cal Playground", id: "resizable-dim-cal") {
            ResizableDimCalPlayground()
        }
        .defaultSize(width: 1200, height: 800)

        Window("Recipe Calibration Playground", id: "recipe-calibration") {
            RecipeCalibrationPlayground()
        }
        .defaultSize(width: 1200, height: 800)
    }
}
