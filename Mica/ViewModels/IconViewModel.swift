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

    // Generation mode is now per-group on `iconSettings` (iconGenerationMode +
    // badgeGenerationMode). A computed convenience for any code that still wants
    // a single "are we in Apple Reference?" answer for the icon.
    var generationMode: GenerationMode {
        get { iconSettings.iconGenerationMode }
        set { iconSettings.iconGenerationMode = newValue }
    }
    @Published var appexEnclosureColor: AppexColor = .blue
    @Published var appexSymbolColor: AppexColor = .white
    @Published var appexRenderedImage: NSImage? = nil
    @Published var appexIsGenerating: Bool = false
    @Published var appexError: String? = nil

    // Badge appex state
    @Published var badgeAppexEnclosureColor: AppexColor = .blue
    @Published var badgeAppexSymbolColor: AppexColor = .white
    @Published var badgeAppexRenderedImage: NSImage? = nil
    @Published var badgeAppexIsGenerating: Bool = false
    @Published var badgeAppexError: String? = nil

    // Derived values (no type changes)
    var actualExportSize: CGFloat { iconSettings.finalExportSize }

    // MARK: - Appex Generation

    struct AppexGenerationKey: Equatable {
        let symbolName: String
        let enclosureColor: AppexColor
        let symbolColor: AppexColor
    }

    var appexGenerationKey: AppexGenerationKey {
        AppexGenerationKey(symbolName: iconSettings.symbolName, enclosureColor: appexEnclosureColor, symbolColor: appexSymbolColor)
    }

    func generateAppexIcon(service: AppexReferenceService) async {
        appexIsGenerating = true
        appexError = nil
        do {
            appexRenderedImage = try await service.referenceIcon(
                for: iconSettings.symbolName,
                enclosureColor: appexEnclosureColor.plistValue,
                symbolColor: appexSymbolColor.plistValue
            )
        } catch {
            appexError = error.localizedDescription
            appexRenderedImage = nil
        }
        appexIsGenerating = false
    }

    struct BadgeAppexGenerationKey: Equatable {
        let showBadge: Bool
        let badgeGenerationMode: GenerationMode
        let symbolName: String
        let enclosureColor: AppexColor
        let symbolColor: AppexColor
    }

    var badgeAppexGenerationKey: BadgeAppexGenerationKey {
        BadgeAppexGenerationKey(
            showBadge: iconSettings.showBadge,
            badgeGenerationMode: iconSettings.badgeGenerationMode,
            symbolName: iconSettings.badgeSymbolName,
            enclosureColor: badgeAppexEnclosureColor,
            symbolColor: badgeAppexSymbolColor
        )
    }

    func generateBadgeAppexIcon(service: AppexReferenceService) async {
        badgeAppexIsGenerating = true
        badgeAppexError = nil
        do {
            badgeAppexRenderedImage = try await service.referenceIcon(
                for: iconSettings.badgeSymbolName,
                enclosureColor: badgeAppexEnclosureColor.plistValue,
                symbolColor: badgeAppexSymbolColor.plistValue
            )
        } catch {
            badgeAppexError = error.localizedDescription
            badgeAppexRenderedImage = nil
        }
        badgeAppexIsGenerating = false
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
