// Views/Inspector/InspectorControls.swift
import SwiftUI

/// Renders the controls for whatever the left `LayerSidebar` has selected: the
/// group's Mica/System picker, then one of three panes — the Source / Layout /
/// Appearance sections for the layer row the sidebar is on (Mica mode with
/// advanced controls on), a single un-tabbed pane of the handful of controls that
/// matter (Mica mode with advanced controls off), or System mode's single pane.
/// See `groupPane(mode:tab:isSystem:…)`.
///
/// **This panel chooses none of that.** The group and the per-group layer arrive
/// as plain values from `ContentView`; the sidebar and the canvas are what write
/// them. There was a `LayerTabPicker` segmented bar here between 2026-07-25 and
/// 2026-08-16, which is why `iconTab`/`badgeTab` used to be bindings.
///
/// `InspectorPreferences` holds the advanced-controls key.
struct InspectorControls: View {
    let group: IconLayerGroup
    /// Active layer per group, owned by ContentView so the sidebar's child rows and
    /// a canvas click drive one value. Read-only here — see the note above.
    let iconTab: LayerTab
    let badgeTab: LayerTab
    /// Each group's generation mode, driving `GroupModePicker` at the top of the
    /// pane. Owned by `ContentView`, not derived from `iconSettings` here: the
    /// badge's mode is *derived* from its foreground source, so switching it away
    /// destroys the value it must restore, and `BadgeModeMemory` — the thing that
    /// remembers it — has to be fed by the settings observer and outlive this view.
    @Binding var iconIsSystem: Bool
    @Binding var badgeIsSystem: Bool
    @Binding var iconSettings: IconSettings
    @Binding var appexEnclosureColor: AppexColor
    @Binding var appexSymbolColor: AppexColor
    @Binding var badgeAppexEnclosureColor: AppexColor
    @Binding var badgeAppexSymbolColor: AppexColor

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

    /// No advanced-controls switch down here — it moved to Settings ▸ General on
    /// 2026-08-04 (item B2 of the Mac-conventions plan), on the grounds that a
    /// preference does not belong inside the panel it reconfigures. The flag is
    /// still read all over this file; only its control left, and it stayed gone.
    ///
    /// The **Mica/System picker is a different question and came back** on
    /// 2026-08-16: the generation mode is a property of the icon rather than a
    /// preference about the inspector, so it belongs beside the controls it
    /// reshapes. Its state does not come back with it — `iconIsSystem` /
    /// `badgeIsSystem` are bindings from `ContentView`, which owns
    /// `BadgeModeMemory`. That is the half of the 2026-08-04 move worth keeping.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Outside the ScrollView on purpose — see `InspectorGroupHeader`.
            InspectorGroupHeader(group: group, sublayer: headerSublayer)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            controlsScrollView
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
            revealAdvancedControlsIfNeeded()
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

    /// The layer currently driving the selected group's pane. Meaningless in System
    /// mode (no layer rows), but still fine to read — it just doesn't change there.
    private var activeTab: LayerTab {
        group == .icon ? iconTab : badgeTab
    }

    /// The layer named beside the group in the header: the active tab whenever the
    /// sidebar would show a row for it, otherwise nothing.
    private var headerSublayer: LayerTab? {
        InspectorGroupHeader.sublayer(
            for: activeTab,
            in: group,
            isSystem: group == .icon ? isIconAppleReference : isBadgeAppleReference,
            advancedControlsEnabled: advancedControlsEnabled
        )
    }

    private var isIconAppleReference: Bool {
        iconSettings.icon.mode == .system
    }

    private var isBadgeAppleReference: Bool {
        iconSettings.badge.mode == .system
    }

    // MARK: - Group panes

