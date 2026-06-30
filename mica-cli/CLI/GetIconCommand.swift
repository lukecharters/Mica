import ArgumentParser
import Foundation

struct GetIconCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Export icons from a file or from every item inside a directory.",
        usage: """
            mica-cli extract <path> [<options>]
            mica-cli extract /Applications/Notes.app
            mica-cli extract /Applications -o ~/Desktop/icons --recursive
            """,
        discussion: """
            EXAMPLES:

            Extract a single app's icon to the working directory:
              mica-cli extract /Applications/Notes.app

            Extract to a chosen directory at 2x resolution:
              mica-cli extract /System/Applications/Calculator.app \\
                -o ~/Desktop/icons --scale 2x

            Extract every item in a directory (one level deep):
              mica-cli extract /Applications -o ~/Desktop/icons --recursive

            Recurse into nested folders up to two levels:
              mica-cli extract ~/Projects -o ~/icons --recursive --depth 2 \\
                --size 256 --color-space sRGB
            """
    )

    @Argument(help: "Path to a file or directory")
    var inputPath: String

    @Option(
        name: [.customShort("o"), .customLong("output")],
        help: ArgumentHelp("Destination directory for exported PNG files (defaults to working directory)", valueName: "path")
    )
    var outputPath: String?

    @Option(name: [.short, .long], help: "Icon size in pixels")
    var size: Int = 512

    @Option(name: .long, help: ArgumentHelp("Output resolution: 1x (default) or 2x", valueName: "scale"))
    var scale: ExportScale = .oneX

    @Flag(name: [.short, .long], help: "Process directory contents recursively")
    var recursive: Bool = false

    @Option(name: [.customLong("depth")], help: "Maximum nested depth to process when input is a directory (0 includes only direct children)")
    var depth: Int?

    @Option(name: .long, help: ArgumentHelp("Color space to render the icon in (displayP3 or sRGB)", valueName: "space"))
    var colorSpace: IconColorSpace = .displayP3

    @OptionGroup(title: "Output")
    var output: OutputOptions

    mutating func validate() throws {
        guard size > 0 else {
            throw ValidationError("Size must be greater than 0. You provided: \(size)")
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
        let reporter = output.reporter
        do {
            let outputs = try runExtraction(reporter: reporter)
            if output.json {
                print(encodeJSON(CommandResultJSON(command: "extract", outputs: outputs)))
            }
        } catch let error as CLIError {
            try reportFailure(reporter, kind: error.kind, message: error.localizedDescription)
        } catch {
            try reportFailure(reporter, kind: "unexpected", message: error.localizedDescription)
        }
    }

    /// Emit a failure (human text to stderr, or a JSON error object to stdout)
    /// and throw `ExitCode.failure`. Never returns normally.
    private func reportFailure(_ reporter: OutputReporter, kind: String, message: String) throws -> Never {
        if output.json {
            print(encodeJSON(CommandErrorJSON(command: "extract", kind: kind, message: message)))
        } else {
            reporter.failure("Error: \(message)")
        }
        throw ExitCode.failure
    }

    private func runExtraction(reporter: OutputReporter) throws -> [OutputFileJSON] {
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
            return try exportDirectory(at: resolvedInputPath, to: outputDirectory, reporter: reporter)
        } else {
            return try exportSingleItem(at: resolvedInputPath, to: outputDirectory, reporter: reporter)
        }
    }

    private func exportSingleItem(at path: String, to outputDirectory: URL, reporter: OutputReporter) throws -> [OutputFileJSON] {
        let filename = OutputResolver.suggestedIconFilename(forItemAt: path, size: size, scaleFactor: scale.factor)
        let destination = outputDirectory.appendingPathComponent(filename)
        try IconExtractor.saveIcon(
            forBundleAt: path,
            size: size,
            scaleFactor: scale.factor,
            colorSpace: colorSpace,
            destination: destination
        )
        reporter.path(destination.path)
        let descriptor = outputDescriptor(destination: destination, source: path)
        reporter.status("Extracted 1 icon to \(outputDirectory.path)")
        return [descriptor]
    }

    private func exportDirectory(at path: String, to outputDirectory: URL, reporter: OutputReporter) throws -> [OutputFileJSON] {
        let rootURL = URL(fileURLWithPath: path, isDirectory: true)
        let maxDepth = depth ?? 1
        let items = try collectItems(inDirectory: rootURL, maxDepth: maxDepth)

        let filteredItems = filterItems(items, excluding: outputDirectory, relativeTo: rootURL)

        guard !filteredItems.isEmpty else {
            reporter.status("No files found in \(rootURL.path)")
            return []
        }

        var outputs: [OutputFileJSON] = []
        for item in filteredItems {
            let destination = try destinationURL(for: item, rootDirectory: rootURL, outputDirectory: outputDirectory)
            try IconExtractor.saveIcon(
                forBundleAt: item.path,
                size: size,
                scaleFactor: scale.factor,
                colorSpace: colorSpace,
                destination: destination
            )
            reporter.path(destination.path)
            reporter.detail("Extracted \(item.lastPathComponent)")
            outputs.append(outputDescriptor(destination: destination, source: item.path))
        }

        let count = outputs.count
        reporter.status("Exported \(count) icon\(count == 1 ? "" : "s") to \(outputDirectory.path)")
        return outputs
    }

    /// Build a JSON descriptor for a saved icon file.
    private func outputDescriptor(destination: URL, source: String) -> OutputFileJSON {
        let dimension = size * scale.factor
        let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path)
        let bytes = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        return OutputFileJSON(path: destination.path, width: dimension, height: dimension, bytes: bytes, source: source)
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

        let filename = OutputResolver.suggestedIconFilename(forItemAt: itemURL.path, size: size, scaleFactor: scale.factor)
        return destinationDirectory.appendingPathComponent(filename)
    }
}
