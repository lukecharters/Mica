// Views/Preview/AppexPreviewPane.swift
import SwiftUI

struct AppexPreviewPane: View {
    @ObservedObject var viewModel: IconViewModel
    var appexService: AppexReferenceService

    var body: some View {
        ZStack(alignment: .topTrailing) {
            previewContent
        }
        .task(id: viewModel.appexGenerationKey) {
            // Debounce: cancel and restart on every change; 400ms wait before firing.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await viewModel.generateAppexIcon(service: appexService)
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
        if viewModel.appexIsGenerating {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Generating…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 256, height: 256)
        } else if let image = viewModel.appexRenderedImage {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: 256, height: 256)
        } else if let error = viewModel.appexError {
            ContentUnavailableView(
                "Generation Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .frame(width: 256, height: 256)
        } else {
            ContentUnavailableView(
                "No Preview",
                systemImage: "app.dashed",
                description: Text("Enter a symbol name to generate")
            )
            .frame(width: 256, height: 256)
        }
    }
}
