// App/SettingsChange.swift
//
// Which single setting a mutation changed. Two jobs, both wanted at the same moment:
//
// 1. **The undo action name** the Edit menu shows — "Undo Change Symbol Color" rather
//    than a bare "Undo".
// 2. **A stable coalescing key**, so the many changes a slider drag produces can be
//    recognised as one continuous edit of one setting.
//
// Deriving both from a *diff* is what keeps this out of the hundreds of bindings that
// write these values. `ContentView` already observes `iconSettings` centrally for undo
// (see `IconViewModel+Undo.swift`); naming the change is one more thing that
// observation can answer, and it cannot fall out of step with the bindings because
// there is nothing at the bindings to keep in step.
//
// **A new stored property must be added to `fields` below.**
// `SettingsChangeTests.everyStoredPropertyIsNamed` reflects over `IconSettings` and
// fails until the count matches, for the same reason
// `MicaConfigTests.storedPropertyCountIsPinned` does: an unnamed setting is not a
// compile error, it is a setting that silently undoes as the generic "Change
// Settings" and never coalesces.

import SwiftUI

/// The single setting a mutation changed, or the generic stand-in for a bulk edit.
struct SettingsChange: Equatable {
    /// Stable identity of the changed setting — `icon.foreground.color`. Not
    /// user-visible: this is what decides whether two consecutive changes are the
    /// same continuous edit.
    let key: String

    /// The undo action name, as the Edit menu shows it after "Undo " / "Redo ".
    let name: String

    /// True when more than one setting changed at once — an image import, a reset to
    /// the simple controls, a configuration being imported. Such a change is named
    /// generically and **never** coalesced by the same-key time window: two unrelated
    /// bulk edits would share the key and wrongly collapse into one undo step. A
    /// gesture that declares itself may still coalesce (the badge drag writes both
    /// offsets every frame, so every one of its frames is a bulk change).
    var isBulk: Bool { key == Self.bulkKey }

    /// True when this change came from a text field the user may still be typing in —
    /// in practice the two symbol-name fields, the only settings-bound `TextField` in
    /// the app.
    ///
    /// **Deliberately unused, and deliberately kept.** It exists because SwiftUI's
    /// `TextField` does not give up first-responder status when the user works another
    /// control, and while it holds on, its *field editor* owns the Edit menu: ⌘Z undoes
    /// typing rather than the switch that was just flipped, and the menu reads "Undo
    /// Typing" over the top of the real action name. The fix is to end text editing on
    /// seeing any change that is *not* one of these — which is what this predicate is
    /// for, and which is exactly what this app does not do.
    ///
    /// Two fixes were built and both cost a visible animation delay on every control
    /// interaction: resigning the responder through AppKit (`makeFirstResponder(nil)`)
    /// fights SwiftUI, which restores focus it still believes in; clearing SwiftUI's own
    /// `@FocusState` from an environment counter reduced the delay but did not remove
    /// it. On 2026-08-01 the user chose to ship the undo defect rather than the delay.
    /// So the field keeps focus, and this predicate waits for an approach that costs
    /// nothing. Do not wire it up again without asking.
    ///
    /// A bulk change is deliberately *not* a text-field edit — an import or a reset is
    /// exactly the kind of "moved on" this is for.
    var isTextFieldEdit: Bool { key.hasSuffix(Self.textFieldKeySuffix) }

    private static let bulkKey = "*"

    /// `SettingsChangeTests.onlySymbolNameIsATextFieldEdit` pins this against the whole
    /// field table, so a second text-bound setting cannot quietly fail to match.
    private static let textFieldKeySuffix = ".symbolName"

    /// Named for the Edit menu's benefit; the user did do one thing, even though the
    /// diff cannot say which single setting it was.
    static let bulk = SettingsChange(key: bulkKey, name: "Change Settings")

    /// The one field that differs, `bulk` when several do, `nil` when nothing does.
    ///
    /// `nil` matters: SwiftUI's `onChange` can fire with an equal value, and
    /// registering an undo for a non-change would put a step on the stack for nothing.
    ///
    /// `@MainActor` because `fields` is: see the note there.
    @MainActor
    static func between(_ old: IconSettings, _ new: IconSettings) -> SettingsChange? {
        var found: SettingsChange?
        for field in fields where field.differs(old, new) {
            guard found == nil else { return bulk }
            found = SettingsChange(key: field.key, name: field.name(new))
        }
        return found
    }
}

