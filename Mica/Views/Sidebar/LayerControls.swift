// Views/Sidebar/LayerControls.swift
import SwiftUI

/// Shared UserDefaults keys for sidebar-wide preferences read by multiple
/// section views via `@AppStorage`.
enum SidebarSettings {
    static let advancedControlsKey = "sidebar.advancedControls"
}

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
    @AppStorage(SidebarSettings.advancedControlsKey) private var advancedControlsEnabled = false

    /// Remembers the badge's previously-picked non-system source so toggling
    /// System → Custom restores the user's choice instead of forcing `.sfSymbol`.
    /// Owned here (rather than in `BadgeGroupInspector`) because `LayerControls`
    /// stays mounted across every layer selection, so the tracked value never goes
    /// stale when the user toggles the mode from a child-layer inspector.
    @State private var lastNonSystemBadgeSource: IconSource = .sfSymbol

    var body: some View {
        VStack(spacing: 0) {
            controlsScrollView
            Divider()
            HStack {
                Text("Show Advanced Controls")
                    .font(.subheadline)
                Spacer()
                Toggle("Show Advanced Controls", isOn: $advancedControlsEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private var controlsScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selection {
                case .group(.icon):
                    iconGroupControls
                case .group(.badge):
                    BadgeGroupInspector(
                        iconSettings: $iconSettings,
                        badgeMode: badgeModeBinding,
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
                    layerWithModePicker(iconModeBinding) { iconForegroundControls }
                case .layer(.icon, .background):
                    layerWithModePicker(iconModeBinding) { iconBackgroundControls }
                case .layer(.badge, .foreground):
                    layerWithModePicker(badgeModeBinding) { badgeForegroundControls }
                case .layer(.badge, .background):
                    layerWithModePicker(badgeModeBinding) { badgeBackgroundControls }
                }
            }
            .id(selection)
        }
        .onAppear {
            if iconSettings.badgeIconSource != .system {
                lastNonSystemBadgeSource = iconSettings.badgeIconSource
            }
        }
        .onChange(of: iconSettings.badgeIconSource) { _, newValue in
            if newValue != .system {
                lastNonSystemBadgeSource = newValue
            }
        }
    }

    /// Wraps a child layer's controls with the parent group's Custom/System picker
    /// at the top, so the generation mode can be switched without first navigating
    /// back to the group header.
    @ViewBuilder
    private func layerWithModePicker<Content: View>(
        _ mode: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupModePicker(isSystem: mode)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            content()
        }
    }

    private var isIconAppleReference: Bool {
        iconSettings.iconGenerationMode == .system
    }

    private var isBadgeAppleReference: Bool {
        iconSettings.badgeGenerationMode == .system
    }

    /// Drives the icon group's Custom/System picker.
    private var iconModeBinding: Binding<Bool> {
        Binding(
            get: { iconSettings.iconGenerationMode == .system },
            set: { iconSettings.iconGenerationMode = $0 ? .system : .mica }
        )
    }

    /// Drives the badge group's Custom/System picker. The badge's mode is derived
    /// from its `badgeIconSource` (`.system` == System), so toggling swaps
    /// the source and restores the prior custom choice on the way back.
    private var badgeModeBinding: Binding<Bool> {
        Binding(
            get: { iconSettings.badgeGenerationMode == .system },
            set: { newValue in
                if newValue {
                    if iconSettings.badgeIconSource != .system {
                        lastNonSystemBadgeSource = iconSettings.badgeIconSource
                    }
                    iconSettings.badgeIconSource = .system
                } else {
                    iconSettings.badgeIconSource = lastNonSystemBadgeSource
                }
            }
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
