import Foundation

/// The version `mica-cli --version` reports.
///
/// It is read from the bundle rather than written here, because `mica-cli` ships
/// inside `Mica.app/Contents/MacOS` — an executable there makes CFBundle resolve
/// the enclosing `.app`, which is the same mechanism that finds
/// `symbol-calibration.json`. So `Bundle.main.infoDictionary` is the app's, and
/// `MARKETING_VERSION` is the single source of truth for both surfaces.
///
/// It was a string literal in `MicaCLI.swift` until 2026-08-19, and it had
/// already drifted: `0.1.0` against an app at `0.1`. Nothing could catch that —
/// the `mica-cli` target carries no `MARKETING_VERSION` of its own, so there was
/// no second value to disagree with.
enum CLIVersion {
    /// What to report when no bundle carries a version.
    ///
    /// Deliberately **not** a plausible version number. Falling back to one would
    /// reintroduce exactly the literal this type exists to remove, and it would
    /// look correct while being wrong. The only way to reach this is the loose
    /// build product, which carries no `Info.plist` — and which already renders
    /// symbols at the wrong size for the same missing-resources reason, so a
    /// visible marker here is a second chance to notice.
    static let unbundled = "unknown (unbundled)"

    /// The version of the bundle this binary is running from.
    static var current: String { resolve(infoDictionary: Bundle.main.infoDictionary) }

    /// - Parameter infoDictionary: `Bundle.infoDictionary`, or nil when there is no bundle.
    static func resolve(infoDictionary: [String: Any]?) -> String {
        guard let version = infoDictionary?["CFBundleShortVersionString"] as? String,
              !version.isEmpty
        else {
            return unbundled
        }
        return version
    }
}