    /// Icon: mode picker, then either the single System pane or the tabbed
    /// Foreground / Background panes.
    @ViewBuilder
    private var iconGroupControls: some View {
        groupPane(mode: $iconIsSystem, tab: iconTab, isSystem: isIconAppleReference) {
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
        groupPane(mode: $badgeIsSystem, tab: badgeTab, isSystem: isBadgeAppleReference) {
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
    /// panes. `tab` selects the third one's content and is ignored by the other two
    /// — System mode has no separately editable layers, and the simple pane edits a
    /// group as one thing.
    ///
    /// The picker shows in all three, because the mode is what *chooses* between
    /// them. Nothing else here carries top padding: `InspectorGroupHeader` sits above
    /// this whole stack and its bottom padding is the gap the picker needs; the
    /// picker's own bottom padding is the gap for everything under it. That last
    /// clause is now true of all three panes — the layer tab bar used to sit between
    /// the picker and `tabContent` and supply its own 16pt.
    @ViewBuilder
    private func groupPane<SystemPane: View, SimplePane: View, TabPane: View>(
        mode: Binding<Bool>,
        tab: LayerTab,
        isSystem: Bool,
        @ViewBuilder systemContent: () -> SystemPane,
        @ViewBuilder simpleContent: () -> SimplePane,
        @ViewBuilder tabContent: (LayerTab) -> TabPane
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupModePicker(isSystem: mode)
                .padding(.horizontal, 10)

            if isSystem {
                systemContent()
            } else if !advancedControlsEnabled {
                simpleContent()
            } else {
                tabContent(tab)
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
                        group: .icon,
                        isVisible: groupVisibleBinding(for: .icon),
                        symbolName: $iconSettings.icon.foreground.symbolName
                    )
                    .padding(4)
                }
            }

            sectionForm {
                Section("Appearance", isExpanded: $iconAppearanceExpanded) {
                    SimpleAppearanceSection(
                        symbolColor: $iconSettings.icon.foreground.color,
                        symbolShadow: $iconSettings.icon.foreground.drawsShadow,
                        backgroundColor: $iconSettings.icon.background.color,
                        backgroundShadow: backgroundShadowEnabled
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
                        group: .badge,
                        isVisible: groupVisibleBinding(for: .badge),
                        symbolName: $iconSettings.badge.foreground.symbolName,
                        symbolHelp: "Enter an SF Symbol name for the badge (e.g., 1.circle.fill, plus, checkmark)"
                    )
                    .padding(4)
                }
            }

            sectionForm {
                Section("Appearance", isExpanded: $badgeAppearanceExpanded) {
                    SimpleAppearanceSection(
                        symbolColor: $iconSettings.badge.foreground.color,
                        symbolShadow: $iconSettings.badge.foreground.drawsShadow,
                        backgroundColor: $iconSettings.badge.background.color,
                        backgroundShadow: $iconSettings.badge.background.drawsShadow
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
            get: { iconSettings.icon.background.shadowStyle != .off },
            set: { iconSettings.icon.background.shadowStyle = $0 ? .macOS26 : .off }
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

            if iconSettings.icon.background.source == .image {
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
                        iconSettings: $iconSettings
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

            if iconSettings.badge.background.source == .image {
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
                        iconSettings: $iconSettings
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
    /// Plain values here, unlike the bindings above them: the panel only reads the
    /// active layer now — the sidebar's child rows write it. Change these to see
    /// another layer's pane.
    var iconTab: LayerTab = .foreground
    var badgeTab: LayerTab = .layout
    @State private var enclosure: AppexColor = .blue
    @State private var symbol: AppexColor = .white
    @State private var badgeEnclosure: AppexColor = .blue
    @State private var badgeSymbol: AppexColor = .white
    /// Stand-ins for `ContentView`'s bindings. The badge's is a plain `@State` here
    /// rather than a `BadgeModeMemory`, so flicking it in a preview forgets the
    /// previous source — that memory is the window's, not the panel's.
    @State private var iconIsSystem = false
    @State private var badgeIsSystem = false

    var body: some View {
        InspectorControls(
            group: group,
            iconTab: iconTab,
            badgeTab: badgeTab,
            iconIsSystem: $iconIsSystem,
            badgeIsSystem: $badgeIsSystem,
            iconSettings: $settings,
            appexEnclosureColor: $enclosure,
            appexSymbolColor: $symbol,
            badgeAppexEnclosureColor: $badgeEnclosure,
            badgeAppexSymbolColor: $badgeSymbol
        )
        .frame(width: 380, height: 700)
        .onAppear {
            settings.badge.isVisible = true
            // Both halves: the pane branches on the settings, the picker on the
            // binding. In the app those are two views of one value; here they have
            // to be set in step or the preview shows a Mica picker over a System pane.
            switch group {
            case .icon:
                settings.icon.mode = isSystem ? .system : .mica
                iconIsSystem = isSystem
            case .badge:
                settings.badge.foreground.source = isSystem ? .system : .symbol
                badgeIsSystem = isSystem
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
