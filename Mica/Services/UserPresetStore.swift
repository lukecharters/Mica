// Services/UserPresetStore.swift
//
// Presets the user saved: one JSON file each, in the app container beside the
// calibration JSONs.
//
// **One location, named in one place, and that is what buys CLI parity.**
// `mica-cli` is not sandboxed and can read the app's container path directly, so a
// user preset saved in the GUI is reachable from `--icon-preset` with no export
// step — as long as both surfaces agree on where it lives. `directoryURL` is that
// agreement; nothing else may spell the path.
//
// ## The file format is the preset, flattened
//
// A saved preset is its configuration keys at the top level, plus two envelope keys
// under a reserved prefix. Flattening is deliberate: the file is then a `MicaConfig`
// file that happens to carry two extra keys, so it can be read by eye, edited by
// hand, and — with the envelope stripped — passed to `--config` directly. The
// alternative (a `{"name": …, "keys": {…}}` wrapper) buys nothing and makes the
// common case, reading one, harder.
//
// The envelope keys use a `$` prefix, which no `MicaConfigKey` can have: every key
// is a `generate` long flag name, and a flag name starting with `$` is not
// expressible. So the two namespaces cannot collide, and the codec would report an
// unrecognised `$scope` as a warning rather than misreading it.
//
// ## Failure is per-file
//
// A directory that does not exist, a file that will not parse, a preset whose keys
// are outside its own scope: all of these lose that one preset and report it. None
// of them is fatal, because the built-ins have to keep working and a user with one
// bad file must still see the other nine.
//
// Shared with `mica-cli`, so this is one of the paths named in both
// `membershipExceptions` lists.

import Foundation

enum UserPresetStore {

    // MARK: - Location

    /// The reserved envelope keys. `$` cannot begin a `MicaConfigKey`, so these
    /// cannot collide with a configuration key in any future spelling.
    enum EnvelopeKey {
        static let name = "$name"
        static let scope = "$scope"

        static let all: Set<String> = [name, scope]
    }

