// Models/ImportedImage.swift — Icon source mode and imported image data
import SwiftUI
import UniformTypeIdentifiers

/// Determines whether an icon or badge uses an SF Symbol or a custom imported image.
enum IconSource: String, CaseIterable, Identifiable, Equatable {
    case sfSymbol = "SF Symbol"
    case customImage = "Custom Image"
    case appleReference = "Apple Reference"
    var id: String { rawValue }
}

/// Holds a PNG-normalized imported image with metadata about its origin.
struct ImportedImage: Equatable {
    let id: UUID
    let imageData: Data
    let sourceName: String
    let isAppIcon: Bool

    var nsImage: NSImage? { NSImage(data: imageData) }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
