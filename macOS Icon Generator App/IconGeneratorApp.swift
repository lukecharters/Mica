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
    }
}
