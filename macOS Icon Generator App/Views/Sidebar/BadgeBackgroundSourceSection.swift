// Views/Sidebar/BadgeBackgroundSourceSection.swift
import SwiftUI

struct BadgeBackgroundSourceSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        Picker("Type", systemImage: "app.grid", selection: $iconSettings.badgeUseImportedBackground) {
            Text("Standard").tag(false)
            Text("Imported").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if iconSettings.badgeUseImportedBackground {
            ImageImportControls(
                importedImage: $iconSettings.badgeImportedBackground,
                onImport: { imported in
                    if imported.isAppIcon {
                        iconSettings.badgeImportedBackgroundPaddingCompensation = true
                    }
                }
            )
        }
    }
}
