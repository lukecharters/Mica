// Models/MicaAppexColors.swift
//
// The four System-mode colours travel beside `IconSettings` rather than inside it:
// they live on `IconViewModel` in the GUI and on `GenerationContext` in the CLI, so
// anything that carries a whole configuration — the JSON config format, the CLI's
// `--config` base — needs this struct alongside the settings, or a System-mode
// configuration would come back in the wrong colours.

import Foundation

/// The four System-mode colours, which `IconSettings` does not hold.
struct MicaAppexColors: Equatable, Sendable {
    var iconEnclosure: AppexColor = .blue
    var iconSymbol: AppexColor = .white
    var badgeEnclosure: AppexColor = .blue
    var badgeSymbol: AppexColor = .white

    init(
        iconEnclosure: AppexColor = .blue,
        iconSymbol: AppexColor = .white,
        badgeEnclosure: AppexColor = .blue,
        badgeSymbol: AppexColor = .white
    ) {
        self.iconEnclosure = iconEnclosure
        self.iconSymbol = iconSymbol
        self.badgeEnclosure = badgeEnclosure
        self.badgeSymbol = badgeSymbol
    }
}
