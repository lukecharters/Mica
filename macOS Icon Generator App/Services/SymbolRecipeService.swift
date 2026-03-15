// SymbolRecipeService.swift - Per-symbol sizing from container_recipes.plist
import SwiftUI

struct SymbolRecipe {
    let pointsizeToShapeMul: Double
    let xOffset: Double
    let yOffset: Double
    let symbolWeight: Font.Weight
}

struct SymbolRecipeService {
    /// Lookup a recipe for the given symbol name (rounded_rect shape, size 29)
    static func recipe(for symbolName: String) -> SymbolRecipe? {
        guard let entry = recipeStore[symbolName] else { return nil }
        return entry
    }

    /// All symbol names that have a recipe in container_recipes.plist
    static var allSymbolNames: [String] {
        recipeStore.keys.sorted()
    }

    // MARK: - Private

    /// Lazy-loaded, thread-safe recipe dictionary
    private static let recipeStore: [String: SymbolRecipe] = {
        guard let root = loadPlist() else { return [:] }
        guard let symbols = root["symbols"] as? [String: Any] else { return [:] }

        var store: [String: SymbolRecipe] = [:]
        store.reserveCapacity(symbols.count)

        for (name, value) in symbols {
            guard let symbolDict = value as? [String: Any],
                  let shapes = symbolDict["shapes"] as? [String: Any],
                  let roundedRect = shapes["rounded_rect"] as? [String: Any],
                  let size29 = roundedRect["29"] as? [String: Any],
                  let mulString = size29["pointsize_to_shape_mul"] as? String,
                  let mul = Double(mulString) else { continue }

            let xOffset: Double = {
                guard let s = size29["x_offset"] as? String else { return 0 }
                return Double(s) ?? 0
            }()

            let yOffset: Double = {
                guard let s = size29["y_offset"] as? String else { return 0 }
                return Double(s) ?? 0
            }()

            let weight: Font.Weight = {
                guard let w = size29["symbol_weight"] as? String else { return .regular }
                return w == "Medium" ? .medium : .regular
            }()

            store[name] = SymbolRecipe(
                pointsizeToShapeMul: mul,
                xOffset: xOffset,
                yOffset: yOffset,
                symbolWeight: weight
            )
        }
        return store
    }()

    /// 2-tier plist loading: system framework path → bundled fallback
    private static func loadPlist() -> [String: Any]? {
        let systemPath = "/System/Library/PrivateFrameworks/SFSymbols.framework/Versions/A/Resources/CoreGlyphsPrivate.bundle/Contents/Resources/container_recipes.plist"

        if let data = try? Data(contentsOf: URL(fileURLWithPath: systemPath)),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            return plist
        }

        // Fallback: bundled copy
        if let url = Bundle.main.url(forResource: "container_recipes", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            return plist
        }

        return nil
    }
}
