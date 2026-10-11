// App/IconSettings+LayerThumbnail.swift
//
// The staging a sidebar layer thumbnail draws: the whole settings with every
// layer but one hidden. The thumbnail then renders through `IconContentView` or
// `BadgeView` like the preview and the export do, so there is no second copy of
// the render to keep in step — which is what the four hand-built thumbnails
// removed on 2026-07-25 were.
//
// App-target only: `mica-cli` has no sidebar, so this file is deliberately absent
// from the CLI targets' `membershipExceptions`.

import Foundation

extension IconSettings {

    /// These settings with only one layer drawn, or nil for a row that is not a
    /// layer (`LayerTab.layout`).
    ///
    /// **Only the four `isHidden` flags change.** Everything else is left as it is,
    /// because the layers read across each other: the badge background's shadow
    /// follows `icon.background.shadowStyle`, for one. Resetting the other layers
    /// to defaults would make the thumbnail lie about the layer it shows.
    ///
    /// The layer itself is forced visible, so a hidden layer still has a picture;
    /// the row dims it rather than showing an empty tile.
    func isolatingLayer(_ group: IconLayerGroup, _ tab: LayerTab) -> IconSettings? {
        guard tab.isHideable else { return nil }
        var staged = self
        staged.icon.foreground.isHidden = !(group == .icon && tab == .foreground)
        staged.icon.background.isHidden = !(group == .icon && tab == .background)
        staged.badge.foreground.isHidden = !(group == .badge && tab == .foreground)
        staged.badge.background.isHidden = !(group == .badge && tab == .background)
        return staged
    }
}
