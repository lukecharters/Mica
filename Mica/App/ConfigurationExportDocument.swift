// App/ConfigurationExportDocument.swift
//
// The FileDocument payload for the configuration fileExporter — not a document
// model, in the same sense as `PNGExportDocument`: write-only, with an
// `init(configuration:)` that refuses. Reading a configuration back in is
// `.fileImporter` plus `MicaConfigCodec.decode`, which never goes through here.
//
// ## Why the export is sometimes a folder
//
// A configuration that references no imported images is one JSON file, and that
// is what gets written. As soon as a layer holds an imported image the export
// becomes a *folder* containing the JSON and its sidecar PNGs.
//
// That is a sandbox constraint, not a stylistic one. The powerbox grants access
// to what the user actually chose in the save panel: choosing `Icon.json` grants
// that file and says nothing about its siblings, so writing `Icon-fg.png` beside
// it fails. Choosing a directory grants its children, so a folder can hold the
// JSON and every sidecar it names.
//
// The convention is pinned so the import side can rely on it: the folder holds
// exactly one top-level `.json` and its sidecar PNGs, all flat. `MicaConfigAssetCatalog`
// is therefore used with its default empty `relativeDirectory` — a subdirectory
// would put a `/` in the allocated paths, which this type would then have to
// turn into nested FileWrappers, and the importer would have to walk.

import SwiftUI
import UniformTypeIdentifiers

struct ConfigurationExportDocument: FileDocument {
    /// Both shapes the exporter can write. The call site picks one via
    /// `fileExporter(contentType:)` — `.folder` when `hasSidecars`, else `.json`.
    static var readableContentTypes: [UTType] { [.json, .folder] }

    /// The JSON's name *inside* the folder. Unused in the single-file case, where
    /// the save panel names the file. The importer finds the JSON by being the only
    /// one at the top level rather than by this name, so a user renaming the folder
    /// afterwards does not break re-import.
    let jsonName: String

    /// The encoded configuration.
    let json: Data

    /// Relative path → PNG bytes, as allocated by `MicaConfigAssetCatalog`. Flat by
    /// construction; see the note above.
    let assets: [String: Data]

    /// Whether this export needs to be a folder rather than a bare JSON file.
    var hasSidecars: Bool { !assets.isEmpty }

    /// The content type the exporter should be given for this document.
    var contentType: UTType { hasSidecars ? .folder : .json }

    init(
        settings: IconSettings,
        appexColors: MicaAppexColors = MicaAppexColors(),
        baseName: String
    ) throws {
        var catalog = MicaConfigAssetCatalog()
        self.json = try MicaConfigCodec.encode(
            settings: settings,
            appexColors: appexColors,
            assets: &catalog
        )
        self.assets = catalog.assets
        self.jsonName = "\(baseName).json"
    }

    init(configuration: ReadConfiguration) throws {
        // Write-only, like PNGExportDocument. Import goes through
        // MicaConfigCodec.decode, which needs the enclosing directory to resolve
        // sidecar paths — something a ReadConfiguration does not carry.
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        makeFileWrapper()
    }

    /// The wrapper `fileWrapper(configuration:)` returns, without the configuration.
    ///
    /// Split out because `FileDocumentWriteConfiguration` has no init reachable from a
    /// test — the same reason `PNGExportDocumentTests` cannot cover its write path at
    /// all. Here the wrapper's *shape* is the whole feature (file vs directory, and
    /// what the directory contains), so it needs to be assertable; the configuration
    /// is unused either way.
    func makeFileWrapper() -> FileWrapper {
        let jsonWrapper = FileWrapper(regularFileWithContents: json)
        guard hasSidecars else { return jsonWrapper }

        var children: [String: FileWrapper] = [jsonName: jsonWrapper]
        for (path, data) in assets {
            children[path] = FileWrapper(regularFileWithContents: data)
        }
        return FileWrapper(directoryWithFileWrappers: children)
    }
}
