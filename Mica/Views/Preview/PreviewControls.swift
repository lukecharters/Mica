// Views/Preview/PreviewControls.swift
import SwiftUI

/// A named preview preset for an MDM self service portal, expressed as the point
/// size the portal displays the icon at. Previewing at this size shows how the
/// icon reads where users will actually see it; it does not affect export.
struct MDMPortalPreset: Identifiable {
    let name: String
    let pointSize: Int

    var id: String { name }

    /// Known self service portals and the point size they show icons at.
    static let all: [MDMPortalPreset] = [
        MDMPortalPreset(name: "Jamf Self Service+ - Catalog View", pointSize: 40),
        MDMPortalPreset(name: "Jamf Self Service+ - Item View", pointSize: 88),
        MDMPortalPreset(name: "Jamf Self Service - Catalog View", pointSize: 75),
        MDMPortalPreset(name: "Jamf Self Service - Item View", pointSize: 120)
    ]
}

/// Zoom-level menu for the SwiftUI preview, shown in the window toolbar.
struct ZoomMenu: View {
    @Binding var zoomLevel: Double

    private let zoomLevels: [Double] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0]

    var body: some View {
        Menu {
            ForEach(zoomLevels, id: \.self) { level in
                Button {
                    zoomLevel = level
                } label: {
                    Text("\(Int(level * 100))%")
                }
            }
        } label: {
                Text(zoomLabel)
        }
        .help("Preview zoom")
    }

    private var zoomLabel: String {
        if zoomLevel == 0 {
            return "Fit"
        }
        return "\(Int(zoomLevel * 100))%"
    }
}

/// Preview-size menu, shown in the window toolbar. Chooses the point size the
/// preview renders the icon at — either a standard size or the size used by a
/// specific MDM self service portal — so you can judge how the icon reads where
/// users will see it. This is preview-only and never affects export (export size
/// lives in `ExportSettingsSidebar`). `nil` follows the current export size.
/// Composes with `ZoomMenu` — the chosen preview size is the base that zoom scales.
struct PreviewSizeMenu: View {
    @Binding var previewPointSize: CGFloat?

    private let standardSizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

    var body: some View {
        Menu {
            Button {
                previewPointSize = nil
            } label: {
                Label("Match Export Size", systemImage: previewPointSize == nil ? "checkmark" : "")
            }

            Section() {
                ForEach(standardSizes, id: \.self) { size in
                    let pointSize = CGFloat(size)
                    Button {
                        previewPointSize = pointSize
                    } label: {
                        Label("\(size)pt", systemImage: previewPointSize == pointSize ? "checkmark" : "")
                    }
                }
            }

            Section() {
                ForEach(MDMPortalPreset.all) { preset in
                    let pointSize = CGFloat(preset.pointSize)
                    Button {
                        previewPointSize = pointSize
                    } label: {
                        Label(
                            "\(preset.name) (\(preset.pointSize)pt)",
                            systemImage: previewPointSize == pointSize ? "checkmark" : ""
                        )
                    }
                }
            }
        } label: {
            Text(sizeLabel)
        }
        .help("Preview size")
    }

    private var sizeLabel: String {
        guard let previewPointSize else { return "Match Export" }
        return "\(Int(previewPointSize))pt"
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
