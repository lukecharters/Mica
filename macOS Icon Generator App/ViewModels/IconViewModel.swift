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

    // Generation mode
    @Published var generationMode: GenerationMode = .swiftUI
    @Published var appexEnclosureColor: AppexEnclosureColor = .blue
    @Published var appexRenderedImage: NSImage? = nil
    @Published var appexIsGenerating: Bool = false
    @Published var appexError: String? = nil

    // Derived values (no type changes)
    var actualExportSize: CGFloat { iconSettings.finalExportSize }

    // MARK: - Appex Generation

    struct AppexGenerationKey: Equatable {
        let symbolName: String
        let enclosureColor: AppexEnclosureColor
    }

    var appexGenerationKey: AppexGenerationKey {
        AppexGenerationKey(symbolName: iconSettings.symbolName, enclosureColor: appexEnclosureColor)
    }

    func generateAppexIcon(service: AppexReferenceService) async {
        appexIsGenerating = true
        appexError = nil
        do {
            appexRenderedImage = try await service.referenceIcon(
                for: iconSettings.symbolName,
                enclosureColor: appexEnclosureColor
            )
        } catch {
            appexError = error.localizedDescription
            appexRenderedImage = nil
        }
        appexIsGenerating = false
    }

    // MARK: - Color Selection

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
