// App/IconViewModel+Configuration.swift
//
// Where the view model meets the JSON configuration format: the four System-mode
// colours as one value, which is what makes them observable as a unit.
//
// Import lands here too (Phase 8). It is deliberately not a per-property copy — an
// import is one thing the user did, so it registers one undo step, which is why
// `isInstallingImportedConfiguration` exists on the view model.

import SwiftUI

extension IconViewModel {
    /// The four System-mode colours as one value. They sit on this object rather than
    /// in `IconSettings` — the renderer takes them separately, and the CLI carries them
    /// on `GenerationContext` for the same reason.
    ///
    /// Grouping them matters for undo: `ContentView` observes *this*, so the four
    /// `@Published` properties produce one change to compare rather than four
    /// independent ones, and `MicaAppexColors: Equatable` is what tells a real edit from
    /// a no-op write.
    var micaAppexColors: MicaAppexColors {
        get {
            MicaAppexColors(
                iconEnclosure: appexEnclosureColor,
                iconSymbol: appexSymbolColor,
                badgeEnclosure: badgeAppexEnclosureColor,
                badgeSymbol: badgeAppexSymbolColor
            )
        }
        set {
            appexEnclosureColor = newValue.iconEnclosure
            appexSymbolColor = newValue.iconSymbol
            badgeAppexEnclosureColor = newValue.badgeEnclosure
            badgeAppexSymbolColor = newValue.badgeSymbol
        }
    }
}
