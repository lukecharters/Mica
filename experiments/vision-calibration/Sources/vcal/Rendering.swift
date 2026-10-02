import AppKit
import SwiftUI

struct IconParams: Codable, Equatable, Sendable {
    var multiplier: Double
    var xOffset: Double
    var yOffset: Double
    var weight: String

    static let weightTokens = ["regular", "medium", "semibold", "bold"]

    var weightIndex: Int { Self.weightTokens.firstIndex(of: weight) ?? 0 }

    func withWeight(index: Int) -> IconParams {
        var copy = self
        copy.weight = Self.weightTokens[min(max(index, 0), Self.weightTokens.count - 1)]
        return copy
    }

    var fontWeight: Font.Weight {
        switch weight {
        case "medium": .medium
        case "semibold": .semibold
        case "bold": .bold
        default: .regular
        }
    }

    var short: String {
        String(format: "m=%.3f x=%+.3f y=%+.3f %@", multiplier, xOffset, yOffset, weight)
    }
}

/// Geometry of `DimIconView` in `Mica/DevTools/SymbolCalibrationTool.swift`, the view every
/// hand-calibrated entry was judged against. Keep the two in step.
enum IconGeometry {
    static let pointSize: CGFloat = 512
    static let scale: CGFloat = 2
    static let baseSize: CGFloat = 256
    static let baseInset: CGFloat = 25
    static let baseCornerRadius: CGFloat = 53

    static func enclosure(forDisplaySize size: CGFloat) -> CGFloat {
        size - 2 * baseInset * size / baseSize
    }
}

private struct CalibrationIconView: View {
    let symbolName: String
    let params: IconParams

    var body: some View {
        let size = IconGeometry.pointSize
        let scale = size / IconGeometry.baseSize
        let inset = IconGeometry.baseInset * scale
        let enclosure = IconGeometry.enclosure(forDisplaySize: size)
        ZStack {
            RoundedRectangle(cornerRadius: IconGeometry.baseCornerRadius * scale, style: .continuous)
                .fill(Color.blue.gradient)
                .padding(inset)
            Image(systemName: symbolName)
                .font(.system(size: enclosure * params.multiplier, weight: params.fontWeight))
                .foregroundColor(.white)
                .offset(x: enclosure * params.xOffset, y: enclosure * params.yOffset)
        }
        .frame(width: size, height: size)
    }
}

@MainActor
enum MicaRenderer {
    static func render(_ symbol: String, _ params: IconParams) -> CGImage? {
        let renderer = ImageRenderer(content: CalibrationIconView(symbolName: symbol, params: params))
        renderer.scale = IconGeometry.scale
        return renderer.cgImage
    }
}

/// Apple's own rendering, made the way `AppexReferenceService` makes it: a copy of
/// Storage.appex with its `ISSymbolName` rewritten, read back through NSWorkspace.
enum AppexReference {
    static let sourceBundle = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions/Storage.appex")

    /// IconServices draws the variant for the *system* appearance: in dark mode a blue enclosure
    /// becomes a dark one with a blue glyph. Neither the drawing appearance nor the process's
    /// `NSApp.appearance` changes that, so a render is refused when the system does not match.
    static func render(_ symbol: String, enclosure: String = "blue", symbolColour: String = "white",
                       appearance: NSAppearance.Name = .aqua, cacheDirectory: URL) throws -> CGImage {
        let mode = appearance == .darkAqua ? "dark" : "light"
        let cached = cacheDirectory.appendingPathComponent("\(mode)/\(symbol)@\(enclosure)+\(symbolColour).png")
        if let image = PNG.read(cached) { return image }
        let systemMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? "dark" : "light"
        guard systemMode == mode else {
            throw HarnessError("asked for a \(mode) reference but the system is in \(systemMode) mode; switch it in System Settings ▸ Appearance")
        }

        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("vcal-" + UUID().uuidString).appendingPathExtension("appex")
        try FileManager.default.copyItem(at: sourceBundle, to: workspace)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let plistURL = workspace.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: plistURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              var icons = plist["CFBundleIcons"] as? [String: Any],
              var config = icons["ISGraphicIconConfiguration"] as? [String: Any]
        else { throw HarnessError("Storage.appex Info.plist has no ISGraphicIconConfiguration") }
        config["ISSymbolName"] = symbol
        config["ISEnclosureColor"] = enclosure
        config["ISSymbolColor"] = symbolColour
        icons["ISGraphicIconConfiguration"] = config
        plist["CFBundleIcons"] = icons
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: plistURL)

        guard let icon = NSWorkspace.shared.icon(forFile: workspace.path).copy() as? NSImage else {
            throw HarnessError("NSWorkspace returned no icon for \(symbol)")
        }
        let pixels = Int(IconGeometry.pointSize * IconGeometry.scale)
        guard let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw HarnessError("could not make a context") }
        context.interpolationQuality = .high
        context.scaleBy(x: IconGeometry.scale, y: IconGeometry.scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let rect = NSRect(x: 0, y: 0, width: IconGeometry.pointSize, height: IconGeometry.pointSize)
        icon.size = rect.size
        icon.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage() else { throw HarnessError("could not read back the icon") }
        try PNG.write(image, to: cached)
        return image
    }
}

enum PNG {
    static func read(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func write(_ image: CGImage, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw HarnessError("could not write \(url.path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw HarnessError("could not write \(url.path)") }
    }
}

struct HarnessError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
