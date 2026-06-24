// Views/Sidebar/LayerControls.swift
import SwiftUI

/// Renders the Source / Layout / Appearance controls for whichever layer (or group)
/// is selected in the left LayerSidebar.
struct LayerControls: View {
    let selection: LayerSelection
    @Binding var iconSettings: IconSettings
    @Binding var appexEnclosureColor: AppexColor
    @Binding var appexSymbolColor: AppexColor
    @Binding var badgeAppexEnclosureColor: AppexColor
    @Binding var badgeAppexSymbolColor: AppexColor
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
                    if !isBadgeAppleReference {
                        // Custom mode: surface the Foreground + Background children
                        // inline beneath the group-level layout controls.
                        layerSectionHeader(LayerRole.foreground.label)
                        badgeForegroundControls
                        layerSectionHeader(LayerRole.background.label)
                        badgeBackgroundControls
                    }
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

    /// Drives the icon group's Custom/System picker.
    private var iconModeBinding: Binding<Bool> {
        Binding(
            get: { iconSettings.iconGenerationMode == .appleReference },
            set: { iconSettings.iconGenerationMode = $0 ? .appleReference : .swiftUI }
        )
    }

    // MARK: - Icon group (header selected)

    @ViewBuilder
    private var iconGroupControls: some View {
        // In System mode the group is the only selectable target for the icon, so
        // expose the appex Source + Appearance directly. In Custom mode, prompt
        // the user to pick a child layer.
        VStack(alignment: .leading, spacing: 0) {
            GroupModePicker(isSystem: iconModeBinding)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

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
                // Custom mode: the group has Foreground + Background children. Show
                // both children's controls inline so the group header is a combined
                // editor in addition to being individually selectable in the sidebar.
                layerSectionHeader(LayerRole.foreground.label)
                iconForegroundControls
                layerSectionHeader(LayerRole.background.label)
                iconBackgroundControls
            }
        }
    }

    /// Header delineating a child layer's controls when both are shown together
    /// under a selected group header.
    @ViewBuilder
    private func layerSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 2)
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
