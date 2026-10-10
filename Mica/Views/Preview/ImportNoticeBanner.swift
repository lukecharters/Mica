// Views/Preview/ImportNoticeBanner.swift
import SwiftUI

/// Hosts the import notice at the top of the preview: shows it while its import is
/// still in place, and dismisses it after a pause that waits while the pointer is
/// over it.
struct ImportNoticeOverlay: View {
    @ObservedObject var viewModel: IconViewModel

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let displayDuration: Duration = .seconds(8)

    private struct TimerKey: Equatable {
        var id: UUID?
        var isHovering: Bool
    }

    private var visibleNotice: ImportNotice? {
        guard let notice = viewModel.importNotice,
              notice.isCurrent(in: viewModel.iconSettings) else { return nil }
        return notice
    }

    var body: some View {
        ZStack {
            if let notice = visibleNotice {
                ImportNoticeBanner(notice: notice) {
                    withAnimation(.smooth) { viewModel.revertImportNotice() }
                }
                .onHover { isHovering = $0 }
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .onAppear {
                    AccessibilityNotification.Announcement("\(notice.title). \(notice.subtitle)").post()
                }
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .animation(.smooth, value: visibleNotice?.id)
        .task(id: TimerKey(id: visibleNotice?.id, isHovering: isHovering)) {
            guard let id = visibleNotice?.id, !isHovering else { return }
            try? await Task.sleep(for: Self.displayDuration)
            guard !Task.isCancelled, viewModel.importNotice?.id == id else { return }
            viewModel.importNotice = nil
        }
    }
}

/// A capsule naming what an import changed, with a button that puts it back.
struct ImportNoticeBanner: View {
    let notice: ImportNotice
    let onRevert: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
            VStack(spacing: 4) {
                Text(verbatim: notice.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(verbatim: notice.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            Button(action: onRevert) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
            .help("Put back the settings this import changed")
            .accessibilityLabel("Revert")
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .modifier(CapsuleGlass())
        .fixedSize()
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = notice.image.nsImage {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
        }
    }
}

private struct CapsuleGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.regularMaterial, in: .capsule)
                .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        }
    }
}

#Preview {
    ImportNoticeBanner(
        notice: ImportNotice.detect(
            from: IconSettings(),
            to: {
                var settings = IconSettings()
                settings.icon.applyBackgroundImage(ImportedImage(
                    id: UUID(), imageData: Data(), sourceName: "Preview", isFileIcon: false))
                return settings
            }()
        )!,
        onRevert: {}
    )
    .padding(40)
}
