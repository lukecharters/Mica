import ArgumentParser
import Foundation

struct GetIconCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "geticon",
        abstract: "Export icons from a file or from every item inside a directory."
    )

    @Argument(help: "Path to a file or directory")
    var inputPath: String

    @Argument(help: "Destination directory for exported PNG files (defaults to working directory)")
    var outputPath: String?

    @Option(name: [.short, .long], help: "Icon size in pixels")
    var size: Int = 512

    @Option(name: [.customLong("scalefactor")], help: "Output scale factor (1 for 1x, 2 for 2x resolution)")
    var scaleFactor: Int = 1

    @Flag(name: [.short, .long], help: "Process directory contents recursively")
    var recursive: Bool = false

    @Option(name: [.customLong("depth")], help: "Maximum nested depth to process when input is a directory (0 includes only direct children)")
    var depth: Int?

    @Option(name: [.customLong("colorspace")], help: "Color space to render the icon in (displayP3 or sRGB)")
    var colorSpace: IconColorSpace = .displayP3

    mutating func validate() throws {
        guard size > 0 else {
            throw ValidationError("Size must be greater than 0. You provided: \(size)")
        }

        guard scaleFactor == 1 || scaleFactor == 2 else {
            throw ValidationError("--scalefactor must be 1 or 2")
        }

        if let depth {
            guard depth >= 0 else {
                throw ValidationError("--depth must be zero or greater")
            }
            guard recursive else {
                throw ValidationError("--depth requires --recursive")
            }
        }
    }

    mutating func run() throws {
        do {
            try runExtraction()
        } catch let error as CLIError {
            print("Generation Error: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("Unexpected Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    private func runExtraction() throws {
        let fm = FileManager.default
        let resolvedInputPath = (inputPath as NSString).expandingTildeInPath

        var isDirectoryRef = ObjCBool(false)
        guard fm.fileExists(atPath: resolvedInputPath, isDirectory: &isDirectoryRef) else {
            throw CLIError.fileSystem("Bundle not found: \(resolvedInputPath)")
        }
        let isDirectory = isDirectoryRef.boolValue

        let inputURL = URL(fileURLWithPath: resolvedInputPath)
        let isPackage = (try? inputURL.resourceValues(forKeys: [.isPackageKey]))?.isPackage ?? false

        let outputDirectory = try OutputResolver.resolveOutputDirectory(outputPath)

        if isDirectory && !isPackage {
            guard recursive else {
                throw CLIError.invalidArgument("Input is a directory at \(resolvedInputPath). Pass --recursive to export its contents.")
            }
            try exportDirectory(at: resolvedInputPath, to: outputDirectory)
        } else {
            try exportSingleItem(at: resolvedInputPath, to: outputDirectory)
        }
    }

    private func exportSingleItem(at path: String, to outputDirectory: URL) throws {
        let filename = OutputResolver.suggestedIconFilename(forItemAt: path, size: size, scaleFactor: scaleFactor)
        let destination = outputDirectory.appendingPathComponent(filename)
        try IconExtractor.saveIcon(
            forBundleAt: path,
            size: size,
            scaleFactor: scaleFactor,
            colorSpace: colorSpace,
            destination: destination
        )
        print("Icon saved to \(destination.path)")
    }

    private func exportDirectory(at path: String, to outputDirectory: URL) throws {
        let rootURL = URL(fileURLWithPath: path, isDirectory: true)
        let maxDepth = depth ?? 1
        let items = try collectItems(inDirectory: rootURL, maxDepth: maxDepth)

        let filteredItems = filterItems(items, excluding: outputDirectory, relativeTo: rootURL)

        guard !filteredItems.isEmpty else {
            print("No files found in \(rootURL.path)")
            return
        }

        for item in filteredItems {
            let destination = try destinationURL(for: item, rootDirectory: rootURL, outputDirectory: outputDirectory)
            try IconExtractor.saveIcon(
                forBundleAt: item.path,
                size: size,
                scaleFactor: scaleFactor,
                colorSpace: colorSpace,
                destination: destination
            )
            print("Icon saved to \(destination.path)")
        }

        let count = filteredItems.count
        let summary = "Exported \(count) icon\(count == 1 ? "" : "s") to \(outputDirectory.path)"
        print(summary)
    }

    private func collectItems(inDirectory rootURL: URL, maxDepth: Int) throws -> [URL] {
        var results: [URL] = []
        var queue: [(URL, Int)] = [(rootURL, 0)]
        let fm = FileManager.default
        var index = 0

        while index < queue.count {
            let (currentURL, currentDepth) = queue[index]
            index += 1

            let childURLs: [URL]
            do {
                childURLs = try fm.contentsOfDirectory(
                    at: currentURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey],
                    options: [.skipsPackageDescendants]
                )
            } catch {
                throw CLIError.fileSystem("Failed to enumerate \(currentURL.path): \(error.localizedDescription)")
            }

            let sortedChildren = childURLs.sorted { lhs, rhs in
                lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
            }

            for child in sortedChildren {
                let childDepth = currentDepth + 1
                results.append(child)

                guard childDepth <= maxDepth else { continue }

                let resourceValues = try? child.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey])
                let isDirectory = resourceValues?.isDirectory ?? false
                let isPackage = resourceValues?.isPackage ?? false
                let isSymbolicLink = resourceValues?.isSymbolicLink ?? false

                if isDirectory && !isPackage && !isSymbolicLink && childDepth < maxDepth {
                    queue.append((child, childDepth))
                }
            }
        }

        return results
    }

    private func filterItems(_ items: [URL], excluding outputDirectory: URL, relativeTo rootDirectory: URL) -> [URL] {
        let standardizedRoot = rootDirectory.standardizedFileURL
        let standardizedOutput = outputDirectory.standardizedFileURL

        let rootPath = standardizedRoot.path
        let outputPath = standardizedOutput.path
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        guard outputPath == rootPath || outputPath.hasPrefix(rootPrefix) else {
            return items
        }

        let outputPrefix = outputPath.hasSuffix("/") ? outputPath : outputPath + "/"

        return items.filter { item in
            let path = item.standardizedFileURL.path
            if path == outputPath {
                return false
            }

            return !path.hasPrefix(outputPrefix)
        }
    }

    private func destinationURL(for itemURL: URL, rootDirectory: URL, outputDirectory: URL) throws -> URL {
        let rootPath = rootDirectory.path
        var relativePath = itemURL.path

        if relativePath.hasPrefix(rootPath) {
            relativePath.removeFirst(rootPath.count)
        }

        if relativePath.hasPrefix("/") {
            relativePath.removeFirst()
        }

        let relativeParent = (relativePath as NSString).deletingLastPathComponent
        var destinationDirectory = outputDirectory

        if !relativeParent.isEmpty {
            destinationDirectory = destinationDirectory.appendingPathComponent(relativeParent)
        }

        do {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw CLIError.fileSystem("Failed to create directory \(destinationDirectory.path): \(error.localizedDescription)")
        }

        let filename = OutputResolver.suggestedIconFilename(forItemAt: itemURL.path, size: size, scaleFactor: scaleFactor)
        return destinationDirectory.appendingPathComponent(filename)
    }
}
