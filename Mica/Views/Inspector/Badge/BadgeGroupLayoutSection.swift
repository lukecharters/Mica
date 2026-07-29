// Views/Inspector/Badge/BadgeGroupLayoutSection.swift
import SwiftUI

/// Badge-wide layout controls: anchor position, manual offset, overall badge scale.
/// Hosted by the badge's Layout tab in Mica mode, and by the single System-mode
/// pane (position and size still apply when the appex badge is composited).
/// See `InspectorControls.badgeGroupControls`.
struct BadgeGroupLayoutSection: View {
    @Binding var iconSettings: IconSettings

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

        Slider(value: $iconSettings.badge.offsetX,
               in: BadgeSpec.offsetRange,
               step: 0.01) {
            Text("X Offset")
            Text("\(Int(iconSettings.badge.offsetX * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }

        Slider(value: $iconSettings.badge.offsetY,
               in: BadgeSpec.offsetRange,
               step: 0.01) {
            Text("Y Offset")
            Spacer()
            Text("\(Int(iconSettings.badge.offsetY * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }

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
            Text("\(Int(iconSettings.badge.scale * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
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
