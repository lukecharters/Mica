import CoreGraphics
import Foundation
import Testing
import ArgumentParser

@Suite struct GetIconCommandTests {

    // MARK: - Argument parsing

    @Test func parsesMinimalArguments() throws {
        let command = try GetIconCommand.parse(["/Applications/Notes.app"])
        #expect(command.inputPath == "/Applications/Notes.app")
        #expect(command.outputPath == nil)
        #expect(command.size == 512)
        #expect(command.scale == .oneX)
        #expect(command.recursive == false)
        #expect(command.depth == nil)
        #expect(command.colorSpace == .sRGB)
    }

    @Test func parsesAllOptions() throws {
        let command = try GetIconCommand.parse([
            "/Applications",
            "--output", "/tmp/icons",
            "--size", "256",
            "--scale", "2x",
            "--recursive",
            "--depth", "0",
            "--color-space", "sRGB"
        ])
        #expect(command.inputPath == "/Applications")
        #expect(command.outputPath == "/tmp/icons")
        #expect(command.size == 256)
        #expect(command.scale == .twoX)
        #expect(command.recursive == true)
        #expect(command.depth == 0)
        #expect(command.colorSpace == .sRGB)
    }

    @Test func parsesOutputShortFlag() throws {
        let command = try GetIconCommand.parse(["/some/path", "-o", "/tmp/out"])
        #expect(command.outputPath == "/tmp/out")
    }

    @Test func parsesShortFlags() throws {
        let command = try GetIconCommand.parse([
            "/some/path",
            "-s", "1024",
            "-r"
        ])
        #expect(command.size == 1024)
        #expect(command.recursive == true)
    }

    // MARK: - Validation

    // `parse` wraps a validate()-thrown ValidationError in ArgumentParser's
    // internal CommandError, so asserting on the error TYPE can never match.
    // Assert on the user-facing message instead.
    private func parseFailureMessage(_ args: [String]) throws -> String {
        let error = try #require(#expect(throws: (any Error).self) {
            _ = try GetIconCommand.parse(args)
        })
        return GetIconCommand.message(for: error)
    }

    @Test func rejectsZeroSize() throws {
        #expect(try parseFailureMessage(["/some/path", "--size", "0"])
            .contains("Size must be greater than 0"))
    }

    @Test func rejectsNegativeSize() throws {
        // "--size=-10" (not "--size -10"): a bare "-10" reads as a flag and
        // fails with missingValueForOption before validation ever runs.
        #expect(try parseFailureMessage(["/some/path", "--size=-10"])
            .contains("Size must be greater than 0"))
    }

    @Test func rejectsInvalidScale() {
        #expect(throws: (any Error).self) {
            _ = try GetIconCommand.parse(["/some/path", "--scale", "3x"])
        }
    }

    @Test func rejectsDepthWithoutRecursive() throws {
        #expect(try parseFailureMessage(["/some/path", "--depth", "2"])
            .contains("--depth requires --recursive"))
    }

    @Test func rejectsNegativeDepth() throws {
        #expect(try parseFailureMessage(["/some/path", "--recursive", "--depth=-1"])
            .contains("--depth must be zero or greater"))
    }

    @Test func acceptsDepthZeroWithRecursive() throws {
        let command = try GetIconCommand.parse(["/some/path", "--recursive", "--depth", "0"])
        #expect(command.depth == 0)
    }

    // MARK: - Output filename generation

    @Test func suggestsFilenameAt1x() {
        let filename = OutputResolver.suggestedIconFilename(
            forItemAt: "/Applications/Notes.app",
            size: 512,
            scaleFactor: 1
        )
        #expect(filename == "Notes-512.png")
    }

    @Test func suggestsFilenameAt2x() {
        let filename = OutputResolver.suggestedIconFilename(
            forItemAt: "/Applications/Notes.app",
            size: 512,
            scaleFactor: 2
        )
        #expect(filename == "Notes-512@2x.png")
    }

    @Test func suggestsFilenameStripsExtension() {
        let filename = OutputResolver.suggestedIconFilename(
            forItemAt: "/path/to/Some File.txt",
            size: 128,
            scaleFactor: 1
        )
        #expect(filename == "Some File-128.png")
    }

    @Test func suggestsFilenameFallsBackForEmptyBase() {
        let filename = OutputResolver.suggestedIconFilename(
            forItemAt: "/",
            size: 256,
            scaleFactor: 1
        )
        #expect(filename == "Application-256.png")
    }

    // MARK: - ExportColorSpace parsing

    @Test func colorSpaceParsesSRGB() {
        #expect(ExportColorSpace(argument: "sRGB") == .sRGB)
    }

    @Test func colorSpaceParsesDisplayP3() {
        #expect(ExportColorSpace(argument: "displayP3") == .displayP3)
    }

    @Test func colorSpaceRejectsInvalidValue() {
        #expect(ExportColorSpace(argument: "bogus") == nil)
    }

    @Test func colorSpaceBuildsCGColorSpace() {
        #expect(ExportColorSpace.sRGB.cgColorSpace.name == CGColorSpace.sRGB)
        #expect(ExportColorSpace.displayP3.cgColorSpace.name == CGColorSpace.displayP3)
    }

    // MARK: - End-to-end smoke test

    // .enabled(if:) instead of a silent early return: a missing Calculator.app
    // shows as a skip, not a green pass that tested nothing.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: "/System/Applications/Calculator.app")))
    func extractsCalculatorIcon() throws {
        let fm = FileManager.default
        let calculatorPath = "/System/Applications/Calculator.app"

        let outputDir = URL.temporaryDirectory.appending(path: "geticon-test-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: outputDir) }

        let destination = outputDir.appending(path: "Calculator-512.png")
        try IconExtractor.saveIcon(
            forBundleAt: calculatorPath,
            size: 512,
            scaleFactor: 1,
            colorSpace: .displayP3,
            destination: destination
        )

        #expect(fm.fileExists(atPath: destination.path))

        let data = try Data(contentsOf: destination)
        #expect(data.count > 0)

        // Valid PNG signature: 89 50 4E 47 0D 0A 1A 0A
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        #expect(Array(data.prefix(8)) == pngSignature)
    }
}
