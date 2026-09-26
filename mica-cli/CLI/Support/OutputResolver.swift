import Foundation

enum OutputResolver {
    static func resolveOutputDirectory(_ rawPath: String?) throws -> URL {
        let fm = FileManager.default

        guard let rawPath else {
            let cwd = fm.currentDirectoryPath
            return URL(fileURLWithPath: cwd, isDirectory: true)
        }

        let expanded = (rawPath as NSString).expandingTildeInPath
        let resolvedPath: String
        if expanded.hasPrefix("/") {
            resolvedPath = expanded
        } else {
            let cwd = fm.currentDirectoryPath
            resolvedPath = (cwd as NSString).appendingPathComponent(expanded)
        }

        let url = URL(fileURLWithPath: resolvedPath, isDirectory: true)
        let existing = nearestExistingPath(to: url.path)
        guard existing.isDirectory else {
            let message = existing.path == url.path
                ? "Output path is not a directory: \(url.path)"
                : "Output path is inside a file, not a directory: \(existing.path)"
            throw CLIError.fileSystem(message)
        }
        return url
    }

    /// The deepest path at or above `path` that exists, found by trimming one
    /// component at a time. Never creates anything: directories are made at the
    /// write, so a run refused by validation leaves none behind.
    static func nearestExistingPath(to path: String) -> (path: String, isDirectory: Bool) {
        let fm = FileManager.default
        var candidate = path
        while true {
            var isDirectory = ObjCBool(false)
            if fm.fileExists(atPath: candidate, isDirectory: &isDirectory) {
                return (candidate, isDirectory.boolValue)
            }
            let parent = (candidate as NSString).deletingLastPathComponent
            guard !parent.isEmpty, parent != candidate else {
                return (fm.currentDirectoryPath, true)
            }
            candidate = parent
        }
    }

    static func suggestedIconFilename(forItemAt path: String, size: Int, scaleFactor: Int) -> String {
        // lastPathComponent of "/" is "/" (not empty) — unusable in a filename.
        let baseName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let scaleSuffix = scaleFactor > 1 ? "@\(scaleFactor)x" : ""
        let safeBase = (baseName.isEmpty || baseName == "/") ? "Application" : baseName
        return "\(safeBase)-\(size)\(scaleSuffix).png"
    }
}
