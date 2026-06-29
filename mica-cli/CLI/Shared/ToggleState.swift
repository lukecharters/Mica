import ArgumentParser

/// A two-state `on|off` toggle taken as an option value (rather than a boolean
/// flag) so the redesigned `mica-cli` surface reads consistently, e.g.
/// `--icon-fg-shadow on` / `--icon-symbol-gradient off`. Shared by every
/// foreground/background/badge toggle across the `generate` subcommand.
enum ToggleState: String, CaseIterable, ExpressibleByArgument {
    case on
    case off

    /// Whether this toggle is enabled.
    var isOn: Bool { self == .on }

    /// Build a toggle from a resolved boolean (used when mapping defaults that
    /// depend on other flags, e.g. shadow defaults that vary by icon source).
    init(_ isOn: Bool) { self = isOn ? .on : .off }
}
