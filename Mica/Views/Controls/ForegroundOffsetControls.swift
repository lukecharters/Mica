// Views/Controls/ForegroundOffsetControls.swift
//
// The two offset sliders (and their reset) for a *foreground* layer, group-agnostic
// and driven by explicit bindings — one implementation for the icon's Foreground ▸
// Layout pane and the badge's, the same way `ForegroundSpec` is one type for both.
// A second copy is how the two would come to disagree about the range, the step or
// the percent readout.
//
// The badge *group*'s offsets are a different control with a different job
// (`BadgeGroupLayoutSection`): those move the whole badge and are clamped by
// `BadgeGeometry` so it stays on the canvas. These move a layer inside its own
// frame and are deliberately unclamped — see `ForegroundSpec.offsetX`.
import SwiftUI

struct ForegroundOffsetControls: View {
    @Binding var offsetX: Double
    @Binding var offsetY: Double
    /// Which group's foreground this is, which is only the help text's business —
    /// the two sliders are otherwise identical. Nothing here reads `IconSettings`,
    /// so a caller cannot pass one group's bindings under the other's name and have
    /// it half work.
    let group: IconLayerGroup
    /// So a drag is one undo step rather than one per frame.
    @Environment(\.continuousEdit) private var continuousEdit

    var body: some View {
        Slider(value: $offsetX,
               in: ForegroundSpec.offsetRange,
               step: 0.01) {
            Text("X Offset")
            Text(verbatim: "\(percent(offsetX))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } onEditingChanged: { continuousEdit.sliderEditing($0) }
        .help(horizontalHelp)

        Slider(value: $offsetY,
               in: ForegroundSpec.offsetRange,
               step: 0.01) {
            Text("Y Offset")
            Spacer()
            Text(verbatim: "\(percent(offsetY))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } onEditingChanged: { continuousEdit.sliderEditing($0) }
        .help(verticalHelp)

        if offsetX != 0 || offsetY != 0 {
            Button("Recenter") {
                offsetX = 0
                offsetY = 0
            }
        }
    }

    private var horizontalHelp: LocalizedStringKey {
        switch group {
        case .icon:  "Move this layer left or right within the icon. It may overhang the edge."
        case .badge: "Move this layer left or right within the badge. The badge itself stays put."
        }
    }

    private var verticalHelp: LocalizedStringKey {
        switch group {
        case .icon:  "Move this layer up or down within the icon. It may overhang the edge."
        case .badge: "Move this layer up or down within the badge. The badge itself stays put."
        }
    }

    /// The percent readout, **rounded rather than truncated** — `Int(0.29 * 100)`
    /// is 28, and a 0.01 step lands on exactly those values. Same rule and same
    /// reason as `BadgeGroupLayoutSection.percent`.
    private func percent(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Layout") {
            ForegroundOffsetControls(offsetX: $settings.icon.foreground.offsetX,
                                     offsetY: $settings.icon.foreground.offsetY,
                                     group: .icon)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
