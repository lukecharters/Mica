// Views/Presets/PresetsWindow.swift
import SwiftUI

/// The presets library as a window of its own — the Content Hub to the toolbar
/// popovers' insert menus. Applies to `PresetTarget.shared`, the last icon window
/// that was key, and browses without one.
struct PresetsWindow: View {
    static let id = "presets"

    var body: some View {
        if let handle = PresetTarget.shared.handle {
            VStack(spacing: 12) {
                ForEach(PresetScope.allCases) { scope in
                    if let preset = PresetCatalog.builtIn.first(where: { $0.scope == scope }) {
                        Button("Apply “\(preset.name)” (\(scope.rawValue))") {
                            handle.apply(preset)
                        }
                    }
                }
            }
            .padding()
        } else {
            ContentUnavailableView {
                Label("No Icon Window", systemImage: "macwindow")
            } description: {
                Text("Open an icon window to apply a preset.")
            }
        }
    }
}
