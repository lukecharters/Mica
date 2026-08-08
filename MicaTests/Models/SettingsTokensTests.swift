// SettingsTokensTests.swift
// The CLI/config token vocabulary (Services/SettingsTokens.swift) is the single
// source the flag transforms, the settings builder and the configuration codec
// all read. These tests pin the two properties that make that safe: every case
// round-trips through its own token, and the handful of deliberate spellings
// (raw-value-backed modes, the superseded "macos11") stay what they are.

import Testing
import Foundation
@testable import Mica

@Suite(.tags(.unit))
struct SettingsTokensTests {

    // MARK: - Round trips

    @Test("Every SymbolRenderingStyle case round-trips its token")
    func renderingStyleRoundTrips() {
        for style in SymbolRenderingStyle.allCases {
            #expect(SymbolRenderingStyle.from(cliToken: style.cliToken) == style)
        }
    }

    @Test("Every SymbolWeight case round-trips its token")
    func symbolWeightRoundTrips() {
        for weight in SymbolWeight.allCases {
            #expect(SymbolWeight.from(cliToken: weight.cliToken) == weight)
        }
    }

    @Test("Every BadgePosition case round-trips its token")
    func badgePositionRoundTrips() {
        for position in BadgePosition.allCases {
            #expect(BadgePosition.from(cliToken: position.cliToken) == position)
        }
    }

    @Test("Every IconCornerRadiusStyle case round-trips its token")
    func cornerRadiusRoundTrips() {
        for style in IconCornerRadiusStyle.allCases {
            #expect(IconCornerRadiusStyle.from(cliToken: style.cliToken) == style)
        }
    }

    @Test("Every BackgroundShadowStyle case round-trips its token")
    func shadowStyleRoundTrips() {
        for style in BackgroundShadowStyle.allCases {
            #expect(BackgroundShadowStyle.from(cliToken: style.cliToken) == style)
        }
    }

    @Test("Every GenerationMode case round-trips its token")
    func generationModeRoundTrips() {
        for mode in GenerationMode.allCases {
            #expect(GenerationMode.from(cliToken: mode.cliToken) == mode)
        }
    }

    @Test("Every ExportColorSpace case round-trips its token")
    func colorSpaceRoundTrips() {
        for space in ExportColorSpace.allCases {
            #expect(ExportColorSpace.from(cliToken: space.cliToken) == space)
        }
    }

    // MARK: - Deliberate spellings

    @Test("The macOS 11-15 design spells as macos15 on both flags")
    func macOS15SpellsAsMacOS15() {
        #expect(BackgroundShadowStyle.macOS15.cliToken == "macos15")
        #expect(IconCornerRadiusStyle.macOS15.cliToken == "macos15")
    }

    // MARK: - Superseded spellings

    // "macos11" was the shipped token for both flags until 2026-08-08. It still
    // decodes so configurations exported before then keep loading, but it is
    // never written and never offered — see `supersededTokensAreNeverOffered`.

    @Test("macos11 still decodes to the macOS 15 style")
    func supersededTokenStillDecodes() {
        #expect(BackgroundShadowStyle.from(cliToken: "macos11") == .macOS15)
        #expect(IconCornerRadiusStyle.from(cliToken: "macos11") == .macOS15)
        #expect(BackgroundShadowStyle.from(cliToken: "MacOS11") == .macOS15, "matched case-insensitively too")
    }

    @Test("A superseded token is never offered as a valid one")
    func supersededTokensAreNeverOffered() {
        #expect(!BackgroundShadowStyle.allCLITokens.contains("macos11"))
        #expect(!IconCornerRadiusStyle.allCLITokens.contains("macos11"))
        #expect(BackgroundShadowStyle.allCLITokens == ["off", "macos15", "macos26"])
        #expect(IconCornerRadiusStyle.allCLITokens == ["off", "macos15", "macos26"])
    }

    @Test("A superseded token normalises to the canonical spelling")
    func supersededTokenNormalises() throws {
        let style = try #require(BackgroundShadowStyle.from(cliToken: "macos11"))
        #expect(style.cliToken == "macos15", "re-encoding a decoded macos11 writes macos15")
    }

    @Test("No enum but the two style pairs supersedes anything")
    func onlyStylesHaveSupersededTokens() {
        #expect(SymbolRenderingStyle.allCases.allSatisfy { $0.supersededCLITokens.isEmpty })
        #expect(SymbolWeight.allCases.allSatisfy { $0.supersededCLITokens.isEmpty })
        #expect(BadgePosition.allCases.allSatisfy { $0.supersededCLITokens.isEmpty })
        #expect(GenerationMode.allCases.allSatisfy { $0.supersededCLITokens.isEmpty })
        #expect(ExportColorSpace.allCases.allSatisfy { $0.supersededCLITokens.isEmpty })
    }

