// AppexColorTests.swift
// AppexColor bridges Apple's named enclosure tokens and arbitrary custom
// colours to the string values ISEnclosureColor / ISSymbolColor accept in an
// .appex Info.plist. These tests pin the plist-string formatting (verified
// against the real `1,0.0902,0.2118,1` value seen in a system icon plist) and
// the plist-value-based equality used by the generation keys.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
struct AppexColorTests {

    // MARK: - rgbaString formatting

    @Test("rgbaString reproduces Apple's authored sRGB value")
    func rgbaString_reproducesAppleValue() {
        let appleRed = Color(.sRGB, red: 1, green: 0.0902, blue: 0.2118, opacity: 1)
        #expect(AppexColor.rgbaString(from: appleRed) == "1,0.0902,0.2118,1")
    }

    @Test("rgbaString renders whole numbers compactly")
    func rgbaString_compactWholeNumbers() {
        #expect(AppexColor.rgbaString(from: .white) == "1,1,1,1")
        #expect(AppexColor.rgbaString(from: .black) == "0,0,0,1")
    }

    @Test("rgbaString(r:g:b:a:) clamps out-of-range components")
    func rgbaString_clamps() {
        #expect(AppexColor.rgbaString(r: 2.0, g: -1.0, b: 0.5, a: 1.0) == "1,0,0.5,1")
    }

    // MARK: - plistValue

    @Test("named colours resolve to their raw token")
    func plistValue_named() {
        #expect(AppexColor.named(.blue).plistValue == "blue")
        #expect(AppexColor.named(.white).plistValue == "white")
        #expect(AppexColor.white.plistValue == "white")
    }

    @Test("custom colours resolve to an r,g,b,a string")
    func plistValue_custom() {
        let c = AppexColor.custom(Color(.sRGB, red: 1, green: 0.0902, blue: 0.2118, opacity: 1))
        #expect(c.plistValue == "1,0.0902,0.2118,1")
        #expect(c.isCustom)
    }

    // MARK: - Equality (plist-value based)

    @Test("equality is based on the rendered plist value")
    func equality_plistValueBased() {
        #expect(AppexColor.blue == AppexColor.named(.blue))
        #expect(AppexColor.blue != AppexColor.green)
        // A custom colour that differs from a named token's plist string is unequal.
        let customRed = AppexColor.custom(Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1))
        #expect(customRed != AppexColor.named(.red))
    }

    @Test("equal colours hash equally")
    func hashing_matchesEquality() {
        #expect(AppexColor.blue.hashValue == AppexColor.named(.blue).hashValue)
    }

    // MARK: - displayColor & static constants

    @Test("displayColor reflects the active source")
    func displayColor_reflectsSource() {
        #expect(AppexColor.named(.blue).displayColor == AppexNamedColor.blue.previewColor)
        let custom = AppexColor.custom(.orange)
        #expect(custom.displayColor == .orange)
    }

    @Test("static constants map to the matching named token", arguments: AppexNamedColor.allCases)
    func staticConstants_matchTokens(_ token: AppexNamedColor) {
        #expect(AppexColor.named(token).plistValue == token.rawValue)
    }
}
