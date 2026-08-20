// App/ExportPanel.swift
//
// The PNG export panel: an `NSSavePanel` carrying the export settings in its
// accessory view, in place of SwiftUI's `.fileExporter`.
//
// **`.fileExporter` cannot do this.** It exposes no accessory hook of any kind, so
// putting the settings beside the filename means running the panel directly. What
// that costs is `FileDocument`'s write step: `PNGExportDocument` still renders and
// encodes (`pngData()`), and the caller writes those bytes to the chosen URL. What
// it does not cost is the rest of the flow — `IconViewModel.showExportDialog` is
// still the one flag ⇧⌘E, the inspector's Export button and the canvas menu all
// set, so `canExport` still gates every route to this panel.
//
// `runModal()` rather than a sheet, matching the four Import as… items and
// `ImageImportControls`: every file panel in Mica is app-modal, and the return
// value is the answer rather than a callback.
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// What the accessory view edits while the panel is up.
///
/// A reference type because `NSHostingView` needs somewhere to write that outlives
/// the SwiftUI view, and `ExportPanel.run` reads it back after `runModal()`
/// returns. It holds no policy — that is all on `ExportPanelOptions`.
@MainActor
final class ExportPanelModel: ObservableObject {
    @Published var options: ExportPanelOptions

    init(options: ExportPanelOptions) {
        self.options = options
    }
}

@MainActor
enum ExportPanel {
    /// A completed export panel: where to write, and what to render.
    struct Outcome: Equatable {
        let url: URL
        /// The settings *this* export asked for, which may differ from the
        /// window's. See `ExportPanelOptions`.
        let export: ExportSpec
    }

    /// Run the panel. Returns nil when the user cancels.
    ///
    /// - Parameters:
    ///   - seed: the window's current export settings, which the accessory opens on.
    ///   - defaultBaseName: the filename without its extension — `IconSettings.exportBaseName`.
    static func run(seed: ExportSpec, defaultBaseName: String) -> Outcome? {
        let model = ExportPanelModel(options: ExportPanelOptions(seed: seed))

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        // Named with the extension because AppKit is not being asked to invent one:
        // `.fileExporter` appended `.png` to its `defaultFilename`, and an export
        // that suddenly produced an extensionless file would be this change's
        // quietest regression.
        panel.nameFieldStringValue = "\(defaultBaseName).png"
        panel.prompt = String(localized: "Export")

        // The accessory sizes itself off the SwiftUI content, which fixes its own
        // width; the panel then centres it. Nothing here may change height while
        // the panel is open — see `ExportOptionsAccessory.overrideFootnote`.
        let hosting = NSHostingView(rootView: ExportOptionsAccessory(model: model))
        // Sized once, explicitly, from what SwiftUI wants. `sizingOptions` was
        // tried first and left the accessory narrower than its content, which the
        // panel then centred — so the label column hung off the left edge.
        hosting.setFrameSize(hosting.fittingSize)
        panel.accessoryView = hosting

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return Outcome(url: url, export: model.options.spec)
    }
}
