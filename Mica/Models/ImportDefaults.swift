// Models/ImportDefaults.swift
import Foundation

/// The two guesses Mica makes when a *background* image is imported: hide that
/// group's foreground, and turn the icon's corner radius off.
///
/// Both are guesses at something the file cannot tell us, so both are
/// preferences in the GUI — see §5 of
/// the visibility-and-imported-backgrounds plan. This type is
/// how that preference reaches `IconSpec.applyBackgroundImage(_:defaults:)`
/// without either spec reading `UserDefaults` itself.
///
/// **The split across targets is the enforcement, not a convention.** This file
/// lives in `Models/`, which the CLI compiles, and carries only `.fixed`.
/// `.fromPreferences()` lives in `App/`, which the CLI does not compile — so a
/// CLI or configuration path *cannot* read the preference, rather than merely
/// being asked not to. That matters because a `UserDefaults` value reaching
/// `MicaConfigCodec`'s decode baselines would make one configuration decode to
/// two different icons on two machines, and `mica-cli` would stop being
/// reproducible.
///
/// `.fixed` is the default argument at both seams, so the CLI and the codec get
/// the fixed rule by not mentioning it rather than by remembering to.
struct ImportDefaults: Equatable {
    /// Hide the imported background's own group foreground.
    var hidesForeground: Bool
    /// Set `IconCornerRadiusStyle.off`. Icon-only — the badge has no corner
    /// radius, its shape coming from `BadgeGeometry.badgeCornerRadiusRatio` or
    /// from imported artwork's own alpha.
    var turnsOffCornerRadius: Bool

    /// What every non-interactive path uses, and what the codec's decode
    /// baselines and the CLI's rules encode. **Do not make this configurable.**
    static let fixed = ImportDefaults(hidesForeground: true, turnsOffCornerRadius: true)
}
