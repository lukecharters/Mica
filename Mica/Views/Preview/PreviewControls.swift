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
/// Zoom-level menu for the SwiftUI preview, shown in the window toolbar.
///
/// The rungs come from `PreviewZoom`, which View ▸ Zoom In / Zoom Out walks too, so
/// the keyboard cannot land on a percentage this menu does not list.
///
/// **The label is a `Label` whose *icon* is the percentage.** A toolbar captions an
/// item from its label's title and names it to VoiceOver by the same title, so a bare
/// `Text(value)` face has no caption in Icon and Text mode and no name at all. With the
/// value in the icon slot the face still reads "100%" and the item reads "Zoom"
/// beneath it, which is how Keynote's zoom control is labelled.
struct ZoomMenu: View {
    @Binding var zoomLevel: Double

    var body: some View {
        Menu {
            ForEach(PreviewZoom.levels, id: \.self) { level in
                Toggle(isOn: zoomBinding(for: level)) {
                    // `verbatim:` — a percentage is a value, not prose, and an Int
                    // interpolated into a `LocalizedStringKey` picks up the locale's
                    // digit grouping. Harmless at 25–800%, wrong the moment anyone
                    // adds a rung past 1000%. See the project notes.
                    Text(verbatim: "\(Int(level * 100))%")
                }
            }
        } label: {
            Label {
                Text("Zoom")
            } icon: {
                Text(verbatim: zoomLabel)
            }
        }
        .help("Preview zoom")
    }

    /// A `Toggle` rather than a `Button` so the current rung gets the menu's own
    /// checkmark gutter. Setting it off does nothing: these are mutually exclusive,
    /// and there is no "no zoom".
    private func zoomBinding(for level: Double) -> Binding<Bool> {
        Binding(
            get: { zoomLevel == level },
            set: { if $0 { zoomLevel = level } }
        )
    }

    /// Off-ladder values are expected here — pinch and ⌘-scroll produce them — so this
    /// reads the level rather than looking it up in `PreviewZoom.levels`.
    private var zoomLabel: String {
        "\(Int(zoomLevel * 100))%"
    }
}

/// Preview-size menu, shown in the window toolbar. Chooses the point size the
/// preview renders the icon at — either a standard size or the size used by a
/// specific MDM self service portal — so you can judge how the icon reads where
/// users will see it. This is preview-only and never affects export (export size
/// lives in `ExportSettingsSection`). `nil` follows the current export size.
/// Composes with `ZoomMenu` — the chosen preview size is the base that zoom scales.
struct PreviewSizeMenu: View {
    @Binding var previewPointSize: CGFloat?

    var body: some View {
        Menu {
            PreviewSizeMenuContent(previewPointSize: $previewPointSize)
        } label: {
            // The size in the icon slot, the name as the title — see `ZoomMenu`.
            Label {
                Text("Preview Size")
            } icon: {
                Text(verbatim: sizeLabel)
            }
        }
        .help("Preview size")
    }

    private var sizeLabel: String {
        guard let previewPointSize else { return "Match Export" }
        return "\(Int(previewPointSize))pt"
    }
}

/// The rows of the preview-size menu, with no `Menu` around them.
///
/// Two menus show this list — the toolbar's `PreviewSizeMenu` and View ▸ Preview
/// Size — and they are one view rather than two copies of a `ForEach`, so an MDM
/// portal added to `MDMPortalSizePreset.all` cannot appear in only one of them.
struct PreviewSizeMenuContent: View {
    @Binding var previewPointSize: CGFloat?

    /// Not `ExportPreferences.sizeChoices`, though it is the same seven numbers
    /// today. These are *preview* point sizes — how big the icon is drawn on screen
    /// — and that list is the export sizes offered in two pickers. Sharing them
    /// would tie a change in one meaning to the other.
    private let standardSizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

    var body: some View {
        // `Toggle` rather than `Button` + a `Label` whose systemImage was
        // `"checkmark"` or `""`: a menu draws a Toggle's state in its own checkmark
        // gutter, where the old spelling put an SF Symbol inline with the title and
        // relied on an empty image name rendering as nothing. That reads as a
        // stray icon in the menu bar, which is where this list now also appears.
        Toggle(isOn: sizeBinding(for: nil)) {
            Text("Match Export Size")
        }

        Section {
            ForEach(standardSizes, id: \.self) { size in
                Toggle(isOn: sizeBinding(for: CGFloat(size))) {
                    // `verbatim:` — 1024 would render as "1,024pt" otherwise.
                    Text(verbatim: "\(size)pt")
                }
            }
        }

        // One section per vendor, headed by the vendor's name. A menu section
        // header is a real `NSMenu` header item on macOS, so this is the platform's
        // own grouping rather than a disabled row pretending to be one.
        ForEach(MDMPortalSizePreset.grouped) { group in
            Section {
                ForEach(group.presets) { preset in
                    Toggle(isOn: sizeBinding(for: CGFloat(preset.pointSize))) {
                        Text(verbatim: "\(preset.name) (\(preset.pointSize)pt)")
                    }
                }
            } header: {
                // `verbatim:` — a vendor is a proper noun, not prose.
                Text(verbatim: group.vendor)
            }
        }
    }

    /// Selecting a row sets that size; switching a row *off* is meaningless here
    /// (the rows are mutually exclusive and one is always current), so it is
    /// ignored rather than mapped to some other size.
    ///
    /// **More than one row can be checked, across sections as well as within one,
    /// and that is not a bug.** The state is a point size and nothing else, so every
    /// row naming that size reads as current — 64 is a standard size, Munki's updates
    /// list *and* Fleet's; 75 is both Jamf Self Service classic's catalogue and
    /// Munki's categories; 40 is both Jamf Self Service+'s catalogue and Fleet's
    /// narrow window. Making exactly one check would mean storing *which row* was
    /// picked, which no renderer would read; the rows are honest as they stand.
    private func sizeBinding(for size: CGFloat?) -> Binding<Bool> {
        Binding(
            get: { previewPointSize == size },
            set: { if $0 { previewPointSize = size } }
        )
    }
}

#Preview {
    @Previewable @State var zoomLevel: Double = 1.0
    @Previewable @State var previewPointSize: CGFloat? = nil
    HStack {
        ZoomMenu(zoomLevel: $zoomLevel)
        PreviewSizeMenu(previewPointSize: $previewPointSize)
    }
    .padding()
}
