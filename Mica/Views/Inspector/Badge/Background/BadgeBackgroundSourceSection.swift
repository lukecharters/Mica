// Views/Sidebar/BadgeBackgroundSourceSection.swift
import SwiftUI

struct BadgeBackgroundSourceSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        LayerVisibleToggle(isHidden: $iconSettings.badgeBackgroundHidden)

        Picker("Type", systemImage: "app.grid", selection: $iconSettings.badgeUseImportedBackground) {
            Text("Color").tag(false)
            Text("Imported").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if iconSettings.badgeUseImportedBackground {
            ImageImportControls(
                importedImage: $iconSettings.badgeImportedBackground,
                onImport: { iconSettings.applyImportedBadgeBackground($0) }
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
