// Views/Controls/ShadowSettingsSection.swift
import SwiftUI

struct ShadowSettingsSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        Section(header: Text("Shadow Settings")) {
            Toggle("Background Drop Shadow", isOn: $iconSettings.enableBackgroundShadow)
                .help("Toggle the drop shadow behind the background shape")
            Toggle("Symbol Drop Shadow", isOn: $iconSettings.enableSymbolShadow)
                .help("Toggle the drop shadow behind the SF Symbol")
        }
    }
}
