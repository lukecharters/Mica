import ArgumentParser

/// Output resolution multiplier shared by every `mica-cli` subcommand.
/// `1x` renders at the requested pixel size; `2x` doubles it (retina).
enum ExportScale: String, CaseIterable, ExpressibleByArgument {
    case oneX = "1x"
    case twoX = "2x"

    /// Integer multiplier applied to the base pixel size.
    var factor: Int { self == .twoX ? 2 : 1 }

    /// The scale matching `ExportSpec`'s default, so `--scale`'s documented
    /// default is derived from the settings rather than restated as a literal.
    static var settingsDefault: ExportScale { ExportSpec().isRetina ? .twoX : .oneX }
}
