// Models/InspectorPreferences.swift
import Foundation

/// Shared UserDefaults keys for inspector-wide preferences read by multiple views
/// via `@AppStorage` — the inspector sections, `InspectorControls` itself, and
/// `ContentView` (which needs the advanced flag to decide what the preview
/// outlines).
enum InspectorPreferences {
    /// Off (the default) collapses each group's inspector to a single un-tabbed
    /// pane matching System mode's shape; on reveals the layer tabs and every
    /// per-layer control.
    ///
    /// The key string deliberately keeps its `sidebar.` prefix even though this
    /// type was renamed from `SidebarSettings`: changing it would silently reset
    /// the preference for anyone who has already toggled it, and a UserDefaults
    /// key is not something a reader of the code has to understand.
    static let advancedControlsKey = "sidebar.advancedControls"
}