// MARK: - The field table

/// One named, comparable setting. Built from a `KeyPath` so an entry is a one-liner
/// and cannot disagree with itself about which property it describes.
struct SettingField {
    let key: String
    let name: (IconSettings) -> String
    let differs: (IconSettings, IconSettings) -> Bool

    init<V: Equatable>(_ key: String, _ name: String, _ path: KeyPath<IconSettings, V>) {
        self.key = key
        self.name = { _ in name }
        self.differs = { $0[keyPath: path] != $1[keyPath: path] }
    }

    /// A visibility flag, named for what it is about to do: "Hide Badge Background"
    /// reads far better in the Edit menu than "Change Badge Background Visibility".
    /// Takes the *new* settings, so the name describes the change being registered.
    init(_ key: String, visibilityOf subject: String, _ path: KeyPath<IconSettings, Bool>) {
        self.key = key
        self.name = { $0[keyPath: path] ? "Hide \(subject)" : "Show \(subject)" }
        self.differs = { $0[keyPath: path] != $1[keyPath: path] }
    }
}

@MainActor
extension SettingsChange {

    /// Every stored property of `IconSettings`, in field order.
    ///
    /// The two foreground groups are generated from one list, because `ForegroundSpec`
    /// is shared: a new foreground setting is named once and both groups get it, which
    /// is the same reason the spec is shared in the first place.
    ///
    /// `@MainActor` rather than `Sendable`: these are closures over `KeyPath`s into
    /// `IconSettings`, which is not `Sendable`, and undo is main-actor work throughout —
    /// the observers that ask for a change name are `@MainActor`, as is every mutation
    /// they describe. Marking the table instead of laundering the model's isolation is
    /// the honest version.
    static let fields: [SettingField] =
        exportFields
        + [SettingField("icon.mode", "Change Icon Generation Mode", \.icon.mode)]
        + foregroundFields("icon.foreground", "Icon", \.icon.foreground)
        + iconBackgroundFields
        + badgeGroupFields
        + foregroundFields("badge.foreground", "Badge", \.badge.foreground)
        + badgeBackgroundFields

    private static let exportFields: [SettingField] = [
        SettingField("export.size", "Change Export Size", \.export.size),
        SettingField("export.isRetina", "Change Retina Scale", \.export.isRetina),
        SettingField("export.colorSpace", "Change Color Space", \.export.colorSpace),
    ]

    private static let badgeGroupFields: [SettingField] = [
        SettingField("badge.position", "Change Badge Position", \.badge.position),
        SettingField("badge.scale", "Change Badge Size", \.badge.scale),
        SettingField("badge.offsetX", "Change Badge X Offset", \.badge.offsetX),
        SettingField("badge.offsetY", "Change Badge Y Offset", \.badge.offsetY),
    ]

    /// 17 fields, one per `ForegroundSpec` stored property.
    private static func foregroundFields(
        _ prefix: String, _ subject: String, _ base: KeyPath<IconSettings, ForegroundSpec>
    ) -> [SettingField] {
        [
            SettingField("\(prefix).source", "Change \(subject) Foreground Type",
                         base.appending(path: \.source)),
            SettingField("\(prefix).symbolName", "Change \(subject) Symbol",
                         base.appending(path: \.symbolName)),
            SettingField("\(prefix).symbolWeight", "Change \(subject) Symbol Weight",
                         base.appending(path: \.symbolWeight)),
            SettingField("\(prefix).symbolScale", "Change \(subject) Symbol Scale",
                         base.appending(path: \.symbolScale)),
            SettingField("\(prefix).image", "Change \(subject) Foreground Image",
                         base.appending(path: \.image)),
            SettingField("\(prefix).imageScale", "Change \(subject) Foreground Image Scale",
                         base.appending(path: \.imageScale)),
            SettingField("\(prefix).offsetX", "Change \(subject) Foreground X Offset",
                         base.appending(path: \.offsetX)),
            SettingField("\(prefix).offsetY", "Change \(subject) Foreground Y Offset",
                         base.appending(path: \.offsetY)),
            SettingField("\(prefix).color", "Change \(subject) Symbol Color",
                         base.appending(path: \.color)),
            SettingField("\(prefix).renderingStyle", "Change \(subject) Symbol Rendering",
                         base.appending(path: \.renderingStyle)),
            SettingField("\(prefix).fillStyle", "Change \(subject) Symbol Fill",
                         base.appending(path: \.fillStyle)),
            SettingField("\(prefix).hierarchicalColor", "Change \(subject) Hierarchical Color",
                         base.appending(path: \.hierarchicalColor)),
            SettingField("\(prefix).palettePrimaryColor", "Change \(subject) Palette Primary Color",
                         base.appending(path: \.palettePrimaryColor)),
            SettingField("\(prefix).paletteSecondaryColor", "Change \(subject) Palette Secondary Color",
                         base.appending(path: \.paletteSecondaryColor)),
            SettingField("\(prefix).paletteTertiaryColor", "Change \(subject) Palette Tertiary Color",
                         base.appending(path: \.paletteTertiaryColor)),
            SettingField("\(prefix).drawsShadow", "Change \(subject) Symbol Shadow",
                         base.appending(path: \.drawsShadow)),
            SettingField("\(prefix).isHidden", visibilityOf: "\(subject) Foreground",
                         base.appending(path: \.isHidden)),
        ]
    }

