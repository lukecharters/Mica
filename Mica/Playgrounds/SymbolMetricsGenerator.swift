// SymbolMetricsGenerator.swift
// Measures intrinsic dimensions of all SF Symbols via NSImage and saves results to JSON.

import AppKit
import Foundation

struct SymbolMetrics: Codable {
    let width: Double
    let height: Double
    let aspectRatio: Double
}

struct SymbolMetricsFile: Codable {
    let generatedAt: String
    let referencePointSize: Double
    let symbolCount: Int
    let symbols: [String: SymbolMetrics]
}

struct SymbolMetricsGenerator {
    static let referencePointSize: CGFloat = 100

    static func generateAll(progressHandler: @Sendable (String, Double) -> Void) async -> SymbolMetricsFile {
        let symbols = loadSymbols()
        var results: [String: SymbolMetrics] = [:]
        let config = NSImage.SymbolConfiguration(pointSize: referencePointSize, weight: .regular)

        for (index, symbol) in symbols.enumerated() {
            guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else {
                continue
            }
            let configured = image.withSymbolConfiguration(config) ?? image
            let size = configured.size
            guard size.width > 0, size.height > 0 else { continue }

            results[symbol] = SymbolMetrics(
                width: Double(size.width),
                height: Double(size.height),
                aspectRatio: Double(size.width / size.height)
            )

            let progress = Double(index + 1) / Double(symbols.count)
            progressHandler(symbol, progress)
        }

        let formatter = ISO8601DateFormatter()
        return SymbolMetricsFile(
            generatedAt: formatter.string(from: Date()),
            referencePointSize: Double(referencePointSize),
            symbolCount: results.count,
            symbols: results
        )
    }

    static func save(_ file: SymbolMetricsFile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    static var defaultOutputURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Mica", isDirectory: true)
        return dir.appendingPathComponent("symbol_metrics.json")
    }

    private static func loadSymbols() -> [String] {
        guard let url = Bundle.main.url(forResource: "sf_symbols", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
}