    @Test("A superseded token cannot shadow another case's canonical one")
    func canonicalTokensWinOverSuperseded() {
        // Guards the lookup order in `from(cliToken:)`: every canonical token
        // must still resolve to its own case, whatever any superseded list says.
        for style in BackgroundShadowStyle.allCases {
            #expect(BackgroundShadowStyle.from(cliToken: style.cliToken) == style)
        }
        for style in IconCornerRadiusStyle.allCases {
            #expect(IconCornerRadiusStyle.from(cliToken: style.cliToken) == style)
        }
    }

    @Test("Token matching is case-insensitive")
    func matchingIsCaseInsensitive() {
        #expect(BadgePosition.from(cliToken: "Bottom-Right") == .bottomRight)
        #expect(ExportColorSpace.from(cliToken: "displayp3") == .displayP3)
        #expect(SymbolWeight.from(cliToken: "ULTRALIGHT") == .ultraLight)
    }

    @Test("An unknown token matches nothing")
    func unknownTokenIsNil() {
        #expect(SymbolRenderingStyle.from(cliToken: "vibrant") == nil)
        #expect(BadgePosition.from(cliToken: "centre") == nil)
        #expect(BackgroundShadowStyle.from(cliToken: "sequoia") == nil, "the old case name was never a token, and supersession did not make it one")
    }

    // MARK: - Overloaded source values

    @Test("ForegroundValue parses symbol: prefixes and paths")
    func foregroundValueParses() {
        #expect(ForegroundValue(parsing: "symbol:star.fill") == .symbol("star.fill"))
        #expect(ForegroundValue(parsing: "SYMBOL:star.fill") == .symbol("star.fill"), "prefix is case-insensitive")
        #expect(ForegroundValue(parsing: "~/art.png") == .image("~/art.png"))
        #expect(ForegroundValue(parsing: "symbol:") == nil, "an empty symbol name is the caller's error to word")
    }

    @Test("ForegroundValue round-trips through cliValue")
    func foregroundValueRoundTrips() throws {
        let symbol = try #require(ForegroundValue(parsing: "symbol:star.fill"))
        #expect(ForegroundValue(parsing: symbol.cliValue) == symbol)
        let image = try #require(ForegroundValue(parsing: "/tmp/a.png"))
        #expect(ForegroundValue(parsing: image.cliValue) == image)
    }

    @Test("IconBackgroundValue parses keywords and paths")
    func iconBackgroundValueParses() {
        #expect(IconBackgroundValue(parsing: "standard") == .standard)
        #expect(IconBackgroundValue(parsing: "custom-gradient") == .customGradient)
        #expect(IconBackgroundValue(parsing: "prerendered-liquid-glass") == .preRendered)
        #expect(IconBackgroundValue(parsing: "Standard") == .standard, "keywords are case-insensitive")
        #expect(IconBackgroundValue(parsing: "~/bg.png") == .image("~/bg.png"))
    }

    @Test("BadgeBackgroundValue has no pre-rendered keyword")
    func badgeBackgroundValueParses() {
        #expect(BadgeBackgroundValue(parsing: "standard") == .standard)
        #expect(BadgeBackgroundValue(parsing: "custom-gradient") == .customGradient)
        #expect(BadgeBackgroundValue(parsing: "prerendered-liquid-glass") == .image("prerendered-liquid-glass"),
                "the icon-only keyword reads as a path for the badge")
    }

    @Test("Background values round-trip through cliValue")
    func backgroundValuesRoundTrip() {
        for value in [IconBackgroundValue.standard, .customGradient, .preRendered, .image("/tmp/x.png")] {
            #expect(IconBackgroundValue(parsing: value.cliValue) == value)
        }
        for value in [BadgeBackgroundValue.standard, .customGradient, .image("/tmp/x.png")] {
            #expect(BadgeBackgroundValue(parsing: value.cliValue) == value)
        }
    }

    // MARK: - Colour list splitting

    @Test("splitColorList accepts exactly the expected count")
    func splitColorListCounts() {
        #expect(splitColorList("red, blue", expecting: 2) == .ok(["red", "blue"]))
        #expect(splitColorList("red,blue,green", expecting: 3) == .ok(["red", "blue", "green"]))
        #expect(splitColorList("red", expecting: 2) == .wrongCount(1))
        #expect(splitColorList("red,blue,green", expecting: 2) == .wrongCount(3))
        #expect(splitColorList("red,", expecting: 2) == .emptyComponent)
    }
}
