import Foundation
import Testing
import ArgumentParser
@testable import sfIconGen_CLI

@Suite struct GetIconCommandTests {

    // MARK: - Argument parsing

    @Test func parsesMinimalArguments() throws {
        let command = try GetIconCommand.parse(["/Applications/Notes.app"])
        #expect(command.inputPath == "/Applications/Notes.app")
        #expect(command.outputPath == nil)
        #expect(command.size == 512)
        #expect(command.scaleFactor == 1)
        #expect(command.recursive == false)
        #expect(command.depth == nil)
        #expect(command.colorSpace == .displayP3)
    }

    @Test func parsesAllOptions() throws {
        let command = try GetIconCommand.parse([
            "/Applications",
            "/tmp/icons",
            "--size", "256",
            "--scalefactor", "2",
            "--recursive",
            "--depth", "0",
            "--colorspace", "sRGB"
        ])
        #expect(command.inputPath == "/Applications")
        #expect(command.outputPath == "/tmp/icons")
        #expect(command.size == 256)
        #expect(command.scaleFactor == 2)
        #expect(command.recursive == true)
        #expect(command.depth == 0)
        #expect(command.colorSpace == .sRGB)
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

    @Test func rejectsZeroSize() {
        #expect(throws: ValidationError.self) {
            _ = try GetIconCommand.parse(["/some/path", "--size", "0"])
        }
    }

    @Test func rejectsNegativeSize() {
        #expect(throws: ValidationError.self) {
            _ = try GetIconCommand.parse(["/some/path", "--size", "-10"])
        }
    }

    @Test func rejectsInvalidScaleFactor() {
        #expect(throws: ValidationError.self) {
            _ = try GetIconCommand.parse(["/some/path", "--scalefactor", "3"])
        }
    }

    @Test func rejectsDepthWithoutRecursive() {
        #expect(throws: ValidationError.self) {
            _ = try GetIconCommand.parse(["/some/path", "--depth", "2"])
        }
    }

    @Test func rejectsNegativeDepth() {
        #expect(throws: ValidationError.self) {
            _ = try GetIconCommand.parse(["/some/path", "--recursive", "--depth", "-1"])
        }
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

    // MARK: - IconColorSpace parsing

    @Test func colorSpaceParsesSRGB() {
        #expect(IconColorSpace(argument: "sRGB") == .sRGB)
    }

    @Test func colorSpaceParsesDisplayP3() {
        #expect(IconColorSpace(argument: "displayP3") == .displayP3)
    }

    @Test func colorSpaceRejectsInvalidValue() {
        #expect(IconColorSpace(argument: "bogus") == nil)
    }

    @Test func colorSpaceBuildsCGColorSpace() throws {
        _ = try IconColorSpace.sRGB.makeColorSpace()
        _ = try IconColorSpace.displayP3.makeColorSpace()
    }

    // MARK: - End-to-end smoke test

    @Test func extractsCalculatorIcon() throws {
        let fm = FileManager.default
        let calculatorPath = "/System/Applications/Calculator.app"
        guard fm.fileExists(atPath: calculatorPath) else {
            // Calculator not present on this system (unlikely, but possible on trimmed installs).
            return
        }

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
