import Testing
import SwiftUI

/// Covers `AppexColor.plistValue(fromCLIString:)` — the CLI bridge that turns a
/// `--symbol-color` / `--enclosure-color` argument into the string written to the
/// appex Info.plist. Named tokens pass through; custom colours resolve to an
/// `r,g,b,a` string (the same format real system icon plists use).
///
/// The `r,g,b,a` string is **output only** as of Phase 3 (2026-08-03). This
/// resolver used to parse that form as *input* too, mirroring `ColorParser`'s bare
/// triple so a string meant the same in both generation modes; when the grammar
/// dropped the bare triple the mirror went with it, or System mode would have kept
/// accepting what Mica mode rejects. `srgb:` is how components are typed now, and
/// `ColorGrammarTests` pins that both modes agree.
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

    // MARK: - Components

    @Test("srgb: components become the plist's r,g,b,a string")
    func srgb_becomesPlistString() throws {
        #expect(try AppexColor.plistValue(fromCLIString: "srgb:1,0.0902,0.2118,1") == "1,0.0902,0.2118,1")
    }

    @Test("a 3-component srgb: gains an opaque alpha")
    func srgb_appendsAlpha() throws {
        #expect(try AppexColor.plistValue(fromCLIString: "srgb:0,0.5,1") == "0,0.5,1,1")
    }

    /// `rgb()` is how 0–255 components are written now — the bare triple's
    /// "0–1 unless one exceeds 1" guess is gone from both this resolver and
    /// `ColorParser`.
    @Test("rgb() components are normalised to 0–1")
    func rgbFunction_normalised() throws {
        // rgb(255,23,54) ≈ Apple's 1,0.0902,0.2118
        #expect(try AppexColor.plistValue(fromCLIString: "rgb(255,23,54)") == "1,0.0902,0.2118,1")
    }

    /// The appex plist cannot carry a colour outside sRGB, so a wide-gamut input
    /// is clamped here — at the plist, which is the only surface that cannot
    /// represent anything else. Phase 4 is what makes that visible rather than
    /// silent.
    @Test("a wide-gamut colour clamps at the plist boundary")
    func wideGamut_clampsAtThePlist() throws {
        #expect(try AppexColor.plistValue(fromCLIString: "display-p3:1,0,0") == "1,0,0,1")
    }

    @Test("the dropped bare component form is refused", arguments: [
        "1,0.0902,0.2118,1", "0,0.5,1", "255,23,54",
    ])
    func bareComponents_refused(_ input: String) {
        #expect(throws: (any Error).self) {
            _ = try AppexColor.plistValue(fromCLIString: input)
        }
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
