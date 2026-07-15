// Views/Preview/AppexPreviewPane.swift
import SwiftUI

struct AppexPreviewPane: View {
    @ObservedObject var viewModel: IconViewModel
    var appexService: AppexReferenceService

    /// Display zoom, owned by `ContentView` and driven by the toolbar's `ZoomMenu`.
    @Binding var zoomLevel: Double
    /// Preview-only override of the icon's display point size (MDM portal sizes,
    /// etc.); `nil` follows the export size. Owned by `ContentView`, driven by the
    /// toolbar's `PreviewSizeMenu`.
    @Binding var previewPointSize: CGFloat?

    var body: some View {
        previewContent
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
//                Spacer(minLength: 0)
                iconContent
                // .padding()
//                Spacer(minLength: 0)
            }
             .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3))
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var iconContent: some View {
        let size = (previewPointSize ?? viewModel.iconSettings.exportSize) * zoomLevel
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
                    let badgeSize = BadgeGeometry.diameter(
                        enclosureSize: enclosureSize,
                        badgeScale: viewModel.iconSettings.badgeScale
                    )
                    let badgeOffset = BadgeGeometry.offset(
                        for: viewModel.iconSettings,
                        enclosureSize: enclosureSize
                    )
                    if viewModel.iconSettings.badgeIconSource == .appleReference,
                       viewModel.badgeAppexRenderedImage == nil {
                        // Preview-only stand-in; BadgeView draws nothing until the
                        // badge's appex image exists.
                        BadgeAppexStatusView(
                            badgeSize: badgeSize,
                            error: viewModel.badgeAppexError
                        )
                        .offset(badgeOffset)
                    } else {
                        BadgeView(
                            settings: viewModel.iconSettings,
                            badgeSize: badgeSize,
                            badgeAppexImage: viewModel.badgeAppexRenderedImage
                        )
                        .offset(badgeOffset)
                    }
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

}

#Preview {
    @Previewable @State var zoomLevel: Double = 1.0
    @Previewable @State var previewPointSize: CGFloat? = nil
    AppexPreviewPane(
        viewModel: IconViewModel(),
        appexService: AppexReferenceService(),
        zoomLevel: $zoomLevel,
        previewPointSize: $previewPointSize
    )
    .frame(width: 600, height: 600)
}
