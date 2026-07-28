// Views/Inspector/Icon/Background/IconBackgroundSourceSection.swift
import SwiftUI

struct IconBackgroundSourceSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        LayerVisibleToggle(isHidden: $iconSettings.iconBackgroundHidden)

        Picker("Type", systemImage: "app.grid", selection: $iconSettings.backgroundMode) {
            Text("Color").tag(BackgroundMode.custom)
            Text("Pre-Rendered").tag(BackgroundMode.preRendered)
            Text("Imported").tag(BackgroundMode.importedImage)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if iconSettings.backgroundMode == .importedImage {
            ImageImportControls(
                importedImage: $iconSettings.importedBackground,
                onImport: { iconSettings.applyImportedIconBackground($0) }
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
