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

                Button("AR Calibration Playground") {
                    openWindow(id: "ar-calibration")
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])
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

        Window("AR Calibration Playground", id: "ar-calibration") {
            AspectRatioCalibrationPlayground()
        }
        .defaultSize(width: 1200, height: 800)
    }
}
