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
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: size, height: size)
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

    private var zoomControl: some View {
        Menu {
            ForEach(zoomLevels, id: \.self) { level in
                Button { zoomLevel = level } label: {
                    Text("\(Int(level * 100))%")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(Int(zoomLevel * 100))%")
                    .monospacedDigit()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
