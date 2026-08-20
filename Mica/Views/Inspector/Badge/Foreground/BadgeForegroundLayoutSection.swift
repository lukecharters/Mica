// Views/Inspector/Badge/Foreground/BadgeForegroundLayoutSection.swift
import SwiftUI

/// Layout controls specific to the **badge foreground layer** (symbol scale or
/// imported-image scale, plus the layer's own nudge within the badge). Badge-wide
/// layout — the corner, the badge's own offset from it, overall size — lives in
/// `BadgeGroupLayoutSection`, shown when the Badge group header is selected. The two
/// offset pairs are different things: that one moves the badge on the icon and is
/// clamped to the canvas, this one moves the glyph inside the badge and is not.
struct BadgeForegroundLayoutSection: View {
    @Binding var iconSettings: IconSettings
    /// So a drag is one undo step rather than one per frame.
    @Environment(\.continuousEdit) private var continuousEdit

    var body: some View {
        switch iconSettings.badge.foreground.source {
        case .symbol:
            Slider(value: $iconSettings.badge.foreground.symbolScale,
                   in: ForegroundSpec.symbolScaleRange,
                   step: 0.05) {
                Text("Symbol Scale")
                Text(verbatim: "\(Int((iconSettings.badge.foreground.symbolScale * 100).rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } onEditingChanged: { continuousEdit.sliderEditing($0) }
            .help("The badge symbol\u{2019}s size within the badge. Badge \u{25B8} Layout \u{25B8} Size changes the badge itself.")

        case .image:
            ImageImportLayoutControls(
                paddingCompensation: .constant(false),
                imageScale: $iconSettings.badge.foreground.imageScale,
                showPaddingCompensation: false
            )

        case .system:
            EmptyView()
        }

        // A System-mode badge is one baked raster — symbol and enclosure together —
        // so there is no foreground layer to move within it.
        if iconSettings.badge.foreground.source != .system {
            ForegroundOffsetControls(offsetX: $iconSettings.badge.foreground.offsetX,
                                     offsetY: $iconSettings.badge.foreground.offsetY,
                                     group: .badge)
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Layout") {
            BadgeForegroundLayoutSection(iconSettings: $settings)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
