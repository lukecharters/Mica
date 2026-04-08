// AppexReferenceService.swift - Reference icon generation via .appex bundle manipulation
//
// Generates ground-truth icons by modifying a system .appex bundle's Info.plist
// to render any SF Symbol through Apple's private IconServices pipeline, then
// capturing the result via NSWorkspace.shared.icon(forFile:).

import AppKit
import Foundation

@MainActor
@Observable
class AppexReferenceService {
    private var cache: [CacheKey: NSImage] = [:]
    var isGenerating = false

    private let sourceBundlePath = "/System/Library/ExtensionKit/Extensions/Storage.appex"

    // MARK: - Cache Key

    private struct CacheKey: Hashable {
        let symbolName: String
        let enclosureColor: AppexEnclosureColor
    }

    // MARK: - Public API

    /// Generate or return cached reference icon at 512pt @2x
    func referenceIcon(for symbolName: String, enclosureColor: AppexEnclosureColor = .blue) async throws -> NSImage {
        let key = CacheKey(symbolName: symbolName, enclosureColor: enclosureColor)
        if let cached = cache[key] { return cached }

        isGenerating = true
        defer { isGenerating = false }

        let icon = try await generateIcon(for: symbolName, enclosureColor: enclosureColor)
        cache[key] = icon
        return icon
    }

    /// Pre-fetch next N symbols in background
    func prefetch(_ symbolNames: [String], enclosureColor: AppexEnclosureColor = .blue) {
        for name in symbolNames {
            let key = CacheKey(symbolName: name, enclosureColor: enclosureColor)
            guard cache[key] == nil else { continue }
            Task.detached(priority: .utility) { [weak self] in
                _ = try? await self?.referenceIcon(for: name, enclosureColor: enclosureColor)
            }
        }
    }

    func cleanup() {}

    // MARK: - Per-Render Workspace

    /// Copy .appex to a unique temp path, configure, render, and clean up.
    /// Each render gets its own UUID-named bundle so LaunchServices never serves a stale icon.
    /// Blocking file I/O is dispatched to a background thread via Task.detached.
    private func generateIcon(for symbolName: String, enclosureColor: AppexEnclosureColor) async throws -> NSImage {
        let sourceBundlePath = self.sourceBundlePath
        let task = Task.detached(priority: .userInitiated) {
            try AppexReferenceService.generateIconSync(
                symbolName: symbolName,
                enclosureColor: enclosureColor,
                sourceBundlePath: sourceBundlePath
            )
        }
        return try await task.value
    }

    private nonisolated static func generateIconSync(
        symbolName: String,
        enclosureColor: AppexEnclosureColor,
        sourceBundlePath: String
    ) throws -> NSImage {
        let sourceURL = URL(fileURLWithPath: sourceBundlePath)
        guard FileManager.default.fileExists(atPath: sourceBundlePath) else {
            throw AppexError.sourceBundleNotFound
        }

        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let wsURL = tempRoot.appendingPathComponent("iconCal-" + UUID().uuidString).appendingPathExtension("appex")

        try FileManager.default.copyItem(at: sourceURL, to: wsURL)
        defer { try? FileManager.default.removeItem(at: wsURL) }

        try configurePlist(at: wsURL, symbolName: symbolName, enclosureColor: enclosureColor)
        try touchBundle(at: wsURL)

        return try renderIcon(at: wsURL)
    }

    // MARK: - Plist Configuration

    private nonisolated static func configurePlist(at bundleURL: URL, symbolName: String, enclosureColor: AppexEnclosureColor) throws {
        let plistURL = bundleURL.appendingPathComponent("Contents/Info.plist", isDirectory: false)

        let data = try Data(contentsOf: plistURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              var bundleIcons = plist["CFBundleIcons"] as? [String: Any],
              var graphicConfig = bundleIcons["ISGraphicIconConfiguration"] as? [String: Any]
        else {
            throw AppexError.invalidPlistStructure
        }

        graphicConfig["ISSymbolName"] = symbolName
        graphicConfig["ISEnclosureColor"] = enclosureColor.rawValue
        graphicConfig["ISSymbolColor"] = "white"

        bundleIcons["ISGraphicIconConfiguration"] = graphicConfig
        plist["CFBundleIcons"] = bundleIcons

        let outputData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try outputData.write(to: plistURL, options: .atomic)
    }

    /// Touch the bundle to invalidate LaunchServices icon cache
    private nonisolated static func touchBundle(at bundleURL: URL) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: bundleURL.path
        )
    }

    // MARK: - Icon Rendering

    /// Render NSWorkspace icon into a 512pt @2x NSImage
    private nonisolated static func renderIcon(at bundleURL: URL) throws -> NSImage {
        guard let iconImage = NSWorkspace.shared.icon(forFile: bundleURL.path).copy() as? NSImage else {
            throw AppexError.renderFailed
        }

        let pointSize: CGFloat = 512
        let pixelSize = 1024 // 2x scale factor
        let drawingRect = NSRect(origin: .zero, size: NSSize(width: pointSize, height: pointSize))

        guard let cgColorSpace = CGColorSpace(name: CGColorSpace.displayP3) else {
            throw AppexError.renderFailed
        }

        let bytesPerRow = pixelSize * 4
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )

        guard let cgContext = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: cgColorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw AppexError.renderFailed
        }

        cgContext.interpolationQuality = .high
        cgContext.clear(CGRect(origin: .zero, size: CGSize(width: CGFloat(pixelSize), height: CGFloat(pixelSize))))
        cgContext.scaleBy(x: 2.0, y: 2.0)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: false)
        iconImage.size = drawingRect.size
        iconImage.draw(in: drawingRect, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = cgContext.makeImage() else {
            throw AppexError.renderFailed
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: pointSize, height: pointSize))
    }

    // MARK: - Errors

    enum AppexError: LocalizedError {
        case sourceBundleNotFound
        case invalidPlistStructure
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .sourceBundleNotFound: "Storage.appex not found at system path"
            case .invalidPlistStructure: "Info.plist missing required ISGraphicIconConfiguration"
            case .renderFailed: "Failed to render reference icon"
            }
        }
    }
}
