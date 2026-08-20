// MicaTests/Models/SettingsChangeTests.swift
//
// The change-naming table. Lives beside the model tests rather than the view-model ones
// because what it describes is `IconSettings`, one entry per stored property.
//
// `everyStoredPropertyIsNamed` is the detector, in the same spirit as
// `MicaConfigTests.storedPropertyCountIsPinned`: adding a setting and forgetting to
// name it is not a compile error. It is a setting whose undo says "Change Settings" and
// which never coalesces, and nobody would notice for months.

import Testing
import SwiftUI
import AppKit
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct SettingsChangeTests {

    // MARK: - Coverage

    /// Counts leaf stored properties, recursing only into Mica's own spec types — the
    /// same walk `MicaConfigTests` uses, and for the same reason.
    private static func leafCount(of value: Any) -> Int {
        let isSpec = value is ExportSpec || value is IconSpec || value is BadgeSpec
            || value is ForegroundSpec || value is IconBackgroundSpec || value is BadgeBackgroundSpec
            || value is IconSettings
        guard isSpec else { return 1 }
        return Mirror(reflecting: value).children.reduce(0) { $0 + leafCount(of: $1.value) }
    }

    @Test("every stored property has a named field")
    func everyStoredPropertyIsNamed() {
        #expect(SettingsChange.fields.count == Self.leafCount(of: IconSettings()))
        #expect(SettingsChange.fields.count == 65)
    }

    /// A duplicated key would make two different settings coalesce into each other: edit
    /// one, then the other within the window, and the second would vanish into the first's
    /// undo step.
    @Test("keys are unique")
    func keysAreUnique() {
        let keys = SettingsChange.fields.map(\.key)
        #expect(Set(keys).count == keys.count)
    }

    @Test("names are unique, so the Edit menu never says the same thing for two settings")
    func namesAreUnique() {
        let names = SettingsChange.fields.map { $0.name(IconSettings()) }
        #expect(Set(names).count == names.count)
    }

    /// The real coverage test: mutate each field in turn and require the diff to name that
    /// field rather than fall back to the bulk stand-in. Catches an entry whose key path
    /// points at the wrong property, which a count cannot.
    @Test("each field detects a change to its own property")
    func eachFieldDetectsItsOwnProperty() {
        for field in SettingsChange.fields {
            var mutated = IconSettings()
            Self.mutate(&mutated, at: field.key)
            let change = SettingsChange.between(IconSettings(), mutated)
            #expect(change?.key == field.key, "\(field.key) was reported as \(change?.key ?? "no change")")
        }
    }

    /// Nudges one property to a value it does not already hold. Exhaustive over the field
    /// table by key, so a new field fails here too until it is added.
    private static func mutate(_ settings: inout IconSettings, at key: String) {
        switch key {
        case "export.size": settings.export.size = 123
        case "export.isRetina": settings.export.isRetina.toggle()
        case "export.colorSpace": settings.export.colorSpace = .displayP3
        case "icon.mode": settings.icon.mode = .system

        case "icon.background.source": settings.icon.background.source = .image
        case "icon.background.color": settings.icon.background.color = .brown
        case "icon.background.usesGradient": settings.icon.background.usesGradient.toggle()
        case "icon.background.usesCustomGradient": settings.icon.background.usesCustomGradient.toggle()
        case "icon.background.gradientStartColor": settings.icon.background.gradientStartColor = .brown
        case "icon.background.gradientEndColor": settings.icon.background.gradientEndColor = .brown
        case "icon.background.cornerRadiusStyle": settings.icon.background.cornerRadiusStyle = .macOS15
        case "icon.background.shadowStyle": settings.icon.background.shadowStyle = .off
        case "icon.background.image": settings.icon.background.image = Self.image
        case "icon.background.imageScale": settings.icon.background.imageScale = 1.7
        case "icon.background.compensatesForPadding": settings.icon.background.compensatesForPadding.toggle()
        case "icon.background.isHidden": settings.icon.background.isHidden.toggle()

        case "badge.position": settings.badge.position = .topLeft
        case "badge.scale": settings.badge.scale = 1.7
        case "badge.offsetX": settings.badge.offsetX = 0.3
        case "badge.offsetY": settings.badge.offsetY = 0.3

        case "badge.background.source": settings.badge.background.source = .image
        case "badge.background.color": settings.badge.background.color = .brown
        case "badge.background.usesGradient": settings.badge.background.usesGradient.toggle()
        case "badge.background.usesCustomGradient": settings.badge.background.usesCustomGradient.toggle()
        case "badge.background.gradientStartColor": settings.badge.background.gradientStartColor = .brown
        case "badge.background.gradientEndColor": settings.badge.background.gradientEndColor = .brown
        case "badge.background.drawsShadow": settings.badge.background.drawsShadow.toggle()
        case "badge.background.image": settings.badge.background.image = Self.image
        case "badge.background.imageScale": settings.badge.background.imageScale = 1.7
        case "badge.background.compensatesForPadding": settings.badge.background.compensatesForPadding.toggle()
        case "badge.background.isHidden": settings.badge.background.isHidden.toggle()

        default:
            // The two foreground groups share one property set, so they share one arm.
            if key.hasPrefix("icon.foreground.") {
                mutateForeground(&settings.icon.foreground, leaf: String(key.dropFirst("icon.foreground.".count)))
            } else if key.hasPrefix("badge.foreground.") {
                mutateForeground(&settings.badge.foreground, leaf: String(key.dropFirst("badge.foreground.".count)))
            } else {
                Issue.record("no mutation for \(key) — add one when you add the field")
            }
        }
    }

    private static func mutateForeground(_ spec: inout ForegroundSpec, leaf: String) {
        switch leaf {
        case "source": spec.source = spec.source == .image ? .symbol : .image
        case "symbolName": spec.symbolName = "\(spec.symbolName).changed"
        case "symbolWeight": spec.symbolWeight = .black
        case "symbolScale": spec.symbolScale = 1.7
        case "image": spec.image = Self.image
        case "imageScale": spec.imageScale = 1.7
        case "offsetX": spec.offsetX = 0.2
        case "offsetY": spec.offsetY = -0.2
        case "color": spec.color = .brown
        case "renderingStyle": spec.renderingStyle = .palette
        case "fillStyle": spec.fillStyle = .gradient
        case "hierarchicalColor": spec.hierarchicalColor = .brown
        case "palettePrimaryColor": spec.palettePrimaryColor = .brown
        case "paletteSecondaryColor": spec.paletteSecondaryColor = .brown
        case "paletteTertiaryColor": spec.paletteTertiaryColor = .brown
        case "drawsShadow": spec.drawsShadow.toggle()
        case "isHidden": spec.isHidden.toggle()
        default: Issue.record("no mutation for foreground leaf \(leaf)")
        }
    }

    /// Real PNG bytes, via the shared helper: `NSBitmapImageRep.setColor` silently no-ops
    /// on a `.deviceRGB` rep, which once made four "distinct" fixtures byte-identical.
    private static let image = ImportedImage(
        id: UUID(),
        imageData: try! ImportedImage.pngData(fill: .systemBrown),
        sourceName: "changed.png",
        isFileIcon: false
    )

    // MARK: - Diffing

    @Test("no difference reports no change")
    func identicalSettingsReportNothing() {
        #expect(SettingsChange.between(IconSettings(), IconSettings()) == nil)
    }

    @Test("one difference reports that field, with its name")
    func oneDifferenceIsNamed() {
        var changed = IconSettings()
        changed.icon.foreground.symbolScale = 1.5

        let change = SettingsChange.between(IconSettings(), changed)

        #expect(change?.key == "icon.foreground.symbolScale")
        #expect(change?.name == "Change Icon Symbol Scale")
        #expect(change?.isBulk == false)
    }

    @Test("several differences report the bulk stand-in")
    func severalDifferencesAreBulk() {
        var changed = IconSettings()
        changed.icon.foreground.symbolScale = 1.5
        changed.badge.position = .topLeft

        let change = SettingsChange.between(IconSettings(), changed)

        #expect(change == SettingsChange.bulk)
        #expect(change?.isBulk == true)
        #expect(change?.name == "Change Settings")
    }

    /// The icon and the badge share one `ForegroundSpec`, so the table generates both from
    /// one list. The keys and names still have to come out distinct per group.
    @Test("the shared foreground spec yields distinct keys and names per group")
    func foregroundGroupsAreDistinguished() {
        var iconChanged = IconSettings()
        iconChanged.icon.foreground.color = .brown
        var badgeChanged = IconSettings()
        badgeChanged.badge.foreground.color = .brown

        #expect(SettingsChange.between(IconSettings(), iconChanged)
                == SettingsChange(key: "icon.foreground.color", name: "Change Icon Symbol Color"))
        #expect(SettingsChange.between(IconSettings(), badgeChanged)
                == SettingsChange(key: "badge.foreground.color", name: "Change Badge Symbol Color"))
    }

    // MARK: - Naming

    @Test("a visibility flag names the action it performs, in both directions")
    func visibilityNamesBothDirections() {
        var hiding = IconSettings()
        hiding.icon.foreground.isHidden = true
        #expect(SettingsChange.between(IconSettings(), hiding)?.name == "Hide Icon Foreground")

        var visible = IconSettings()
        visible.icon.foreground.isHidden = true
        var showing = visible
        showing.icon.foreground.isHidden = false
        #expect(SettingsChange.between(visible, showing)?.name == "Show Icon Foreground")
    }

    /// The Edit menu prefixes these with "Undo " / "Redo ", so a name starting with a verb
    /// is the difference between "Undo Change Badge Size" and "Undo Badge Size".
    @Test("every name reads as an action")
    func namesAreVerbPhrases() {
        let verbs = ["Change ", "Show ", "Hide ", "Move "]
        for field in SettingsChange.fields {
            let name = field.name(IconSettings())
            #expect(verbs.contains { name.hasPrefix($0) }, "\(field.key) is named \"\(name)\"")
        }
        #expect(SettingsChange.bulk.name.hasPrefix("Change "))
    }

    // MARK: - Ending text editing

    /// `ContentView` ends text editing on any change that is *not* a text-field edit, so
    /// this predicate decides whether the symbol field keeps focus. Checked against the
    /// whole table rather than the two keys by name: a second settings-bound `TextField`
    /// would otherwise be added without anyone noticing that it drops focus mid-word.
    ///
    /// If this fails because a new text-bound setting exists, the fix is in
    /// `SettingsChange.textFieldKeySuffix`, not here.
    @Test("only the two symbol-name fields count as text-field edits")
    func onlySymbolNameIsATextFieldEdit() {
        let textFieldKeys = SettingsChange.fields
            .filter { SettingsChange(key: $0.key, name: $0.name(IconSettings())).isTextFieldEdit }
            .map(\.key)
        #expect(textFieldKeys == ["icon.foreground.symbolName", "badge.foreground.symbolName"])
    }

    @Test("a bulk change is not a text-field edit")
    func bulkIsNotATextFieldEdit() {
        #expect(!SettingsChange.bulk.isTextFieldEdit)
    }

    @Test("typing a symbol name is a text-field edit, changing anything else is not")
    func textFieldEditIsDetectedFromADiff() {
        var typed = IconSettings()
        typed.icon.foreground.symbolName = "star.fill"
        #expect(SettingsChange.between(IconSettings(), typed)?.isTextFieldEdit == true)

        var toggled = IconSettings()
        toggled.icon.foreground.drawsShadow.toggle()
        #expect(SettingsChange.between(IconSettings(), toggled)?.isTextFieldEdit == false)
    }
}
