// Models/GenerationMode.swift
import Foundation

enum GenerationMode: String, CaseIterable, Identifiable {
    case swiftUI = "Custom"
    case appleReference = "Apple"

    var id: String { rawValue }
}
