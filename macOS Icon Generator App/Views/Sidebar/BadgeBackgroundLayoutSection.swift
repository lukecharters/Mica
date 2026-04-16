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
