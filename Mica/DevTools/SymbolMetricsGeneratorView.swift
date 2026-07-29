// SymbolMetricsGeneratorView.swift
// Simple three-state progress window for generating SF Symbol metrics.

import SwiftUI

struct SymbolMetricsGeneratorView: View {
    @State private var state: GeneratorState = .ready
    @State private var currentSymbol = ""
    @State private var progress = 0.0
    @State private var result: GeneratorResult?

    private enum GeneratorState {
        case ready
        case running
        case complete
    }

    private struct GeneratorResult {
        let success: Bool
        let symbolCount: Int
        let outputURL: URL
        let errorMessage: String?
    }

    var body: some View {
        VStack(spacing: 20) {
            switch state {
            case .ready:
                readyView
            case .running:
                runningView
            case .complete:
                completeView
            }
        }
        .padding(30)
        .frame(width: 420, height: 220)
    }

    // MARK: - Ready

    private var readyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "ruler")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("Measure all SF Symbols and save their intrinsic dimensions to JSON.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Generate") {
                startGeneration()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)

            Text(currentSymbol)
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("\(Int(progress * 100))%")
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Complete

    private var completeView: some View {
        VStack(spacing: 16) {
            if let result {
                if result.success {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)

                    Text("Measured \(result.symbolCount) symbols")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([result.outputURL])
                        }

                        Button("Done") {
                            state = .ready
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)

                    Text(result.errorMessage ?? "Unknown error")
                        .foregroundStyle(.secondary)

                    Button("Done") {
                        state = .ready
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Generation

    private func startGeneration() {
        state = .running
        progress = 0
        currentSymbol = ""

        Task {
            let metricsFile = await SymbolMetricsGenerator.generateAll { symbol, pct in
                Task { @MainActor in
                    currentSymbol = symbol
                    progress = pct
                }
            }

            let outputURL = SymbolMetricsGenerator.defaultOutputURL
            do {
                try SymbolMetricsGenerator.save(metricsFile, to: outputURL)
                result = GeneratorResult(
                    success: true,
                    symbolCount: metricsFile.symbolCount,
                    outputURL: outputURL,
                    errorMessage: nil
                )
            } catch {
                result = GeneratorResult(
                    success: false,
                    symbolCount: 0,
                    outputURL: outputURL,
                    errorMessage: error.localizedDescription
                )
            }
            state = .complete
        }
    }
}
