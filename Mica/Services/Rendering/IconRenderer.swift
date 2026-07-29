// IconRenderer.swift - Renders an IconSettings to an NSImage for export
//
// The export entry points and the supersampling/downsampling that makes small
// exports land on integer pixel bounds. The views it renders are
// `IconContentView` and `BadgeView`, in this folder.
import SwiftUI
import CoreGraphics

struct IconRenderer {
    /// Integer supersampling factor for a nominal export pixel size. Exports
    /// below 1024px are rendered at the smallest integer multiple that reaches
    /// 1024 and downsampled. At 1x, shape frames are snapped to integral pixel
    /// bounds while Core Text rounds SF Symbol glyph origins independently —
    /// the two can disagree by up to a full device pixel, which reads as an
    /// off-centre symbol (worst on badges at small sizes). Supersampling keeps
    /// that mismatch sub-pixel in the output.
    static func supersampleFactor(forPixelSize pixelSize: CGFloat) -> Int {
        guard pixelSize > 0, pixelSize < 1024 else { return 1 }
        return Int((1024 / pixelSize).rounded(.up))
    }

    // Public entry – must run on MainActor due to SwiftUI/ImageRenderer isolation
    @MainActor
    static func renderIcon(settings: IconSettings, badgeAppexImage: NSImage? = nil) -> NSImage {
        let exportSize = settings.export.pixelSize
        let iconView = IconContentView(settings: settings, displaySize: exportSize, badgeAppexImage: badgeAppexImage)
            .frame(width: exportSize, height: exportSize)

        let factor = supersampleFactor(forPixelSize: exportSize)
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = CGFloat(factor)
        renderer.isOpaque = false

        if let nsImage = renderer.nsImage {
            let colorSpaceConverted = convertToColorSpace(
                image: nsImage,
                colorSpace: settings.export.colorSpace,
                downsampleFactor: factor
            )
            return setImageDPI(image: colorSpaceConverted, settings: settings)
        }
        return NSImage(size: CGSize(width: exportSize, height: exportSize))
    }

    /// Render an appex base image with a badge overlay composited on top.
    @MainActor
    static func renderAppexWithBadge(
        appexImage: NSImage,
        settings: IconSettings,
        badgeAppexImage: NSImage? = nil
    ) -> NSImage {
        let exportSize = settings.export.pixelSize
        let scaleFactor = exportSize / 256.0
        let backgroundInset = 25 * scaleFactor
        let enclosureSize = exportSize - 2 * backgroundInset
        let badgeSize = BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badge.scale)

        let compositeView = ZStack {
            // Mirrors the Mica path: a hidden icon group isn't drawn, leaving just
            // the badge on a transparent canvas.
            if !settings.icon.isHidden {
                Image(nsImage: appexImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: exportSize, height: exportSize)
            } else {
                Color.clear
                    .frame(width: exportSize, height: exportSize)
            }

            if settings.badge.isVisible {
                BadgeView(
                    settings: settings,
                    badgeSize: badgeSize,
                    badgeAppexImage: badgeAppexImage
                )
                .offset(BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize))
            }
        }
        .frame(width: exportSize, height: exportSize)

        // Supersample only when a badge overlay is drawn — without one the view
        // is a straight passthrough of the appex raster, and an upsample/downsample
        // round trip would soften it for no benefit.
        let factor = settings.badge.isVisible ? supersampleFactor(forPixelSize: exportSize) : 1
        let renderer = ImageRenderer(content: compositeView)
        renderer.scale = CGFloat(factor)
        renderer.isOpaque = false

        if let nsImage = renderer.nsImage {
            let colorSpaceConverted = convertToColorSpace(
                image: nsImage,
                colorSpace: settings.export.colorSpace,
                downsampleFactor: factor
            )
            return setImageDPI(image: colorSpaceConverted, settings: settings)
        }
        return NSImage(size: CGSize(width: exportSize, height: exportSize))
    }

    // Thread-safe wrapper that hops to the main queue when needed
    static func renderIconSafely(settings: IconSettings, badgeAppexImage: NSImage? = nil) -> NSImage {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { renderIcon(settings: settings, badgeAppexImage: badgeAppexImage) }
        }
        var output = NSImage(size: CGSize(width: settings.export.pixelSize, height: settings.export.pixelSize))
        DispatchQueue.main.sync {
            output = MainActor.assumeIsolated { renderIcon(settings: settings, badgeAppexImage: badgeAppexImage) }
        }
        return output
    }

    // MARK: - Color space and DPI helpers
    static func setImageDPI(image: NSImage, settings: IconSettings) -> NSImage {
        guard let originalCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        // Logical size derives from the actual raster and the export scale rather
        // than settings.export.size, so a supersampled render that has already been
        // reduced isn't re-labelled with a point size it no longer has.
        let scale: CGFloat = settings.export.isRetina ? 2 : 1
        let logicalSize = CGSize(
            width: CGFloat(originalCGImage.width) / scale,
            height: CGFloat(originalCGImage.height) / scale
        )
        let newImage = NSImage(size: logicalSize)
        let bitmapRep = NSBitmapImageRep(cgImage: originalCGImage)
        bitmapRep.size = logicalSize
        newImage.addRepresentation(bitmapRep)
        return newImage
    }

    static func convertToColorSpace(image: NSImage, colorSpace: ExportColorSpace, downsampleFactor: Int = 1) -> NSImage {
        guard let originalCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        // Use the bitmap's own pixel dimensions rather than the logical size,
        // which can be fractional at a retina scale and would resample the whole
        // image into a context up to 1px smaller. A supersampled render is the
        // exception: it is deliberately reduced by its integer factor here, so
        // conversion and downsample are one pass.
        let width: Int
        let height: Int
        if downsampleFactor > 1 {
            width = Int((Double(originalCGImage.width) / Double(downsampleFactor)).rounded())
            height = Int((Double(originalCGImage.height) / Double(downsampleFactor)).rounded())
        } else {
            width = originalCGImage.width
            height = originalCGImage.height
        }

        let targetCGColorSpace: CGColorSpace = {
            switch colorSpace {
            case .sRGB: return CGColorSpace(name: CGColorSpace.sRGB)!
            case .displayP3: return CGColorSpace(name: CGColorSpace.displayP3)!
            }
        }()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: targetCGColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.interpolationQuality = .high
        context.draw(originalCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let newCGImage = context.makeImage() else { return image }
        return NSImage(cgImage: newCGImage, size: image.size)
    }
}
