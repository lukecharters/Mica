// Views/Sidebar/LayerSidebar.swift
import SwiftUI

/// Left sidebar: two selectable groups (Icon, Badge), each with a tri-state
/// visibility toggle and its own generation-mode picker. Each group expands into
/// Foreground / Background child layers in Custom mode; in System mode the group
/// header is the only selectable target for that group.
struct LayerSidebar: View {
    @Binding var iconSettings: IconSettings
    @Binding var selection: LayerSelection
    let appexEnclosureColor: AppexEnclosureColor
    let appexSymbolColor: AppexEnclosureColor
    let badgeAppexEnclosureColor: AppexEnclosureColor
    let badgeAppexSymbolColor: AppexEnclosureColor

    /// Remembers the badge's previously-picked non-system source so toggling
    /// System → Custom restores the user's choice instead of forcing `.sfSymbol`.
    @State private var lastNonSystemBadgeSource: IconSource = .sfSymbol

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                groupSection(.icon)
                Divider().padding(.horizontal, 12)
                groupSection(.badge)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.windowBackgroundColor))
        .onChange(of: iconSettings.iconGenerationMode) { _, _ in
            migrateSelection(group: .icon)
        }
        .onChange(of: iconSettings.badgeIconSource) { oldValue, newValue in
            if newValue != .appleReference {
                lastNonSystemBadgeSource = newValue
            }
            migrateSelection(group: .badge)
        }
    }

    /// When a group switches into System mode, any selected child layer collapses
    /// to the group header (children are hidden in System mode).
    private func migrateSelection(group: IconLayerGroup) {
        guard case .layer(let g, _) = selection, g == group else { return }
        if isSystem(group) {
            selection = .group(group)
        }
    }

    @ViewBuilder
    private func groupSection(_ group: IconLayerGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GroupHeaderRow(
                group: group,
                isSelected: selection == .group(group),
                visibility: visibility(for: group),
                visibilityBinding: groupVisibilityBinding(for: group),
                modeBinding: modeBinding(for: group),
                onSelect: { selection = .group(group) }
            )
            .padding(.horizontal, 8)

            if !isSystem(group) {
                VStack(spacing: 2) {
                    ForEach(LayerRole.allCases) { role in
                        LayerRow(
                            group: group,
                            role: role,
                            iconSettings: $iconSettings,
                            appexEnclosureColor: appexEnclosureColor,
                            appexSymbolColor: appexSymbolColor,
                            badgeAppexEnclosureColor: badgeAppexEnclosureColor,
                            badgeAppexSymbolColor: badgeAppexSymbolColor,
                            isSelected: selection == .layer(group, role),
                            onSelect: { selection = .layer(group, role) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.leading, 14) // indent children under header
            }
        }
    }

    // MARK: - Per-group helpers

    private func isSystem(_ group: IconLayerGroup) -> Bool {
        switch group {
        case .icon:  return iconSettings.iconGenerationMode == .appleReference
        case .badge: return iconSettings.badgeGenerationMode == .appleReference
        }
    }

    private func visibility(for group: IconLayerGroup) -> LayerGroupVisibility {
        switch group {
        case .icon:  return iconSettings.iconVisibility()
        case .badge: return iconSettings.badgeVisibility()
        }
    }

    /// Group-eye toggle behavior: any state with at least one hidden flag still
    /// shown → "show all"; everything visible → "hide all".
    private func groupVisibilityBinding(for group: IconLayerGroup) -> Binding<Bool> {
        switch group {
        case .icon:
            return Binding(
                get: { iconSettings.iconVisibility() == .on },
                set: { iconSettings.iconHidden = !$0 }
            )
        case .badge:
            return Binding(
                get: { iconSettings.badgeVisibility() == .on },
                set: { iconSettings.badgeHidden = !$0 }
            )
        }
    }

    private func modeBinding(for group: IconLayerGroup) -> Binding<Bool> {
        switch group {
        case .icon:
            return Binding(
                get: { iconSettings.iconGenerationMode == .appleReference },
                set: { iconSettings.iconGenerationMode = $0 ? .appleReference : .swiftUI }
            )
        case .badge:
            return Binding(
                get: { iconSettings.badgeGenerationMode == .appleReference },
                set: { newValue in
                    if newValue {
                        if iconSettings.badgeIconSource != .appleReference {
                            lastNonSystemBadgeSource = iconSettings.badgeIconSource
                        }
                        iconSettings.badgeIconSource = .appleReference
                    } else {
                        iconSettings.badgeIconSource = lastNonSystemBadgeSource
                    }
                }
            )
        }
    }
}

// MARK: - Group header row

private struct GroupHeaderRow: View {
    let group: IconLayerGroup
    let isSelected: Bool
    let visibility: LayerGroupVisibility
    let visibilityBinding: Binding<Bool>
    let modeBinding: Binding<Bool>
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            GroupVisibilityToggle(visibility: visibility, binding: visibilityBinding, isSelected: isSelected)

            Text(group.label)
                .font(.headline)
                .foregroundStyle(isSelected ? Color.white : .primary)

            Spacer(minLength: 8)

            GroupModePicker(isSystem: modeBinding, isSelected: isSelected)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.1))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

