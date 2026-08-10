// App/LocalizedFromCatalog.swift
//
// Looking up a string catalog with a key that is *computed* rather than written.
//
// Three families of Mica's user-facing text are built at run time rather than
// spelled as literals, and none of them can go through `String(localized:)` or
// `Text("…")`:
//
// 1. `ColorToken.displayName`, derived from the token name by title-casing it —
//    deliberately, so there is no second hand-written list of colour names to
//    drift out of step with `ColorTokenTable`.
// 2. The undo action names in `SettingsChange`, half of which interpolate an
//    "Icon"/"Badge" subject into a shared template.
// 3. The sentence fragments `IconAccessibilityDescription` assembles for
//    VoiceOver.
//
// **`String(localized:)` cannot express any of them.** Its argument is a
// `String.LocalizationValue`, whose key must be a literal; interpolating a
// variable into one produces a `%@` substitution — a *different* key, with the
// variable as an argument — rather than the key you meant. So these sites need
// the plain bundle lookup, which takes a runtime `String`.
//
// **The catalog entries for these keys are marked `"extractionState": "manual"`**
// in `Localizable.xcstrings`. Xcode's extractor only sees literals, so it would
// otherwise report every one of them as stale and offer to delete them.

import Foundation

extension String {

    /// This string looked up in the app's string catalog, falling back to itself.
    ///
    /// The fallback is what makes it safe to call on strings that have no entry:
    /// only the ~30 keys that actually differ between English variants are in the
    /// catalog, and everything else resolves to the source spelling it already is.
    var localizedFromCatalog: String {
        Bundle.main.localizedString(forKey: self, value: self, table: nil)
    }
}
