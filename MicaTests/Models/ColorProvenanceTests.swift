// ColorProvenanceTests.swift
//
// Phase 2 of the colour-resolution plan: `IconSettings` stores colours *with
// their provenance*, so a token stays a token from the flag or the file all the way
// back out again.
//
// These are end-to-end pins on the property that motivated the change, rather than
// unit tests of `MicaColorValue` (those are in `MicaColorValueTests`). Each one
// fails if some layer flattens a colour to components on the way through — which is
// what every layer did until 2026-08-02, because `IconSettings` held a bare `Color`
// and the only way to recover a name was to compare values.

import Testing
import SwiftUI
import AppKit
import Foundation
@testable import Mica

@Suite(.tags(.unit))
@MainActor
struct ColorProvenanceTests {

    private static func roundTrip(_ settings: IconSettings) throws -> IconSettings {
        var catalog = MicaConfigAssetCatalog()
        let json = try MicaConfigCodec.encode(
            settings: settings, appexColors: MicaAppexColors(), assets: &catalog
        )
        return try MicaConfigCodec.decode(json: json, configDirectory: nil, loadImage: { _ in
            throw ImportedImage.FixtureError.bitmapCreationFailed
        }).settings
    }

    private static func encodedValue(_ key: String, _ settings: IconSettings) throws -> String? {
        var catalog = MicaConfigAssetCatalog()
        let json = try MicaConfigCodec.encode(
            settings: settings, appexColors: MicaAppexColors(), assets: &catalog
        )
        let object = try JSONSerialization.jsonObject(with: json) as? [String: Any]
        return object?[key] as? String
    }

    // MARK: - A token survives the whole way round

    @Test("a token colour is written as its token, not as components")
    func tokenIsWrittenAsAToken() throws {
        var settings = IconSettings()
        settings.icon.background.source = .color
        settings.icon.background.color = .token("blue")
        #expect(try Self.encodedValue("icon-bg-color", settings) == "blue")
    }

    @Test("a token survives encode → decode as the same token")
    func tokenSurvivesRoundTrip() throws {
        var settings = IconSettings()
        settings.icon.background.source = .color
        settings.icon.background.color = .token("blue")
        settings.icon.foreground.color = .token("primary")
        let back = try Self.roundTrip(settings)
        #expect(back.icon.background.color.source == .token("blue"))
        #expect(back.icon.foreground.color.source == .token("primary"))
    }

    @Test("a token plus an opacity survives as both halves")
    func fadedTokenSurvivesRoundTrip() throws {
        // The bug named in §3 item 3 of the plan: `Color.primary.opacity(0.5)`
        // matched no token, so a configuration saved in Aqua reopened wrong in Dark
        // Aqua. Both halves have to make it through for the colour to stay adaptive.
        var settings = IconSettings()
        settings.icon.foreground.color = .token("primary", alpha: 0.5)
        #expect(try Self.encodedValue("icon-symbol-color", settings) == "primary:0.5")

        let back = try Self.roundTrip(settings)
        #expect(back.icon.foreground.color.source == .token("primary"))
        #expect(back.icon.foreground.color.alpha == 0.5)
    }

