// Views/Sidebar/BackgroundSourceSection.swift
import SwiftUI

struct BackgroundSourceSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        Picker("Type", systemImage: "app.grid", selection: $iconSettings.backgroundMode) {
            Text("Standard").tag(BackgroundMode.custom)
            Text("Liquid Glass").tag(BackgroundMode.preRendered)
            Text("Imported").tag(BackgroundMode.importedImage)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if iconSettings.backgroundMode == .importedImage {
            ImageImportControls(
                importedImage: $iconSettings.importedBackground,
                onImport: { imported in
                    if imported.isAppIcon {
                        iconSettings.importedBackgroundPaddingCompensation = true
                    }
                }
            )
        }
    }
}
