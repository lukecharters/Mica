// App/IconViewModel.swift
// MVVM: Holds UI state and simple actions for the icon preview and inspector. See `IconViewModel+Undo.swift` for the undo logic.
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

    /// `export` defaults to the fixed `ExportSpec()`, so every test and every
    /// SwiftUI preview gets the built-in defaults; only `ContentView.init()` passes
    /// `.fromPreferences()`. Reading the preference here instead would make a
    /// machine's Settings ▸ Export choice silently change what the test suite
    /// asserts against.
    init(export: ExportSpec = ExportSpec()) {
        iconSettings.export = export
    }

    /// The configuration export, prepared by `beginConfigurationExport()` rather than
    /// computed in `body`: building it encodes the JSON and collects every imported
    /// image's bytes, which is far too much to redo on each view update. The exporter
    /// reads the prepared value, so the two are set together.
    @Published var showConfigExportDialog: Bool = false
    @Published var configExportDocument: ConfigurationExportDocument?

    /// Whether the configuration open panel is showing. A failed import installs
    /// nothing — see `importConfiguration(from:undoManager:)`.
    @Published var showConfigImportDialog: Bool = false

    /// The one thing the window is telling the user about, or nil.
    ///
    /// Four separate properties fed four separate alerts until 2026-08-05 — a copy
    /// failure, a configuration export failure, a configuration import failure and the
    /// import's warnings — beside seven `print()`s that told the user nothing at all.
    /// See `UserMessage` for what belongs here and what stays inline.
    ///
    /// **One slot, last write wins, and that cannot lose a message in practice.** Every
    /// value here follows a discrete action, and the alert showing one is modal to its
    /// window, so the user cannot start a second action while it is up. The only pair
    /// that could arrive without a click between them is a configuration import's error
    /// and its warnings, and those are exclusive by construction: a failed import
    /// installs nothing and produces no warnings.
    @Published var userMessage: UserMessage?

    /// Show `message`, or do nothing if there is nothing to show.
    ///
    /// Takes an optional so a caller can pass a constructor that answers "nothing to
    /// say" with nil — `UserMessage.configurationImportWarnings(_:)` is the one that
    /// does — without every call site repeating the `if let`.
    func report(_ message: UserMessage?) {
        guard let message else { return }
        userMessage = message
    }

    /// The reporter to hand the views and the menu. See `UserMessage`.
    ///
    /// `lazy` rather than computed so `ContentView` hands the *same* value to the
    /// environment and to the focused-value modifier on every body pass. A fresh
    /// closure each time is a fresh environment value each time, which invalidates
    /// every descendant reading it for no reason.
    lazy var messageReporter = UserMessageReporter { [weak self] message in
        MainActor.assumeIsolated { self?.report(message) }
    }

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
            // Projected inside the `do`, so a colour System mode cannot express
            // lands in `appexError` — which the preview pane shows and `canExport`
            // reads, so the icon is not silently exported without it (decision D2).
            let image = try await service.referenceIcon(
                for: iconSettings.icon.foreground.symbolName,
                enclosureColor: AppexPlistColor(projecting: appexEnclosureColor, role: .enclosure),
                symbolColor: AppexPlistColor(projecting: appexSymbolColor, role: .symbol)
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
                enclosureColor: AppexPlistColor(projecting: badgeAppexEnclosureColor, role: .enclosure),
                symbolColor: AppexPlistColor(projecting: badgeAppexSymbolColor, role: .symbol)
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
