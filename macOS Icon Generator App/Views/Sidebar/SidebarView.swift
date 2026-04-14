// Views/Sidebar/SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @Binding var iconSettings: IconSettings
    @Binding var generationMode: GenerationMode
    @Binding var appexEnclosureColor: AppexEnclosureColor
    @Binding var appexSymbolColor: AppexEnclosureColor
    let colorOptions: [(name: String, color: Color)]

    // Persisted disclosure group state
    @AppStorage("sidebar.iconSource.expanded") private var iconSourceExpanded = true
    @AppStorage("sidebar.iconLayout.expanded") private var iconLayoutExpanded = true
    @AppStorage("sidebar.iconAppearance.expanded") private var iconAppearanceExpanded = true
    @AppStorage("sidebar.background.expanded") private var backgroundExpanded = true
    @AppStorage("sidebar.badgeSource.expanded") private var badgeSourceExpanded = true
    @AppStorage("sidebar.badgeLayout.expanded") private var badgeLayoutExpanded = true
    @AppStorage("sidebar.badgeAppearance.expanded") private var badgeAppearanceExpanded = true
    @AppStorage("sidebar.badgeBackground.expanded") private var badgeBackgroundExpanded = true

    private var isAppleReference: Bool {
        generationMode == .appleReference
    }

    var body: some View {
        Form {
            Section(header: Text("Icon")) {
                DisclosureGroup("Source", isExpanded: $iconSourceExpanded) {
                    IconSourceSection(
                        iconSettings: $iconSettings,
                        generationMode: $generationMode
                    )
                }

                if !isAppleReference {
                    DisclosureGroup("Layout", isExpanded: $iconLayoutExpanded) {
                        IconLayoutSection(iconSettings: $iconSettings)
                    }
                }

                DisclosureGroup("Appearance", isExpanded: $iconAppearanceExpanded) {
                    IconAppearanceSection(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions,
                        isAppleReference: isAppleReference,
                        appexSymbolColor: $appexSymbolColor,
                        appexEnclosureColor: $appexEnclosureColor
                    )
                }

                if !isAppleReference {
                    DisclosureGroup("Background", isExpanded: $backgroundExpanded) {
                        BackgroundSection(
                            iconSettings: $iconSettings,
                            colorOptions: colorOptions
                        )
                    }
                }
            }

            Divider()

            Section {
                HStack {
                    Text("Badge")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $iconSettings.showBadge)
                        .labelsHidden()
                }

                DisclosureGroup("Source", isExpanded: $badgeSourceExpanded) {
                    BadgeSourceSection(iconSettings: $iconSettings)
                }

                DisclosureGroup("Layout", isExpanded: $badgeLayoutExpanded) {
                    BadgeLayoutSection(iconSettings: $iconSettings)
                }

                DisclosureGroup("Appearance", isExpanded: $badgeAppearanceExpanded) {
                    BadgeAppearanceSection(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions
                    )
                }

                DisclosureGroup("Background", isExpanded: $badgeBackgroundExpanded) {
                    BadgeBackgroundSection(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions
                    )
                }
            }
        }
        .formStyle(GroupedFormStyle())
    }
}