    /// `~/Library/…/Application Support/Mica/Presets`.
    ///
    /// **The one spelling of this path.** In the sandboxed app it resolves inside
    /// the container (`~/Library/Containers/com.lukecharters.Mica/Data/…`); run from
    /// `mica-cli`, which is not sandboxed, `.applicationSupportDirectory` resolves to
    /// the real `~/Library/Application Support`, which is a *different* directory.
    /// `containerDirectoryURL` below is what closes that gap; this is the plain
    /// answer for the surface that owns the files.
    static var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mica", isDirectory: true)
            .appendingPathComponent("Presets", isDirectory: true)
    }

    /// The app container's copy of the same path, spelled absolutely.
    ///
    /// Needed only by `mica-cli`, and needed *because* the app is sandboxed: the GUI
    /// writes into its container, and an unsandboxed process asking for
    /// `.applicationSupportDirectory` does not land there. Without this the CLI would
    /// look in a directory the GUI never writes and report every user preset as
    /// unknown — a failure that looks like the preset not having been saved.
    static var containerDirectoryURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/com.lukecharters.Mica/Data/Library/Application Support/Mica/Presets",
                                   isDirectory: true)
    }

    /// Both locations, in the order they are searched.
    ///
    /// Inside the sandbox the two resolve to the same directory and the duplicate is
    /// dropped; outside it they differ and the container wins, because that is where
    /// the GUI actually wrote. A CLI-only user with no app container falls through to
    /// the plain path, so `mica-cli` on a machine with no Mica.app still has
    /// somewhere to read presets from.
    static var searchDirectories: [URL] {
        let container = containerDirectoryURL
        let plain = directoryURL
        return container.path == plain.path ? [container] : [container, plain]
    }

    // MARK: - Loading

    /// What loading produced: the presets that read, and one message per file that
    /// did not.
    struct LoadResult: Equatable {
        var presets: [MicaPreset] = []
        var problems: [String] = []
    }

    /// Load every user preset, sorted by name within scope.
    ///
    /// A missing directory is not a problem — it is what a user who has never saved
    /// a preset has, and reporting it would put an error in front of everyone on
    /// first launch.
    static func load(from directories: [URL] = searchDirectories) -> LoadResult {
        var result = LoadResult()
        var seen: Set<String> = []

        for directory in directories {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []

            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            where file.pathExtension.lowercased() == "json" {
                switch decode(fileAt: file) {
                case .success(let preset):
                    // A preset already loaded from an earlier directory wins, so the
                    // container's copy shadows a same-named one on the plain path
                    // rather than appearing twice in the pane.
                    guard seen.insert(preset.id).inserted else { continue }
                    result.presets.append(preset)
                case .failure(let problem):
                    result.problems.append("\(file.lastPathComponent): \(problem.description)")
                }
            }
        }

        result.presets.sort { ($0.scope.rawValue, $0.name) < ($1.scope.rawValue, $1.name) }
        return result
    }

    /// The user presets for one scope.
    static func load(_ scope: PresetScope, from directories: [URL] = searchDirectories) -> [MicaPreset] {
        load(from: directories).presets.filter { $0.scope == scope }
    }

    /// Why one preset file was skipped.
    ///
    /// A sentence rather than a code, because the only thing anyone does with it is
    /// read it: every failure here means "skip this file", and the difference between
    /// them is what the user has to fix. It is an `Error` solely so `Result` will take
    /// it; nothing catches one.
    struct Problem: Error, Equatable, CustomStringConvertible {
        var description: String
        init(_ description: String) { self.description = description }
    }

    /// Decode one file.
    static func decode(fileAt url: URL) -> Result<MicaPreset, Problem> {
        guard let data = try? Data(contentsOf: url) else {
            return .failure(Problem("could not be read"))
        }
        return decode(json: data)
    }

    static func decode(json data: Data) -> Result<MicaPreset, Problem> {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return .failure(Problem("is not a JSON object"))
        }
        guard let name = dictionary[EnvelopeKey.name] as? String,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(Problem("has no \"\(EnvelopeKey.name)\""))
        }
        guard let rawScope = dictionary[EnvelopeKey.scope] as? String,
              let scope = PresetScope(rawValue: rawScope) else {
            return .failure(Problem("has no valid \"\(EnvelopeKey.scope)\" (expected \"icon\" or \"badge\")"))
        }

        var keys: [String: MicaPresetValue] = [:]
        for (key, value) in dictionary where !EnvelopeKey.all.contains(key) {
            guard let presetValue = MicaPresetValue(json: value) else { continue }
            keys[key] = presetValue
        }

        let preset = MicaPreset(name: name, scope: scope, keys: keys, isBuiltIn: false)

        // Out-of-scope keys are dropped rather than applied, because the scoped copy
        // would drop them anyway — silently. Saying so is the difference between a
        // hand-edited file that half-works and one that explains itself.
        let unscoped = preset.unscopedKeys
        guard unscoped.isEmpty else {
            return .failure(Problem("is a \(scope.rawValue) preset but carries \(unscoped.joined(separator: ", "))"))
        }
        return .success(preset)
    }

    // MARK: - Saving

    /// Where a preset's file goes. The name is slugified rather than used raw:
    /// a display name may contain `/` or `:`, which a filename may not.
    ///
    /// The slug is not the identity — `$name` is — so two presets whose names
    /// slugify alike would collide on disk. `uniqueName(_:in:)` prevents that by
    /// rejecting the duplicate *name* first, which is the check a user can see.
    static func fileURL(for preset: MicaPreset, in directory: URL = directoryURL) -> URL {
        directory.appendingPathComponent("\(preset.scope.rawValue)-\(slug(preset.name)).json")
    }

    static func slug(_ name: String) -> String {
        let allowed = name.lowercased().map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        // Collapse runs and trim, so "Restart  Required!" is `restart-required`
        // rather than `restart--required-`.
        let collapsed = String(allowed)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "preset" : collapsed
    }

    /// Write a preset, creating the directory if needed. Overwrites a file with the
    /// same slug, which is what a save over an existing name should do.
    static func save(_ preset: MicaPreset, in directory: URL = directoryURL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var object = preset.jsonObject
        object[EnvelopeKey.name] = preset.name
        object[EnvelopeKey.scope] = preset.scope.rawValue

        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        )
        try data.write(to: fileURL(for: preset, in: directory), options: .atomic)
    }

    /// Delete a user preset. Deleting a built-in is not expressible — they are not
    /// files — so this takes the preset and asserts nothing.
    static func delete(_ preset: MicaPreset, in directory: URL = directoryURL) throws {
        guard !preset.isBuiltIn else { return }
        try FileManager.default.removeItem(at: fileURL(for: preset, in: directory))
    }

    // MARK: - Naming

    /// A name not already taken within `scope`, by appending " 2", " 3", ….
    ///
    /// Compared case-insensitively and against **built-ins too**: a user preset
    /// called "Installer" would sit in the same section as the built-in one, and two
    /// identically-labelled rows a click apart is the confusion this avoids. The
    /// suffix is the Finder's convention for the same problem.
    static func uniqueName(_ proposed: String, in scope: PresetScope, existing: [MicaPreset]) -> String {
        let trimmed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Preset" : trimmed
        let taken = Set(
            existing.filter { $0.scope == scope }.map { $0.name.lowercased() }
        )
        guard taken.contains(base.lowercased()) else { return base }

        var suffix = 2
        while taken.contains("\(base.lowercased()) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    // MARK: - Capturing the current icon

    /// The current settings as a preset of the given scope.
    ///
    /// Encodes through `MicaConfigCodec`, so what is captured is exactly what an
    /// exported configuration would carry — minimal above the identity set, and
    /// gated by applicability — and then keeps only the scope's own keys. Going
    /// through the encoder rather than reading `IconSettings` directly is what stops
    /// this becoming a third implementation of "which keys describe this icon".
    ///
    /// **Imported images are dropped, and that is a real limitation.** The encoder
    /// allocates a sidecar filename for one, which a preset has nowhere to put; the
    /// key would survive as a path to a file that does not exist. `droppedImageKeys`
    /// reports them so the save flow can say so rather than saving a preset that
    /// renders blank.
    struct Capture {
        var preset: MicaPreset
        /// Keys removed because they named a sidecar image this preset cannot carry.
        var droppedImageKeys: [String] = []
    }

    static func capture(
        _ settings: IconSettings,
        appexColors: MicaAppexColors,
        scope: PresetScope,
        name: String
    ) throws -> Capture {
        var assets = MicaConfigAssetCatalog()
        let data = try MicaConfigCodec.encode(settings: settings, appexColors: appexColors, assets: &assets)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MicaConfigError.notAnObject
        }

        // The image slots the encoder allocated, as the keys that hold them.
        let imageKeys: Set<String> = [
            settings.icon.foreground.source == .image ? MicaConfigKey.iconFG.rawValue : nil,
            settings.icon.background.source == .image ? MicaConfigKey.iconBG.rawValue : nil,
            settings.badge.foreground.source == .image ? MicaConfigKey.badgeFG.rawValue : nil,
            settings.badge.background.source == .image ? MicaConfigKey.badgeBG.rawValue : nil,
        ].compactMap { $0 }.reduce(into: Set<String>()) { $0.insert($1) }

        var keys: [String: MicaPresetValue] = [:]
        var dropped: [String] = []
        for (rawKey, value) in object {
            guard let key = MicaConfigKey(rawValue: rawKey), scope.owns(key) else { continue }
            if imageKeys.contains(rawKey) {
                dropped.append(rawKey)
                continue
            }
            guard let presetValue = MicaPresetValue(json: value) else { continue }
            keys[rawKey] = presetValue
        }

        addForegroundKey(to: &keys, from: settings, scope: scope)

        return Capture(
            preset: MicaPreset(name: name, scope: scope, keys: keys, isBuiltIn: false),
            droppedImageKeys: dropped.sorted()
        )
    }

    /// Put the scope's foreground key back if the encoder gated it away.
    ///
    /// **A preset carries its symbol even when the configuration encoder would not**,
    /// and this is the one place the two formats deliberately disagree. The encoder
    /// drops `icon-fg` / `badge-fg` for a layer that does not draw (gate 6: a hidden
    /// layer takes its appearance keys with it), which is right for a file describing
    /// a render. For a preset it is wrong twice over: the pane's thumbnail would have
    /// nothing to draw, and — for the badge — `badge-fg` is one of the three keys
    /// that *activate* a badge, so a badge preset without it applies to nothing.
    ///
    /// A background-only badge is the case that makes this compulsory rather than
    /// tidy: the encoder writes `badge-bg-color`, which is in the badge namespace but
    /// is **not** an activator, so every key in that capture would be inert.
    ///
    /// An image foreground is left alone — it was already dropped and reported by
    /// `droppedImageKeys`, and writing a `symbol:` key over it would replace the
    /// user's artwork with whatever symbol name the spec happened to be carrying.
    private static func addForegroundKey(
        to keys: inout [String: MicaPresetValue],
        from settings: IconSettings,
        scope: PresetScope
    ) {
        let key: MicaConfigKey
        let foreground: ForegroundSpec
        switch scope {
        case .icon:
            key = .iconFG
            foreground = settings.icon.foreground
        case .badge:
            key = .badgeFG
            foreground = settings.badge.foreground
        }
        guard keys[key.rawValue] == nil, foreground.source == .symbol else { return }
        keys[key.rawValue] = .string("symbol:\(foreground.symbolName)")
    }

    /// Whether `scope` currently holds something a preset can capture.
    ///
    /// Only the badge can answer no. An icon always draws something; a badge that is
    /// switched off has no state worth naming, and saving one would produce a preset
    /// that turns a badge *on* — the opposite of what the user was looking at when
    /// they saved it.
    static func canCapture(_ settings: IconSettings, scope: PresetScope) -> Bool {
        switch scope {
        case .icon:  return true
        case .badge: return settings.badge.isVisible
        }
    }
}
