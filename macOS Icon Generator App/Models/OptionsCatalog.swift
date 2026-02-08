// Models/OptionsCatalog.swift
// Centralized catalog for preset options; tuple element types preserved
import SwiftUI

struct OptionsCatalog {
    /// All preset colors are resolved to explicit sRGB so that equality checks
    /// (`Color == Color`) work reliably and rendering is consistent across
    /// solid fills, gradients, and different color-space contexts.
    static let colorOptions: [(name: String, color: Color)] = {
        func sRGB(_ color: Color) -> Color {
            if let resolved = NSColor(color).usingColorSpace(.sRGB) {
                return Color(resolved)
            }
            return color
        }
        return [
            ("Black", sRGB(.black)),
            ("Blue", sRGB(.blue)),
            ("Brown", sRGB(.brown)),
            ("Cyan", sRGB(.cyan)),
            ("Gray", sRGB(.gray)),
            ("Green", sRGB(.green)),
            ("Indigo", sRGB(.indigo)),
            ("Mint", sRGB(.mint)),
            ("Orange", sRGB(.orange)),
            ("Pink", sRGB(.pink)),
            ("Purple", sRGB(.purple)),
            ("Red", sRGB(.red)),
            ("Teal", sRGB(.teal)),
            ("White", sRGB(.white)),
            ("Yellow", sRGB(.yellow)),
        ]
    }()

    /// Look up a resolved sRGB color by name from the catalog.
    static func color(named name: String) -> Color {
        colorOptions.first { $0.name == name }?.color ?? .blue
    }

    /// Reverse lookup: find the catalog name for a given color.
    static func colorName(for color: Color) -> String? {
        colorOptions.first { $0.color == color }?.name
    }
}
