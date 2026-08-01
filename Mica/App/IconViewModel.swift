// App/IconViewModel.swift
// MVVM: Holds UI state and simple actions for the Icon Generator
import SwiftUI

@MainActor
final class IconViewModel: ObservableObject {
    /// True only while an imported configuration is being installed into these
    /// properties. The undo observers in `ContentView` check it, so that an import
    /// registers the one combined step it makes for itself rather than a step per
    /// property it happens to write. See `IconViewModel+Undo.swift`.
    var isInstallingImportedConfiguration = false

    /// Undo bookkeeping: which writes came from an undo rather than the user, and
    /// whether a continuous edit is in progress. Stored here because extensions cannot
    /// add stored properties; all the logic — and the reasoning — is in
    /// `IconViewModel+Undo.swift`.
    var undoState = UndoState()

    // Mirror previous @State vars from ContentView with identical types
    @Published var iconSettings: IconSettings = IconSettings()
    @Published var showExportDialog: Bool = false

    /// The configuration export, prepared by `beginConfigurationExport()` rather than
    /// computed in `body`: building it encodes the JSON and collects every imported
    /// image's bytes, which is far too much to redo on each view update. The exporter
    /// reads the prepared value, so the two are set together.
    @Published var showConfigExportDialog: Bool = false
    @Published var configExportDocument: ConfigurationExportDocument?

    /// Why a configuration export could not be prepared. Encoding a configuration has
    /// no expected failure, so this exists to make an unexpected one visible instead of
    /// producing a menu item that silently does nothing.
    @Published var configExportError: String?

    /// Anything an imported configuration said that this build could not honour — an
    /// unknown key, an unparseable colour, a missing sidecar image. Held rather than
    /// discarded so the import can account for what it dropped. See
    /// `IconViewModel+Configuration.swift`.
    @Published var configImportWarnings: [MicaConfigWarning] = []

    // Generation mode is now per-group on `iconSettings` (iconGenerationMode +
    // badgeGenerationMode). A computed convenience for any code that still wants
    // a single "are we in Apple Reference?" answer for the icon.
    var generationMode: GenerationMode {
        get { iconSettings.icon.mode }
        set { iconSettings.icon.mode = newValue }
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
    var actualExportSize: CGFloat { iconSettings.export.pixelSize }

    /// Whether an export would produce the icon the preview is showing.
    ///
    /// System-mode layers export their appex-rendered image, so an export started
    /// before that image arrives silently omits the pending layer. Both the icon and
    /// the badge can be in System mode independently, and either one pending is enough
    /// to block.
    ///
    /// This lives here, not on the inspector's export button, because the File menu's
    /// Export as PNG… asks the same question from outside the inspector — and it reads
    /// `appexRenderedImage`, which only the view model has. Two copies of the rule
    /// would drift, and the copy that drifted would be the one that writes a broken PNG.
    var canExport: Bool {
        !waitingOnIconAppex && !waitingOnBadgeAppex
    }

    private var waitingOnIconAppex: Bool {
        iconSettings.icon.mode == .system && appexRenderedImage == nil
    }

    private var waitingOnBadgeAppex: Bool {
        iconSettings.badge.isVisible
            && iconSettings.badge.foreground.source == .system
            && badgeAppexRenderedImage == nil
    }

    // MARK: - Appex Generation

    struct AppexGenerationKey: Equatable {
        let symbolName: String
        let enclosureColor: AppexColor
        let symbolColor: AppexColor
    }

    var appexGenerationKey: AppexGenerationKey {
        AppexGenerationKey(symbolName: iconSettings.icon.foreground.symbolName, enclosureColor: appexEnclosureColor, symbolColor: appexSymbolColor)
    }

    func generateAppexIcon(service: AppexReferenceService) async {
        appexIsGenerating = true
        appexError = nil
        do {
            let image = try await service.referenceIcon(
                for: iconSettings.icon.foreground.symbolName,
                enclosureColor: appexEnclosureColor.plistValue,
                symbolColor: appexSymbolColor.plistValue
            )
            // .task(id:) cancellation is cooperative and the service render is not
            // itself cancelled, so a superseded request can finish late. Drop its
            // result instead of overwriting state that belongs to a newer key; the
            // superseding task owns the isGenerating flag from here.
            guard !Task.isCancelled else { return }
            appexRenderedImage = image
        } catch {
            guard !Task.isCancelled else { return }
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
            showBadge: iconSettings.badge.isVisible,
            badgeGenerationMode: iconSettings.badge.mode,
            symbolName: iconSettings.badge.foreground.symbolName,
            enclosureColor: badgeAppexEnclosureColor,
            symbolColor: badgeAppexSymbolColor
        )
    }

    func generateBadgeAppexIcon(service: AppexReferenceService) async {
        badgeAppexIsGenerating = true
        badgeAppexError = nil
        do {
            let image = try await service.referenceIcon(
                for: iconSettings.badge.foreground.symbolName,
                enclosureColor: badgeAppexEnclosureColor.plistValue,
                symbolColor: badgeAppexSymbolColor.plistValue
            )
            // Same late-completion guard as generateAppexIcon — see comment there.
            guard !Task.isCancelled else { return }
            badgeAppexRenderedImage = image
        } catch {
            guard !Task.isCancelled else { return }
            badgeAppexError = error.localizedDescription
            badgeAppexRenderedImage = nil
        }
        badgeAppexIsGenerating = false
    }

}
