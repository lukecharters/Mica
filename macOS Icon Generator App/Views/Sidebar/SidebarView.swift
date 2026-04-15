// Views/Sidebar/SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @Binding var iconSettings: IconSettings
    @Binding var generationMode: GenerationMode
    @Binding var appexEnclosureColor: AppexEnclosureColor
    @Binding var appexSymbolColor: AppexEnclosureColor
    let colorOptions: [(name: String, color: Color)]

    @State private var selectedSegment: IconOrBadge = .icon

    // Persisted section expand/collapse state (reused keys from prior sidebar redesign)
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
        VStack(spacing: 0) {
            IconBadgePicker(selection: $selectedSegment)

            Divider()
                .padding(.top, 4)

            ScrollView {
                VStack(spacing: 0) {
                    switch selectedSegment {
                    case .icon:
                        iconContent
                    case .badge:
                        badgeContent
                    }
                }
            }
            .id(selectedSegment) // Reset scroll position when switching segments
        }
    }

    // MARK: - Icon content (Symbol form + Background form stacked)

    @ViewBuilder
    private var iconContent: some View {
        groupHeader("Symbol")
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
        }
        .formStyle(GroupedFormStyle())
        .fixedSize(horizontal: false, vertical: true)

        if !isAppleReference {
            Divider()
                .padding(.top, 4)

            groupHeader("Background")
            Form {
                Section("Background", isExpanded: $backgroundExpanded) {
                    BackgroundSection(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions
                    )
                }
            }
            .formStyle(GroupedFormStyle())
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Badge content (Show Badge toggle + Symbol form + Background form stacked)

    @ViewBuilder
    private var badgeContent: some View {
        Form {
            Section {
                HStack {
                    Text("Show Badge")
                    Spacer()
                    Toggle("Show Badge", isOn: $iconSettings.showBadge)
                        .labelsHidden()
                }
            }
        }
        .formStyle(GroupedFormStyle())
        .fixedSize(horizontal: false, vertical: true)

        groupHeader("Symbol")
        Form {
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
        }
        .formStyle(GroupedFormStyle())
        .fixedSize(horizontal: false, vertical: true)

        Divider()
            .padding(.top, 4)

        groupHeader("Background")
        Form {
            Section("Background", isExpanded: $badgeBackgroundExpanded) {
                BadgeBackgroundSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions
                )
            }
        }
        .formStyle(GroupedFormStyle())
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Shared

    private func groupHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title3)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}
