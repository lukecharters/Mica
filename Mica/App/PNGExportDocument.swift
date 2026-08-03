// App/PNGExportDocument.swift
//
// The FileDocument payload for the PNG fileExporter — not a document model.
// `readableContentTypes` is [.png], `fileWrapper(configuration:)` renders and
// returns PNG bytes, and `init(configuration:)` is a stub that discards its
// input: nothing is ever read back in through this type.
//
// Renamed from IconDocument on 2026-07-28. The `.mica` document format it used to
// refer to was abandoned on 2026-07-31; the app has no document model and keeps
// work by exporting a configuration instead — see ConfigurationExportDocument and
// docs/plans/json-config-format.md.
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

struct PNGExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    var settings: IconSettings
    var renderedImage: NSImage?
    var appexExportParams: AppexExportParams?
    var badgeAppexImage: NSImage?

    struct AppexExportParams {
        let symbolName: String
        /// The stored colours, **not** their plist projection. Projecting can fail
        /// — a colour outside sRGB, a translucent enclosure — and `fileWrapper` is
        /// where a failure can be reported, whereas the caller building these is a
        /// non-throwing computed property in `ContentView`. In practice the render
        /// has already failed by then and `canExport` has withdrawn ⇧⌘E, so this is
        /// the second line of defence rather than the first.
        let enclosureColor: AppexColor
        let symbolColor: AppexColor
        let pointSize: CGFloat
        let scaleFactor: Int
        let colorSpace: ExportColorSpace
    }

    init(settings: IconSettings, badgeAppexImage: NSImage? = nil) {
        self.settings = settings
        self.renderedImage = nil
        self.appexExportParams = nil
        self.badgeAppexImage = badgeAppexImage
    }

    init(renderedImage: NSImage) {
        self.settings = IconSettings()
        self.renderedImage = renderedImage
        self.appexExportParams = nil
        self.badgeAppexImage = nil
    }

    init(appexExport: AppexExportParams, settings: IconSettings = IconSettings(), badgeAppexImage: NSImage? = nil) {
        self.settings = settings
        self.renderedImage = nil
        self.appexExportParams = appexExport
        self.badgeAppexImage = badgeAppexImage
    }

    init(configuration: ReadConfiguration) throws {
        // We don't support reading icons back in, only exporting them
        self.settings = IconSettings()
        self.renderedImage = nil
        self.appexExportParams = nil
        self.badgeAppexImage = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try pngData())
    }

    /// Render this document and encode it as PNG bytes.
    ///
    /// Split out of `fileWrapper(configuration:)` on 2026-08-03 so the drag-out
    /// payload (`DraggableIcon`) reaches the same render path ⇧⌘E does, without
    /// having to synthesize a `WriteConfiguration` it has no way to obtain.
    ///
    func pngData() throws -> Data {
        let resolved = try resolvedImage()
        return try PNGExporter.pngData(from: resolved.image, scaleFactor: resolved.scaleFactor)
    }

    /// Render this document to an `NSImage`, with the scale factor its bytes should be
    /// encoded at.
    ///
    /// **Keep this the only copy.** The branch below — a Mica render, a bare appex
    /// raster, or an appex raster composited with a badge, plus the hidden-icon-group
    /// case that forces compositing — is the whole of what "export the current icon"
    /// means, and the failure mode of a second copy is one surface producing a subtly
    /// different icon than the Save panel does for the same settings. Three callers now
    /// route through it: ⇧⌘E, the drag-out (`DraggableIcon`) and Copy (`IconPasteboard`).
    ///
    /// Returning the image rather than only its PNG bytes is what Copy needs: the
    /// pasteboard carries TIFF alongside PNG, and deriving TIFF from encoded PNG bytes
    /// would mean decoding what we just encoded.
    func resolvedImage() throws -> (image: NSImage, scaleFactor: Int) {
        let image: NSImage
        let scaleFactor: Int

        if let params = appexExportParams {
            let appexImage = try AppexReferenceService.renderForExport(
                symbolName: params.symbolName,
                enclosureColor: AppexPlistColor(projecting: params.enclosureColor, role: .enclosure),
                symbolColor: AppexPlistColor(projecting: params.symbolColor, role: .symbol),
                pointSize: params.pointSize,
                scaleFactor: params.scaleFactor,
                colorSpace: params.colorSpace
            )
            // A hidden icon group also needs the compositing path: the raw appex
            // raster can only be used as-is when the icon is visible and there's
            // no badge to overlay.
            if settings.badge.isVisible || settings.icon.isHidden {
                if Thread.isMainThread {
                    image = MainActor.assumeIsolated {
                        IconRenderer.renderAppexWithBadge(
                            appexImage: appexImage,
                            settings: settings,
                            badgeAppexImage: badgeAppexImage
                        )
                    }
                } else {
                    var composited = appexImage
                    let capturedSettings = settings
                    let capturedBadgeImage = badgeAppexImage
                    DispatchQueue.main.sync {
                        composited = MainActor.assumeIsolated {
                            IconRenderer.renderAppexWithBadge(
                                appexImage: appexImage,
                                settings: capturedSettings,
                                badgeAppexImage: capturedBadgeImage
                            )
                        }
                    }
                    image = composited
                }
            } else {
                image = appexImage
            }
            scaleFactor = params.scaleFactor
        } else if let rendered = renderedImage {
            image = rendered
            scaleFactor = 2
        } else {
            image = IconRenderer.renderIconSafely(settings: settings, badgeAppexImage: badgeAppexImage)
            scaleFactor = settings.export.isRetina ? 2 : 1
        }

        return (image, scaleFactor)
    }
}
