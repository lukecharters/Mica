// Views/Inspector/InspectorControls.swift
import SwiftUI

/// Renders the controls for whichever group is selected in the left LayerSidebar:
/// the group's Mica/System picker, then one of three panes — the tabbed
/// Source / Layout / Appearance sections for the active `LayerTabPicker` tab
/// (Mica mode with advanced controls on), a single un-tabbed pane of the handful
/// of controls that matter (Mica mode with advanced controls off), or System
/// mode's single pane. See `groupPane(mode:tab:isSystem:…)`.
///
/// `InspectorPreferences` (in Models) holds the advanced-controls key.
struct InspectorControls: View {
    let group: IconLayerGroup
    /// Active tab per group, owned by ContentView so a canvas click can drive it.
    @Binding var iconTab: LayerTab
    @Binding var badgeTab: LayerTab
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
    /// Moved here from the dissolved BadgeGroupInspector; key kept so existing
    /// user state carries over.
    @AppStorage("sidebar.badgeGroupLayout.expanded") private var badgeGroupLayoutExpanded = true
    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    /// Remembers the badge's previously-picked non-system source so toggling
    /// System → Mica restores the user's choice instead of forcing `.symbol`.
    /// Owned here because `InspectorControls` stays mounted across every group and
    /// tab change, so the tracked value never goes stale.
    @State private var lastNonSystemBadgeSource: ForegroundSource = .symbol

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
                switch group {
                case .icon:
                    iconGroupControls
                case .badge:
                    badgeGroupControls
                }
            }
            // Reset scroll position when the user moves to another group or tab,
            // so a long pane doesn't leave the next one scrolled halfway down.
            // The simple pane has no tabs, so it keys on the group alone —
            // otherwise a canvas click, which still moves the hidden tab, would
            // scroll the pane back to the top for no visible reason.
            .id("\(group.rawValue).\(advancedControlsEnabled ? activeTab.rawValue : "simple")")
        }
        .onAppear {
            if iconSettings.badgeIconSource != .system {
                lastNonSystemBadgeSource = iconSettings.badgeIconSource
            }
            revealAdvancedControlsIfNeeded()
        }
        .onChange(of: iconSettings.badgeIconSource) { _, newValue in
            if newValue != .system {
                lastNonSystemBadgeSource = newValue
            }
        }
        .onChange(of: advancedControlsEnabled) { _, isOn in
            // The simple pane has one row per setting, so anything needing extra
            // rows — an imported source, palette rendering, a custom gradient —
            // is folded away on the way in. Non-destructive: the artwork and
            // colours stay in the model, so switching back and re-picking a
            // source restores the previous look.
            if !isOn { iconSettings.resetToSimpleControls() }
        }
        .onChange(of: iconSettings.usesImportedSources) { _, _ in
            revealAdvancedControlsIfNeeded()
        }
    }

    /// An image can be imported from the File and Edit menus or by dropping one on
    /// the canvas, all of which work while the simple pane is showing. The simple
    /// pane has no controls for an imported layer, so reveal the ones that do
    /// rather than leave a pane that contradicts the preview.
    ///
    /// Also checked `onAppear`, which covers an import that landed while the
    /// inspector was closed. Cannot loop with the fold above: that only runs on
    /// the advanced → simple transition, and it clears every imported source.
    private func revealAdvancedControlsIfNeeded() {
        if !advancedControlsEnabled, iconSettings.usesImportedSources {
            advancedControlsEnabled = true
        }
    }

    /// The tab currently driving the selected group's pane. Meaningless in System
    /// mode (no tabs), but still fine to read — it just doesn't change there.
    private var activeTab: LayerTab {
        group == .icon ? iconTab : badgeTab
    }

    private var isIconAppleReference: Bool {
        iconSettings.iconGenerationMode == .system
    }

    private var isBadgeAppleReference: Bool {
        iconSettings.badgeGenerationMode == .system
    }

    /// Drives the icon group's Mica/System picker.
    private var iconModeBinding: Binding<Bool> {
        Binding(
            get: { iconSettings.iconGenerationMode == .system },
            set: { iconSettings.iconGenerationMode = $0 ? .system : .mica }
        )
    }

    /// Drives the badge group's Mica/System picker. The badge's mode is derived
    /// from its `badgeIconSource` (`.system` == System), so toggling swaps
    /// the source and restores the prior Mica choice on the way back.
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

    // MARK: - Group panes

    /// Icon: mode picker, then either the single System pane or the tabbed
    /// Foreground / Background panes.
    @ViewBuilder
    private var iconGroupControls: some View {
        groupPane(mode: iconModeBinding, tab: $iconTab, isSystem: isIconAppleReference) {
            // System mode renders the whole icon as one appex image, so only its
            // source symbol and colours are editable.
            VStack(spacing: Self.sectionSpacing) {
                sectionForm {
                    Section("Source", isExpanded: $iconSourceExpanded) {
                        IconForegroundSourceSection(
                            iconSettings: $iconSettings,
                            isSystem: true
                        )
                        .padding(4)
                    }
                }

                sectionForm {
                    Section("Appearance", isExpanded: $iconAppearanceExpanded) {
                        IconForegroundAppearanceSection(
                            iconSettings: $iconSettings,
                            colorOptions: colorOptions,
                            isAppleReference: true,
                            appexSymbolColor: $appexSymbolColor,
                            appexEnclosureColor: $appexEnclosureColor
                        )
                        .padding(4)
                    }
                }
            }
        } simpleContent: {
            iconSimpleControls
        } tabContent: { tab in
            switch tab {
            case .foreground, .layout: iconForegroundControls // .layout is badge-only
            case .background:          iconBackgroundControls
            }
        }
    }

    /// Badge: mode picker, then either the single System pane (which keeps the
    /// group-level layout controls, since position and size are applied when the
    /// appex badge is composited) or the tabbed Layout / Foreground / Background
    /// panes.
    @ViewBuilder
    private var badgeGroupControls: some View {
        groupPane(mode: badgeModeBinding, tab: $badgeTab, isSystem: isBadgeAppleReference) {
            VStack(spacing: Self.sectionSpacing) {
                sectionForm {
                    Section("Source", isExpanded: $badgeSourceExpanded) {
                        BadgeForegroundSourceSection(
                            iconSettings: $iconSettings,
                            isSystem: true
                        )
                        .padding(4)
                    }
                }

                sectionForm {
                    Section("Appearance", isExpanded: $badgeAppearanceExpanded) {
                        BadgeForegroundAppearanceSection(
                            iconSettings: $iconSettings,
                            colorOptions: colorOptions,
                            badgeAppexSymbolColor: $badgeAppexSymbolColor,
                            badgeAppexEnclosureColor: $badgeAppexEnclosureColor
                        )
                        .padding(4)
                    }
                }

                badgeLayoutSectionForm
            }
        } simpleContent: {
            badgeSimpleControls
        } tabContent: { tab in
            switch tab {
            case .layout:     badgeLayoutControls
            case .foreground: badgeForegroundControls
            case .background: badgeBackgroundControls
            }
        }
    }

    /// Shared frame for both groups: the Mica/System picker, then one of the three
    /// panes. The layer tab bar belongs to Mica mode with advanced controls on —
    /// System mode has no separately editable layers, and the simple pane
    /// deliberately mirrors System's un-tabbed shape.
    @ViewBuilder
    private func groupPane<SystemPane: View, SimplePane: View, TabPane: View>(
        mode: Binding<Bool>,
        tab: Binding<LayerTab>,
        isSystem: Bool,
        @ViewBuilder systemContent: () -> SystemPane,
        @ViewBuilder simpleContent: () -> SimplePane,
        @ViewBuilder tabContent: (LayerTab) -> TabPane
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupModePicker(isSystem: mode)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if isSystem {
                systemContent()
            } else if !advancedControlsEnabled {
                simpleContent()
            } else {
                LayerTabPicker(group: group, selection: tab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                tabContent(tab.wrappedValue)
            }
        }
    }

    // MARK: - Simple panes (Mica mode, advanced controls off)

    /// Icon, un-tabbed: the symbol, the two colours, and the two shadows. Reuses
    /// the tabbed panes' expand/collapse keys so a collapsed Source stays
    /// collapsed across the advanced toggle.
    @ViewBuilder
    private var iconSimpleControls: some View {
        VStack(spacing: Self.sectionSpacing) {
            sectionForm {
                Section("Source", isExpanded: $iconSourceExpanded) {
                    SimpleSourceSection(
                        isVisible: groupVisibleBinding(for: .icon),
                        symbolName: $iconSettings.symbolName
                    )
                    .padding(4)
                }
            }

            sectionForm {
                Section("Appearance", isExpanded: $iconAppearanceExpanded) {
                    SimpleAppearanceSection(
                        symbolColor: $iconSettings.symbolColor,
                        symbolShadow: $iconSettings.enableSymbolShadow,
                        backgroundColor: $iconSettings.baseColor,
                        backgroundShadow: backgroundShadowEnabled,
                        colorOptions: colorOptions
                    )
                    .padding(4)
                }
            }
        }
        .padding(.bottom, 20)
    }

    /// Badge, un-tabbed: the same rows as the icon, plus the group-level layout
    /// controls — matching the System badge pane, which keeps them for the same
    /// reason (position and size apply however the badge itself is drawn).
    @ViewBuilder
    private var badgeSimpleControls: some View {
        VStack(spacing: Self.sectionSpacing) {
            sectionForm {
                Section("Source", isExpanded: $badgeSourceExpanded) {
                    SimpleSourceSection(
                        isVisible: groupVisibleBinding(for: .badge),
                        symbolName: $iconSettings.badgeSymbolName,
                        symbolHelp: "Enter an SF Symbol name for the badge (e.g., 1.circle.fill, plus, checkmark)"
                    )
                    .padding(4)
                }
            }

            sectionForm {
                Section("Appearance", isExpanded: $badgeAppearanceExpanded) {
                    SimpleAppearanceSection(
                        symbolColor: $iconSettings.badgeSymbolColor,
                        symbolShadow: $iconSettings.badgeEnableSymbolShadow,
                        backgroundColor: $iconSettings.badgeBaseColor,
                        backgroundShadow: $iconSettings.badgeEnableBackgroundShadow,
                        colorOptions: colorOptions
                    )
                    .padding(4)
                }
            }

            badgeLayoutSectionForm
        }
        .padding(.bottom, 20)
    }

    /// One Visible toggle for a whole group. Reads as off unless *every* layer is
    /// visible, so a per-layer flag set in advanced mode can be cleared here.
    private func groupVisibleBinding(for group: IconLayerGroup) -> Binding<Bool> {
        Binding(
            get: { iconSettings.isGroupFullyVisible(group) },
            set: { iconSettings.setGroupVisible($0, for: group) }
        )
    }

    /// The icon's background shadow as a plain on/off, mapping "on" to the modern
    /// macOS 26 style — the same mapping `IconBackgroundAppearanceSection` uses when
    /// the advanced style picker is hidden.
    private var backgroundShadowEnabled: Binding<Bool> {
        Binding(
            get: { iconSettings.backgroundShadowStyle != .off },
            set: { iconSettings.backgroundShadowStyle = $0 ? .macOS26 : .off }
        )
    }

    // MARK: - Badge Layout (Mica mode)

    @ViewBuilder
    private var badgeLayoutControls: some View {
        VStack(spacing: Self.sectionSpacing) {
            badgeLayoutSectionForm
        }
        .padding(.bottom, 20)
    }

    /// Badge-wide position / offset / size. Shared by the Mica-mode Layout tab and
    /// the System-mode pane.
    @ViewBuilder
    private var badgeLayoutSectionForm: some View {
        sectionForm {
            Section("Badge Layout", isExpanded: $badgeGroupLayoutExpanded) {
                BadgeGroupLayoutSection(iconSettings: $iconSettings)
                    .padding(4)
            }
        }
    }

    // MARK: - Icon Foreground (Mica mode)

    @ViewBuilder
    private var iconForegroundControls: some View {
        VStack(spacing: Self.sectionSpacing) {
            sectionForm {
                Section("Source", isExpanded: $iconSourceExpanded) {
                    IconForegroundSourceSection(
                        iconSettings: $iconSettings,
                        isSystem: false
                    )
                    .padding(4)
                }
            }
            sectionForm {
                Section("Layout", isExpanded: $iconLayoutExpanded) {
                    IconForegroundLayoutSection(iconSettings: $iconSettings)
                    .padding(4)
                }
            }
            sectionForm {
                Section("Appearance", isExpanded: $iconAppearanceExpanded) {
                    IconForegroundAppearanceSection(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions,
                        isAppleReference: false,
                        appexSymbolColor: $appexSymbolColor,
                        appexEnclosureColor: $appexEnclosureColor
                    )
                    .padding(4)
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Icon Background (Mica mode)

    @ViewBuilder
    private var iconBackgroundControls: some View {
        VStack(spacing: Self.sectionSpacing) {
            sectionForm {
                Section("Source", isExpanded: $backgroundSourceExpanded) {
                    IconBackgroundSourceSection(iconSettings: $iconSettings)
                        .padding(4)
                }
            }

            if iconSettings.backgroundMode == .image {
                sectionForm {
                    Section("Layout", isExpanded: $backgroundLayoutExpanded) {
                        IconBackgroundLayoutSection(iconSettings: $iconSettings)
                        .padding(4)
                    }
                }
            }

            sectionForm {
                Section("Appearance", isExpanded: $backgroundAppearanceExpanded) {
                    IconBackgroundAppearanceSection(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions
                    )
                    .padding(4)
                }
            }
        }
    }

    // MARK: - Badge Foreground (Mica mode)

    @ViewBuilder
    private var badgeForegroundControls: some View {
        VStack(spacing: Self.sectionSpacing) {
            sectionForm {
                Section("Source", isExpanded: $badgeSourceExpanded) {
                    BadgeForegroundSourceSection(
                        iconSettings: $iconSettings,
                        isSystem: false
                    )
                    .padding(4)
                }
            }
            sectionForm {
                Section("Layout", isExpanded: $badgeLayoutExpanded) {
                    BadgeForegroundLayoutSection(iconSettings: $iconSettings)
                        .padding(4)
                }
            }
            sectionForm {
                Section("Appearance", isExpanded: $badgeAppearanceExpanded) {
                    BadgeForegroundAppearanceSection(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions,
                        badgeAppexSymbolColor: $badgeAppexSymbolColor,
                        badgeAppexEnclosureColor: $badgeAppexEnclosureColor
                    )
                    .padding(4)
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Badge Background (Mica mode)

    @ViewBuilder
    private var badgeBackgroundControls: some View {
        VStack(spacing: Self.sectionSpacing) {
            sectionForm {
                Section("Source", isExpanded: $badgeBackgroundSourceExpanded) {
                    BadgeBackgroundSourceSection(iconSettings: $iconSettings)
                        .padding(4)
                }
            }

            if iconSettings.badgeUseImportedBackground {
                sectionForm {
                    Section("Layout", isExpanded: $badgeBackgroundLayoutExpanded) {
                        BadgeBackgroundLayoutSection(iconSettings: $iconSettings)
                            .padding(4)
                    }
                }
            }

            sectionForm {
                Section("Appearance", isExpanded: $badgeBackgroundAppearanceExpanded) {
                    BadgeBackgroundAppearanceSection(
                        iconSettings: $iconSettings,
                        colorOptions: colorOptions
                    )
                    .padding(4)
                }
            }
        }
    }

    // MARK: - Section layout helpers

    /// Vertical gap between the per-section grouped forms. macOS gives no API to
    /// space `Section`s inside a single grouped `Form`, so each section is its own
    /// single-section grouped form and this drives the gap between them.
    private static let sectionSpacing: CGFloat = 20

    /// Wraps a single `Section` in its own grouped, non-scrolling form so a
    /// surrounding `VStack(spacing:)` controls the inter-section spacing.
    @ViewBuilder
    private func sectionForm<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        Form { content() }
            .formStyle(GroupedFormStyle())
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Previews

/// Host that supplies the bindings `InspectorControls` needs, so each preview
/// below is a one-liner.
///
/// The Mica-mode previews open on whichever pane the advanced-controls
/// preference is currently set to — flick the switch at the bottom of the preview
/// itself to see the other one. It isn't injected here on purpose: the only store
/// `@AppStorage` reads is the app's own defaults, so a preview that set it would
/// silently change the real app's setting.
private struct InspectorControlsPreview: View {
    let group: IconLayerGroup
    var isSystem: Bool = false
    @State private var settings = IconSettings()
    @State private var iconTab: LayerTab = .foreground
    @State private var badgeTab: LayerTab = .layout
    @State private var enclosure: AppexColor = .blue
    @State private var symbol: AppexColor = .white
    @State private var badgeEnclosure: AppexColor = .blue
    @State private var badgeSymbol: AppexColor = .white

    var body: some View {
        InspectorControls(
            group: group,
            iconTab: $iconTab,
            badgeTab: $badgeTab,
            iconSettings: $settings,
            appexEnclosureColor: $enclosure,
            appexSymbolColor: $symbol,
            badgeAppexEnclosureColor: $badgeEnclosure,
            badgeAppexSymbolColor: $badgeSymbol,
            colorOptions: OptionsCatalog.colorOptions
        )
        .frame(width: 380, height: 700)
        .onAppear {
            settings.showBadge = true
            switch group {
            case .icon:  settings.iconGenerationMode = isSystem ? .system : .mica
            case .badge: settings.badgeIconSource = isSystem ? .system : .symbol
            }
        }
    }
}

#Preview("Icon") {
    InspectorControlsPreview(group: .icon)
}

#Preview("Icon — System") {
    InspectorControlsPreview(group: .icon, isSystem: true)
}

#Preview("Badge") {
    InspectorControlsPreview(group: .badge)
}

#Preview("Badge — System") {
    InspectorControlsPreview(group: .badge, isSystem: true)
}
