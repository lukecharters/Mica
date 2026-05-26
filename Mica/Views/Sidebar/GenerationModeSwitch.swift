// Views/Sidebar/IconModePicker.swift
import SwiftUI

/// Two-segment grouping for the sidebar: Custom (SwiftUI rendering) vs System (Apple reference rendering).
enum IconModeSegment: Int, CaseIterable, Identifiable {
    case custom = 0
    case system = 1

    var id: Int { rawValue }

    var systemImageName: String {
        switch self {
        case .custom: "slider.horizontal.3"
        case .system: "command"
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
            Text("Icon Generation Mode").font(.headline)
            HStack(spacing: 0) {
                ForEach(IconModeSegment.allCases) { segment in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isSystem = (segment == .system)
                        }
                    }
                    label: {
                        HStack(spacing: 2) {
                            Image(systemName: segment.systemImageName)
//                                .font(.system(size: 28))
                                .symbolRenderingMode(.monochrome)
//                                .frame(width: 36, height: 28)
                            Text(segment.label)
//                                .font(.body)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
//                            RoundedRectangle(cornerRadius: 20)
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
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

#Preview {
    @Previewable @State var isSystem = false
    IconModePicker(isSystem: $isSystem)
        .frame(width: 300)
        .padding()
}
