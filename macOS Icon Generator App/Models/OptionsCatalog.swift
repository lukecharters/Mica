// Models/OptionsCatalog.swift
// Centralized catalog for preset options; tuple element types preserved
import SwiftUI

struct OptionsCatalog {
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
        ("Yellow", .yellow)
    ]

    static let sizeOptions: [(label: String, size: CGFloat)] = [
        ("128px", 128),
        ("256px", 256),
        ("512px", 512),
        ("1024px", 1024)
    ]
}
