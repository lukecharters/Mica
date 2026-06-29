import ArgumentParser

/// Output resolution multiplier shared by every `mica-cli` subcommand.
/// `1x` renders at the requested pixel size; `2x` doubles it (retina).
enum ExportScale: String, CaseIterable, ExpressibleByArgument {
    case oneX = "1x"
    case twoX = "2x"

    /// Integer multiplier applied to the base pixel size.
    var factor: Int { self == .twoX ? 2 : 1 }
}
