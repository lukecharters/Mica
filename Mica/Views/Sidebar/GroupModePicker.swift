// Views/Sidebar/GroupModePicker.swift
import SwiftUI

/// Views-layer display metadata for `GenerationMode` (kept out of the shared
/// model so the CLI doesn't carry UI strings).
extension GenerationMode {
    var systemImageName: String {
        switch self {
        case .mica: "slider.horizontal.3"
        case .system: "command"
        }
    }

    var label: String {
        switch self {
        case .mica: "Mica"
        case .system: "System"
        }
    }
}

/// Two-state segmented control: Mica vs System for a single group. Shown at the
/// top of a group's inspector (Icon / Badge) so the user can switch that group
/// between Mica's SwiftUI rendering and Apple's system reference.
struct GroupModePicker: View {
    @Binding var isSystem: Bool

    private var selection: GenerationMode {
        isSystem ? .system : .mica
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Generation Mode").font(.headline)
            HStack(spacing: 0) {
                ForEach(GenerationMode.allCases) { segment in
                    Button {
                        isSystem = (segment == .system)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: segment.systemImageName)
                                .symbolRenderingMode(.monochrome)
                            Text(segment.label)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selection == segment
                                      ? Color.accentColor
                                      : Color.primary.opacity(0.1))
                        )
                        .foregroundStyle(selection == segment ? Color.white : .primary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

#Preview {
    @Previewable @State var isSystem = false
    GroupModePicker(isSystem: $isSystem)
        .frame(width: 340)
        .padding()
}
