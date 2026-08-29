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

    /// The shaded fill exists because a white multicolour glyph on the control
    /// background reads as an empty cell, so the two fills have to differ. Comparing
    /// them is the only assertion available: both are dynamic system colours whose
    /// resolved components depend on the appearance the test happens to run under.
    @Test("Shading changes the cell fill")
    func shadingChangesTheCellFill() {
        #expect(SymbolPickerPreview.cellBackground(shaded: true)
                != SymbolPickerPreview.cellBackground(shaded: false))
        #expect(SymbolPickerPreview.cellBackground(shaded: false)
                == Color(nsColor: .controlBackgroundColor))
    }

    /// The tint is drawn *over* the fill, so the value that reads as "selected" on the
    /// control background disappears against the shaded one. A single opacity for both
    /// would lose the selected cell in exactly one of the two states.
    @Test("The selection tint is stronger over the shaded fill")
    func selectionTintIsStrongerOverTheShadedFill() {
        let shaded = SymbolPickerPreview.selectionTintOpacity(shaded: true)
        let plain = SymbolPickerPreview.selectionTintOpacity(shaded: false)
        #expect(shaded > plain)
        // Opaque would replace the fill rather than tint it, which is the thing the
        // two-layer background exists to avoid.
        #expect(shaded < 1)
        #expect(plain > 0)
    }

    /// The shaded choice is stored beside the rendering mode and under the same
    /// prefix; changing either key silently resets everyone's choice.
    @Test("The shaded-background key is stable")
    func shadedBackgroundKeyIsStable() {
        #expect(SymbolPickerPreview.shadedBackgroundKey == "symbolPicker.shadedBackground")
        #expect(SymbolPickerPreview.shadedBackgroundKey != SymbolPickerPreview.renderingStyleKey)
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
