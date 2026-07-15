// Views/Sidebar/LayerSidebar.swift
import SwiftUI

/// Left sidebar: two selectable groups (Icon, Badge), each with a tri-state
/// visibility toggle. Each group expands into Foreground / Background child layers
/// in Custom mode; in System mode the group header is the only selectable target
/// for that group. The Custom/System generation-mode picker lives in the group's
/// inspector on the right (see `GroupModePicker`).
struct LayerSidebar: View {
    @Binding var iconSettings: IconSettings
    @Binding var selection: LayerSelection
    let appexEnclosureColor: AppexColor
    let appexSymbolColor: AppexColor
    let badgeAppexEnclosureColor: AppexColor
    let badgeAppexSymbolColor: AppexColor

    var body: some View {
        List(selection: selectionBinding) {
            groupSection(.icon)
            groupSection(.badge)
        }
        .listStyle(.sidebar)
        // Child-selection → group migration on mode switch lives in ContentView
        // (the selection's owner): this sidebar column can be hidden/unmounted
        // when the mode is flipped from the inspector, so onChange here can miss.
    }

    /// `List` single-selection wants a `Binding<LayerSelection?>`. Bridge from the
    /// non-optional binding and ignore nils so the sidebar always keeps a selection
    /// (clicking empty space never deselects).
    private var selectionBinding: Binding<LayerSelection?> {
        Binding(
            get: { selection },
            set: { if let new = $0 { selection = new } }
        )
    }

    @ViewBuilder
    private func groupSection(_ group: IconLayerGroup) -> some View {
        Section {
            GroupHeaderRow(
                group: group,
                visibility: visibility(for: group),
                visibilityBinding: groupVisibilityBinding(for: group)
            )
            .tag(LayerSelection.group(group))

            if !isSystem(group) {
                ForEach(LayerRole.allCases) { role in
                    LayerRow(
                        group: group,
                        role: role,
                        iconSettings: $iconSettings,
                        appexEnclosureColor: appexEnclosureColor,
                        appexSymbolColor: appexSymbolColor,
                        badgeAppexEnclosureColor: badgeAppexEnclosureColor,
                        badgeAppexSymbolColor: badgeAppexSymbolColor
                    )
                    .tag(LayerSelection.layer(group, role))
                    .padding(.leading, 12) // indent children under header
                }
            }
        }
    }

    // MARK: - Per-group helpers

    private func isSystem(_ group: IconLayerGroup) -> Bool {
        switch group {
        case .icon:  return iconSettings.iconGenerationMode == .system
        case .badge: return iconSettings.badgeGenerationMode == .system
        }
    }

    private func visibility(for group: IconLayerGroup) -> LayerGroupVisibility {
        switch group {
        case .icon:  return iconSettings.iconVisibility()
        case .badge: return iconSettings.badgeVisibility()
        }
    }

    /// Group-eye toggle behavior: any layer visible (`.on` or `.mixed`) → click
    /// hides all; everything hidden → click shows all. Must stay consistent
    /// with `GroupVisibilityToggle`'s tooltips.
    private func groupVisibilityBinding(for group: IconLayerGroup) -> Binding<Bool> {
        switch group {
        case .icon:
            return Binding(
                get: { iconSettings.iconVisibility() != .off },
                set: { iconSettings.iconHidden = !$0 }
            )
        case .badge:
            return Binding(
                get: { iconSettings.badgeVisibility() != .off },
                set: { iconSettings.badgeHidden = !$0 }
            )
        }
    }

}

// MARK: - Group header row

private struct GroupHeaderRow: View {
    let group: IconLayerGroup
    let visibility: LayerGroupVisibility
    let visibilityBinding: Binding<Bool>

    private var iconName: String {
        switch group {
        case .icon:  return "app.fill"
        case .badge: return "app.badge.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 26, weight: .medium))
                .frame(width: 36, height: 36)

            Text(group.label)
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 8)
            GroupVisibilityToggle(visibility: visibility, binding: visibilityBinding)
        }
    }
}

/// Tri-state eye for a whole group. `.mixed` shows `eye.half.closed` and clicking
/// hides everything (consistent with the binding's setter).
private struct GroupVisibilityToggle: View {
    let visibility: LayerGroupVisibility
    let binding: Binding<Bool>

    var body: some View {
        Button {
            binding.wrappedValue.toggle()
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(visibility == .off ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var symbolName: String {
        switch visibility {
        case .on:    return "eye"
        case .off:   return "eye.slash"
        case .mixed: return "eye.half.closed"
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

// MARK: - Child layer row

private struct LayerRow: View {
    let group: IconLayerGroup
    let role: LayerRole
    @Binding var iconSettings: IconSettings
    let appexEnclosureColor: AppexColor
    let appexSymbolColor: AppexColor
    let badgeAppexEnclosureColor: AppexColor
    let badgeAppexSymbolColor: AppexColor

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
                .lineLimit(1)

            Spacer(minLength: 0)

            LayerVisibilityToggle(isVisible: visibility)
        }
    }
}

private struct LayerVisibilityToggle: View {
    @Binding var isVisible: Bool

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            Image(systemName: isVisible ? "eye" : "eye.slash")
                .font(.system(size: 13))
                .foregroundStyle(isVisible ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isVisible ? "Hide layer" : "Show layer")
    }
}

// MARK: - Mini thumbnail

private struct LayerThumbnail: View {
    let group: IconLayerGroup
    let role: LayerRole
    let settings: IconSettings
    let appexEnclosureColor: AppexColor
    let appexSymbolColor: AppexColor
    let badgeAppexEnclosureColor: AppexColor
    let badgeAppexSymbolColor: AppexColor

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(.clear))
            .overlay {
                content.padding(4)
            }
//            .overlay(
//                RoundedRectangle(cornerRadius: 8, style: .continuous)
//                    .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
//            )
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
        case .sfSymbol, .system:
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
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        case .custom:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
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
        case .sfSymbol, .system:
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
            .font(.system(size: 26))
            

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