/// Tri-state eye for a whole group. `.mixed` shows the outline `eye` and clicking
/// hides everything (consistent with the binding's setter).
private struct GroupVisibilityToggle: View {
    let visibility: LayerGroupVisibility
    let binding: Binding<Bool>
    let isSelected: Bool

    var body: some View {
        Button {
            binding.wrappedValue.toggle()
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tintColor)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var symbolName: String {
        switch visibility {
        case .on:    return "eye.fill"
        case .off:   return "eye.slash"
        case .mixed: return "eye"
        }
    }

    private var tintColor: Color {
        if isSelected {
            return visibility == .off ? .white.opacity(0.6) : .white
        } else {
            return visibility == .off ? .secondary : .primary
        }
    }

    private var helpText: String {
        switch visibility {
        case .on:    return "Hide layers"
        case .off:   return "Show layers"
        case .mixed: return "Hide layers (currently mixed)"
        }
    }
}

/// Compact two-state segmented control: Custom vs System for a single group.
private struct GroupModePicker: View {
    @Binding var isSystem: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 2) {
            segment(label: "Custom", systemImage: "slider.horizontal.3", active: !isSystem) {
                isSystem = false
            }
            segment(label: "System", systemImage: "command", active: isSystem) {
                isSystem = true
            }
        }
        .padding(2)
        .background(
            Capsule().fill(Color.primary.opacity(0.08))
        )
    }

    @ViewBuilder
    private func segment(label: String, systemImage: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .medium))
                Text(label)
                    .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(active ? Color.accentColor : Color.secondary.opacity(0.3))
            )
            .foregroundStyle(active ? Color.primary : (isSelected ? Color.white : .primary))
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

// MARK: - Child layer row

private struct LayerRow: View {
    let group: IconLayerGroup
    let role: LayerRole
    @Binding var iconSettings: IconSettings
    let appexEnclosureColor: AppexEnclosureColor
    let appexSymbolColor: AppexEnclosureColor
    let badgeAppexEnclosureColor: AppexEnclosureColor
    let badgeAppexSymbolColor: AppexEnclosureColor
    let isSelected: Bool
    let onSelect: () -> Void

    private var visibility: Binding<Bool> {
        switch (group, role) {
        case (.icon, .foreground):
            return Binding(
                get: { !iconSettings.iconForegroundHidden },
                set: { iconSettings.iconForegroundHidden = !$0 }
            )
        case (.icon, .background):
            return Binding(
                get: { !iconSettings.iconBackgroundHidden },
                set: { iconSettings.iconBackgroundHidden = !$0 }
            )
        case (.badge, .foreground):
            return Binding(
                get: { !iconSettings.badgeForegroundHidden },
                set: { iconSettings.badgeForegroundHidden = !$0 }
            )
        case (.badge, .background):
            return Binding(
                get: { !iconSettings.badgeBackgroundHidden },
                set: { iconSettings.badgeBackgroundHidden = !$0 }
            )
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            LayerThumbnail(
                group: group,
                role: role,
                settings: iconSettings,
                appexEnclosureColor: appexEnclosureColor,
                appexSymbolColor: appexSymbolColor,
                badgeAppexEnclosureColor: badgeAppexEnclosureColor,
                badgeAppexSymbolColor: badgeAppexSymbolColor
            )
            .frame(width: 36, height: 36)

            Text(role.label)
                .font(.body)
                .foregroundStyle(isSelected ? Color.white : .primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            LayerVisibilityToggle(isVisible: visibility, isSelected: isSelected)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.1))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

private struct LayerVisibilityToggle: View {
    @Binding var isVisible: Bool
    let isSelected: Bool

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            Image(systemName: isVisible ? "eye" : "eye.slash")
                .font(.system(size: 13))
                .foregroundStyle(tintColor)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isVisible ? "Hide layer" : "Show layer")
    }

    private var tintColor: Color {
        if isSelected {
            return isVisible ? .white : .white.opacity(0.6)
        } else {
            return isVisible ? .primary : .secondary
        }
    }
}

// MARK: - Mini thumbnail

