// ViewModels/IconViewModel.swift
// MVVM: Holds UI state and simple actions for the Icon Generator
import SwiftUI

@MainActor
final class IconViewModel: ObservableObject {
    // Mirror previous @State vars from ContentView with identical types
    @Published var iconSettings: IconSettings = IconSettings()
    @Published var showExportDialog: Bool = false
    @Published var exportPath: URL? = nil
    @Published var testingMode: Bool = false
    @Published var layoutSettings: LayoutSettings = LayoutSettings()

    // Derived values (no type changes)
    var actualExportSize: CGFloat { iconSettings.finalExportSize }

    // Actions for selecting preset colors (kept simple; types unchanged)
    func selectPresetColor(index: Int, options: [(name: String, color: Color)]) {
        guard options.indices.contains(index) else { return }
        iconSettings.baseColor = options[index].color
    }

    func selectBadgePresetColor(index: Int, options: [(name: String, color: Color)]) {
        guard options.indices.contains(index) else { return }
        iconSettings.badgeBaseColor = options[index].color
    }
}
