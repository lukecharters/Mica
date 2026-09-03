// App/PresetSearch.swift
//
// The Presets window's filter: one scope, narrowed by the search field.

import Foundation

enum PresetSearch {
    /// Whether a preset shown as `name` matches what was typed.
    ///
    /// Case- and diacritic-insensitive, on any part of the name, after trimming the
    /// query — `localizedStandardContains` is what Finder's search does. An empty
    /// query matches everything.
    static func matches(_ name: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return name.localizedStandardContains(trimmed)
    }

    /// The rows of one scope that match the query, in the order given.
    static func filter(_ rows: [ResolvedPreset], scope: PresetScope, query: String) -> [ResolvedPreset] {
        rows.filter { $0.scope == scope && matches($0.displayName, query: query) }
    }
}
