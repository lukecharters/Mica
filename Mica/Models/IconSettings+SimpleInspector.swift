// Models/IconSettings+SimpleInspector.swift
//
// Support for the inspector's simple pane — the single un-tabbed Source +
// Appearance pane shown in Mica mode when "Show Advanced Controls" is off. It
// exposes one row per setting (symbol, symbol colour, background colour, and the
// two shadows), so any state that would need extra rows has to be folded away
// first. That folding lives here rather than in the views so it can be tested.
//
// App-target only: `mica-cli` has no inspector, so this file is deliberately
// absent from the CLI targets' `membershipExceptions`.

import Foundation

extension IconSettings {

    // MARK: - Imported sources

    /// True when any layer is driven by an imported image. The simple pane has no
    /// control for those, so `InspectorControls` reveals the advanced controls
    /// when this becomes true — imports can arrive from the File and Edit menus
    /// or a canvas drop while the simple pane is showing.
    var usesImportedSources: Bool {
        iconSource == .customImage
            || backgroundMode == .importedImage
            || badgeIconSource == .customImage
            || badgeUseImportedBackground
    }

    // MARK: - Folding state back into the simple pane

    /// Forces every layer back to something the simple pane can express: an SF
    /// Symbol foreground on a plain colour background, monochrome rendering, and
    /// a single background colour.
    ///
    /// Non-destructive — imported artwork, palette colours, custom gradient
    /// colours and `preRenderedColorName` are all left in place, so re-enabling
    /// the advanced controls and re-picking a source restores the previous look.
    /// Settings that only change *how* a layer renders without adding a row
    /// (gradients, symbol weight, corner style, symbol scale) are left alone;
    /// they stay hidden-but-applied exactly as they always have.
    mutating func resetToSimpleControls() {
        // Icon. `iconSource` is never `.system` — the icon's System mode lives in
        // `iconGenerationMode` — so no guard is needed here.
        if iconSource == .customImage {
            iconSource = .sfSymbol
        }
        if backgroundMode != .custom {
            backgroundMode = .custom
        }
        symbolRenderingMode = .monochrome
        useCustomColors = false

        // Badge. `badgeGenerationMode` is derived from `badgeIconSource`, so
        // writing `.sfSymbol` over `.system` would knock a System badge out of
        // System mode.
        if badgeIconSource == .customImage {
            badgeIconSource = .sfSymbol
        }
        badgeUseImportedBackground = false
        badgeSymbolRenderingMode = .monochrome
        badgeUseCustomColors = false
    }

    // MARK: - Group visibility

    /// Whether every layer in a group is visible. Stricter than the inverse of
    /// `iconHidden`/`badgeHidden`, which only report a *fully* hidden group: a
    /// group with one layer hidden reads as not fully visible, so the simple
    /// pane's single Visible toggle sits off and one flick of it brings the whole
    /// group back.
    func isGroupFullyVisible(_ group: IconLayerGroup) -> Bool {
        switch group {
        case .icon:  return !iconForegroundHidden && !iconBackgroundHidden
        case .badge: return !badgeForegroundHidden && !badgeBackgroundHidden
        }
    }

    /// Shows or hides a whole group, applying to every layer in it. Showing a
    /// group therefore clears a per-layer hidden flag left over from advanced
    /// mode, which the simple pane has no other way to reach.
    mutating func setGroupVisible(_ visible: Bool, for group: IconLayerGroup) {
        switch group {
        case .icon:  iconHidden = !visible
        case .badge: badgeHidden = !visible
        }
    }
}