    @Test("a stored token still resolves per appearance after a round trip")
    func tokenStaysAdaptiveAfterRoundTrip() throws {
        var settings = IconSettings()
        settings.icon.background.source = .color
        settings.icon.background.color = .token("blue")
        let back = try Self.roundTrip(settings)

        func bytes(_ appearance: NSAppearance.Name) -> ColorParser.ExtendedComponents {
            var result: ColorParser.ExtendedComponents!
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                result = ColorParser.ExtendedComponents.resolving(back.icon.background.color.resolved)
            }
            return result
        }
        // Still two different colours — i.e. still a token, not frozen to one.
        #expect(bytes(.aqua) != bytes(.darkAqua))
    }

    // MARK: - A picked colour survives too, unclamped

    @Test("a Display P3 pick survives a round trip out of sRGB gamut")
    func wideGamutPickSurvivesRoundTrip() throws {
        // §1.2: the wheel is the default colour-panel tab and hands back Display
        // P3, so this is the ordinary case. Clamping here would quietly desaturate
        // every wide-gamut colour a user picked.
        var settings = IconSettings()
        settings.icon.background.source = .color
        settings.icon.background.color = MicaColorValue(
            resolving: Color(.displayP3, red: 1, green: 0, blue: 0, opacity: 1)
        )
        let written = try #require(try Self.encodedValue("icon-bg-color", settings))
        #expect(written.hasPrefix("extended-srgb:"))

        let back = try Self.roundTrip(settings)
        guard case .components(.srgb(let r, let g, _, _)) = back.icon.background.color.source else {
            Issue.record("expected components, got \(back.icon.background.color.source)")
            return
        }
        #expect(r > 1.0, "red was clamped to \(r)")
        #expect(g < 0.0, "green was clamped to \(g)")
    }

    // MARK: - Provenance from the CLI

    @Test("a CLI token flag stores a token, not a resolved colour")
    func cliFlagKeepsTheToken() throws {
        let value = try MicaColorValue(strictlyParsing: "blue")
        #expect(value.source == .token("blue"))
    }

    @Test("a CLI hex flag stores components")
    func cliHexStoresComponents() throws {
        let value = try MicaColorValue(strictlyParsing: "#123456")
        guard case .components = value.source else {
            Issue.record("expected components for a hex value, got \(value.source)")
            return
        }
    }

    // MARK: - What the inspector reads

    @Test("the picker's mode comes from the source, not from value equality")
    func pickerModeIsReadFromTheSource() throws {
        // `ColorPickerWithDropdown` shows the dropdown exactly when the value names
        // an offered preset. These four cases are what it branches on.
        #expect(MicaColorValue.token("blue").isPresentableToken)
        #expect(!MicaColorValue.token("primary").isPresentableToken)
        #expect(!MicaColorValue.components(.srgb(r: 0.2, g: 0.6, b: 0.9, a: 1)).isPresentableToken)

        // By-value recovery still happens where a string arrives with no provenance
        // — a hex value from a configuration earns its canonical spelling. It is the
        // *colour well* that must never mint a token; `aWellPickIsNeverAToken` below
        // is that rule.
        let parsedBlue = MicaColorValue(resolving: Color.blue)
        #expect(parsedBlue.isPresentableToken)
    }

    @Test("a token that is not a preset keeps its name while the well is shown")
    func nonPresetTokenIsNotFlattenedByBeingDisplayed() {
        // `primary` shows in the colour well because there is no swatch for it. That
        // must not convert it — the binding only writes on a real change, which is
        // what `Binding.asColor`'s equality guard is for.
        var value = MicaColorValue.token("primary")
        let binding = Binding(get: { value }, set: { value = $0 })
        binding.asColor.wrappedValue = value.resolved   // a no-op re-render write
        #expect(value.source == .token("primary"))
    }

    @Test("a colour well pick is never a token, even when it lands on one")
    func aWellPickIsNeverAToken() {
        // The bug this pins: dragging a slider onto a system colour rewrote the
        // value as that token, which flipped `ColorPickerWithDropdown` from the well
        // to the preset menu mid-drag. The well vanished from the hierarchy with the
        // shared NSColorPanel still open, so the colour froze on that token and no
        // further dragging moved it. A wheel pick is custom by construction.
        for landed in [Color.blue, .red, .white, .black, Color.primary] {
            var value = MicaColorValue.components(.srgb(r: 0.2, g: 0.6, b: 0.9, a: 1))
            let binding = Binding(get: { value }, set: { value = $0 })
            binding.asColor.wrappedValue = landed

            #expect(value.tokenName == nil, "a well pick minted the token \(value.stringValue)")
            guard case .components = value.source else {
                Issue.record("expected components from a well pick, got \(value.source)")
                continue
            }
            // Honest provenance, not a different colour: it still renders as what
            // the user dragged to.
            let picked = ColorParser.ExtendedComponents.resolving(landed)
                .rounded(to: MicaColorValue.precision)
            #expect(value.source == .components(picked))
        }
    }

    @Test("a preset stays a preset when the well hands back an equal colour")
    func anEqualWriteInADifferentColourSpaceDoesNotFlattenAToken() {
        // The panel can return the same colour in another colour space, which `!=`
        // on `Color` reads as an edit. The guard compares components at the stored
        // precision so it doesn't, and a token the user never touched survives.
        var value = MicaColorValue.token("blue")
        let binding = Binding(get: { value }, set: { value = $0 })
        let sameColourAnotherSpace = ColorParser.ExtendedComponents
            .resolving(value.resolved)
            .color
        binding.asColor.wrappedValue = sameColourAnotherSpace
        #expect(value.source == .token("blue"))
    }

    // MARK: - The appex bridge

    @Test("a System-mode preset is a token, and a custom colour keeps its own")
    func appexColourCarriesProvenance() throws {
        let preset = AppexColor.named(.mint)
        #expect(preset.plistValue == "mint")

        let custom = AppexColor.custom(MicaColorValue.components(.srgb(r: 1, g: 0, b: 0, a: 1)))
        #expect(custom.plistValue == "1,0,0,1")
        #expect(custom.customColor.source == .components(.srgb(r: 1, g: 0, b: 0, a: 1)))
    }

    @Test("an appex custom colour clamps only on the way to the plist")
    func appexClampsAtTheBoundaryNotInStorage() {
        // §4.4: the plist cannot carry wide gamut, so the string is clamped — but
        // the stored value keeps the components, so switching back to Mica mode
        // does not lose the colour.
        let wide = MicaColorValue.components(.srgb(r: 1.093, g: -0.2267, b: -0.1501, a: 1))
        let custom = AppexColor.custom(wide)
        #expect(custom.plistValue == "1,0,0,1")
        #expect(custom.customColor == wide)
    }
}
