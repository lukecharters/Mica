// Views/Inspector/Icon/Background/IconBackgroundSourceSection.swift
import SwiftUI

struct IconBackgroundSourceSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        LayerVisibleToggle(isHidden: $iconSettings.icon.background.isHidden)

        Picker("Type", systemImage: "app.grid", selection: $iconSettings.icon.background.source) {
            Text("Color").tag(IconBackgroundSource.color)
            Text("Pre-Rendered").tag(IconBackgroundSource.preRendered)
            Text("Imported").tag(IconBackgroundSource.image)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if iconSettings.icon.background.source == .image {
            ImageImportControls(
                importedImage: $iconSettings.icon.background.image,
                onImport: { iconSettings.icon.applyBackgroundImage($0, defaults: .fromPreferences()) }
            )
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Source") {
            IconBackgroundSourceSection(iconSettings: $settings)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
