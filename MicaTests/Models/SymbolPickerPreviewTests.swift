// SymbolPickerPreviewTests.swift
import SwiftUI
import Testing
@testable import Mica

@Suite("Symbol picker rendering preview")
@MainActor
struct SymbolPickerPreviewTests {

    @Test("Every mode leads with the fixed primary colour")
    func everyModeLeadsWithPrimary() {
        for style in SymbolRenderingStyle.allCases {
            let colors = SymbolPickerPreview.colors(for: style)
            #expect(colors.first == .primary, "\(style.rawValue) does not lead with primary")
        }
    }

    @Test("Palette mode is primary, blue, red")
    func paletteIsPrimaryBlueRed() {
        #expect(SymbolPickerPreview.colors(for: .palette) == [.primary, .blue, .red])
    }

    /// Three styles select `foregroundStyle`'s three-argument overload in the view, so
    /// a mode that grew a second colour would silently start tinting the *secondary*
    /// level of a symbol that has none.
    @Test("Only palette supplies more than one colour", arguments: [
        SymbolRenderingStyle.monochrome, .hierarchical, .multicolor,
    ])
    func nonPaletteModesSupplyOneColour(style: SymbolRenderingStyle) {
        #expect(SymbolPickerPreview.colors(for: style) == [.primary])
    }

    /// The preference key is a stored contract: changing it silently resets everyone's
    /// choice, and its `symbolPicker.` prefix is what keeps it out of the inspector's
    /// namespace.
    @Test("The stored key is stable")
    func storedKeyIsStable() {
        #expect(SymbolPickerPreview.renderingStyleKey == "symbolPicker.renderingStyle")
    }

    /// `@AppStorage` stores the raw value, so a mode must survive the round trip
    /// through UserDefaults — which it only does while every case's raw value is a
    /// non-empty string the enum can parse back.
    @Test("Every mode round-trips through its stored raw value")
    func everyModeRoundTripsThroughItsRawValue() {
        for style in SymbolRenderingStyle.allCases {
            #expect(SymbolRenderingStyle(rawValue: style.rawValue) == style)
        }
    }
}
