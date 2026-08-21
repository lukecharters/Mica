// Services/DeveloperToolsPreference.swift
import Foundation

/// The one switch behind the Developer menu — and behind the calibration
/// override, which is why it is here rather than in `App/`.
///
/// **`Services/`, not `App/`, because `SymbolSizingService` reads it**, and that
/// file is compiled by the CLI targets too. The alternative was a second copy of
/// the key string in whichever file could not see the first, which is exactly how
/// a preference ends up written under one name and read under another.
///
/// In the CLI's process it is always false: nothing there sets it, and nothing
/// there should — `mica-cli` renders with the calibration Mica shipped. That is
/// already what happens today, the container copy being unreachable from an
/// unsandboxed process, so the gate changes nothing for it.
enum DeveloperToolsPreference {
    /// Off when absent, which `bool(forKey:)` gives for free — and off is the
    /// answer that has to be free, since it is what everyone who never opts in
    /// gets.
    ///
    /// The key is a shipped name: changing it silently resets the preference for
    /// anyone who has already turned the tools on.
    static let enabledKey = "developer.toolsEnabled"

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }
}
