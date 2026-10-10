// ExportFlagsTests.swift
// Covers the generate command's export namespace: --size (with its @2x
// suffix) and --color-space parsing and their mapping into
// IconSettings.export.exportSize / export.colorSpace via buildIconSettings. The extract
// command's equivalents are covered in ExtractCommandTests.

import Testing
import Foundation

@Suite
@MainActor
struct ExportFlagsTests {

    // MARK: - Defaults

    @Test("Export defaults: 512px, 1x, sRGB")
    func defaults() throws {
        let settings = try IconGenerationRunner().buildTestSettings(from: parseCommand(["--icon-symbol", "star.fill"]))
        #expect(settings.export.size == 512)
        #expect(settings.export.isRetina == false)
        #expect(settings.export.colorSpace == .sRGB)
    }

    // MARK: - Absent vs. explicitly-default flags
    //
    // The export flags are Optional with no default value so that `--config`
    // can distinguish "not passed" from "passed the default". These two tests
    // pin that distinction: without them, restoring a declaration default
    // would keep every other test in this file green while silently making a
    // document's stored export values impossible to preserve.

    @Test("--force is off unless passed")
    func forceFlag() throws {
        #expect(try parseCommand(["--icon-symbol", "star.fill"]).output.force == false)
        #expect(try parseCommand(["--icon-symbol", "star.fill", "--force"]).output.force == true)
    }

    @Test("A run refused by validation leaves no output directory behind")
    func refusedRunCreatesNoOutputDirectory() throws {
        let root = URL.temporaryDirectory.appending(path: "mica-outdir-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try parseCommand([
            "--icon-symbol", "star.fill", "-o", root.appending(path: "a/b/x.png").path, "--icon-bg-color", "nope",
        ])
        #expect(throws: (any Error).self) { try command.performValidationForTesting() }
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test("An output path inside a file is refused")
    func outputInsideAFileIsRefused() throws {
        let file = try makeTempImageFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let command = try parseCommand(["--icon-symbol", "star.fill", "-o", file.appending(path: "sub/x.png").path])
        #expect(throws: (any Error).self) { try command.performValidationForTesting() }
    }

    @Test("Omitted export flags parse as nil, so a config document can supply them")
    func omittedExportFlagsAreNil() throws {
        let command = try parseCommand(["--icon-symbol", "star.fill"])
        #expect(command.export.size == nil)
        #expect(command.export.colorSpace == nil)
    }

    @Test("Export flags passed their default value still parse as non-nil")
    func explicitDefaultValuesAreNotNil() throws {
        let command = try parseCommand([
            "--icon-symbol", "star.fill", "--size", "512", "--color-space", "sRGB",
        ])
        #expect(command.export.size == ExportSize(points: 512))
        #expect(command.export.colorSpace == .sRGB)
    }

    // MARK: - --size

    @Test("--size maps to export.size", arguments: [16, 128, 256, 1024])
    func sizeMapsToExportSize(_ size: Int) throws {
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--size", "\(size)"]))
        #expect(settings.export.size == CGFloat(size))
    }

    @Test("--size rejects out-of-range, non-integer and badly suffixed values",
          arguments: ["15", "1025", "0", "512.5", "abc", "1025@2x", "512@3x", "512@", "@2x", "512x2"])
    func sizeRejectsInvalid(_ size: String) {
        #expect(throws: (any Error).self) {
            _ = try parseCommand(["--icon-symbol", "star.fill", "--size", size])
        }
    }

    // MARK: - @2x

    @Test("--size with @2x sets export.isRetina; a bare or @1x size clears it")
    func suffixMapsToRetina() throws {
        let runner = IconGenerationRunner()
        #expect(try runner.buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--size", "256@2x"])).export.exportSize
            == ExportSize(points: 256, scale: .twoX))
        #expect(try runner.buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--size", "256@1x"])).export.isRetina == false)
        #expect(try runner.buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--size", "256"])).export.isRetina == false)
    }

    @Test("export.pixelSize doubles at @2x")
    func finalExportSizeDoubles() throws {
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--size", "512@2x"]))
        #expect(settings.export.pixelSize == 1024)
    }

    @Test("--scale is gone")
    func scaleFlagIsGone() {
        #expect(throws: (any Error).self) {
            _ = try parseCommand(["--icon-symbol", "star.fill", "--scale", "2x"])
        }
    }

    // MARK: - --color-space

    @Test("--color-space maps to export.colorSpace")
    func colorSpaceMapping() throws {
        let runner = IconGenerationRunner()
        #expect(try runner.buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--color-space", "displayP3"])).export.colorSpace == .displayP3)
        #expect(try runner.buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--color-space", "sRGB"])).export.colorSpace == .sRGB)
    }

    @Test("--color-space rejects unknown values")
    func colorSpaceRejectsInvalid() {
        #expect(throws: (any Error).self) {
            _ = try parseCommand(["--icon-symbol", "star.fill", "--color-space", "adobeRGB"])
        }
    }
}
