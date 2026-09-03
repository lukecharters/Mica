// Views/Preview/PreviewControls.swift
import SwiftUI

/// A named preview preset for an MDM self service portal, expressed as the point
/// size the portal displays the icon at. Previewing at this size shows how the
/// icon reads where users will actually see it; it does not affect export.
///
/// `vendor` is the menu section the preset sits under, so `name` carries only the
/// portal and the view — the vendor's own name is stripped from the front of it
/// where the section header already says it. Munki is the exception and keeps
/// "Managed Software Center" in every row, because the vendor and the app are not
/// the same word and admins know the app by its name.
struct MDMPortalSizePreset: Identifiable {
    let vendor: String
    let name: String
    let pointSize: Int

    /// The vendor is part of the identity: two vendors can name a view the same
    /// thing, and several already do.
    var id: String { "\(vendor) \(name)" }

    /// Known self service portals and the point size they show icons at.
    ///
    /// Managed Software Center draws its lists in a `WKWebView`, so its sizes come
    /// from munki's own templates and stylesheets rather than from a nib. Three of
    /// the four are the `<img width height>` on the item template; the item page is
    /// the exception — its template says 175 and `detail.css` then overrides it to
    /// 140, which is what the user sees. Read the CSS, not just the template.
    /// Software and My Items share one row layout, hence one entry for both.
    ///
    /// Fleet Desktop is a `WKWebView` shell too — it opens Fleet's own
    /// `/device/{token}/self-service` page — so its sizes come from the React
    /// frontend rather than from anything in the Swift app. They are
    /// `SOFTWARE_ICON_SIZES` in `frontend/styles/var/icon_sizes.ts`, chosen per
    /// view by a `size` prop on `SoftwareIcon`: the software list's table cell
    /// takes the default `small` (24, pinned a second time by
    /// `.software-name-cell .software-icon`), the updates card takes `large`
    /// (64), and the tile layout takes `medium` (40). **The tiles are Fleet's
    /// *mobile* layout**, which a Mac window reaches by being dragged under the
    /// 768px breakpoint — the shell's minimum width is 480, so it is reachable
    /// rather than theoretical. The shell sets no page zoom, so a CSS pixel is
    /// a point.
    ///
    /// **Order matters twice.** `grouped` takes the vendors in the order they
    /// first appear here, and a vendor's rows in the order they appear within it,
    /// so this list is the only place the menu is arranged.
    static let all: [MDMPortalSizePreset] = [
        MDMPortalSizePreset(vendor: "Fleet Desktop", name: "Software View", pointSize: 24),
        MDMPortalSizePreset(vendor: "Fleet Desktop", name: "Updates View", pointSize: 64),
        MDMPortalSizePreset(vendor: "Intune Company Portal", name: "List View", pointSize: 30),
        MDMPortalSizePreset(vendor: "Intune Company Portal", name: "Grid View", pointSize: 80),
        MDMPortalSizePreset(vendor: "Intune Company Portal", name: "Item View", pointSize: 163),
        MDMPortalSizePreset(vendor: "Iru Self Service", name: "All Views", pointSize: 82),
        MDMPortalSizePreset(vendor: "Jamf Self Service+", name: "Catalog View", pointSize: 40),
        MDMPortalSizePreset(vendor: "Jamf Self Service+", name: "Item View", pointSize: 88),
        MDMPortalSizePreset(vendor: "Jamf Self Service classic", name: "Browse View", pointSize: 75),
        MDMPortalSizePreset(vendor: "Jamf Self Service classic", name: "Item View", pointSize: 120),
        MDMPortalSizePreset(vendor: "Munki Managed Software Center", name: "Updates View", pointSize: 64),
        MDMPortalSizePreset(vendor: "Munki Managed Software Center", name: "Categories View", pointSize: 75),
        MDMPortalSizePreset(vendor: "Munki Managed Software Center", name: "Software View", pointSize: 90),
        MDMPortalSizePreset(vendor: "Munki Managed Software Center", name: "Item View", pointSize: 140)
    ]

    /// `all` split into one group per vendor, which is what the menu's sections are.
    ///
    /// Derived rather than stored, so a preset added to `all` cannot be left out of
    /// a section or land in a section of its own by a mistyped vendor showing up as
    /// a second heading with the same-looking name — a grouping that is a *view* of
    /// the list has no second copy to disagree with it.
    static var grouped: [MDMPortalVendorGroup] {
        all.reduce(into: [MDMPortalVendorGroup]()) { groups, preset in
            if let index = groups.firstIndex(where: { $0.vendor == preset.vendor }) {
                groups[index].presets.append(preset)
            } else {
                groups.append(MDMPortalVendorGroup(vendor: preset.vendor, presets: [preset]))
            }
        }
    }
}

