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
        var isDirectory = ObjCBool(false)

        if fm.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw CLIError.fileSystem("Output path is not a directory: \(url.path)")
            }
            return url
        }

        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw CLIError.fileSystem("Failed to create output directory \(url.path): \(error.localizedDescription)")
        }
        return url
    }

    static func suggestedIconFilename(forItemAt path: String, size: Int, scaleFactor: Int) -> String {
        // lastPathComponent of "/" is "/" (not empty) — unusable in a filename.
        let baseName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let scaleSuffix = scaleFactor > 1 ? "@\(scaleFactor)x" : ""
        let safeBase = (baseName.isEmpty || baseName == "/") ? "Application" : baseName
        return "\(safeBase)-\(size)\(scaleSuffix).png"
    }
}
