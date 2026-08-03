// App/InspectorPreferences.swift
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

    /// On import of a background image, hide that group's foreground. On by
    /// default — most such imports are a finished app icon being re-exported.
    ///
    /// Off suits the opposite workflow: re-badging an icon you already have, by
    /// importing it as the background and putting a symbol over it. There the
    /// default is wrong every time, and hard to discover as *wrong*, because the
    /// foreground disappears at the moment of import.
    static let hidesForegroundOnBackgroundImportKey = "import.hidesForeground"

    /// On import of a background image, set the icon's corner radius to `off`.
    /// On by default, because artwork that fills its own bounds loses its corners
    /// to any radius at all.
    ///
    /// Off suits artwork that *should* be clipped to a chiclet — a texture or a
    /// photo. Nothing in the file says which kind arrived, which is why this asks
    /// rather than guesses per-file. Icon-only; the badge has no corner radius.
    static let turnsOffCornerRadiusOnBackgroundImportKey = "import.turnsOffCornerRadius"
}

extension ImportDefaults {
    /// The interactive import defaults: what the File and Edit menus, the
    /// inspector source sections and the canvas drop pass.
    ///
    /// **`App/`-only on purpose.** The CLI and the configuration codec do not
    /// compile this file, so they cannot reach a preference — see `ImportDefaults`
    /// for why that has to be structural rather than a rule to remember.
    static func fromPreferences(_ defaults: UserDefaults = .standard) -> ImportDefaults {
        // `object(forKey:) == nil` distinguishes "never set" from "set to false",
        // because both preferences default to *on* and `bool(forKey:)` returns
        // false for an absent key.
        func flag(_ key: String) -> Bool {
            defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
        }
        return ImportDefaults(
            hidesForeground: flag(InspectorPreferences.hidesForegroundOnBackgroundImportKey),
            turnsOffCornerRadius: flag(InspectorPreferences.turnsOffCornerRadiusOnBackgroundImportKey)
        )
    }
}
