// Views/Inspector/Badge/BadgeGroupLayoutSection.swift
import SwiftUI

/// Badge-wide layout controls: anchor position, manual offset, overall badge scale.
/// Hosted by the badge's Layout tab in Mica mode, and by the single System-mode
/// pane (position and size still apply when the appex badge is composited).
/// See `InspectorControls.badgeGroupControls`.
struct BadgeGroupLayoutSection: View {
    @Binding var iconSettings: IconSettings
    /// So a drag is one undo step rather than one per frame.
    @Environment(\.continuousEdit) private var continuousEdit

    var body: some View {
        Picker("Position", systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", selection: $iconSettings.badge.position) {
            ForEach(BadgePosition.allCases) { position in
                Text(position.rawValue).tag(position)
            }
        }
        .onChange(of: iconSettings.badge.position) {
            iconSettings.badge.offsetX = 0
            iconSettings.badge.offsetY = 0
        }
        .help("Which corner of the icon the badge sits in")

        Slider(value: $iconSettings.badge.offsetX,
               in: BadgeSpec.offsetRange,
               step: 0.01) {
            Text("X Offset")
            Text(verbatim: "\(percent(iconSettings.badge.offsetX))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } onEditingChanged: { continuousEdit.sliderEditing($0) }
        .help("Move the badge horizontally from its corner. Dragging it on the canvas does the same, as do the arrow keys.")

        Slider(value: $iconSettings.badge.offsetY,
               in: BadgeSpec.offsetRange,
               step: 0.01) {
            Text("Y Offset")
            Spacer()
            Text(verbatim: "\(percent(iconSettings.badge.offsetY))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } onEditingChanged: { continuousEdit.sliderEditing($0) }
        .help("Move the badge vertically from its corner. Dragging it on the canvas does the same, as do the arrow keys.")

        if iconSettings.badge.offsetX != 0 || iconSettings.badge.offsetY != 0 {
            Button("Reset Position") {
                iconSettings.badge.offsetX = 0
                iconSettings.badge.offsetY = 0
            }
        }

        Slider(value: $iconSettings.badge.scale,
               in: ForegroundSpec.symbolScaleRange,
               step: 0.05) {
            Text("Size")
            Spacer()
            Text(verbatim: "\(percent(iconSettings.badge.scale))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } onEditingChanged: { continuousEdit.sliderEditing($0) }
        .help("The whole badge, relative to the size macOS itself draws one. Past about 109% it starts moving inward to stay on the canvas.")
    }

    /// The percent readout, **rounded rather than truncated**.
    ///
    /// `Int(0.29 * 100)` is 28: the product is 28.999999999999996 and `Int` drops
    /// the tail, so a 29% offset read as 28%. The sliders step by 0.01, which is
    /// exactly the size of value that lands on the wrong side of that.
    /// `IconAccessibilityDescription` speaks the same numbers and rounds the same
    /// way, so what VoiceOver says and what the slider shows cannot disagree.
    private func percent(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Badge Layout") {
            BadgeGroupLayoutSection(iconSettings: $settings)
        }
    }
    .formStyle(GroupedFormStyle())
    .frame(width: 380)
    .padding()
}
