// Models/ImportedImage.swift — imported image data
//
// `ForegroundSource`, which used to live here as `IconSource`, moved to
// IconSettings.swift with the other configuration enums (2026-07-28).

import SwiftUI
import UniformTypeIdentifiers

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
