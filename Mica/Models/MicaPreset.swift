// Models/MicaPreset.swift
//
// A preset: a named, scope-complete set of configuration keys.
//
// **A preset is a `MicaConfig` file plus an envelope.** The keys are the existing
// codec's, unchanged — `MicaConfigCodec.decode` is what turns them into settings,
// so a preset can say exactly what a configuration can say and nothing more. The
// envelope carries the two things that are *not* configuration keys and cannot be:
// the display name and the scope.
//
// ## Scope-complete
//
// A preset replaces its whole scope. A key absent from one decodes to its
// **default**, never to whatever the user currently has. Without that rule,
// clicking preset A then B gives a different icon than clicking B alone, and the
// residue accumulates invisibly. Decoding through the codec is what makes it free:
// the codec already resolves an absent key to its default, so
// `PresetApplication.apply` has only to copy the scope across wholesale.
//
// The corollary is that a genuinely flat preset must carry `"icon-bg-gradient":
// false` explicitly — `IconBackgroundSpec().usesGradient` is `true`, so omitting it
// means the default, which is *on*.
//
// ## Why the key namespace makes this cheap
//
// Every `MicaConfigKey` is `icon-*`, `badge-*`, or one of the three export keys, and
// `ConfigReader.apply()` writes each family into exactly one branch of
// `IconSettings` — `icon-*` into `settings.icon`, `badge-*` into `settings.badge`,
// the rest into `settings.export`. So the scopes below are a partition of the key
// vocabulary *and* of the settings tree, and **presets never touch export settings**
// falls straight out of that rather than needing a rule.
//
// ## Both scopes carry their symbol
//
// `icon-fg` and `badge-fg` are part of a preset: click one and you get what the
// thumbnail showed. Style-only presets (restyle whatever glyph you already have)
// were considered and declined — under scope-complete an absent `icon-fg` already
// means "reset to the default", so absence cannot also mean "keep mine", and the
// badge is worse still because activation keys off the *presence* of `badge-fg`.
// The CLI gets style-only behaviour for free anyway, because a preset applies
// before the flags that override it: `--icon-preset media --icon-symbol hammer.fill`.
//
// Shared with `mica-cli`, so this is one of the paths named in both
// `membershipExceptions` lists.

import Foundation

// MARK: - Scope

/// Which half of an icon a preset replaces.
///
/// The same division the sidebar and the inspector already make, and the same one
/// the key namespace makes. There is deliberately no whole-icon scope: an icon
/// preset that also carried a badge would have to say something about a badge the
/// user may not want, and "no badge" is not a thing the badge namespace can say
/// without `badge-visibility`, which is decode-only.
enum PresetScope: String, CaseIterable, Codable, Sendable, Identifiable {
    case icon
    case badge

    var id: String { rawValue }

    /// The keys this scope owns. Read as a predicate rather than a list at the one
    /// place it matters (`MicaPreset.unscopedKeys`), so a key added to
    /// `MicaConfigKey` joins the right scope without a second list to update.
    func owns(_ key: MicaConfigKey) -> Bool {
        switch self {
        case .icon:  return key.rawValue.hasPrefix("icon-")
        case .badge: return key.isBadgeKey
        }
    }

    /// The undo action name an apply registers. Distinct per scope, because undoing
    /// an icon preset and undoing a badge preset are different things to be told.
    var undoActionName: String {
        switch self {
        case .icon:  return "Apply Icon Preset"
        case .badge: return "Apply Badge Preset"
        }
    }
}

// MARK: - Values

/// A configuration value as a preset stores it.
///
/// Deliberately not `Any`. A preset round-trips through `JSONSerialization` on its
/// way into the codec, and the four cases here are exactly what the codec's typed
/// readers accept: a string, a JSON boolean (which `ToggleState` also accepts as
/// `"on"`/`"off"`), a JSON number, and the array form of the four multi-colour keys
/// — the form that finally admits comma-containing colours like `extended-srgb:`.
enum MicaPresetValue: Equatable, Sendable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case strings([String])

    /// The `JSONSerialization`-compatible value.
    var jsonObject: Any {
        switch self {
        case .string(let value):  return value
        case .bool(let value):    return value
        case .number(let value):  return value
        case .strings(let value): return value
        }
    }

    /// Read back from a decoded JSON object. Returns nil for anything the codec
    /// could not read either — null, a nested object, a mixed array — so a
    /// malformed user preset loses the one key rather than the whole file.
    init?(json: Any) {
        // Order matters: `JSONSerialization` surfaces booleans and numbers alike as
        // `NSNumber`, and only a CFBoolean is a boolean. Without this check a
        // `true` would store as `1` and `toggle()` would then reject it.
        if let number = json as? NSNumber, CFGetTypeID(json as CFTypeRef) == CFBooleanGetTypeID() {
            self = .bool(number.boolValue)
        } else if let string = json as? String {
            self = .string(string)
        } else if let number = json as? NSNumber {
            self = .number(number.doubleValue)
        } else if let array = json as? [String] {
            self = .strings(array)
        } else {
            return nil
        }
    }
}

// MARK: - The preset

/// A named set of configuration keys, scoped to the icon or the badge.
struct MicaPreset: Equatable, Identifiable, Sendable {
    /// The display name. For a built-in this is a literal in `PresetCatalog`, so it
    /// reaches the string catalog through `localizedFromCatalog`; for a user preset
    /// it is whatever they typed and is shown verbatim. **Never put either in
    /// `Text(_:)` directly** — that call site takes the verbatim overload for a
    /// `String` and silently skips the catalog.
    var name: String

    /// Which half of the icon this replaces.
    var scope: PresetScope

    /// The configuration keys, as the codec's own key strings. Keys outside the
    /// scope are tolerated on the way in and dropped — see `unscopedKeys`.
    var keys: [String: MicaPresetValue]

    /// False for a preset the user saved. Built-ins cannot be renamed or deleted,
    /// and their names go through the string catalog.
    var isBuiltIn: Bool

    /// Stable across a rename only for built-ins, which never rename. A user preset
    /// is identified by its name within its scope, which is also what the store's
    /// filenames encode — see `UserPresetStore`.
    var id: String { "\(isBuiltIn ? "builtin" : "user").\(scope.rawValue).\(name)" }

    init(name: String, scope: PresetScope, keys: [String: MicaPresetValue], isBuiltIn: Bool = false) {
        self.name = name
        self.scope = scope
        self.keys = keys
        self.isBuiltIn = isBuiltIn
    }

    // MARK: Scope hygiene

    /// Keys this preset carries that its scope does not own.
    ///
    /// Never empty for a well-formed preset. It is checked rather than assumed
    /// because a preset can arrive from a file a user edited by hand: an `icon-*`
    /// key in a badge preset would be applied by the codec and then dropped by the
    /// scoped copy, which is silent. `PresetCatalogTests` pins the built-ins at
    /// zero, and `UserPresetStore` warns for the rest.
    var unscopedKeys: [String] {
        keys.keys
            .filter { name in
                guard let key = MicaConfigKey(rawValue: name) else { return true }
                return !scope.owns(key)
            }
            .sorted()
    }

    /// The keys as a JSON object the codec can decode.
    var jsonObject: [String: Any] {
        keys.mapValues(\.jsonObject)
    }
}
