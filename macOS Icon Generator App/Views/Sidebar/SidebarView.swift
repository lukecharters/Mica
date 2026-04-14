// Views/Sidebar/SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @Binding var iconSettings: IconSettings
    @Binding var generationMode: GenerationMode
    @Binding var appexEnclosureColor: AppexEnclosureColor
    @Binding var appexSymbolColor: AppexEnclosureColor
    let colorOptions: [(name: String, color: Color)]

    @State private var selectedTab: Int = 0

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
            Section("Source") {
                IconSourceSection(
                    iconSettings: $iconSettings,
                    generationMode: $generationMode
                )
            }

            if !isAppleReference {
                Section("Layout") {
                    IconLayoutSection(iconSettings: $iconSettings)
                }
            }

            Section("Appearance") {
                IconAppearanceSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions,
                    isAppleReference: isAppleReference,
                    appexSymbolColor: $appexSymbolColor,
                    appexEnclosureColor: $appexEnclosureColor
                )
            }

            if !isAppleReference {
                Section("Background") {
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

            Section("Source") {
                BadgeSourceSection(iconSettings: $iconSettings)
            }

            Section("Layout") {
                BadgeLayoutSection(iconSettings: $iconSettings)
            }

            Section("Appearance") {
                BadgeAppearanceSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions
                )
            }

            Section("Background") {
                BadgeBackgroundSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions
                )
            }
        }
        .formStyle(GroupedFormStyle())
    }
}
