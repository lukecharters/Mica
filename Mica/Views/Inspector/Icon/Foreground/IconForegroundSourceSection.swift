// Views/Inspector/Icon/Foreground/IconForegroundSourceSection.swift
import SwiftUI

struct IconForegroundSourceSection: View {
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
                switch iconSettings.iconSource {
                case .symbol: return .symbol
                case .image: return .imported
                case .system: return .symbol
                }
            },
            set: { newValue in
                switch newValue {
                case .symbol:
                    iconSettings.iconSource = .symbol
                case .imported:
                    iconSettings.iconSource = .image
                }
            }
        )
    }

    var body: some View {
        if isSystem {
            // System mode renders the icon as one appex image, so visibility is
            // all-or-nothing for the group rather than per layer.
            LayerVisibleToggle(isHidden: $iconSettings.iconHidden)
            symbolField
        } else {
            LayerVisibleToggle(isHidden: $iconSettings.iconForegroundHidden)

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
                    importedImage: $iconSettings.importedImage,
                    onImport: { iconSettings.applyImportedIconForeground($0) }
                )
            }
        }
    }

    private var symbolField: some View {
        SymbolNameField(symbolName: $iconSettings.symbolName)
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Source") {
            IconForegroundSourceSection(iconSettings: $settings, isSystem: false)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
