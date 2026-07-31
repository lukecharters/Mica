// Services/MicaConfigAssetCatalog.swift
//
// Allocates the sidecar image files an exported configuration references. The
// codec's encode side is pure — it never touches the disk — so it records each
// imported image here and writes its allocated *relative path* into the JSON;
// the caller (the GUI's export flow) then writes `assets` beside the JSON file.
//
// Three rules, each with a test:
//
// 1. **Everything becomes `.png`** — `ImportedImage.imageData` is PNG-normalised
//    on import, so the extension is a statement of fact, not a conversion.
// 2. **Byte-identical images share one file**, under whichever name filed first.
// 3. **A name collision with *different* bytes gets a suffix** — `Icon.png`,
//    `Icon-2.png`. Two layers can legitimately import different files that happen
//    to share a filename.
//
// Assignment order is the codec's field order (icon foreground, icon background,
// badge foreground, badge background), so the same settings always produce the
// same names.

import Foundation

struct MicaConfigAssetCatalog: Equatable, Sendable {
    /// Optional subdirectory prepended to every allocated path, so a caller can
    /// keep sidecars out of the JSON's directory listing. Empty by default:
    /// sidecars sit right next to the JSON.
    var relativeDirectory: String

    /// Relative path → PNG bytes, ready to be written beside the JSON.
    private(set) var assets: [String: Data] = [:]

    init(relativeDirectory: String = "") {
        self.relativeDirectory = relativeDirectory
    }

    /// The relative path to record for `image`, registering its bytes if this is
    /// the first time they have been seen.
    mutating func relativePath(for image: ImportedImage) -> String {
        let base = Self.baseName(for: image.sourceName)

        // Rule 2: same bytes already filed, under any name.
        if let existing = assets.first(where: { $0.value == image.imageData })?.key {
            return existing
        }

        // Rules 1 and 3.
        let prefix = relativeDirectory.isEmpty ? "" : "\(relativeDirectory)/"
        var candidate = "\(prefix)\(base).png"
        var suffix = 2
        while assets[candidate] != nil {
            candidate = "\(prefix)\(base)-\(suffix).png"
            suffix += 1
        }
        assets[candidate] = image.imageData
        return candidate
    }

    /// The extension-less, filesystem-safe stem of a source name.
    ///
    /// `sourceName` is user-supplied by way of a filename, so it can contain a path
    /// separator, be a `..` traversal, or be unusable altogether. Separators become
    /// dashes; leading and trailing dots and dashes go, so no asset is a dotfile or
    /// reads as a flag; and anything left empty falls back to `Image` rather than
    /// producing an unnamed asset. `../escape.png` becomes `escape.png`.
    static func baseName(for sourceName: String) -> String {
        let stem = (sourceName as NSString).deletingPathExtension
        let cleaned = stem
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return cleaned.isEmpty ? "Image" : cleaned
    }
}
