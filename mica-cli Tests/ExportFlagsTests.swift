// ExportFlagsTests.swift
// Covers the generate command's export namespace: --size / --scale /
// --color-space parsing and their mapping into IconSettings.exportSize /
// exportRetinaSize / exportColorSpace via buildIconSettings. The extract
// command's equivalents are covered in GetIconCommandTests.

import Testing
import Foundation

@Suite
@MainActor
struct ExportFlagsTests {

    // MARK: - Defaults

    @Test("Export defaults: 512px, 1x, sRGB")
    func defaults() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(from: parseCommand(["star.fill"]))
        #expect(settings.exportSize == 512)
        #expect(settings.exportRetinaSize == false)
        #expect(settings.exportColorSpace == .sRGB)
    }

    // MARK: - --size

    @Test("--size maps to exportSize", arguments: [16, 128, 256, 1024])
    func sizeMapsToExportSize(_ size: Int) throws {
        let settings = try IconGeneratorCLI().buildTestSettings(
            from: parseCommand(["star.fill", "--size", "\(size)"]))
        #expect(settings.exportSize == CGFloat(size))
    }

    @Test("--size rejects out-of-range and non-integer values",
          arguments: ["15", "1025", "0", "512.5", "abc"])
    func sizeRejectsInvalid(_ size: String) {
        #expect(throws: (any Error).self) {
            _ = try parseCommand(["star.fill", "--size", size])
        }
    }

    // MARK: - --scale

    @Test("--scale 2x sets exportRetinaSize; 1x and default clear it")
    func scaleMapsToRetina() throws {
        let cli = IconGeneratorCLI()
        #expect(try cli.buildTestSettings(
            from: parseCommand(["star.fill", "--scale", "2x"])).exportRetinaSize == true)
        #expect(try cli.buildTestSettings(
            from: parseCommand(["star.fill", "--scale", "1x"])).exportRetinaSize == false)
    }

    @Test("finalExportSize doubles at 2x")
    func finalExportSizeDoubles() throws {
        let settings = try IconGeneratorCLI().buildTestSettings(
            from: parseCommand(["star.fill", "--size", "512", "--scale", "2x"]))
        #expect(settings.finalExportSize == 1024)
    }

    @Test("--scale rejects unsupported factors", arguments: ["3x", "0x", "2", "x2"])
    func scaleRejectsInvalid(_ scale: String) {
        #expect(throws: (any Error).self) {
            _ = try parseCommand(["star.fill", "--scale", scale])
        }
    }

    // MARK: - --color-space

    @Test("--color-space maps to exportColorSpace")
    func colorSpaceMapping() throws {
        let cli = IconGeneratorCLI()
        #expect(try cli.buildTestSettings(
            from: parseCommand(["star.fill", "--color-space", "displayP3"])).exportColorSpace == .displayP3)
        #expect(try cli.buildTestSettings(
            from: parseCommand(["star.fill", "--color-space", "sRGB"])).exportColorSpace == .sRGB)
    }

    @Test("--color-space rejects unknown values")
    func colorSpaceRejectsInvalid() {
        #expect(throws: (any Error).self) {
            _ = try parseCommand(["star.fill", "--color-space", "adobeRGB"])
        }
    }
}
