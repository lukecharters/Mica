// App/PreviewSizeChoice.swift
//
// One row of the preview-size picker, and the rule for which row a point size is.
//
// The picker's face shows the size the preview is drawn at, and its title captions the
// toolbar item — which a `Menu` cannot do, and is why this is a `Picker` at all. A
// `Picker` needs one distinct tag per row, and several rows name the same point size:
// 64 is a standard size, Munki's updates list and Fleet's; 75 is Jamf classic's browse
// view and Munki's categories. So the tag is the *row*, not the size, and this is the
// rule that turns the one stored size back into a row.
//
// **App-target only**: the CLI has no preview.

import CoreGraphics
import Foundation

enum PreviewSizeChoice: Hashable {
    /// Follow the export size — the default, stored as nil.
    case matchExport
    /// One of the standard sizes, in points.
    case standard(Int)
    /// An MDM portal's row, by `MDMPortalSizePreset.id`.
    case portal(String)

    /// The plain sizes, offered ahead of the vendor sections.
    ///
    /// Not `ExportPreferences.sizeChoices`, though it is the same seven numbers today.
    /// These are *preview* point sizes — how big the icon is drawn on screen — where
    /// that list is the export sizes offered in two pickers. Sharing them would tie a
    /// change in one meaning to the other.
    static let standardSizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

    /// The row that shows `pointSize`.
    ///
    /// Where a size has more than one row, the **standard row wins**, and among portals
    /// the first in `MDMPortalSizePreset.all`. A size no row names — nothing in the app
    /// writes one — falls back to a standard row that does not exist, which the picker
    /// shows as no selection rather than as the wrong one.
    init(pointSize: CGFloat?) {
        guard let pointSize else {
            self = .matchExport
            return
        }
        let size = Int(pointSize)
        if Self.standardSizes.contains(size) {
            self = .standard(size)
        } else if let preset = MDMPortalSizePreset.all.first(where: { $0.pointSize == size }) {
            self = .portal(preset.id)
        } else {
            self = .standard(size)
        }
    }

    /// What choosing this row stores.
    var pointSize: CGFloat? {
        switch self {
        case .matchExport:
            nil
        case .standard(let size):
            CGFloat(size)
        case .portal(let id):
            MDMPortalSizePreset.all.first { $0.id == id }.map { CGFloat($0.pointSize) }
        }
    }
}
