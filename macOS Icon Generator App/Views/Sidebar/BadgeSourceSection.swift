// Views/Sidebar/BadgeSourceSection.swift
import SwiftUI

struct BadgeSourceSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        Picker("Source", selection: $iconSettings.badgeIconSource) {
            Label("SF Symbol", systemImage: "character.textbox").tag(IconSource.sfSymbol)
            Label("Imported", systemImage: "photo").tag(IconSource.customImage)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        switch iconSettings.badgeIconSource {
        case .sfSymbol:
            TextField("Symbol", text: $iconSettings.badgeSymbolName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .help("Enter an SF Symbol name for the badge (e.g., 1.circle.fill, plus, checkmark)")

        case .customImage:
            ImageImportControls(importedImage: $iconSettings.badgeImportedImage)

        case .appleReference:
            EmptyView() // Apple Ref source UI to be implemented in later tasks
        }
    }
}
