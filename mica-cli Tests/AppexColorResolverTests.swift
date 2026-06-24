import Testing
import SwiftUI
@testable import mica_cli

/// Covers `AppexColor.plistValue(fromCLIString:)` — the CLI bridge that turns a
/// `--symbol-color` / `--enclosure-color` argument into the string written to the
/// appex Info.plist. Named tokens pass through; custom colours resolve to an
/// `r,g,b,a` string (the same format real system icon plists use).
@Suite struct AppexColorResolverTests {

    // MARK: - Named tokens

    @Test("named appex tokens pass through unchanged", arguments: [
        "blue", "white", "black", "gray", "green", "red", "yellow",
        "orange", "pink", "purple", "indigo", "teal", "cyan", "brown"
    ])
    func namedTokens_passThrough(_ token: String) throws {
        #expect(try AppexColor.plistValue(fromCLIString: token) == token)
    }

    @Test("named tokens are case-insensitive")
    func namedTokens_caseInsensitive() throws {
        #expect(try AppexColor.plistValue(fromCLIString: "Blue") == "blue")
        #expect(try AppexColor.plistValue(fromCLIString: "  WHITE  ") == "white")
    }

    // MARK: - r,g,b,a components

    @Test("0–1 r,g,b,a components pass through as a plist string")
    func rgba_floats_passThrough() throws {
        #expect(try AppexColor.plistValue(fromCLIString: "1,0.0902,0.2118,1") == "1,0.0902,0.2118,1")
    }

    @Test("a 3-component r,g,b gains an opaque alpha")
    func rgb_appendsAlpha() throws {
        #expect(try AppexColor.plistValue(fromCLIString: "0,0.5,1") == "0,0.5,1,1")
    }

    @Test("0–255 components are normalised to 0–1")
    func rgb_255_normalised() throws {
        // 255,23,54 ≈ Apple's 1,0.0902,0.2118
        #expect(try AppexColor.plistValue(fromCLIString: "255,23,54") == "1,0.0902,0.2118,1")
    }

    // MARK: - Hex

    @Test("hex colours resolve to an r,g,b,a string")
    func hex_resolvesToRGBA() throws {
        let result = try AppexColor.plistValue(fromCLIString: "#FFFFFF")
        #expect(result == "1,1,1,1")
    }

    // MARK: - Failure

    @Test("an unparseable value throws")
    func invalid_throws() {
        #expect(throws: (any Error).self) {
            _ = try AppexColor.plistValue(fromCLIString: "not-a-color")
        }
    }

    @Test("an empty value throws")
    func empty_throws() {
        #expect(throws: (any Error).self) {
            _ = try AppexColor.plistValue(fromCLIString: "   ")
        }
    }
}