/// One vendor's presets, in the order they appear in `MDMPortalSizePreset.all`.
struct MDMPortalVendorGroup: Identifiable {
    let vendor: String
    var presets: [MDMPortalSizePreset]

    var id: String { vendor }
}
/// The zoom pop-up in the window toolbar: the current percentage on its face, "Zoom"
/// as its caption.
///
/// A `Picker`, not a `Menu`. The toolbar captions an item from its label's title, and a
/// `Menu` has only its face — which here has to be the value. A menu-style `Picker`
/// shows the selected row on its face and hands its title to the toolbar, which is how
/// Keynote's zoom control reads "125%" with "Zoom" beneath it.
///
/// The rungs come from `PreviewZoom`, which View ▸ Zoom In / Zoom Out walks too, so the
/// keyboard cannot land on a percentage this list does not offer. A pinch or ⌘-scroll
/// can, and a picker can only show a value it has a row for — so
/// `PreviewZoom.pickerLevels(including:)` adds that value as a rung of its own.
struct ZoomPicker: View {
    @Binding var zoomLevel: Double

    var body: some View {
        Picker("Zoom", selection: $zoomLevel) {
            ForEach(PreviewZoom.pickerLevels(including: zoomLevel), id: \.self) { level in
                // `verbatim:` — a percentage is a value, not prose, and an Int
                // interpolated into a `LocalizedStringKey` picks up the locale's digit
                // grouping. Harmless at 25–800%, wrong the moment anyone adds a rung
                // past 1000%. See the project notes.
                Text(verbatim: "\(Int(level * 100))%").tag(level)
            }
        }
        .pickerStyle(.menu)
        .help("Preview zoom")
    }
}

/// The preview-size pop-up. Chooses the point size the preview renders the icon at —
/// either a standard size or the size used by a specific MDM self service portal — so
/// you can judge how the icon reads where users will see it. Preview-only; export size
/// lives in `ExportSettingsSection`. `nil` follows the current export size, and the
/// chosen size is the base that `ZoomPicker` scales.
///
/// A `Picker` for the reason `ZoomPicker` is one: the toolbar captions it "Preview Size"
/// while its face shows the size. **Two surfaces show this picker** — the toolbar, in
/// menu style, and View ▸ Preview Size, where a `Picker` in a `CommandGroup` renders as
/// a submenu — and they are one view rather than two copies of the rows, so an MDM
/// portal added to `MDMPortalSizePreset.all` cannot appear in only one of them.
///
/// The selection is a `PreviewSizeChoice`, not the point size: a picker needs one tag
/// per row and several rows name the same size. Which row is checked for a shared size
/// is that type's rule.
struct PreviewSizePicker: View {
    @Binding var previewPointSize: CGFloat?

    var body: some View {
        Picker("Preview Size", selection: choice) {
            Text("Match Export Size").tag(PreviewSizeChoice.matchExport)

            Section {
                ForEach(PreviewSizeChoice.standardSizes, id: \.self) { size in
                    // `verbatim:` — 1024 would render as "1,024pt" otherwise.
                    Text(verbatim: "\(size)pt").tag(PreviewSizeChoice.standard(size))
                }
            }

            // One section per vendor, headed by the vendor's name. A menu section
            // header is a real `NSMenu` header item on macOS, so this is the platform's
            // own grouping rather than a disabled row pretending to be one.
            ForEach(MDMPortalSizePreset.grouped) { group in
                Section {
                    ForEach(group.presets) { preset in
                        Text(verbatim: "\(preset.name) (\(preset.pointSize)pt)")
                            .tag(PreviewSizeChoice.portal(preset.id))
                    }
                } header: {
                    // `verbatim:` — a vendor is a proper noun, not prose.
                    Text(verbatim: group.vendor)
                }
            }
        }
        .help("Preview size")
    }

    private var choice: Binding<PreviewSizeChoice> {
        Binding(
            get: { PreviewSizeChoice(pointSize: previewPointSize) },
            set: { previewPointSize = $0.pointSize }
        )
    }
}

#Preview {
    @Previewable @State var zoomLevel: Double = 1.0
    @Previewable @State var previewPointSize: CGFloat? = nil
    HStack {
        ZoomPicker(zoomLevel: $zoomLevel)
        PreviewSizePicker(previewPointSize: $previewPointSize)
            .pickerStyle(.menu)
    }
    .padding()
}
