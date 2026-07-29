// Views/Inspector/Badge/Background/BadgeBackgroundSourceSection.swift
import SwiftUI

struct BadgeBackgroundSourceSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        LayerVisibleToggle(isHidden: $iconSettings.badge.background.isHidden)

        Picker("Type", systemImage: "app.grid", selection: $iconSettings.badge.background.source) {
            Text("Color").tag(BadgeBackgroundSource.color)
            Text("Imported").tag(BadgeBackgroundSource.image)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if iconSettings.badge.background.source == .image {
            ImageImportControls(
                importedImage: $iconSettings.badge.background.image,
                onImport: { iconSettings.badge.background.apply($0) }
            )
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Source") {
            BadgeBackgroundSourceSection(iconSettings: $settings)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
