// Models/SidebarSettings.swift
import Foundation

/// Shared UserDefaults keys for sidebar-wide preferences read by multiple views
/// via `@AppStorage` — the inspector sections, `InspectorControls` itself, and
/// `ContentView` (which needs the advanced flag to decide what the preview
/// outlines).
enum SidebarSettings {
    /// Off (the default) collapses each group's inspector to a single un-tabbed
    /// pane matching System mode's shape; on reveals the layer tabs and every
    /// per-layer control.
    static let advancedControlsKey = "sidebar.advancedControls"
}
