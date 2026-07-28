// Views/Inspector/Badge/Background/BadgeBackgroundLayoutSection.swift
import SwiftUI

struct BadgeBackgroundLayoutSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        ImageImportLayoutControls(
            paddingCompensation: $iconSettings.badge.background.compensatesForPadding,
            imageScale: $iconSettings.badge.background.imageScale
        )
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Layout") {
            BadgeBackgroundLayoutSection(iconSettings: $settings)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
