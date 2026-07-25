// IconDocument.swift - FileDocument conformance for exporting
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

struct IconDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    var settings: IconSettings
    var preRenderedImage: NSImage?
    var appexExportParams: AppexExportParams?
    var badgeAppexImage: NSImage?

    struct AppexExportParams {
        let symbolName: String
        /// Plist colour value — a named token (`"blue"`) or an `"r,g,b,a"` string.
        let enclosureColor: String
        let symbolColor: String
        let pointSize: CGFloat
        let scaleFactor: Int
        let colorSpace: ExportColorSpace
    }

    init(settings: IconSettings, badgeAppexImage: NSImage? = nil) {
        self.settings = settings
        self.preRenderedImage = nil
        self.appexExportParams = nil
        self.badgeAppexImage = badgeAppexImage
    }

    init(preRenderedImage: NSImage) {
        self.settings = IconSettings()
        self.preRenderedImage = preRenderedImage
        self.appexExportParams = nil
        self.badgeAppexImage = nil
    }

    init(appexExport: AppexExportParams, settings: IconSettings = IconSettings(), badgeAppexImage: NSImage? = nil) {
        self.settings = settings
        self.preRenderedImage = nil
        self.appexExportParams = appexExport
        self.badgeAppexImage = badgeAppexImage
    }

    init(configuration: ReadConfiguration) throws {
        // We don't support reading icons back in, only exporting them
        self.settings = IconSettings()
        self.preRenderedImage = nil
        self.appexExportParams = nil
        self.badgeAppexImage = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let image: NSImage
        let scaleFactor: Int

        if let params = appexExportParams {
            let appexImage = try AppexReferenceService.renderForExport(
                symbolName: params.symbolName,
                enclosureColor: params.enclosureColor,
                symbolColor: params.symbolColor,
                pointSize: params.pointSize,
                scaleFactor: params.scaleFactor,
                colorSpace: params.colorSpace
            )
            // A hidden icon group also needs the compositing path: the raw appex
            // raster can only be used as-is when the icon is visible and there's
            // no badge to overlay.
            if settings.showBadge || settings.iconHidden {
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
        } else if let preRendered = preRenderedImage {
            image = preRendered
            scaleFactor = 2
        } else {
            image = IconRenderer.renderIconSafely(settings: settings, badgeAppexImage: badgeAppexImage)
            scaleFactor = settings.exportRetinaSize ? 2 : 1
        }

        return try makePNGFileWrapper(image: image, scaleFactor: scaleFactor)
    }

    private func makePNGFileWrapper(image: NSImage, scaleFactor: Int) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try PNGExporter.pngData(from: image, scaleFactor: scaleFactor))
    }
}
