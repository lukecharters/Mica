// Views/Sidebar/BadgeGroupInspector.swift
import SwiftUI

/// Inspector contents shown when the Badge group header is selected. Holds the
/// badge's group-level layout (position + offset + overall scale). In System mode
/// the group is the only selectable badge target, so Source + Appearance for the
/// appex badge are surfaced here too.
struct BadgeGroupInspector: View {
    @Binding var iconSettings: IconSettings
    /// Custom/System picker binding, owned by `LayerControls` so the same restore
    /// state is shared with the badge child-layer inspectors.
    @Binding var badgeMode: Bool
    var colorOptions: [(name: String, color: Color)] = []
    var badgeAppexSymbolColor: Binding<AppexColor>? = nil
    var badgeAppexEnclosureColor: Binding<AppexColor>? = nil

    @AppStorage("sidebar.badgeGroupLayout.expanded") private var badgeGroupLayoutExpanded = true
    @AppStorage("sidebar.badgeSource.expanded") private var badgeSourceExpanded = true
    @AppStorage("sidebar.badgeAppearance.expanded") private var badgeAppearanceExpanded = true

    private var isAppleReference: Bool {
        iconSettings.badgeGenerationMode == .appleReference
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupModePicker(isSystem: $badgeMode)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Form {
                if isAppleReference {
                    Section("Source", isExpanded: $badgeSourceExpanded) {
                        BadgeSourceSection(
                            iconSettings: $iconSettings,
                            isSystem: true
                        )
                    }

                    if let symbolColor = badgeAppexSymbolColor, let enclosureColor = badgeAppexEnclosureColor {
                        Section("Appearance", isExpanded: $badgeAppearanceExpanded) {
                            BadgeAppearanceSection(
                                iconSettings: $iconSettings,
                                colorOptions: colorOptions,
                                badgeAppexSymbolColor: symbolColor,
                                badgeAppexEnclosureColor: enclosureColor
                            )
                        }
                    }
                }

                Section("Layout", isExpanded: $badgeGroupLayoutExpanded) {
                    BadgeGroupLayoutSection(iconSettings: $iconSettings)
                }
            }
            .formStyle(GroupedFormStyle())
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Badge-wide layout controls: anchor position, manual offset, overall badge scale.
struct BadgeGroupLayoutSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        Picker("Position", systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", selection: $iconSettings.badgePosition) {
            ForEach(BadgePosition.allCases) { position in
                Text(position.rawValue).tag(position)
            }
        }
        .onChange(of: iconSettings.badgePosition) {
            iconSettings.badgeManualOffsetX = 0
            iconSettings.badgeManualOffsetY = 0
        }

        Slider(value: $iconSettings.badgeManualOffsetX,
               in: IconSettings.badgeOffsetRange,
               step: 0.01) {
            Text("X Offset")
            Text("\(Int(iconSettings.badgeManualOffsetX * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }

        Slider(value: $iconSettings.badgeManualOffsetY,
               in: IconSettings.badgeOffsetRange,
               step: 0.01) {
            Text("Y Offset")
            Spacer()
            Text("\(Int(iconSettings.badgeManualOffsetY * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }

        if iconSettings.badgeManualOffsetX != 0 || iconSettings.badgeManualOffsetY != 0 {
            Button("Reset Position") {
                iconSettings.badgeManualOffsetX = 0
                iconSettings.badgeManualOffsetY = 0
            }
        }

        Slider(value: $iconSettings.badgeScale,
               in: IconSettings.manualSymbolScaleRange,
               step: 0.05) {
            Text("Size")
            Spacer()
            Text("\(Int(iconSettings.badgeScale * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    @Previewable @State var badgeMode = false
    BadgeGroupInspector(iconSettings: $settings, badgeMode: $badgeMode)
        .frame(width: 380)
        .padding()
}
