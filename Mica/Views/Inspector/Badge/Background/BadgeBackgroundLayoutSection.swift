// Views/Sidebar/BadgeBackgroundLayoutSection.swift
import SwiftUI

struct BadgeBackgroundLayoutSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        ImageImportLayoutControls(
            paddingCompensation: $iconSettings.badgeImportedBackgroundPaddingCompensation,
            imageScale: $iconSettings.badgeImportedBackgroundScale
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
