import ArgumentParser
import CoreGraphics

enum IconColorSpace: String, CaseIterable, ExpressibleByArgument {
    case displayP3 = "displayP3"
    case sRGB = "sRGB"

    func makeColorSpace() throws -> CGColorSpace {
        guard let space = CGColorSpace(name: cgSpaceName) else {
            throw CLIError.configurationError("Failed to load color space: \(rawValue)")
        }
        return space
    }

    private var cgSpaceName: CFString {
        switch self {
        case .displayP3:
            return CGColorSpace.displayP3
        case .sRGB:
            return CGColorSpace.sRGB
        }
    }
}
