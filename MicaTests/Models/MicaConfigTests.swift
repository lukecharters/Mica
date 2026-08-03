// MicaConfigTests.swift
// The JSON configuration codec (Services/MicaConfig.swift). Three kinds of pin:
//
// - **Round trips**: `decode(encode(s))` reproduces `s` for canonically-shaped
//   settings (imported images compared by bytes and name — `ImportedImage.==`
//   is id-based, and a decode always mints fresh ids).
// - **Coverage**: the 62-leaf reflection count detects a new stored property,
//   and `everyConfigKeyChangesSomething` proves all 44 keys reach a field.
// - **Liberality and warnings**: booleans or "on"/"off", numbers or numeric
//   strings, arrays or comma-joined colours, British aliases; anything
//   unreadable warns and keeps the default rather than failing the load.
//
// Image fixtures come from MicaTests/Support/ImportedImageFixtures.swift —
// never NSBitmapImageRep.setColor, which silently no-ops on .deviceRGB.

import Testing
import SwiftUI
import Foundation
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct MicaConfigTests {

    // MARK: - Helpers

    private static func decode(
        _ dictionary: [String: Any],
        configDirectory: URL? = nil,
        loadImage: MicaConfigCodec.ImageLoader? = nil
    ) throws -> MicaConfigContents {
        let json = try JSONSerialization.data(withJSONObject: dictionary)
        if let loadImage {
            return try MicaConfigCodec.decode(json: json, configDirectory: configDirectory, loadImage: loadImage)
        }
        return try MicaConfigCodec.decode(
            json: json,
            configDirectory: configDirectory,
            loadImage: { url in try ImportedImage.testFixture(sourceName: url.lastPathComponent) }
        )
    }

    /// Encode, then decode through a loader backed by the encode's own asset
    /// catalog — the sidecar files, without a filesystem.
    private static func roundTrip(
        _ settings: IconSettings,
        appexColors: MicaAppexColors = MicaAppexColors()
    ) throws -> MicaConfigContents {
        var catalog = MicaConfigAssetCatalog()
        let json = try MicaConfigCodec.encode(settings: settings, appexColors: appexColors, assets: &catalog)
        let assets = catalog.assets
        return try MicaConfigCodec.decode(json: json, configDirectory: nil, loadImage: { url in
            guard let data = assets[url.lastPathComponent] else {
                throw ImportedImage.FixtureError.bitmapCreationFailed
            }
            return ImportedImage(id: UUID(), imageData: data, sourceName: url.lastPathComponent, isFileIcon: false)
        })
    }

    /// Settings equality that treats imported images by content, not identity.
    private static func expectEquivalent(
        _ result: IconSettings,
        _ expected: IconSettings,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        var strippedResult = result
        var strippedExpected = expected
        for keyPath in [\IconSettings.icon.foreground.image, \.icon.background.image,
                        \.badge.foreground.image, \.badge.background.image] {
            let resultImage = result[keyPath: keyPath]
            let expectedImage = expected[keyPath: keyPath]
            #expect(resultImage?.imageData == expectedImage?.imageData, sourceLocation: sourceLocation)
            strippedResult[keyPath: keyPath] = nil
            strippedExpected[keyPath: keyPath] = nil
        }
        #expect(strippedResult == strippedExpected, sourceLocation: sourceLocation)
    }

    // MARK: - Reflection coverage

    /// Counts leaf stored properties, recursing only into Mica's own spec types.
    /// `Mirror` reports stored properties and skips computed ones, which is
    /// exactly the set the configuration has to be able to express or exempt.
    private static func leafCount(of value: Any) -> Int {
        let isSpec = value is ExportSpec || value is IconSpec || value is BadgeSpec
            || value is ForegroundSpec || value is IconBackgroundSpec || value is BadgeBackgroundSpec
            || value is IconSettings
        guard isSpec else { return 1 }
        return Mirror(reflecting: value).children.reduce(0) { $0 + leafCount(of: $1.value) }
    }

    @Test("the stored-property count is pinned, so a new setting cannot be forgotten")
    func storedPropertyCountIsPinned() {
        #expect(Self.leafCount(of: IconSettings()) == 62,
                "a new stored property needs a config key (and a probe below) or an entry in the documented lossiness list")
    }

    @Test("each spec contributes the leaf count the codec was built against")
    func perSpecLeafCounts() {
        #expect(Self.leafCount(of: ExportSpec()) == 3)
        #expect(Self.leafCount(of: ForegroundSpec.iconDefault) == 15)
        #expect(Self.leafCount(of: IconBackgroundSpec()) == 13)
        #expect(Self.leafCount(of: BadgeBackgroundSpec()) == 11)
        #expect(Self.leafCount(of: IconSpec()) == 1 + 15 + 13)
        #expect(Self.leafCount(of: BadgeSpec()) == 4 + 15 + 11)
    }

    // MARK: - Key coverage

    /// One probe per key: decoding the probe's context with and without the key
    /// must produce different settings (or appex colours). Context keys supply
    /// the discriminators a key depends on — an image background for the scale
    /// and padding keys, `badge-fg` for every badge key.
    private static let keyProbes: [(key: String, value: Any, context: [String: Any])] = [
        ("size", 256, [:]),
        ("scale", "2x", [:]),
        ("color-space", "displayP3", [:]),
        ("icon-generation-mode", "system", [:]),
        ("badge-generation-mode", "system", ["badge-fg": "symbol:plus"]),
        // Decode-only sugar: each writes both of its group's layer keys.
        ("icon-visibility", false, [:]),
        ("badge-visibility", false, ["badge-fg": "symbol:plus"]),
        ("icon-fg", "symbol:bolt.fill", [:]),
        ("icon-fg-scale", 1.4, [:]),
        ("icon-symbol-rendering", "hierarchical", [:]),
        ("icon-symbol-color", "red", [:]),
        ("icon-symbol-palette", ["red", "green", "blue"], [:]),
        ("icon-symbol-weight", "bold", [:]),
        ("icon-symbol-gradient", true, [:]),
        ("icon-fg-shadow", false, [:]),
        ("icon-fg-visibility", false, [:]),
        ("icon-bg", "custom-gradient", [:]),
        ("icon-bg-color", "red", [:]),
        ("icon-bg-gradient-colors", ["pink", "brown"], ["icon-bg": "custom-gradient"]),
        ("icon-bg-gradient", false, [:]),
        ("icon-bg-corner-radius", "macos11", [:]),
        ("icon-bg-scale", 1.5, ["icon-bg": "bg.png"]),
        ("icon-bg-shadow", "off", [:]),
        ("icon-bg-padding", true, ["icon-bg": "bg.png"]),
        ("icon-bg-visibility", false, [:]),
        ("badge-fg", "symbol:plus", [:]),
        ("badge-fg-scale", 1.4, ["badge-fg": "symbol:plus"]),
        ("badge-symbol-rendering", "hierarchical", ["badge-fg": "symbol:plus"]),
        ("badge-symbol-color", "red", ["badge-fg": "symbol:plus"]),
        ("badge-symbol-palette", ["red", "green", "blue"], ["badge-fg": "symbol:plus"]),
        ("badge-symbol-weight", "bold", ["badge-fg": "symbol:plus"]),
        ("badge-symbol-gradient", true, ["badge-fg": "symbol:plus"]),
        ("badge-fg-shadow", false, ["badge-fg": "symbol:plus"]),
        ("badge-fg-visibility", false, ["badge-fg": "symbol:plus"]),
        ("badge-bg", "custom-gradient", ["badge-fg": "symbol:plus"]),
        ("badge-bg-color", "purple", ["badge-fg": "symbol:plus"]),
        ("badge-bg-gradient-colors", ["pink", "brown"], ["badge-fg": "symbol:plus", "badge-bg": "custom-gradient"]),
        ("badge-bg-gradient", false, ["badge-fg": "symbol:plus"]),
        ("badge-bg-scale", 1.5, ["badge-fg": "symbol:plus", "badge-bg": "bg.png"]),
        ("badge-bg-shadow", false, ["badge-fg": "symbol:plus"]),
        ("badge-bg-padding", true, ["badge-fg": "symbol:plus", "badge-bg": "bg.png"]),
        ("badge-bg-visibility", false, ["badge-fg": "symbol:plus"]),
        ("badge-position", "top-left", ["badge-fg": "symbol:plus"]),
        ("badge-scale", 1.3, ["badge-fg": "symbol:plus"]),
        ("badge-offset-x", 0.2, ["badge-fg": "symbol:plus"]),
        ("badge-offset-y", -0.1, ["badge-fg": "symbol:plus"]),
    ]

    @Test("every configuration key changes something")
    func everyConfigKeyChangesSomething() throws {
        #expect(Self.keyProbes.count == MicaConfigKey.allCases.count, "every key needs a probe")
        let probedKeys = Set(Self.keyProbes.map(\.key))
        #expect(probedKeys == Set(MicaConfigKey.allCases.map(\.rawValue)))

        for probe in Self.keyProbes {
            let without = try Self.decode(probe.context)
            var withKey = probe.context
            withKey[probe.key] = probe.value
            let with = try Self.decode(withKey)
            #expect(
                with.settings != without.settings || with.appexColors != without.appexColors,
                "'\(probe.key)' decoded to nothing"
            )
        }
    }

    // MARK: - Minimality

    /// The identity set for default settings, spelled out. A configuration is
    /// the only record of a user's work, so it must describe the icon rather
    /// than diff against whatever this build's defaults happen to be — see the
    /// identity-set note in `MicaConfig.swift`. If a default *value* changes,
    /// this test should be updated; if the set of *keys* changes, think twice.
    @Test("default settings encode to the identity set, not an empty object")
    func defaultsEncodeIdentitySet() throws {
        let json = try MicaConfigCodec.encode(settings: IconSettings())
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

        #expect(Set(object.keys) == [
            "size",
            "icon-generation-mode",
            "icon-fg",
            "icon-symbol-color",
            "icon-bg-color",
        ])
        #expect(object["icon-generation-mode"] as? String == "mica")
        #expect(object["icon-fg"] as? String == "symbol:command")
        #expect(object["icon-symbol-color"] as? String == "white")
        #expect(object["icon-bg-color"] as? String == "blue")
        #expect(object["size"] as? Int == Int(IconSettings().export.size))
    }

    @Test("an invisible badge is omitted whole")
    func invisibleBadgeIsOmitted() throws {
        var settings = IconSettings()
        settings.badge.position = .topLeft   // stored, but the badge is hidden
        let json = try MicaConfigCodec.encode(settings: settings)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        // The icon's identity keys are expected; no badge key may appear.
        #expect(object.keys.allSatisfy { !$0.hasPrefix("badge-") })
    }

    @Test("a visible badge writes its identity keys even at their defaults")
    func visibleBadgeWritesIdentitySet() throws {
        var settings = IconSettings()
        settings.badge.isVisible = true   // both layers; the background draws too
        let json = try MicaConfigCodec.encode(settings: settings)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

        #expect(object["badge-generation-mode"] as? String == "mica")
        #expect(object["badge-fg"] as? String == "symbol:gearshape.fill")
        #expect(object["badge-symbol-color"] != nil)
        #expect(object["badge-bg-color"] != nil)
    }

    // MARK: - Applicability gates

    /// Palette and the single symbol colour are mutually exclusive in
    /// `IconContentView.applySymbolColor`, so exactly one of them is written.
    /// Verified against the renderer: under `--icon-symbol-rendering palette`,
    /// changing `--icon-symbol-color` produces byte-identical PNGs.
    @Test("palette rendering writes the palette and drops the single colour")
    func paletteRoundTripsUnderPalette() throws {
        var settings = IconSettings()
        settings.icon.foreground.renderingStyle = .palette
        settings.icon.foreground.palettePrimaryColor = .red
        settings.icon.foreground.paletteSecondaryColor = .green
        settings.icon.foreground.paletteTertiaryColor = .blue

        let json = try MicaConfigCodec.encode(settings: settings)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(object["icon-symbol-palette"] as? [String] == ["red", "green", "blue"])
        #expect(object["icon-symbol-color"] == nil)

        let result = try Self.roundTrip(settings)
        #expect(result.settings.icon.foreground.palettePrimaryColor == .red)
        #expect(result.settings.icon.foreground.paletteTertiaryColor == .blue)
    }

    @Test("a palette set under any other rendering style is not written")
    func paletteIsDroppedWhenNotRendered() throws {
        var settings = IconSettings()
        settings.icon.foreground.renderingStyle = .hierarchical
        settings.icon.foreground.palettePrimaryColor = .red

        let json = try MicaConfigCodec.encode(settings: settings)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(object["icon-symbol-palette"] == nil)
        #expect(object["icon-symbol-color"] != nil)
    }

    /// System mode renders a bare appex raster, whose only inputs are the symbol
    /// name, the symbol colour and the enclosure colour
    /// (`AppexReferenceService`). Every other Mica-side icon key describes a
    /// pipeline that did not run.
    @Test("System mode writes only the three keys the appex reads")
    func systemModeDropsMicaOnlyKeys() throws {
        var settings = IconSettings()
        settings.icon.mode = .system
        settings.icon.foreground.symbolName = "shield.fill"
        settings.icon.foreground.symbolWeight = .bold
        settings.icon.foreground.symbolScale = 1.3
        settings.icon.background.cornerRadiusStyle = .macOS11
        settings.icon.background.shadowStyle = .sequoia

        let json = try MicaConfigCodec.encode(settings: settings)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

        #expect(object["icon-fg"] as? String == "symbol:shield.fill")
        #expect(object["icon-symbol-color"] != nil)
        #expect(object["icon-bg-color"] != nil)
        for dropped in ["icon-symbol-weight", "icon-fg-scale", "icon-bg-corner-radius",
                        "icon-bg-shadow", "icon-bg", "icon-symbol-rendering"] {
            #expect(object[dropped] == nil, "\(dropped) describes the Mica pipeline, which did not run")
        }
    }

    /// Importing badge artwork hides the badge symbol, so gate 6 takes the symbol's
    /// keys — `badge-fg` now included, since gate 2 went and with it the exemption
    /// that used to keep it. `badge-bg` carries activation in its place, which is the
    /// invariant that let the exemption go.
    @Test("an imported badge background drops the badge symbol's keys, badge-fg included")
    func importedBadgeBackgroundDropsSymbolKeys() throws {
        var settings = IconSettings()
        settings.badge.isVisible = true
        settings.badge.foreground.symbolWeight = .bold
        settings.badge.foreground.color = .red
        settings.badge.applyBackgroundImage(try ImportedImage.testFixture(sourceName: "Back.png"))

        var catalog = MicaConfigAssetCatalog()
        let json = try MicaConfigCodec.encode(settings: settings, assets: &catalog)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

        #expect(object["badge-bg"] != nil, "the activator the badge now decodes from")
        #expect(object["badge-fg"] == nil, "gate 6 applies to it like any foreground key")
        #expect(object["badge-symbol-weight"] == nil)
        #expect(object["badge-symbol-color"] == nil)
        // The conditional baseline is met exactly, so the key that says so is omitted.
        #expect(object["badge-fg-visibility"] == nil)

        // And it round-trips as artwork-only rather than decoding away.
        let decoded = try Self.roundTrip(settings)
        #expect(decoded.settings.badge.isVisible == true)
        #expect(decoded.settings.badge.foreground.isHidden == true)
        #expect(decoded.settings.badge.background.image != nil)
    }

    /// **The invariant that let `badge-fg`'s "never gated" exemption go**: whatever a
    /// visible badge looks like, the file must carry at least one key that switches the
    /// badge on, or the whole group decodes as absent.
    ///
    /// Worth a matrix rather than an argument, because the reasoning is easy to get
    /// wrong. `badge-bg` is written for imported artwork and a custom gradient, but a
    /// *plain colour* background writes only `badge-bg-color`, which does not activate.
    /// The plan's version of this invariant missed that case; the fallback in the writer
    /// exists because of it.
    @Test("every visible badge writes at least one activator", arguments: [
        "symbol over a plain colour",
        "symbol over a custom gradient",
        "symbol over imported artwork",
        "hidden symbol over imported artwork",
        "hidden symbol over a plain colour",
        "hidden symbol over a custom gradient",
        "symbol with the background hidden",
        "imported symbol over a plain colour",
        "system badge",
    ])
    func everyVisibleBadgeWritesAnActivator(_ variant: String) throws {
        var settings = IconSettings()
        settings.badge.isVisible = true

        switch variant {
        case "symbol over a plain colour":
            break
        case "symbol over a custom gradient":
            settings.badge.background.usesCustomGradient = true
        case "symbol over imported artwork":
            settings.badge.applyBackgroundImage(try ImportedImage.testFixture(sourceName: "A.png"))
            settings.badge.foreground.isHidden = false
        case "hidden symbol over imported artwork":
            settings.badge.applyBackgroundImage(try ImportedImage.testFixture(sourceName: "A.png"))
        case "hidden symbol over a plain colour":
            settings.badge.foreground.isHidden = true
        case "hidden symbol over a custom gradient":
            settings.badge.background.usesCustomGradient = true
            settings.badge.foreground.isHidden = true
        case "symbol with the background hidden":
            settings.badge.background.isHidden = true
        case "imported symbol over a plain colour":
            settings.badge.foreground.apply(try ImportedImage.testFixture(sourceName: "Glyph.png"))
        default:
            settings.badge.mode = .system
        }

        var catalog = MicaConfigAssetCatalog()
        let json = try MicaConfigCodec.encode(settings: settings, assets: &catalog)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

        let activators = MicaConfigKey.activatingBadgeNames.filter { object[$0] != nil }
        #expect(!activators.isEmpty,
                "\(variant) wrote no activator, so this badge decodes away: \(object.keys.sorted())")

        // And prove it rather than trusting the key list: the badge survives a round trip.
        let decoded = try Self.roundTrip(settings)
        #expect(decoded.settings.badge.isVisible == true, "\(variant) lost its badge")
    }

    @Test("switching the badge symbol back on writes its keys again")
    func badgeForegroundToggledBackOn_writesItsKeys() throws {
        // The assertion that could not have been written before: gate 2 dropped these
        // keys on the *background's* source, so no setting could bring them back.
        var settings = IconSettings()
        settings.badge.isVisible = true
        settings.badge.foreground.symbolWeight = .bold
        settings.badge.applyBackgroundImage(try ImportedImage.testFixture(sourceName: "Back.png"))
        settings.badge.foreground.isHidden = false

        let json = try MicaConfigCodec.encode(settings: settings)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

        #expect(object["badge-fg"] != nil)
        #expect(object["badge-symbol-weight"] as? String == "bold")
        // Rule 2 makes the foreground visible on decode, so no visibility key is needed.
        #expect(object["badge-fg-visibility"] == nil)

        let decoded = try Self.roundTrip(settings)
        #expect(decoded.settings.badge.foreground.isHidden == false)
        #expect(decoded.settings.badge.foreground.symbolWeight == .bold)
    }

    @Test("the identity set survives a round trip unchanged")
    func identitySetRoundTrips() throws {
        let json = try MicaConfigCodec.encode(settings: IconSettings())
        let decoded = try Self.roundTrip(IconSettings())
        #expect(decoded.warnings.isEmpty)
        // Re-encoding the decoded settings must reproduce the same file — the
        // identity keys decode to exactly the defaults they were written from,
        // so writing them changes nothing about what the file means.
        let second = try MicaConfigCodec.encode(settings: decoded.settings)
        #expect(second == json)
    }

    @Test("an image background omits its import-baseline shadow and padding")
    func imageBackgroundBaselinesAreOmitted() throws {
        var settings = IconSettings()
        var background = settings.icon.background
        background.apply(try ImportedImage.testFixture(sourceName: "bg.png"))
        settings.icon.background = background

        var catalog = MicaConfigAssetCatalog()
        let json = try MicaConfigCodec.encode(settings: settings, assets: &catalog)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        // The baseline keys, and only those, must be absent — the identity keys
        // beside them are expected. An image background is also the case where
        // `icon-bg-color` stops being identity, because it colours nothing.
        #expect(object["icon-bg-shadow"] == nil, "shadow .off is the import baseline")
        #expect(object["icon-bg-padding"] == nil, "compensation on is the import baseline")
        #expect(object["icon-bg-color"] == nil, "an image background is not a colour")
        #expect(object["icon-bg"] as? String == "bg.png")
        #expect(catalog.assets["bg.png"] != nil)
    }

    // MARK: - Round trips

    @Test("default settings round-trip to default settings")
    func defaultsRoundTrip() throws {
        let result = try Self.roundTrip(IconSettings())
        #expect(result.settings == IconSettings())
        #expect(result.appexColors == MicaAppexColors())
        #expect(result.warnings.isEmpty)
    }

    /// A symbol-everything fixture in canonical decode shape: `color` mirrors
    /// `hierarchicalColor`, a custom gradient keeps `color == gradientStart`.
    private static func distinctiveSymbolSettings() -> IconSettings {
        var settings = IconSettings()
        settings.export.size = 256
        settings.export.isRetina = true
        settings.export.colorSpace = .displayP3

        settings.icon.foreground.symbolName = "bolt.fill"
        settings.icon.foreground.symbolScale = 1.4
        settings.icon.foreground.color = .orange
        settings.icon.foreground.hierarchicalColor = .orange
        settings.icon.foreground.renderingStyle = .hierarchical
        settings.icon.foreground.fillStyle = .gradient
        settings.icon.foreground.symbolWeight = .bold
        settings.icon.foreground.drawsShadow = false
        // No palette here: the rendering style above is `.hierarchical`, and the
        // encoder writes the palette only under `.palette` rendering because
        // that is the only style that draws it. `paletteRoundTripsUnderPalette`
        // covers the palette; `paletteIsDroppedWhenNotRendered` covers the gate.

        settings.icon.background.usesCustomGradient = true
        settings.icon.background.gradientStartColor = .pink
        settings.icon.background.gradientEndColor = .brown
        settings.icon.background.color = .pink   // canonical: decode mirrors the start colour
        settings.icon.background.usesGradient = false
        settings.icon.background.cornerRadiusStyle = .macOS11
        settings.icon.background.shadowStyle = .sequoia

        settings.badge.isVisible = true
        settings.badge.position = .topLeft
        settings.badge.scale = 1.3
        settings.badge.offsetX = 0.2
        settings.badge.offsetY = -0.1
        settings.badge.foreground.symbolName = "bell.fill"
        settings.badge.foreground.symbolScale = 0.8
        settings.badge.foreground.color = .yellow
        settings.badge.foreground.hierarchicalColor = .yellow
        settings.badge.foreground.drawsShadow = false
        settings.badge.background.color = .purple
        settings.badge.background.usesGradient = false
        settings.badge.background.drawsShadow = false
        return settings
    }

    @Test("a fully non-default symbol configuration round-trips")
    func distinctiveSymbolSettingsRoundTrip() throws {
        let settings = Self.distinctiveSymbolSettings()
        let result = try Self.roundTrip(settings)
        #expect(result.settings == settings)
        #expect(result.warnings.isEmpty)
    }

    @Test("a hidden badge layer round-trips")
    func hiddenBadgeLayerRoundTrips() throws {
        var settings = IconSettings()
        settings.badge.foreground.isHidden = false
        settings.badge.background.isHidden = true

        let result = try Self.roundTrip(settings)
        #expect(result.settings.badge.foreground.isHidden == false)
        #expect(result.settings.badge.background.isHidden == true)
    }

    @Test("a pre-rendered background round-trips")
    func preRenderedRoundTrips() throws {
        var settings = IconSettings()
        settings.icon.background.source = .preRendered
        settings.icon.background.preRenderedColorName = "teal"

        let result = try Self.roundTrip(settings)
        #expect(result.settings.icon.background.source == .preRendered)
        #expect(result.settings.icon.background.preRenderedColorName == "teal")
    }

    /// A pre-rendered asset is drawn as-is by `IconContentView.backgroundLayer`
    /// — no gradient, no corner radius — so neither key is written for it, and
    /// neither survives. Verified against the renderer: two renders differing
    /// only in `--icon-bg-corner-radius` over `prerendered-liquid-glass` are
    /// byte-identical.
    @Test("a pre-rendered background drops the keys it does not read")
    func preRenderedDropsInertKeys() throws {
        var settings = IconSettings()
        settings.icon.background.source = .preRendered
        settings.icon.background.usesGradient = !IconSettings().icon.background.usesGradient
        settings.icon.background.cornerRadiusStyle = .macOS11

        let json = try MicaConfigCodec.encode(settings: settings)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(object["icon-bg-gradient"] == nil)
        #expect(object["icon-bg-corner-radius"] == nil)
    }

    @Test("the custom-solid gradient state round-trips", arguments: [
        (usesGradient: true, usesCustomGradient: true),
        (usesGradient: false, usesCustomGradient: true),
        (usesGradient: true, usesCustomGradient: false),
        (usesGradient: false, usesCustomGradient: false),
    ])
    func gradientCombinationsRoundTrip(_ combo: (usesGradient: Bool, usesCustomGradient: Bool)) throws {
        var settings = IconSettings()
        settings.icon.background.usesGradient = combo.usesGradient
        settings.icon.background.usesCustomGradient = combo.usesCustomGradient
        if combo.usesCustomGradient {
            settings.icon.background.color = settings.icon.background.gradientStartColor
        }

        let result = try Self.roundTrip(settings)
        #expect(result.settings.icon.background.usesGradient == combo.usesGradient)
        #expect(result.settings.icon.background.usesCustomGradient == combo.usesCustomGradient)
    }

    @Test("imported images round-trip by bytes, name and layer")
    func importedImagesRoundTrip() throws {
        // The two images go on the icon foreground and the *badge* foreground.
        // Both on the icon would mean an imported background, which *hides* the icon
        // foreground — gate 6 then drops its keys, so the foreground image would not be
        // written. See `importedBackgroundDropsTheForeground` for that case, and
        // `iconForegroundToggledBackOn_writesItsKeys` for switching it back on.
        var settings = IconSettings()
        var foreground = settings.icon.foreground
        foreground.apply(try ImportedImage.testFixture(fill: .systemRed, sourceName: "Glyph.png"))
        foreground.imageScale = 0.9
        // Canonical decode shape: an image foreground's cosmetic symbolName is
        // the file's stem (what the CLI builder writes); the GUI's apply(_:)
        // leaves the previous name, which the format does not carry.
        foreground.symbolName = "Glyph"
        settings.icon.foreground = foreground
        settings.badge.isVisible = true
        var badgeForeground = settings.badge.foreground
        badgeForeground.apply(try ImportedImage.testFixture(fill: .systemBlue, sourceName: "Backdrop.png"))
        badgeForeground.imageScale = 1.2
        badgeForeground.symbolName = "Backdrop"
        settings.badge.foreground = badgeForeground

        let result = try Self.roundTrip(settings)
        #expect(result.settings.icon.foreground.image?.sourceName == "Glyph.png")
        #expect(result.settings.icon.foreground.imageScale == 0.9)
        #expect(result.settings.badge.foreground.image?.sourceName == "Backdrop.png")
        #expect(result.settings.badge.foreground.imageScale == 1.2)
        #expect(result.warnings.isEmpty)
    }

    /// Importing an icon background hides the foreground, so gate 6 takes the
    /// foreground's keys — including its imported image and that image's sidecar.
    /// Same output as gate 2 produced, reached through a reversible visibility flag
    /// rather than a veto nothing could reach past.
    @Test("an imported icon background drops the foreground it hides")
    func importedBackgroundDropsTheForeground() throws {
        var settings = IconSettings()
        settings.icon.foreground.apply(try ImportedImage.testFixture(fill: .systemRed, sourceName: "Glyph.png"))
        settings.icon.foreground.symbolName = "Glyph"
        settings.icon.applyBackgroundImage(
            try ImportedImage.testFixture(fill: .systemBlue, sourceName: "Backdrop.png"))
        settings.icon.background.imageScale = 1.2
        settings.icon.background.compensatesForPadding = false

        var catalog = MicaConfigAssetCatalog()
        let json = try MicaConfigCodec.encode(settings: settings, assets: &catalog)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

        #expect(object["icon-bg"] != nil)
        #expect(object["icon-bg-scale"] as? Double == 1.2)
        #expect(object["icon-bg-padding"] as? Bool == true)
        // Nothing from the hidden foreground, and only the background's sidecar.
        #expect(object.keys.allSatisfy { !$0.hasPrefix("icon-fg") && !$0.hasPrefix("icon-symbol") })
        #expect(catalog.assets.count == 1)
        // The corner radius went to `.off` on import, which is now the baseline, so
        // that key is omitted too.
        #expect(object["icon-bg-corner-radius"] == nil)

        let decoded = try Self.roundTrip(settings)
        #expect(decoded.settings.icon.foreground.isHidden == true)
        #expect(decoded.settings.icon.background.cornerRadiusStyle == .off)
    }

    @Test("switching the icon foreground back on writes its keys again")
    func iconForegroundToggledBackOn_writesItsKeys() throws {
        // The assertion gate 2 made impossible: its condition was the *background's*
        // source, so no foreground setting could bring these keys back.
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "heart.fill"
        settings.icon.foreground.symbolWeight = .bold
        settings.icon.applyBackgroundImage(
            try ImportedImage.testFixture(fill: .systemBlue, sourceName: "Backdrop.png"))
        settings.icon.foreground.isHidden = false

        let json = try MicaConfigCodec.encode(settings: settings)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

        #expect(object["icon-fg"] as? String == "symbol:heart.fill")
        #expect(object["icon-symbol-weight"] as? String == "bold")
        // Rule 2 makes it visible on decode from `icon-fg` alone, so no visibility key.
        #expect(object["icon-fg-visibility"] == nil)

        let decoded = try Self.roundTrip(settings)
        #expect(decoded.settings.icon.foreground.isHidden == false)
        #expect(decoded.settings.icon.foreground.symbolName == "heart.fill")
        #expect(decoded.settings.icon.foreground.symbolWeight == .bold)
        #expect(decoded.settings.icon.background.image != nil)
    }

    @Test("a wanted corner radius over imported artwork is written")
    func cornerRadiusOverImportedArtwork_isWritten() throws {
        // The other side of the third baseline: `.off` is the import default and is
        // omitted, so anything else the user picks has to be written or their clipped
        // artwork comes back unclipped.
        var settings = IconSettings()
        settings.icon.applyBackgroundImage(try ImportedImage.testFixture(sourceName: "Art.png"))
        settings.icon.background.cornerRadiusStyle = .macOS26

        let json = try MicaConfigCodec.encode(settings: settings)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(object["icon-bg-corner-radius"] as? String == "macos26")

        let decoded = try Self.roundTrip(settings)
        #expect(decoded.settings.icon.background.cornerRadiusStyle == .macOS26)
    }

    @Test("System-mode appex colours round-trip beside the settings")
    func systemModeRoundTrips() throws {
        var settings = IconSettings()
        settings.icon.mode = .system
        settings.icon.foreground.symbolName = "shield.fill"
        var appexColors = MicaAppexColors()
        appexColors.iconEnclosure = .custom(Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1))
        appexColors.iconSymbol = .named(.teal)

        let result = try Self.roundTrip(settings, appexColors: appexColors)
        #expect(result.settings.icon.mode == .system)
        #expect(result.settings.icon.foreground.symbolName == "shield.fill")
        #expect(result.appexColors.iconEnclosure == appexColors.iconEnclosure)
        #expect(result.appexColors.iconSymbol == appexColors.iconSymbol)
    }

    @Test("a System-mode badge round-trips its mode and colours")
    func systemBadgeRoundTrips() throws {
        var settings = IconSettings()
        settings.badge.isVisible = true
        settings.badge.foreground.symbolName = "bell.fill"
        settings.badge.mode = .system
        var appexColors = MicaAppexColors()
        appexColors.badgeEnclosure = .named(.red)
        appexColors.badgeSymbol = .named(.yellow)

        let result = try Self.roundTrip(settings, appexColors: appexColors)
        #expect(result.settings.badge.mode == .system)
        #expect(result.settings.badge.foreground.source == .system)
        #expect(result.settings.badge.foreground.symbolName == "bell.fill")
        #expect(result.appexColors.badgeEnclosure == appexColors.badgeEnclosure)
        #expect(result.appexColors.badgeSymbol == appexColors.badgeSymbol)
    }

    // MARK: - Liberal decode

    @Test("toggles take booleans or on/off strings")
    func togglesAreLiberal() throws {
        let viaBool = try Self.decode(["icon-bg-gradient": false])
        let viaString = try Self.decode(["icon-bg-gradient": "off"])
        #expect(viaBool.settings.icon.background.usesGradient == false)
        #expect(viaString.settings == viaBool.settings)
    }

    @Test("numbers take JSON numbers or numeric strings")
    func numbersAreLiberal() throws {
        let viaNumber = try Self.decode(["size": 256])
        let viaString = try Self.decode(["size": "256"])
        #expect(viaNumber.settings.export.size == 256)
        #expect(viaString.settings == viaNumber.settings)
    }

    @Test("multi-colour keys take arrays or comma-joined strings")
    func colorListsAreLiberal() throws {
        let viaArray = try Self.decode(["icon-symbol-palette": ["red", "green", "blue"]])
        let viaString = try Self.decode(["icon-symbol-palette": "red,green,blue"])
        #expect(viaArray.settings.icon.foreground.palettePrimaryColor == .red)
        #expect(viaString.settings == viaArray.settings)
    }

    @Test("the array form admits comma-containing colour strings")
    func arrayFormTakesExtendedColors() throws {
        let extended = "extended-srgb:0.20000,0.60000,0.90196,1.00000"
        let result = try Self.decode(["icon-symbol-palette": [extended, "green", "blue"]])
        #expect(result.warnings.isEmpty)
        #expect(result.settings.icon.foreground.palettePrimaryColor == (try MicaColorValue(parsing: extended)))
    }

    @Test("British aliases decode; the American key wins a tie")
    func britishAliases() throws {
        let alias = try Self.decode(["icon-bg-colour": "red"])
        #expect(alias.settings.icon.background.color == .red)
        #expect(alias.warnings.isEmpty)

        let tie = try Self.decode(["icon-bg-colour": "green", "icon-bg-color": "red"])
        #expect(tie.settings.icon.background.color == .red)
        #expect(tie.warnings.count == 1)
        #expect(tie.warnings.first?.key == "icon-bg-colour")
    }

    @Test("the export scale takes 2x or the bare number 2")
    func exportScaleIsLiberal() throws {
        #expect(try Self.decode(["scale": "2x"]).settings.export.isRetina == true)
        #expect(try Self.decode(["scale": 2]).settings.export.isRetina == true)
        #expect(try Self.decode(["scale": 1]).settings.export.isRetina == false)
    }

    // MARK: - Warnings

    @Test("an unknown key warns and changes nothing")
    func unknownKeyWarns() throws {
        let result = try Self.decode(["render-quality": "high"])
        #expect(result.settings == IconSettings())
        #expect(result.warnings.count == 1)
        #expect(result.warnings.first?.key == "render-quality")
    }

    @Test("a process-level flag name gets a pointed message")
    func processLevelKeyWarns() throws {
        let result = try Self.decode(["output": "~/icon.png"])
        #expect(result.warnings.count == 1)
        #expect(result.warnings.first?.message.contains("command-line flag") == true)
    }

    @Test("an unparseable colour warns and keeps the default")
    func badColorWarns() throws {
        let result = try Self.decode(["icon-symbol-color": "not-a-colour ("])
        #expect(result.settings.icon.foreground.color == IconSettings().icon.foreground.color)
        #expect(result.warnings.count == 1)
    }

    @Test("a wrong palette count warns and discards the key")
    func wrongPaletteCountWarns() throws {
        let result = try Self.decode(["icon-symbol-palette": "red,green"])
        #expect(result.settings.icon.foreground.palettePrimaryColor == IconSettings().icon.foreground.palettePrimaryColor)
        #expect(result.warnings.count == 1)
    }

    @Test("an out-of-range size warns and keeps the default")
    func outOfRangeSizeWarns() throws {
        let result = try Self.decode(["size": 5000])
        #expect(result.settings.export.size == ExportSpec.defaultSize)
        #expect(result.warnings.count == 1)
    }

    @Test("a boolean where a number belongs warns rather than reading as 1")
    func booleanIsNotANumber() throws {
        let result = try Self.decode(["size": true])
        #expect(result.settings.export.size == ExportSpec.defaultSize)
        #expect(result.warnings.count == 1)
    }

    @Test("a missing image warns and the layer opens without pixels")
    func missingImageWarns() throws {
        struct Missing: Error {}
        let result = try Self.decode(["icon-bg": "gone.png"], loadImage: { _ in throw Missing() })
        #expect(result.settings.icon.background.source == .image)
        #expect(result.settings.icon.background.image == nil)
        #expect(result.warnings.count == 1)
    }

    @Test("badge keys without badge-fg are inert, and say so")
    func badgeKeysWithoutActivationWarn() throws {
        // Both fixture keys are modifiers, so this survives phase 5 unchanged — what
        // narrowed is the codec's own list, which now excludes the three activators
        // rather than only `badge-fg`.
        let result = try Self.decode(["badge-position": "top-left", "badge-scale": 1.3])
        #expect(result.settings == IconSettings(), "the badge stays off")
        #expect(result.warnings.count == 1)
        #expect(result.warnings.first?.key == "badge-fg")
        #expect(result.warnings.first?.message.contains("badge-position") == true)
    }

    // Parameterised over the key name rather than a fixture dictionary, because
    // `arguments:` requires Sendable and `[String: Any]` is not.
    @Test("Each activating key turns the badge on and draws no inert warning",
          arguments: MicaConfigKey.activatingBadgeNames.sorted())
    func activatingBadgeKeysDoNotWarn(_ activator: String) throws {
        // The other half of the warning contract: these keys are not inert, so saying
        // they are would be false. Driven off `activatingBadgeNames` itself, so a
        // fourth activator cannot be added without this covering it.
        let value: Any
        switch activator {
        case MicaConfigKey.badgeFG.rawValue: value = "symbol:plus"
        case MicaConfigKey.badgeVisibility.rawValue: value = true
        default: value = "standard"
        }
        let result = try Self.decode([activator: value, "badge-position": "top-left"])

        #expect(result.settings.badge.isVisible == true)
        #expect(result.settings.badge.position == .topLeft, "the modifier is read once a badge exists")
        #expect(result.warnings.filter { $0.message.contains("inert") }.isEmpty,
                "unexpected warnings: \(result.warnings)")
    }

    @Test("badge-visibility false leaves the badge off and names the activators")
    func badgeVisibilityFalseStillWarns() throws {
        let result = try Self.decode(["badge-visibility": false, "badge-position": "top-left"])
        #expect(result.settings.badge.isVisible == false)
        let message = try #require(result.warnings.first?.message)
        #expect(message.contains("badge-position"), "the inert key is named")
        for activator in MicaConfigKey.activatingBadgeNames {
            #expect(message.contains(activator), "the message should say what would activate a badge")
        }
    }

    @Test("An imported icon background alone hides the icon foreground")
    func importedIconBackgroundAlone_hidesTheForeground() throws {
        // The codec's mirror of the icon's foreground rule, branch for branch with the
        // builder. Absent `icon-fg-visibility` + an imported icon background ⇒ hidden
        // is one of the three conditional baselines phase 7 has to match on encode.
        let bare = try Self.decode(["icon-bg": "art.png"])
        #expect(bare.settings.icon.background.isHidden == false)
        #expect(bare.settings.icon.foreground.isHidden == true)

        // Rule 2: any other icon foreground key is a request for a foreground.
        let styled = try Self.decode(["icon-bg": "art.png", "icon-symbol-color": "green"])
        #expect(styled.settings.icon.foreground.isHidden == false)
        let named = try Self.decode(["icon-bg": "art.png", "icon-fg": "symbol:heart.fill"])
        #expect(named.settings.icon.foreground.isHidden == false)

        // Rule 1: an explicit key wins either way, and outranks rule 2.
        let forcedOn = try Self.decode(["icon-bg": "art.png", "icon-fg-visibility": true])
        #expect(forcedOn.settings.icon.foreground.isHidden == false)
        let forcedOff = try Self.decode([
            "icon-bg": "art.png", "icon-symbol-color": "green", "icon-fg-visibility": false,
        ])
        #expect(forcedOff.settings.icon.foreground.isHidden == true)
    }

    @Test("A generated icon background never touches the foreground", arguments: [
        "standard", "custom-gradient", "prerendered-liquid-glass",
    ])
    func generatedIconBackground_leavesTheForegroundAlone(_ kind: String) throws {
        // The rule is conditional on a freshly *imported* background; nothing else may
        // reach the foreground's visibility.
        let result = try Self.decode(["icon-bg": kind])
        #expect(result.settings.icon.foreground.isHidden == false)
    }

    @Test("An imported badge background alone hides the badge foreground")
    func importedBadgeBackgroundAlone_hidesTheForeground() throws {
        // The codec's mirror of the badge's foreground rule: absent
        // `badge-fg-visibility` + an imported badge background ⇒ hidden. One of the
        // three conditional baselines phase 7 has to match on encode.
        let bare = try Self.decode(["badge-bg": "art.png"])
        #expect(bare.settings.badge.isVisible == true)
        #expect(bare.settings.badge.background.isHidden == false)
        #expect(bare.settings.badge.foreground.isHidden == true)

        // Rule 2: naming a foreground key is a request for a foreground.
        let styled = try Self.decode(["badge-bg": "art.png", "badge-symbol-color": "red"])
        #expect(styled.settings.badge.foreground.isHidden == false)

        // Rule 1: an explicit statement wins either way.
        let forcedOn = try Self.decode(["badge-bg": "art.png", "badge-fg-visibility": true])
        #expect(forcedOn.settings.badge.foreground.isHidden == false)
        let forcedOff = try Self.decode(["badge-bg": "art.png", "badge-fg-visibility": false])
        #expect(forcedOff.settings.badge.foreground.isHidden == true)
    }

    @Test("invalid JSON is the one fatal error")
    func invalidJSONThrows() {
        #expect(throws: MicaConfigError.self) {
            _ = try MicaConfigCodec.decode(json: Data("{ truncated".utf8), configDirectory: nil)
        }
        #expect(throws: MicaConfigError.notAnObject) {
            _ = try MicaConfigCodec.decode(json: Data("[1, 2]".utf8), configDirectory: nil)
        }
    }

    // MARK: - Path resolution

    @Test("relative image paths resolve against the configuration's directory")
    func relativePathsAnchorToConfigDirectory() throws {
        nonisolated(unsafe) var seen: URL?
        let directory = URL(fileURLWithPath: "/tmp/claude/configs")
        _ = try Self.decode(
            ["icon-bg": "Assets/bg.png"],
            configDirectory: directory,
            loadImage: { url in
                seen = url
                return try ImportedImage.testFixture(sourceName: url.lastPathComponent)
            }
        )
        #expect(seen?.path == "/tmp/claude/configs/Assets/bg.png")
    }

    // MARK: - AppexColor.parsing

    @Test("a named token keeps Apple's curated rendering")
    func appexParsingKeepsTokens() throws {
        #expect(try AppexColor.parsing(cliString: "teal") == .named(.teal))
        #expect(try AppexColor.parsing(cliString: "grey") == .named(.gray), "British spelling normalises")
    }

    @Test("a non-token resolves to custom components that reproduce plistValue")
    func appexParsingMatchesPlistValue() throws {
        for input in ["white:0.5", "#FF1736", "srgb:1,0.0902,0.2118", "display-p3:1,0.2,0"] {
            let parsed = try AppexColor.parsing(cliString: input)
            #expect(parsed.isCustom)
            #expect(parsed.plistValue == (try AppexColor.plistValue(fromCLIString: input)))
        }
    }

    /// What a System-mode colour is *written* as, which is not what the plist
    /// gets. `plistValue` is Apple's grammar — bare clamped components — and Mica
    /// stopped accepting that spelling in Phase 3, so writing it into a
    /// configuration would produce a file only the System-mode branch could read
    /// back. `configValue` is the spelling every other colour in the file uses,
    /// and it keeps provenance: `white:0.5` comes back following the appearance
    /// rather than as components that merely matched on the day it was saved.
    @Test("a System-mode colour is written in the shared grammar, not the plist's")
    func appexConfigValueUsesTheSharedGrammar() throws {
        #expect(AppexColor.named(.teal).configValue == "teal")

        let translucent = try AppexColor.parsing(cliString: "white:0.5")
        #expect(translucent.configValue == "white:0.5")
        #expect(translucent.plistValue == "1,1,1,0.5", "the plist still gets Apple's form")

        // A written value has to read back — and read back to the same thing.
        for input in ["white:0.5", "#FF1736", "srgb:1,0.0902,0.2118", "teal"] {
            let once = try AppexColor.parsing(cliString: input)
            let twice = try AppexColor.parsing(cliString: once.configValue)
            #expect(once == twice, "\(input) → \(once.configValue) did not survive")
            #expect(twice.configValue == once.configValue, "\(input) is not stable")
        }
    }

    // MARK: - Asset catalog

    @Test("byte-identical images share one file")
    func catalogDeduplicatesBytes() throws {
        var catalog = MicaConfigAssetCatalog()
        let image = try ImportedImage.testFixture(sourceName: "Logo.png")
        let twin = ImportedImage(id: UUID(), imageData: image.imageData, sourceName: "Copy.png", isFileIcon: false)
        #expect(catalog.relativePath(for: image) == "Logo.png")
        #expect(catalog.relativePath(for: twin) == "Logo.png")
        #expect(catalog.assets.count == 1)
    }

    @Test("a name collision with different bytes gets a suffix")
    func catalogSuffixesCollisions() throws {
        var catalog = MicaConfigAssetCatalog()
        let red = try ImportedImage.testFixture(fill: .systemRed, sourceName: "Icon.png")
        let blue = try ImportedImage.testFixture(fill: .systemBlue, sourceName: "Icon.jpeg")
        #expect(catalog.relativePath(for: red) == "Icon.png")
        #expect(catalog.relativePath(for: blue) == "Icon-2.png", "everything becomes .png")
    }

    @Test("source names are sanitised")
    func catalogSanitisesNames() throws {
        var catalog = MicaConfigAssetCatalog()
        let sneaky = try ImportedImage.testFixture(sourceName: "../escape.png")
        #expect(catalog.relativePath(for: sneaky) == "escape.png")
        var second = MicaConfigAssetCatalog()
        let empty = try ImportedImage.testFixture(sourceName: "...")
        #expect(second.relativePath(for: empty) == "Image.png")
    }

    @Test("a relative directory prefixes every allocated path")
    func catalogRelativeDirectory() throws {
        var catalog = MicaConfigAssetCatalog(relativeDirectory: "Assets")
        let image = try ImportedImage.testFixture(sourceName: "Logo.png")
        #expect(catalog.relativePath(for: image) == "Assets/Logo.png")
    }

    @Test("the test fixtures have distinct bytes")
    func fixturesHaveDistinctBytes() throws {
        // NSBitmapImageRep.setColor once made every fill byte-identical and the
        // dedup rule collapsed "distinct" fixtures; this pins the fixture path.
        let red = try ImportedImage.pngData(fill: .systemRed)
        let blue = try ImportedImage.pngData(fill: .systemBlue)
        #expect(red != blue)
    }
}
