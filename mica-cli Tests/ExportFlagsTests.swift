// ExportFlagsTests.swift
// Covers the generate command's export namespace: --size / --scale /
// --color-space parsing and their mapping into IconSettings.exportSize /
// export.isRetina / export.colorSpace via buildIconSettings. The extract
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

    @Test("Omitted export flags parse as nil, so a config document can supply them")
    func omittedExportFlagsAreNil() throws {
        let command = try parseCommand(["--icon-symbol", "star.fill"])
        #expect(command.export.size == nil)
        #expect(command.export.scale == nil)
        #expect(command.export.colorSpace == nil)
    }

    @Test("Export flags passed their default value still parse as non-nil")
    func explicitDefaultValuesAreNotNil() throws {
        let command = try parseCommand([
            "--icon-symbol", "star.fill", "--size", "512", "--scale", "1x", "--color-space", "sRGB",
        ])
        #expect(command.export.size == 512)
        #expect(command.export.scale == .oneX)
        #expect(command.export.colorSpace == .sRGB)
    }

    // MARK: - --size

    @Test("--size maps to export.size", arguments: [16, 128, 256, 1024])
    func sizeMapsToExportSize(_ size: Int) throws {
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--size", "\(size)"]))
        #expect(settings.export.size == CGFloat(size))
    }

    @Test("--size rejects out-of-range and non-integer values",
          arguments: ["15", "1025", "0", "512.5", "abc"])
    func sizeRejectsInvalid(_ size: String) {
        #expect(throws: (any Error).self) {
            _ = try parseCommand(["--icon-symbol", "star.fill", "--size", size])
        }
    }

    // MARK: - --scale

    @Test("--scale 2x sets export.isRetina; 1x and default clear it")
    func scaleMapsToRetina() throws {
        let runner = IconGenerationRunner()
        #expect(try runner.buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--scale", "2x"])).export.isRetina == true)
        #expect(try runner.buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--scale", "1x"])).export.isRetina == false)
    }

    @Test("export.pixelSize doubles at 2x")
    func finalExportSizeDoubles() throws {
        let settings = try IconGenerationRunner().buildTestSettings(
            from: parseCommand(["--icon-symbol", "star.fill", "--size", "512", "--scale", "2x"]))
        #expect(settings.export.pixelSize == 1024)
    }

    @Test("--scale rejects unsupported factors", arguments: ["3x", "0x", "2", "x2"])
    func scaleRejectsInvalid(_ scale: String) {
        #expect(throws: (any Error).self) {
            _ = try parseCommand(["--icon-symbol", "star.fill", "--scale", scale])
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
