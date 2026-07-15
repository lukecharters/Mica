// Models/GenerationMode.swift
import Foundation

/// How a layer group is rendered: Mica's own SwiftUI pipeline, or Apple's
/// system (appex reference) pipeline. Raw values are the canonical vocabulary
/// shared by the GUI, the CLI's --icon/--badge-generation-mode tokens, and docs.
enum GenerationMode: String, CaseIterable, Identifiable {
    case mica = "mica"
    case system = "system"

    var id: String { rawValue }
}
