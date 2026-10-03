// PixelFitRun.swift - Fits a list of symbols to Apple's rendering, one after another
//
// Drives `PixelFitter` from the calibration tool: renders each appex reference off the
// main actor (one symbol ahead), fits on it, and hands each entry back to the caller.

import AppKit
import Foundation

@MainActor
@Observable
final class PixelFitRun {
    private(set) var isRunning = false
    private(set) var total = 0
    private(set) var processed = 0
    private(set) var flagged = 0
    private(set) var unresolved = 0
    private(set) var failed = 0
    private(set) var currentSymbol: String?
    private(set) var startedAt: Date?
    var message: String?
    private var task: Task<Void, Never>?

    /// IconServices draws the variant for the **system** appearance: in dark mode a blue
    /// enclosure becomes a near-black one with a blue glyph. Nothing an app sets changes
    /// that, so a run refuses to start, and stops, while the system is dark.
    static var systemIsDark: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    var progress: Double { total == 0 ? 0 : Double(processed) / Double(total) }

    var estimatedRemaining: TimeInterval? {
        guard let startedAt, processed > 0 else { return nil }
        return Date().timeIntervalSince(startedAt) / Double(processed) * Double(total - processed)
    }

    /// Fits `symbols` in order. `start` gives each one's starting values; `write` receives
    /// every fitted entry; `checkpoint` is called every 20 symbols and at the end.
    func start(
        symbols: [String],
        threshold: Double,
        start: @escaping (String) -> PixelFitter.Values,
        write: @escaping (String, SymbolCalibrationEntry) -> Void,
        checkpoint: @escaping () -> Void
    ) {
        guard !isRunning else { return }
        guard !Self.systemIsDark else {
            message = "The Mac is in dark mode, which changes Apple's rendering. Switch to light mode to fit."
            return
        }
        isRunning = true
        total = symbols.count
        processed = 0; flagged = 0; unresolved = 0; failed = 0
        startedAt = Date()
        message = nil

        task = Task {
            var pending: Task<CGImage?, Never>? = symbols.first.map(Self.renderReference)
            for (index, symbol) in symbols.enumerated() {
                if Task.isCancelled { break }
                if Self.systemIsDark {
                    message = "Stopped: the Mac switched to dark mode."
                    break
                }
                currentSymbol = symbol
                let reference = await pending?.value
                pending = index + 1 < symbols.count ? Self.renderReference(symbols[index + 1]) : nil

                guard let reference else {
                    unresolved += 1
                    processed += 1
                    continue
                }
                let target = await Task.detached(priority: .userInitiated) {
                    ReferenceGlyphCoverage.estimate(from: reference, size: PixelFitter.size)
                }.value
                guard let result = await PixelFitter.fit(symbol, target: target, start: start(symbol)) else {
                    if Task.isCancelled { break }
                    failed += 1
                    processed += 1
                    continue
                }
                let entry = PixelFitter.entry(for: result, threshold: threshold)
                if entry.status != "calibrated" { flagged += 1 }
                write(symbol, entry)
                processed += 1
                if processed % 20 == 0 { checkpoint() }
            }
            pending?.cancel()
            checkpoint()
            currentSymbol = nil
            isRunning = false
        }
    }

    func cancel() {
        task?.cancel()
    }

    /// Apple's rendering at the calibration tool's size, or nil when IconServices drew its
    /// stand-in for a name it could not resolve.
    private static func renderReference(_ symbol: String) -> Task<CGImage?, Never> {
        Task.detached(priority: .userInitiated) {
            guard let image = try? AppexReferenceService.renderForExport(
                symbolName: symbol, enclosureColor: .defaultEnclosure, symbolColor: .defaultSymbol,
                pointSize: PixelFitter.pointSize, scaleFactor: 2, colorSpace: .sRGB),
                !AppexReferenceService.isUnresolvedSymbolRender(image, pointSize: PixelFitter.pointSize, scaleFactor: 2, colorSpace: .sRGB)
            else { return nil }
            var rect = CGRect(origin: .zero, size: image.size)
            return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
    }
}
