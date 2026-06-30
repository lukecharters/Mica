// OutputModeTests.swift
// Covers the Phase 5 output redesign: the shared --json / --quiet / --verbose
// options, verbosity resolution, the q/v conflict, and the stable JSON result
// schema (encode + round-trip).

import Testing
import Foundation
@testable import mica_cli

@Suite
@MainActor
struct OutputModeTests {

    // MARK: - Option parsing + verbosity

    @Test("Output flags parse on the generate command")
    func flagsParse() throws {
        #expect(try parseCommand(["star.fill"]).output.json == false)
        #expect(try parseCommand(["star.fill", "--json"]).output.json == true)
        #expect(try parseCommand(["star.fill", "-q"]).output.quiet == true)
        #expect(try parseCommand(["star.fill", "-v"]).output.verbose == true)
    }

    @Test("Verbosity resolves from --quiet / --verbose with normal as the default")
    func verbosityResolution() throws {
        #expect(try parseCommand(["star.fill"]).output.verbosity == .normal)
        #expect(try parseCommand(["star.fill", "--quiet"]).output.verbosity == .quiet)
        #expect(try parseCommand(["star.fill", "--verbose"]).output.verbosity == .verbose)
    }

    @Test("--quiet and --verbose together are rejected")
    func quietVerboseConflict() {
        #expect(throws: (any Error).self) {
            try parseCommand(["star.fill", "-q", "-v"])
        }
    }

    // MARK: - JSON schema

    @Test("A success result encodes and round-trips with the stable schema")
    func successResultRoundTrips() throws {
        let file = OutputFileJSON(path: "/tmp/star.fill.png", width: 512, height: 512, bytes: 84457, source: "star.fill")
        let result = CommandResultJSON(command: "generate", outputs: [file])

        #expect(result.status == "success")
        #expect(result.count == 1)

        let json = encodeJSON(result)
        let decoded = try JSONDecoder().decode(CommandResultJSON.self, from: Data(json.utf8))
        #expect(decoded == result)
        #expect(decoded.outputs.first == file)
    }

    @Test("Multiple outputs report the right count")
    func multipleOutputsCount() {
        let a = OutputFileJSON(path: "/tmp/a.png", width: 256, height: 256, bytes: 10, source: "/Applications/A.app")
        let b = OutputFileJSON(path: "/tmp/b.png", width: 256, height: 256, bytes: 20, source: "/Applications/B.app")
        let result = CommandResultJSON(command: "extract", outputs: [a, b])
        #expect(result.count == 2)
        #expect(result.command == "extract")
    }

    @Test("An error result encodes and round-trips with the stable schema")
    func errorResultRoundTrips() throws {
        let error = CommandErrorJSON(command: "generate", kind: "rendering", message: "boom")
        #expect(error.status == "error")

        let json = encodeJSON(error)
        let decoded = try JSONDecoder().decode(CommandErrorJSON.self, from: Data(json.utf8))
        #expect(decoded == error)
        #expect(decoded.error.kind == "rendering")
        #expect(decoded.error.message == "boom")
    }

    @Test("Encoded JSON uses sorted keys and unescaped slashes")
    func encodingFormatting() throws {
        let file = OutputFileJSON(path: "/tmp/x.png", width: 1, height: 1, bytes: 1, source: nil)
        let result = CommandResultJSON(command: "generate", outputs: [file])
        let json = encodeJSON(result)
        // sortedKeys: top-level "command" precedes "status".
        let commandIdx = try #require(json.range(of: "\"command\""))
        let statusIdx = try #require(json.range(of: "\"status\""))
        #expect(commandIdx.lowerBound < statusIdx.lowerBound)
        // withoutEscapingSlashes: paths are not escaped as "\/".
        #expect(!json.contains("\\/"))
        #expect(json.contains("/tmp/x.png"))
    }

    // MARK: - Byte formatting

    @Test("Human byte counts format by magnitude")
    func byteFormatting() {
        #expect(humanByteCount(512) == "512 bytes")
        #expect(humanByteCount(2048) == "2.0 KB")
        #expect(humanByteCount(5 * 1024 * 1024) == "5.0 MB")
    }
}
