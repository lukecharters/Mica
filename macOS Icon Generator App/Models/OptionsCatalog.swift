// Models/OptionsCatalog.swift
// Centralized catalog for preset options; tuple element types preserved
import SwiftUI

struct OptionsCatalog {
    /// All preset named SwiftUI colors available for icon customization.
    static let colorOptions: [(name: String, color: Color)] = [
        ("Black", .black),
        ("Blue", .blue),
        ("Brown", .brown),
        ("Cyan", .cyan),
        ("Gray", .gray),
        ("Green", .green),
        ("Indigo", .indigo),
        ("Mint", .mint),
        ("Orange", .orange),
        ("Pink", .pink),
        ("Purple", .purple),
        ("Red", .red),
        ("Teal", .teal),
        ("White", .white),
        ("Yellow", .yellow),
    ]

    /// Look up a color by name from the catalog.
    static func color(named name: String) -> Color {
        colorOptions.first { $0.name == name }?.color ?? .blue
    }
}
