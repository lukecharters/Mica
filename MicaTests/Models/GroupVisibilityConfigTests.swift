// GroupVisibilityConfigTests.swift
// `icon-visibility` / `badge-visibility` as configuration keys: accepted on the way
// in, never produced on the way out. Phase 4 of
// the visibility-and-imported-backgrounds plan.
//
// The category is new — `processLevelNames` excludes flags that describe an
// *invocation*, which these do not; they describe the icon perfectly well and are
// simply sugar for writing both of a group's layer keys. Keeping them out of the
// encoder is what stops a file carrying two spellings of one state.

import Testing
import Foundation
@testable import Mica

@Suite("Group visibility configuration keys")
@MainActor
struct GroupVisibilityConfigTests {

    private func decode(_ config: [String: Any]) throws -> MicaConfigContents {
        let data = try JSONSerialization.data(withJSONObject: config, options: [])
        return try MicaConfigCodec.decode(json: data, configDirectory: nil)
    }

    private func encode(_ settings: IconSettings) throws -> [String: Any] {
        let data = try MicaConfigCodec.encode(settings: settings, appexColors: MicaAppexColors())
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    // MARK: - Decode

    @Test("icon-visibility false hides both icon layers")
    func iconVisibility_decodes() throws {
        let result = try decode(["icon-fg": "symbol:star.fill", "icon-visibility": false])
        #expect(result.settings.icon.foreground.isHidden == true)
        #expect(result.settings.icon.background.isHidden == true)
    }

    @Test("The group key applies first and a layer key overrides it")
    func groupThenLayerPrecedence() throws {
        // The builder rule, mirrored — decode has to agree rule for rule or the two
        // surfaces mean different things by the same file.
        let result = try decode([
            "icon-fg": "symbol:star.fill",
            "icon-visibility": false,
            "icon-fg-visibility": true,
        ])
        #expect(result.settings.icon.foreground.isHidden == false)
        #expect(result.settings.icon.background.isHidden == true)
    }

    @Test("badge-visibility false alone leaves the badge off")
    func badgeVisibilityFalseAlone_leavesTheBadgeOff() throws {
        // The single value most likely to be got wrong: a `badge-`-prefixed key
        // *and* a decode-only one. A key that switches something off must never be
        // what switches it on.
        let result = try decode(["icon-fg": "symbol:star.fill", "badge-visibility": false])
        #expect(result.settings.badge.isVisible == false)
    }

    @Test("badge-visibility true turns the badge on")
    func badgeVisibilityTrue_turnsTheBadgeOn() throws {
        let result = try decode(["icon-fg": "symbol:star.fill", "badge-visibility": true])
        #expect(result.settings.badge.isVisible == true)
    }

    @Test("badge-visibility off beats badge-fg activating the badge")
    func badgeVisibilityOff_beatsActivation() throws {
        let result = try decode([
            "icon-fg": "symbol:star.fill",
            "badge-fg": "symbol:plus",
            "badge-visibility": false,
        ])
        #expect(result.settings.badge.isVisible == false)
    }

    @Test("badge-visibility is not reported as an inert badge key")
    func badgeVisibility_isNotInert() throws {
        // It acted, so saying otherwise would be false. The rest of the badge
        // namespace still needs a foreground until phase 5.
        let result = try decode(["icon-fg": "symbol:star.fill", "badge-visibility": true])
        let inertWarnings = result.warnings.filter { $0.message.contains("inert") }
        #expect(inertWarnings.isEmpty, "unexpected warnings: \(result.warnings)")
    }

    // MARK: - Encode never writes them

    @Test("The encoder never writes a group visibility key", arguments: [
        "both layers hidden", "foreground only", "background only", "all visible",
    ])
    func encoderNeverWritesGroupKeys(_ variant: String) throws {
        var settings = IconSettings()
        switch variant {
        case "both layers hidden": settings.icon.isHidden = true
        case "foreground only": settings.icon.foreground.isHidden = true
        case "background only": settings.icon.background.isHidden = true
        default: break
        }
        settings.badge.isVisible = true

        let output = try encode(settings)
        for name in MicaConfigKey.decodeOnlyNames {
            #expect(output[name] == nil, "'\(name)' must never be encoded (\(variant))")
        }
    }

    @Test("A round trip normalises the sugar to the two layer keys")
    func roundTripNormalisesTheSugar() throws {
        // The file changes; the icon does not. This is the first case where
        // importing and re-exporting deliberately rewrites a key, so it is worth
        // saying out loud rather than discovering.
        let decoded = try decode(["icon-fg": "symbol:star.fill", "icon-visibility": false])
        let reEncoded = try encode(decoded.settings)

        #expect(reEncoded["icon-visibility"] == nil)
        #expect(reEncoded["icon-fg-visibility"] as? Bool == false)
        #expect(reEncoded["icon-bg-visibility"] as? Bool == false)

        // The visibility state itself survives the rewrite, which is the claim.
        let reDecoded = try decode(reEncoded)
        #expect(reDecoded.settings.icon.foreground.isHidden == true)
        #expect(reDecoded.settings.icon.background.isHidden == true)

        // What does NOT survive is the hidden layers' appearance: gate 6 takes a
        // hidden layer's keys with it, so `icon-fg` is dropped and the symbol comes
        // back as the default rather than star.fill. That is the format's
        // documented lossiness — the same terms as an invisible badge — and not
        // something this key introduces. Asserting full settings equality here
        // would be asserting a guarantee the format deliberately does not make.
        #expect(reDecoded.settings.icon.foreground.symbolName == ForegroundSpec.iconDefault.symbolName)
        #expect(decoded.settings.icon.foreground.symbolName == "star.fill")
    }

    @Test("A visible group's sugar normalises by disappearing entirely")
    func roundTripOfAVisibleGroup_writesNoVisibilityKeys() throws {
        // The other half: `icon-visibility: true` describes the default, so both
        // layer keys equal their baseline and are omitted. Nothing is lost, and the
        // group key is still not written.
        let decoded = try decode(["icon-fg": "symbol:star.fill", "icon-visibility": true])
        let reEncoded = try encode(decoded.settings)

        #expect(reEncoded["icon-visibility"] == nil)
        #expect(reEncoded["icon-fg-visibility"] == nil)
        #expect(reEncoded["icon-bg-visibility"] == nil)

        let reDecoded = try decode(reEncoded)
        #expect(reDecoded.settings == decoded.settings, "a visible group loses nothing")
    }

    @Test("Every decode-only key is a real key, and none is process-level")
    func decodeOnlyNamesAreWellFormed() {
        for name in MicaConfigKey.decodeOnlyNames {
            let key = MicaConfigKey(rawValue: name)
            #expect(key != nil, "'\(name)' is listed as decode-only but is not a key")
            #expect(key?.isDecodeOnly == true)
            #expect(!MicaConfigKey.processLevelNames.contains(name),
                    "'\(name)' cannot be both decode-only and process-level — they mean different things")
        }
    }
}
