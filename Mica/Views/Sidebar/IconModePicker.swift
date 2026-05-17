// Views/Sidebar/IconModePicker.swift
import SwiftUI

/// Two-segment grouping for the sidebar: Custom (SwiftUI rendering) vs System (Apple reference rendering).
enum IconModeSegment: Int, CaseIterable, Identifiable {
    case custom = 0
    case system = 1

    var id: Int { rawValue }

    var systemImageName: String {
        switch self {
        case .custom: "slider.horizontal.2.square"
        case .system: "command.square.fill"
        }
    }

    var label: String {
        switch self {
        case .custom: "Custom"
        case .system: "System"
        }
    }
}

/// Custom 2-segment picker matching the IconBadgePicker style.
/// Selects between Custom (SwiftUI) and System (Apple reference) rendering for the active segment.
struct IconModePicker: View {
    @Binding var isSystem: Bool

    private var selection: IconModeSegment {
        isSystem ? .system : .custom
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Generation Mode").font(.title)
            HStack(spacing: 0) {
                ForEach(IconModeSegment.allCases) { segment in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isSystem = (segment == .system)
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: segment.systemImageName)
                                .font(.system(size: 28))
                                .symbolRenderingMode(.monochrome)
                                .frame(width: 36, height: 28)
                            Text(segment.label)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selection == segment
                                      ? Color.accentColor.opacity(0.8)
                                      : Color.clear)
                        )
                        .foregroundStyle(selection == segment ? Color.white : .secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    @Previewable @State var isSystem = false
    IconModePicker(isSystem: $isSystem)
        .frame(width: 300)
        .padding()
}
