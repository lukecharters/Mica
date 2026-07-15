// Models/ImportedImage.swift — Icon source mode and imported image data
import SwiftUI
import UniformTypeIdentifiers

/// Determines whether an icon or badge uses an SF Symbol or a custom imported image.
enum IconSource: String, CaseIterable, Identifiable, Equatable {
    case sfSymbol = "SF Symbol"
    case customImage = "Custom Image"
    case system = "System"
    var id: String { rawValue }
}

/// Holds a PNG-normalized imported image with metadata about its origin.
struct ImportedImage: Equatable {
    let id: UUID
    let imageData: Data
    let sourceName: String
    /// True when the image is a Finder icon extracted via NSWorkspace (an app
    /// bundle or any other non-image file), false when the source file's own
    /// pixels were imported. Drives the "Icon"/"Image" label in the UI.
    let isFileIcon: Bool

    var nsImage: NSImage? { NSImage(data: imageData) }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
