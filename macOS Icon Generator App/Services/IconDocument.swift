// IconDocument.swift - FileDocument conformance for exporting
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

struct IconDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    var settings: IconSettings
    var preRenderedImage: NSImage?
    var appexExportParams: AppexExportParams?

    struct AppexExportParams {
        let symbolName: String
        let enclosureColor: AppexEnclosureColor
        let symbolColor: AppexEnclosureColor
        let pointSize: CGFloat
        let scaleFactor: Int
        let colorSpace: ExportColorSpace
    }

    init(settings: IconSettings) {
        self.settings = settings
        self.preRenderedImage = nil
        self.appexExportParams = nil
    }

    init(preRenderedImage: NSImage) {
        self.settings = IconSettings()
        self.preRenderedImage = preRenderedImage
        self.appexExportParams = nil
    }

    init(appexExport: AppexExportParams) {
        self.settings = IconSettings()
        self.preRenderedImage = nil
        self.appexExportParams = appexExport
    }

    init(configuration: ReadConfiguration) throws {
        // We don't support reading icons back in, only exporting them
        self.settings = IconSettings()
        self.preRenderedImage = nil
        self.appexExportParams = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let image: NSImage
        let scaleFactor: Int

        if let params = appexExportParams {
            image = try AppexReferenceService.renderForExport(
                symbolName: params.symbolName,
                enclosureColor: params.enclosureColor,
                symbolColor: params.symbolColor,
                pointSize: params.pointSize,
                scaleFactor: params.scaleFactor,
                colorSpace: params.colorSpace
            )
            scaleFactor = params.scaleFactor
        } else if let preRendered = preRenderedImage {
            image = preRendered
            scaleFactor = 2
        } else {
            image = IconRenderer.renderIconSafely(settings: settings)
            scaleFactor = settings.exportRetinaSize ? 2 : 1
        }

        return try makePNGFileWrapper(image: image, scaleFactor: scaleFactor)
    }

    private func makePNGFileWrapper(image: NSImage, scaleFactor: Int) throws -> FileWrapper {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let dpi = CGFloat(scaleFactor == 2 ? 144 : 72)
        let pixelsPerMeter = dpi / 0.0254
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyPNGXPixelsPerMeter: pixelsPerMeter,
                kCGImagePropertyPNGYPixelsPerMeter: pixelsPerMeter
            ]
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return FileWrapper(regularFileWithContents: data as Data)
    }
}
