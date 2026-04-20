// SymbolRecipeServiceTests.swift
// container_recipes.plist is Apple's hand-tuned per-symbol sizing table.
// These tests verify the loader parses known entries correctly and
// returns nil for absent ones.

import Testing
import SwiftUI
@testable import macOS_Icon_Generator_App

@Suite(.tags(.unit))
@MainActor
struct SymbolRecipeServiceTests {

    @Test("Loader finds star.fill with the expected multiplier and weight")
    func knownSymbol_starFill() throws {
        let recipe = try #require(SymbolRecipeService.recipe(for: "star.fill"))
        // Exact value from Apple's plist is 1.7023809523809523 — allow
        // a generous epsilon in case Apple re-ships the plist.
        #expect(abs(recipe.pointsizeToShapeMul - 1.7023809523809523) < 0.01)
        #expect(recipe.symbolWeight == .regular)
    }

    @Test("Loader finds folder.fill with the expected multiplier")
    func knownSymbol_folderFill() throws {
        let recipe = try #require(SymbolRecipeService.recipe(for: "folder.fill"))
        #expect(abs(recipe.pointsizeToShapeMul - 1.869281045751634) < 0.01)
    }

    @Test("Unknown symbol returns nil")
    func unknownSymbol_returnsNil() {
        #expect(SymbolRecipeService.recipe(for: "definitely_not_a_real_symbol_xyz123") == nil)
        #expect(SymbolRecipeService.recipe(for: "") == nil)
    }

    @Test("allSymbolNames is non-empty and sorted")
    func allSymbolNames_sortedAndPopulated() {
        let names = SymbolRecipeService.allSymbolNames
        #expect(names.count > 100, "Expected hundreds of symbols from container_recipes.plist")
        #expect(names == names.sorted())
    }

    @Test("A small corpus of shipped symbols all resolve to a positive multiplier",
          arguments: ["star.fill", "folder.fill", "gear", "heart.fill", "pencil"])
    func corpus_allResolvePositive(_ symbol: String) throws {
        let recipe = try #require(
            SymbolRecipeService.recipe(for: symbol),
            "Expected shipped recipe for \(symbol)"
        )
        #expect(recipe.pointsizeToShapeMul > 0)
        #expect([Font.Weight.regular, .medium].contains(recipe.symbolWeight))
    }
}
