// Views/Inspector/Badge/Foreground/BadgeForegroundSourceSection.swift
import SwiftUI

struct BadgeForegroundSourceSection: View {
    @Binding var iconSettings: IconSettings
    let isSystem: Bool

    /// Source selection within Custom mode (SF Symbol vs Imported image).
    private enum SourceType: String, CaseIterable, Identifiable {
        case symbol = "SF Symbol"
        case imported = "Imported"
        var id: String { rawValue }
    }

    private var sourceType: Binding<SourceType> {
        Binding(
            get: {
                switch iconSettings.badgeIconSource {
                case .symbol: return .symbol
                case .image: return .imported
                case .system: return .symbol
                }
            },
            set: { newValue in
                switch newValue {
                case .symbol:
                    iconSettings.badgeIconSource = .symbol
                case .imported:
                    iconSettings.badgeIconSource = .image
                }
            }
        )
    }

    var body: some View {
        if isSystem {
            // System mode renders the badge as one appex image, so visibility is
            // all-or-nothing for the group rather than per layer.
            LayerVisibleToggle(isHidden: $iconSettings.badgeHidden)
            symbolField
        } else {
            LayerVisibleToggle(isHidden: $iconSettings.badgeForegroundHidden)

            Picker("Source", selection: sourceType) {
                ForEach(SourceType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch sourceType.wrappedValue {
            case .symbol:
                symbolField

            case .imported:
                ImageImportControls(
                    importedImage: $iconSettings.badgeImportedImage,
                    onImport: { iconSettings.applyImportedBadgeForeground($0) }
                )
            }
        }
    }

    private var symbolField: some View {
        SymbolNameField(
            symbolName: $iconSettings.badgeSymbolName,
            help: "Enter an SF Symbol name for the badge (e.g., 1.circle.fill, plus, checkmark)"
        )
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Source") {
            BadgeForegroundSourceSection(iconSettings: $settings, isSystem: false)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
