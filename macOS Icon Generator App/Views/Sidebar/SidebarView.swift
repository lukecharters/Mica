// Views/Sidebar/SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @Binding var iconSettings: IconSettings
    @Binding var generationMode: GenerationMode
    @Binding var appexEnclosureColor: AppexEnclosureColor
    @Binding var appexSymbolColor: AppexEnclosureColor
    let colorOptions: [(name: String, color: Color)]

    @State private var selectedTab: Int = 0

    // Persisted section expand/collapse state
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
        TabView(selection: $selectedTab) {
            iconTab
                .tabItem { Label("Icon", systemImage: "app") }
                .tag(0)
            badgeTab
                .tabItem { Label("Badge", systemImage: "seal") }
                .tag(1)
        }
        .tabViewStyle(GroupedTabViewStyle())
        .padding(.top, 4)
    }

    // MARK: - Icon Tab

    private var iconTab: some View {
        Form {
            Section("Source", isExpanded: $iconSourceExpanded) {
                IconSourceSection(
                    iconSettings: $iconSettings,
                    generationMode: $generationMode
                )
            }

            if !isAppleReference {
                Section("Layout", isExpanded: $iconLayoutExpanded) {
                    IconLayoutSection(iconSettings: $iconSettings)
                }
            }

            Section("Appearance", isExpanded: $iconAppearanceExpanded) {
                IconAppearanceSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions,
                    isAppleReference: isAppleReference,
                    appexSymbolColor: $appexSymbolColor,
                    appexEnclosureColor: $appexEnclosureColor
                )
            }

            if !isAppleReference {
                Section("Background", isExpanded: $backgroundExpanded) {
                    BackgroundSection(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions
                    )
                }
            }
        }
        .formStyle(GroupedFormStyle())
    }

    // MARK: - Badge Tab

    private var badgeTab: some View {
        Form {
            Section {
                HStack {
                    Text("Show Badge")
                    Spacer()
                    Toggle("", isOn: $iconSettings.showBadge)
                        .labelsHidden()
                }
            }

            Section("Source", isExpanded: $badgeSourceExpanded) {
                BadgeSourceSection(iconSettings: $iconSettings)
            }

            Section("Layout", isExpanded: $badgeLayoutExpanded) {
                BadgeLayoutSection(iconSettings: $iconSettings)
            }

            Section("Appearance", isExpanded: $badgeAppearanceExpanded) {
                BadgeAppearanceSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions
                )
            }

            Section("Background", isExpanded: $badgeBackgroundExpanded) {
                BadgeBackgroundSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions
                )
            }
        }
        .formStyle(GroupedFormStyle())
    }
}