    /// 12 fields. One more than the badge's — the corner radius.
    private static let iconBackgroundFields: [SettingField] = [
        SettingField("icon.background.source", "Change Icon Background Type",
                     \.icon.background.source),
        SettingField("icon.background.color", "Change Icon Background Color",
                     \.icon.background.color),
        SettingField("icon.background.usesGradient", "Change Icon Background Gradient",
                     \.icon.background.usesGradient),
        SettingField("icon.background.usesCustomGradient", "Change Icon Custom Gradient",
                     \.icon.background.usesCustomGradient),
        SettingField("icon.background.gradientStartColor", "Change Icon Gradient Primary Color",
                     \.icon.background.gradientStartColor),
        SettingField("icon.background.gradientEndColor", "Change Icon Gradient Secondary Color",
                     \.icon.background.gradientEndColor),
        SettingField("icon.background.cornerRadiusStyle", "Change Icon Corner Style",
                     \.icon.background.cornerRadiusStyle),
        SettingField("icon.background.shadowStyle", "Change Icon Background Shadow",
                     \.icon.background.shadowStyle),
        SettingField("icon.background.image", "Change Icon Background Image",
                     \.icon.background.image),
        SettingField("icon.background.imageScale", "Change Icon Background Image Scale",
                     \.icon.background.imageScale),
        SettingField("icon.background.compensatesForPadding", "Change Icon Padding Compensation",
                     \.icon.background.compensatesForPadding),
        SettingField("icon.background.isHidden", visibilityOf: "Icon Background",
                     \.icon.background.isHidden),
    ]

    /// 11 fields. The badge's shadow is a `Bool` rather than a preset, because a badge
    /// only ever has one shadow shape.
    private static let badgeBackgroundFields: [SettingField] = [
        SettingField("badge.background.source", "Change Badge Background Type",
                     \.badge.background.source),
        SettingField("badge.background.color", "Change Badge Background Color",
                     \.badge.background.color),
        SettingField("badge.background.usesGradient", "Change Badge Background Gradient",
                     \.badge.background.usesGradient),
        SettingField("badge.background.usesCustomGradient", "Change Badge Custom Gradient",
                     \.badge.background.usesCustomGradient),
        SettingField("badge.background.gradientStartColor", "Change Badge Gradient Primary Color",
                     \.badge.background.gradientStartColor),
        SettingField("badge.background.gradientEndColor", "Change Badge Gradient Secondary Color",
                     \.badge.background.gradientEndColor),
        SettingField("badge.background.drawsShadow", "Change Badge Background Shadow",
                     \.badge.background.drawsShadow),
        SettingField("badge.background.image", "Change Badge Background Image",
                     \.badge.background.image),
        SettingField("badge.background.imageScale", "Change Badge Background Image Scale",
                     \.badge.background.imageScale),
        SettingField("badge.background.compensatesForPadding", "Change Badge Padding Compensation",
                     \.badge.background.compensatesForPadding),
        SettingField("badge.background.isHidden", visibilityOf: "Badge Background",
                     \.badge.background.isHidden),
    ]
}
