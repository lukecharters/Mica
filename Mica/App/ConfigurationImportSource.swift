// App/ConfigurationImportSource.swift
//
// Which of the two exported shapes the user picked, and where the JSON is inside it.
//
// `ConfigurationExportDocument` writes either a bare `.json` or a flat folder holding
// exactly one top-level `.json` plus its sidecar PNGs. This resolves either back to a
// JSON URL and the directory that relative image paths are measured from.
//
// The JSON inside a folder is found by **being the only one**, not by its name — the
// exporter names it from the icon's export base name, but a user is free to rename the
// folder or the file afterwards and re-import should still work.

import Foundation

struct ConfigurationImportSource {
    /// The JSON to decode.
    let jsonURL: URL

    /// What relative image paths in that JSON resolve against.
    let directory: URL

    /// Whether the user picked a bare `.json` rather than an exported folder. Decides
    /// whether the sidecar advisory below applies.
    let isBareJSON: Bool

    init(url: URL) throws {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

        guard isDirectory else {
            jsonURL = url
            directory = url.deletingLastPathComponent()
            isBareJSON = true
            return
        }

        let children = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )
        let jsonFiles = children.filter { $0.pathExtension.lowercased() == "json" }

        guard !jsonFiles.isEmpty else { throw ConfigurationImportError.noConfigurationInFolder }
        guard jsonFiles.count == 1 else {
            throw ConfigurationImportError.severalConfigurationsInFolder(jsonFiles.count)
        }

        jsonURL = jsonFiles[0]
        directory = url
        isBareJSON = false
    }

    /// The decoder's warnings, plus an explanation when the images are missing because
    /// of *how* the configuration was picked rather than anything wrong with it.
    ///
    /// Picking a bare `.json` out of an exported folder grants access to that file and
    /// nothing beside it — the sandbox's powerbox extends a grant to a chosen directory's
    /// children, never to a chosen file's siblings. So the settings import fine and every
    /// image slot comes back empty, which looks like corruption unless it is named.
    ///
    /// There is no way to obtain that sibling access, so the advice is to import the
    /// folder. Do not replace this with an attempt to widen the grant.
    func warningsAdvising(_ warnings: [MicaConfigWarning]) -> [MicaConfigWarning] {
        guard isBareJSON, warnings.contains(where: { Self.imageKeys.contains($0.key) })
        else { return warnings }

        return warnings + [
            MicaConfigWarning(
                key: "images",
                message: """
                    The images could not be read because only the JSON file was opened. \
                    Import the folder that contains it to bring the images with it.
                    """
            )
        ]
    }

    /// The four keys whose value can be an image path.
    private static let imageKeys: Set<String> = [
        MicaConfigKey.iconFG.rawValue,
        MicaConfigKey.iconBG.rawValue,
        MicaConfigKey.badgeFG.rawValue,
        MicaConfigKey.badgeBG.rawValue,
    ]
}

enum ConfigurationImportError: Error, LocalizedError, Equatable {
    case noConfigurationInFolder
    case severalConfigurationsInFolder(Int)

    var errorDescription: String? {
        switch self {
        case .noConfigurationInFolder:
            return "That folder has no configuration in it — an exported configuration folder contains a .json file."
        case .severalConfigurationsInFolder(let count):
            return "That folder has \(count) .json files in it, so there is no way to tell which is the configuration. Choose the .json file itself."
        }
    }
}
