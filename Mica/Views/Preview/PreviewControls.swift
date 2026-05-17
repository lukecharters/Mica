// Views/Preview/PreviewControls.swift
import SwiftUI

struct PreviewControls: View {
    @Binding var iconSettings: IconSettings
    @Binding var zoomLevel: Double

    private let zoomLevels: [Double] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0]

    var body: some View {
        HStack(spacing: 8) {
            // Size display (shows export dimensions)
            sizeControl

            // Zoom control
            zoomControl
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var sizeControl: some View {
        Menu {
            ForEach([16, 32, 64, 128, 256, 512, 1024], id: \.self) { size in
                Button {
                    iconSettings.exportSize = CGFloat(size)
                } label: {
                    HStack {
                        Text("\(size)pt")
                        if iconSettings.exportRetinaSize {
                            Text("(\(size * 2)px)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Divider()

            Toggle("2x Retina", isOn: $iconSettings.exportRetinaSize)
        } label: {
            HStack(spacing: 4) {
                Text(sizeLabel)
                    .monospacedDigit()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var sizeLabel: String {
        let size = Int(iconSettings.exportSize)
        if iconSettings.exportRetinaSize {
            return "\(size)pt 2x"
        } else {
            return "\(size)pt"
        }
    }

    private var zoomControl: some View {
        Menu {
            ForEach(zoomLevels, id: \.self) { level in
                Button {
                    zoomLevel = level
                } label: {
                    Text("\(Int(level * 100))%")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(zoomLabel)
                    .monospacedDigit()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var zoomLabel: String {
        if zoomLevel == 0 {
            return "Fit"
        }
        return "\(Int(zoomLevel * 100))%"
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    @Previewable @State var zoomLevel: Double = 1.0
    PreviewControls(iconSettings: $settings, zoomLevel: $zoomLevel)
        .padding()
}