private struct LayerThumbnail: View {
    let group: IconLayerGroup
    let role: LayerRole
    let settings: IconSettings
    let appexEnclosureColor: AppexEnclosureColor
    let appexSymbolColor: AppexEnclosureColor
    let badgeAppexEnclosureColor: AppexEnclosureColor
    let badgeAppexSymbolColor: AppexEnclosureColor

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(.controlBackgroundColor))
            .overlay {
                content.padding(3)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch (group, role) {
        case (.icon, .foreground):
            IconForegroundThumb(settings: settings)
        case (.icon, .background):
            IconBackgroundThumb(settings: settings)
        case (.badge, .foreground):
            BadgeForegroundThumb(settings: settings)
        case (.badge, .background):
            BadgeBackgroundThumb(settings: settings)
        }
    }
}

// MARK: - Sub-thumbs (mirror IconContentView/BadgeView rendering at small size)

private struct IconForegroundThumb: View {
    let settings: IconSettings

    var body: some View {
        switch settings.iconSource {
        case .customImage:
            if let nsImage = settings.importedImage?.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholder
            }
        case .sfSymbol, .appleReference:
            SymbolThumb(
                name: settings.symbolName,
                renderingMode: settings.symbolRenderingMode,
                symbolColor: settings.symbolColor,
                hierarchicalColor: settings.hierarchicalSymbolColor,
                paletteColors: (
                    settings.paletteSymbolPrimaryColor,
                    settings.paletteSymbolSecondaryColor,
                    settings.paletteSymbolTertiaryColor
                )
            )
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        Image(systemName: "photo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.tertiary)
    }
}

private struct IconBackgroundThumb: View {
    let settings: IconSettings

    var body: some View {
        switch settings.backgroundMode {
        case .preRendered:
            Image(settings.preRenderedAssetName)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

        case .custom:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(customBackgroundStyle)

        case .importedImage:
            if let nsImage = settings.importedBackground?.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
            }
        }
    }

    private var customBackgroundStyle: AnyShapeStyle {
        if settings.useCustomColors {
            return settings.enableBackgroundGradient
                ? AnyShapeStyle(LinearGradient(colors: settings.gradientColors, startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(settings.customPrimaryColor)
        }
        return settings.enableBackgroundGradient
            ? AnyShapeStyle(settings.baseColor.gradient)
            : AnyShapeStyle(settings.baseColor)
    }
}

private struct BadgeForegroundThumb: View {
    let settings: IconSettings

    var body: some View {
        switch settings.badgeIconSource {
        case .customImage:
            if let nsImage = settings.badgeImportedImage?.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.tertiary)
            }
        case .sfSymbol, .appleReference:
            SymbolThumb(
                name: settings.badgeSymbolName,
                renderingMode: settings.badgeSymbolRenderingMode,
                symbolColor: settings.badgeSymbolColor,
                hierarchicalColor: settings.badgeHierarchicalSymbolColor,
                paletteColors: (
                    settings.badgePaletteSymbolPrimaryColor,
                    settings.badgePaletteSymbolSecondaryColor,
                    settings.badgePaletteSymbolTertiaryColor
                )
            )
        }
    }
}

private struct BadgeBackgroundThumb: View {
    let settings: IconSettings

    var body: some View {
        if settings.badgeUseImportedBackground, let nsImage = settings.badgeImportedBackground?.nsImage {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            Circle()
                .fill(badgeBackgroundStyle)
        }
    }

    private var badgeBackgroundStyle: AnyShapeStyle {
        if settings.badgeUseCustomColors {
            return settings.badgeEnableBackgroundGradient
                ? AnyShapeStyle(LinearGradient(colors: settings.badgeGradientColors, startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(settings.badgeCustomPrimaryColor)
        }
        return settings.badgeEnableBackgroundGradient
            ? AnyShapeStyle(settings.badgeBaseColor.gradient)
            : AnyShapeStyle(settings.badgeBaseColor)
    }
}

private struct SymbolThumb: View {
    let name: String
    let renderingMode: SymbolRenderingMode
    let symbolColor: Color
    let hierarchicalColor: Color
    let paletteColors: (Color, Color, Color)

    var body: some View {
        let image = Image(systemName: name)
            .resizable()
            .aspectRatio(contentMode: .fit)

        switch renderingMode {
        case .monochrome, .multicolor:
            image
                .symbolRenderingMode(renderingMode.symbolRenderingMode)
                .foregroundStyle(symbolColor)
        case .hierarchical:
            image
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(hierarchicalColor)
        case .palette:
            image
                .symbolRenderingMode(.palette)
                .foregroundStyle(paletteColors.0, paletteColors.1, paletteColors.2)
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    @Previewable @State var selection: LayerSelection = .layer(.icon, .foreground)
    LayerSidebar(
        iconSettings: $settings,
        selection: $selection,
        appexEnclosureColor: .blue,
        appexSymbolColor: .white,
        badgeAppexEnclosureColor: .blue,
        badgeAppexSymbolColor: .white
    )
    .frame(width: 280, height: 500)
}
