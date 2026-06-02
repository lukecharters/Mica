// Views/Preview/AppexPreviewPane.swift
import SwiftUI

struct AppexPreviewPane: View {
    @ObservedObject var viewModel: IconViewModel
    var appexService: AppexReferenceService

    @State private var zoomLevel: Double = 1.0

    private let zoomLevels: [Double] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            previewContent
            zoomControl
                .padding(12)
        }
        .task(id: viewModel.appexGenerationKey) {
            // Debounce: cancel and restart on every change; 400ms wait before firing.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await viewModel.generateAppexIcon(service: appexService)
        }
        .task(id: viewModel.badgeAppexGenerationKey) {
            guard viewModel.iconSettings.showBadge,
                  viewModel.iconSettings.badgeIconSource == .appleReference else {
                return
            }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await viewModel.generateBadgeAppexIcon(service: appexService)
        }
    }

    private var previewContent: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack {
                Spacer(minLength: 60)
                iconContent
                    .padding()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }

    @ViewBuilder
    private var iconContent: some View {
        let size = 512 * zoomLevel
        if viewModel.appexIsGenerating {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Generating…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        } else if let image = viewModel.appexRenderedImage {
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: size, height: size)

                if viewModel.iconSettings.showBadge {
                    let enclosureSize = size * (1 - 50.0 / 256.0)
                    let badgeSize = enclosureSize * (80.0 / 208.0) * viewModel.iconSettings.badgeScale
                    BadgeView(
                        settings: viewModel.iconSettings,
                        badgeSize: badgeSize,
                        badgeAppexImage: viewModel.badgeAppexRenderedImage
                    )
                    .offset(badgeOffset(enclosureSize: enclosureSize))
                }
            }
        } else if let error = viewModel.appexError {
            ContentUnavailableView(
                "Generation Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .frame(width: 512, height: 512)
        } else {
            ContentUnavailableView(
                "No Preview",
                systemImage: "app.dashed",
                description: Text("Enter a symbol name to generate")
            )
            .frame(width: 512, height: 512)
        }
    }

    private func badgeOffset(enclosureSize: CGFloat) -> CGSize {
        let ax = enclosureSize * (76.0 / 208.0)
        let ay = enclosureSize * (80.0 / 208.0)
        let mx = enclosureSize * viewModel.iconSettings.badgeManualOffsetX
        let my = enclosureSize * viewModel.iconSettings.badgeManualOffsetY
        switch viewModel.iconSettings.badgePosition {
        case .topRight:    return CGSize(width: ax + mx, height: -ay + my)
        case .topLeft:     return CGSize(width: -ax + mx, height: -ay + my)
        case .bottomRight: return CGSize(width: ax + mx, height: ay + my)
        case .bottomLeft:  return CGSize(width: -ax + mx, height: ay + my)
        }
    }

    private var zoomControl: some View {
        Menu {
            ForEach(zoomLevels, id: \.self) { level in
                Button { zoomLevel = level } label: {
                    Text("\(Int(level * 100))%")
                }
            }
        } label: {
                Text("\(Int(zoomLevel * 100))%")
        }
    }
}

#Preview {
    AppexPreviewPane(
        viewModel: IconViewModel(),
        appexService: AppexReferenceService()
    )
    .frame(width: 600, height: 600)
}
