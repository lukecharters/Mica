// IconDocument.swift - FileDocument conformance for exporting
import SwiftUI
import UniformTypeIdentifiers

struct IconDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    
    var settings: IconSettings
    
    init(settings: IconSettings) {
        self.settings = settings
    }
    
    init(configuration: ReadConfiguration) throws {
        // We don't support reading icons back in, only exporting them
        self.settings = IconSettings()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Use the safe rendering method that works from any thread
        let image = IconRenderer.renderIconSafely(settings: settings)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        return FileWrapper(regularFileWithContents: pngData)
    }
}
