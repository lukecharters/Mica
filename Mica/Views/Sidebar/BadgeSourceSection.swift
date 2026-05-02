// Views/Sidebar/BadgeSourceSection.swift
import SwiftUI

struct BadgeSourceSection: View {
    @Binding var iconSettings: IconSettings

    @State private var showSymbolNameHelp = false

    var body: some View {
        Picker("Source", selection: $iconSettings.badgeIconSource) {
            Text("SF Symbol").tag(IconSource.sfSymbol)
            Text("Imported").tag(IconSource.customImage)
            Text("System").tag(IconSource.appleReference)
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
            HStack(spacing: 8) {
                TextField("Symbol", text: $iconSettings.badgeSymbolName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: { showSymbolNameHelp.toggle() }) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(BorderlessButtonStyle())
                .popover(isPresented: $showSymbolNameHelp) {
                    Text("Enter the name of any SF Symbol. \nDownload Apple's SF Symbols app to see a list of all available symbols.")
                        .padding()
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}
