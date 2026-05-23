// Views/Sidebar/SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @Binding var iconSettings: IconSettings
    @Binding var generationMode: GenerationMode
    @Binding var appexEnclosureColor: AppexEnclosureColor
    @Binding var appexSymbolColor: AppexEnclosureColor
    @Binding var badgeAppexEnclosureColor: AppexEnclosureColor
    @Binding var badgeAppexSymbolColor: AppexEnclosureColor
    let colorOptions: [(name: String, color: Color)]

    @State private var selectedSegment: IconOrBadge = .icon
    @State private var lastNonSystemBadgeSource: IconSource = .sfSymbol

    // Persisted section expand/collapse state (reused keys from prior sidebar redesign)
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

    private var isAppleReference: Bool {
        generationMode == .appleReference
    }

    private var modePickerBinding: Binding<Bool> {
        Binding(
            get: {
                switch selectedSegment {
                case .icon: generationMode == .appleReference
                case .badge: iconSettings.badgeIconSource == .appleReference
                }
            },
            set: { newValue in
                switch selectedSegment {
                case .icon:
                    generationMode = newValue ? .appleReference : .swiftUI
                case .badge:
                    if newValue {
                        if iconSettings.badgeIconSource != .appleReference {
                            lastNonSystemBadgeSource = iconSettings.badgeIconSource
                        }
                        iconSettings.badgeIconSource = .appleReference
                    } else {
                        iconSettings.badgeIconSource = lastNonSystemBadgeSource
                    }
                }
            }
        )
    }

    var body: some View {
        VStack() {
            IconBadgePicker(selection: $selectedSegment)
            IconModePicker(isSystem: modePickerBinding)


            Divider()
//                .padding(.horizontal, 20)
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
        groupHeader("Foreground")
        Form {
            Section("Source", isExpanded: $iconSourceExpanded) {
                IconSourceSection(
                    iconSettings: $iconSettings,
                    isSystem: isAppleReference
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
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)

        if !isAppleReference {
            Divider()
                .padding(.horizontal, 20)
                .padding(.top, 4)

            groupHeader("Background")
            Form {
                Section("Source", isExpanded: $backgroundSourceExpanded) {
                    BackgroundSourceSection(iconSettings: $iconSettings)
                }

                if iconSettings.backgroundMode == .importedImage{
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
    }

    // MARK: - Badge content (Show Badge toggle + Symbol form + Background form stacked)

    //TODO: Move badge toggle above scroll view
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
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)

        groupHeader("Foreground")
        Form {
            Section("Source", isExpanded: $badgeSourceExpanded) {
                BadgeSourceSection(
                    iconSettings: $iconSettings,
                    isSystem: iconSettings.badgeIconSource == .appleReference
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

        if iconSettings.badgeIconSource != .appleReference {
            Divider()
                .padding(.horizontal, 20)
                .padding(.top, 4)

            groupHeader("Background")
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

    // MARK: - Shared

    private func groupHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    @Previewable @State var mode: GenerationMode = .swiftUI
    @Previewable @State var enclosureColor: AppexEnclosureColor = .blue
    @Previewable @State var symbolColor: AppexEnclosureColor = .white
    @Previewable @State var badgeEnclosureColor: AppexEnclosureColor = .blue
    @Previewable @State var badgeSymbolColor: AppexEnclosureColor = .white
    SidebarView(
        iconSettings: $settings,
        generationMode: $mode,
        appexEnclosureColor: $enclosureColor,
        appexSymbolColor: $symbolColor,
        badgeAppexEnclosureColor: $badgeEnclosureColor,
        badgeAppexSymbolColor: $badgeSymbolColor,
        colorOptions: OptionsCatalog.colorOptions
    )
    .frame(width: 420, height: 700)
}
