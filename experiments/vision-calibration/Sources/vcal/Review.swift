import AppKit
import Foundation

/// A sheet per symbol for checking the fit by eye: Apple's icon beside Mica's at the fitted weight
/// and at the hand-calibrated weight, with an overlay of each.
@MainActor
enum Review {
    static let panel = 320
    static let header = 64

    struct Entry {
        var sample: Sample
        var perWeight: [CoverageFit.Result]
        var chosen: CoverageFit.Result { perWeight.max { $0.iou < $1.iou }! }
        var atHandWeight: CoverageFit.Result { perWeight[sample.truth.weightIndex] }
    }

    static func run(samples: [Sample], enclosure: String, symbolColour: String, cacheDirectory: URL, outputDirectory: URL) throws {
        var entries: [Entry] = []
        for (index, sample) in samples.enumerated() {
            let reference = try AppexReference.render(sample.symbol, enclosure: enclosure, symbolColour: symbolColour, cacheDirectory: cacheDirectory)
            let target = ReferenceCoverage.normalised(reference, size: 1024)
            let perWeight = IconParams.weightTokens.indices.map {
                CoverageFit.descend(sample.symbol, target: target, start: sample.truth, size: 1024, weights: [$0], binary: false)
            }
            let entry = Entry(sample: sample, perWeight: perWeight)
            entries.append(entry)
            try PNG.write(sheet(entry, reference: reference, target: target), to: outputDirectory.appendingPathComponent("\(sample.symbol).png"))
            print("[\(index + 1)/\(samples.count)] \(sample.symbol): hand \(sample.truth.weight), fit \(entry.chosen.params.weight)  " +
                  perWeight.map { "\($0.params.weight) \(f3($0.iou))" }.joined(separator: "  "))
        }
        try html(entries, enclosure: enclosure, symbolColour: symbolColour).write(to: outputDirectory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    }

    private static func sheet(_ entry: Entry, reference: CGImage, target: Coverage) -> CGImage {
        let symbol = entry.sample.symbol
        let chosen = entry.chosen, hand = entry.atHandWeight
        let sameWeight = chosen.params.weight == hand.params.weight
        var columns: [(String, String, CGImage)] = [("macOS 27 (Apple)", "", reference)]
        if let icon = MicaRenderer.render(symbol, chosen.params) {
            columns.append(("Mica, fitted weight", "\(chosen.params.short)  IoU \(f3(chosen.iou))", icon))
        }
        if let overlay = overlay(target, symbol, chosen.params) { columns.append(("overlay, fitted", "red: Apple only  cyan: Mica only", overlay)) }
        if !sameWeight {
            if let icon = MicaRenderer.render(symbol, hand.params) {
                columns.append(("Mica, hand weight refit", "\(hand.params.short)  IoU \(f3(hand.iou))", icon))
            }
            if let overlay = overlay(target, symbol, hand.params) { columns.append(("overlay, hand weight", "", overlay)) }
        }
        if let icon = MicaRenderer.render(symbol, entry.sample.truth) {
            columns.append(("Mica, stored values", entry.sample.truth.short, icon))
        }

        let gap = 12
        let width = columns.count * panel + (columns.count + 1) * gap
        let height = header + panel + gap * 2 + 22
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 0.93, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let title = "\(symbol)   hand: \(entry.sample.truth.weight)   fit: \(chosen.params.weight)   IoU by weight: " +
            entry.perWeight.map { "\($0.params.weight) \(f3($0.iou))" }.joined(separator: ", ")
        draw(title, at: CGPoint(x: gap, y: height - 26), size: 15, bold: true)
        for (i, column) in columns.enumerated() {
            let x = gap + i * (panel + gap)
            draw(column.0, at: CGPoint(x: x, y: height - header + 8), size: 13, bold: true)
            context.draw(column.2, in: CGRect(x: x, y: gap + 22, width: panel, height: panel))
            draw(column.1, at: CGPoint(x: x, y: gap), size: 10.5, bold: false)
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }

    private static func draw(_ text: String, at point: CGPoint, size: CGFloat, bold: Bool) {
        let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.black]).draw(at: point)
    }

    private static func overlay(_ target: Coverage, _ symbol: String, _ params: IconParams) -> CGImage? {
        guard let mica = GlyphCoverage.mica(symbol, params, size: target.size) else { return nil }
        let n = target.size
        var rgba = [UInt8](repeating: 255, count: n * n * 4)
        for i in 0..<(n * n) {
            let a = target.values[i], b = mica.values[i], both = min(a, b)
            let red = a - both, cyan = b - both
            rgba[i * 4] = UInt8(min(255, 255 * (both + red)))
            rgba[i * 4 + 1] = UInt8(min(255, 255 * both + 200 * cyan + 40 * red))
            rgba[i * 4 + 2] = UInt8(min(255, 255 * (both + cyan) + 40 * red))
        }
        return Pixels.image(rgba, size: n)
    }

    private static func html(_ entries: [Entry], enclosure: String, symbolColour: String) -> String {
        let changed = entries.filter { $0.chosen.params.weight != $0.sample.truth.weight }
        var out = """
            <!doctype html><meta charset="utf-8"><title>Fit review</title>
            <style>body{font:14px -apple-system,sans-serif;margin:24px;background:#fafafa;color:#222}
            img{max-width:100%;border:1px solid #ccc;margin:6px 0 28px}h2{font-size:15px;margin:0}
            .changed{color:#b3261e}</style>
            <h1>Pixel fit review: \(enclosure) + \(symbolColour), light mode</h1>
            <p>\(entries.count) symbols; the fit chose a different weight from the stored one for \(changed.count).
            Overlay: white is shared, red is Apple's glyph only, cyan is Mica's only.</p>
            """
        for e in entries {
            let different = e.chosen.params.weight != e.sample.truth.weight
            out += "<h2\(different ? " class=\"changed\"" : "")>\(e.sample.symbol): stored \(e.sample.truth.weight), fit \(e.chosen.params.weight)</h2>"
            out += "<img src=\"\(e.sample.symbol).png\" alt=\"\(e.sample.symbol)\">\n"
        }
        return out
    }
}
