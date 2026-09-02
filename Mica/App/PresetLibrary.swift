// App/PresetLibrary.swift
//
// The one list of presets every surface reads — the toolbar popovers in each icon
// window and the Presets window. A save or a delete made from any of them is
// visible to all of them at once, because there is one list.

import Foundation

/// Built-ins first, then the user's saved presets, each decoded once.
///
/// **Decoding is the expensive part and it happens only here.** A preset's thumbnail
/// settings, its crop corner and its advanced-controls indicator all come from one
/// `ResolvedPreset`, made on `reload()` — never from a view's `body`, which repaints on
/// every edit to the icon.
///
/// `reload()` is the only thing that touches the filesystem, and callers decide when:
/// a library surface appearing, and the moment after a save or a delete. Construction
/// reads nothing, so a window can be built without paying for the directory.
@MainActor
@Observable
final class PresetLibrary {
    static let shared = PresetLibrary()

    /// Where user presets are read from. A parameter so tests can point it at a
    /// temporary directory rather than the app container.
    private let directories: [URL]

    /// The user's saved presets, as last read.
    private(set) var user: [MicaPreset] = []

    /// Every preset, built-ins first, decoded and ready to draw.
    private(set) var resolved: [ResolvedPreset] = ResolvedPreset.resolve(PresetCatalog.builtIn)

    /// Everything a new name has to be uniqued against.
    var all: [MicaPreset] { PresetCatalog.builtIn + user }

    init(directories: [URL] = UserPresetStore.searchDirectories) {
        self.directories = directories
    }

    /// Re-read the user presets from disk and rebuild the resolved list.
    ///
    /// Returns the problems, one per file that could not be used, for the caller to
    /// report once, joined — the library has no reporter of its own, and which window
    /// shows the alert is the caller's business.
    @discardableResult
    func reload() -> [String] {
        let result = UserPresetStore.load(from: directories)
        user = result.presets
        // Built-ins first, so a user preset of the same name sorts after the one it
        // was uniqued against rather than in front of it.
        resolved = ResolvedPreset.resolve(PresetCatalog.builtIn + result.presets)
        return result.problems
    }
}
