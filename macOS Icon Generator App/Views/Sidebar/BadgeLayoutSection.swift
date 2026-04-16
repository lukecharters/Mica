// Views/Sidebar/BadgeLayoutSection.swift
import SwiftUI

struct BadgeLayoutSection: View {
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

        HStack {
            Text("X Offset")
            Spacer()
            Text("\(Int(iconSettings.badgeManualOffsetX * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        Slider(value: $iconSettings.badgeManualOffsetX,
               in: IconSettings.badgeOffsetRange,
               step: 0.01)

        HStack {
            Text("Y Offset")
            Spacer()
            Text("\(Int(iconSettings.badgeManualOffsetY * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        Slider(value: $iconSettings.badgeManualOffsetY,
               in: IconSettings.badgeOffsetRange,
               step: 0.01)

        if iconSettings.badgeManualOffsetX != 0 || iconSettings.badgeManualOffsetY != 0 {
            Button("Reset Position") {
                iconSettings.badgeManualOffsetX = 0
                iconSettings.badgeManualOffsetY = 0
            }
        }

        HStack {
            Text("Size")
            Spacer()
            Text("\(Int(iconSettings.badgeScale * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        Slider(value: $iconSettings.badgeScale,
               in: IconSettings.manualSymbolScaleRange,
               step: 0.05)

        switch iconSettings.badgeIconSource {
        case .sfSymbol:
            HStack {
                Text("Scale")
                Spacer()
                Text("\(Int(iconSettings.badgeSymbolScale * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $iconSettings.badgeSymbolScale,
                   in: IconSettings.manualSymbolScaleRange,
                   step: 0.05)

        case .customImage:
            ImageImportLayoutControls(
                paddingCompensation: .constant(false),
                imageScale: $iconSettings.badgeImportedImageScale,
                showPaddingCompensation: false
            )

        case .appleReference:
            EmptyView() // Layout hidden in Apple Ref mode by SidebarView
        }
    }
}
