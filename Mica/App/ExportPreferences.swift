// App/ExportPreferences.swift
import Foundation

/// UserDefaults keys for the export settings a **new window** opens with.
///
/// Kept apart from `InspectorPreferences` because these are not inspector state:
/// they seed `ExportSpec`, which is part of the icon rather than part of the UI
/// looking at it. Both live in `App/` for the same structural reason — the CLI and
/// the configuration codec do not compile this file, so they cannot reach a
/// preference. If they could, one configuration would render two different icons
/// on two machines.
enum ExportPreferences {
    /// Stored as a `Double`; `@AppStorage` has no `CGFloat` overload, and neither
    /// does `UserDefaults`.
    static let defaultSizeKey = "export.defaultSize"
    /// Stored as `ExportColorSpace.rawValue`, which is also the CLI's
    /// `--color-space` token.
    static let defaultColorSpaceKey = "export.defaultColorSpace"

    /// The sizes both size pickers offer — Settings ▸ Export and the inspector's
    /// Export tab. One list so the two cannot drift into offering different sets.
    ///
    /// Deliberately *not* on `ExportSpec`: this is a presentation choice, where
    /// `minSize`/`maxSize` are the shipped contract the CLI validates `--size`
    /// against. Any size in that range is legal; these seven are the ones worth a
    /// menu row.
    static let sizeChoices: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
}

extension ExportSpec {
    /// The export settings a new window opens with.
    ///
    /// `ExportSpec()` stays the *fixed* default — what the CLI, the configuration
    /// decoder, every test and every SwiftUI preview get — and this is the
    /// explicitly-requested preference-aware variant. Same split, for the same
    /// reason, as `ImportDefaults.fixed` / `.fromPreferences(_:)`; the only caller
    /// is `ContentView.init()`.
    ///
    /// A stored value that is out of range or unreadable falls back to the built-in
    /// default rather than being clamped. Clamping would quietly turn a defaults
    /// domain someone had hand-edited into a size they never asked for, and there is
    /// no UI here to show them what happened.
    static func fromPreferences(_ defaults: UserDefaults = .standard) -> ExportSpec {
        var spec = ExportSpec()

        if let stored = defaults.object(forKey: ExportPreferences.defaultSizeKey) as? Double,
           (Double(ExportSpec.minSize)...Double(ExportSpec.maxSize)).contains(stored) {
            spec.size = CGFloat(stored)
        }

        if let raw = defaults.string(forKey: ExportPreferences.defaultColorSpaceKey),
           let colorSpace = ExportColorSpace(rawValue: raw) {
            spec.colorSpace = colorSpace
        }

        return spec
    }
}
