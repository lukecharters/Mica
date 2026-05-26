// Views/Sidebar/LayerControls.swift
import SwiftUI

/// Renders the Source / Layout / Appearance controls for whichever layer (or group)
/// is selected in the left LayerSidebar.
struct LayerControls: View {
    let selection: LayerSelection
    @Binding var iconSettings: IconSettings
    @Binding var appexEnclosureColor: AppexEnclosureColor
    @Binding var appexSymbolColor: AppexEnclosureColor
    @Binding var badgeAppexEnclosureColor: AppexEnclosureColor
    @Binding var badgeAppexSymbolColor: AppexEnclosureColor
    let colorOptions: [(name: String, color: Color)]

    // Persisted section expand/collapse state.
    @AppStorage("sidebar.iconSource.expanded") private var iconSourceExpanded = true
    @AppStorage("sidebar.iconLayout.expanded") private var iconLayoutExpanded = true
    @AppStorage("sidebar.iconAppearance.expanded") private var iconAppearanceExpanded = true
    @AppStorage("sidebar.backgroundSource.expanded") private var backgroundSourceExpanded = true
    @AppStorage("sidebar.backgroundLayout.expanded") private var backgroundLayoutExpanded = true
    @AppStorage("sidebar.backgroundAppearance.expanded") private var backgroundAppearanceExpanded = true
    @AppStorage("sidebar.badgeSource.expanded") private var badgeSourceExpanded = true
    @AppStorage("sidebar.badgeLayout.expanded") private var badgeLayoutExpanded = true
    @AppStorage("sidebar.badgeAppearance.expanded") private var badgeAppearanceExpanded = true
    @AppStorage("sidebar.badgeBackgroundSource.expanded") private var badgeBackgroundSourceExpanded = true
    @AppStorage("sidebar.badgeBackgroundLayout.expanded") private var badgeBackgroundLayoutExpanded = true
    @AppStorage("sidebar.badgeBackgroundAppearance.expanded") private var badgeBackgroundAppearanceExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selection {
                case .group(.icon):
                    iconGroupControls
                case .group(.badge):
                    BadgeGroupInspector(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions,
                        badgeAppexSymbolColor: $badgeAppexSymbolColor,
                        badgeAppexEnclosureColor: $badgeAppexEnclosureColor
                    )
                case .layer(.icon, .foreground):
                    iconForegroundControls
                case .layer(.icon, .background):
                    iconBackgroundControls
                case .layer(.badge, .foreground):
                    badgeForegroundControls
                case .layer(.badge, .background):
                    badgeBackgroundControls
                }
            }
            .id(selection)
        }
    }

    private var isIconAppleReference: Bool {
        iconSettings.iconGenerationMode == .appleReference
    }

    private var isBadgeAppleReference: Bool {
        iconSettings.badgeGenerationMode == .appleReference
    }

    // MARK: - Icon group (header selected)

    @ViewBuilder
    private var iconGroupControls: some View {
        // In System mode the group is the only selectable target for the icon, so
        // expose the appex Source + Appearance directly. In Custom mode, prompt
        // the user to pick a child layer.
        if isIconAppleReference {
            Form {
                Section("Source", isExpanded: $iconSourceExpanded) {
                    IconSourceSection(
                        iconSettings: $iconSettings,
                        isSystem: true
                    )
                }

                Section("Appearance", isExpanded: $iconAppearanceExpanded) {
                    IconAppearanceSection(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions,
                        isAppleReference: true,
                        appexSymbolColor: $appexSymbolColor,
                        appexEnclosureColor: $appexEnclosureColor
                    )
                }
            }
            .formStyle(GroupedFormStyle())
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            ContentUnavailableView(
                "Select a Layer",
                systemImage: "square.stack.3d.up",
                description: Text("Pick Foreground or Background to edit the icon's source and appearance.")
            )
            .padding(.top, 24)
        }
    }

    // MARK: - Icon Foreground (Custom mode)

    @ViewBuilder
    private var iconForegroundControls: some View {
        Form {
            Section("Source", isExpanded: $iconSourceExpanded) {
                IconSourceSection(
                    iconSettings: $iconSettings,
                    isSystem: false
                )
            }

            Section("Layout", isExpanded: $iconLayoutExpanded) {
                IconLayoutSection(iconSettings: $iconSettings)
            }

            Section("Appearance", isExpanded: $iconAppearanceExpanded) {
                IconAppearanceSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions,
                    isAppleReference: false,
                    appexSymbolColor: $appexSymbolColor,
                    appexEnclosureColor: $appexEnclosureColor
                )
            }
        }
        .formStyle(GroupedFormStyle())
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Icon Background (Custom mode)

    @ViewBuilder
    private var iconBackgroundControls: some View {
        Form {
            Section("Source", isExpanded: $backgroundSourceExpanded) {
                BackgroundSourceSection(iconSettings: $iconSettings)
            }

            if iconSettings.backgroundMode == .importedImage {
                Section("Layout", isExpanded: $backgroundLayoutExpanded) {
                    BackgroundLayoutSection(iconSettings: $iconSettings)
                }
            }

            Section("Appearance", isExpanded: $backgroundAppearanceExpanded) {
                BackgroundAppearanceSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions
                )
            }
        }
        .formStyle(GroupedFormStyle())
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Badge Foreground (Custom mode)

    @ViewBuilder
    private var badgeForegroundControls: some View {
        Form {
            Section("Source", isExpanded: $badgeSourceExpanded) {
                BadgeSourceSection(
                    iconSettings: $iconSettings,
                    isSystem: false
                )
            }
            Section("Layout", isExpanded: $badgeLayoutExpanded) {
                BadgeLayoutSection(iconSettings: $iconSettings)
            }
            Section("Appearance", isExpanded: $badgeAppearanceExpanded) {
                BadgeAppearanceSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions,
                    badgeAppexSymbolColor: $badgeAppexSymbolColor,
                    badgeAppexEnclosureColor: $badgeAppexEnclosureColor
                )
            }
        }
        .formStyle(GroupedFormStyle())
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Badge Background (Custom mode)

    @ViewBuilder
    private var badgeBackgroundControls: some View {
        Form {
            Section("Source", isExpanded: $badgeBackgroundSourceExpanded) {
                BadgeBackgroundSourceSection(iconSettings: $iconSettings)
            }

            if iconSettings.badgeUseImportedBackground {
                Section("Layout", isExpanded: $badgeBackgroundLayoutExpanded) {
                    BadgeBackgroundLayoutSection(iconSettings: $iconSettings)
                }
            }

            Section("Appearance", isExpanded: $badgeBackgroundAppearanceExpanded) {
                BadgeBackgroundAppearanceSection(
                    iconSettings: $iconSettings,
                    colorOptions: colorOptions
                )
            }
        }
        .formStyle(GroupedFormStyle())
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}
