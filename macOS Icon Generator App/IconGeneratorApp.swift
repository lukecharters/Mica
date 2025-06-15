// IconGeneratorApp.swift
import SwiftUI

@main
struct IconGeneratorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
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
    }

}
