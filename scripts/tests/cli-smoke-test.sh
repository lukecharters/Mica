#!/usr/bin/env bash
#
# CLI smoke-test for mica-cli.
# Exercises every non-default argument value (happy path) plus a fixed set of
# invalid-input cases (negative path), across the redesigned flag surface:
#   - generate (default subcommand): --icon-fg…/--icon-bg…, --badge-fg…/--badge-bg…,
#     --icon-generation-mode/--badge-generation-mode, --scale, --color-space,
#     and the --json/-q/-v output modes.
#   - generate --config <file.json>: a configuration alone, a flag overriding one,
#     the warning and fatal paths, and relative image resolution.
#   - extract subcommand: <path> -o <dir> [--size --scale --color-space --recursive --depth].
# Produces per-case PNGs in a timestamped output directory and a README.txt summary.
# See the original design notes for the original design.

set -u
set -o pipefail

# ---- configuration -----------------------------------------------------------

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly FIXTURES_DIR="${PROJECT_ROOT}/scripts/tests/fixtures"
readonly OUTPUT_ROOT="${PROJECT_ROOT}/scripts/tests/smoke-output"
readonly FIXTURE_SYMBOL="${FIXTURES_DIR}/test-symbol-2.png"
readonly FIXTURE_BACKGROUND="${FIXTURES_DIR}/test-background-2.png"
readonly FIXTURE_CONFIG="${FIXTURES_DIR}/smoke-config.json"
# The app scheme, not mica-cli — see build_cli() for why the smoke test exercises
# the embedded copy of the binary rather than the loose build product.
readonly SCHEME="Mica"
readonly XCODE_PROJECT="${PROJECT_ROOT}/Mica.xcodeproj"

# Populated by setup_run / build_cli.
CLI_BINARY=""
OUTPUT_DIR=""
README=""

# Counters (initialized in main).
HAPPY_INDEX=0
HAPPY_PASS=0
HAPPY_FAIL=0
NEG_PASS=0
NEG_FAIL=0
EXTRACT_INDEX=0
EXTRACT_PASS=0
EXTRACT_FAIL=0
CONFIG_INDEX=0
CONFIG_PASS=0
CONFIG_FAIL=0
PARITY_INDEX=0
PARITY_PASS=0
PARITY_FAIL=0

# Filled by expand_fixtures() — fixture-placeholder-expanded argument list.
EXPANDED_ARGS=()

# ---- case data ---------------------------------------------------------------
# Entry format: slug|symbol[|arg1|arg2|...]
# The symbol field is a bare SF Symbol name; set_symbol_args() turns it into
# `--icon-symbol <name>`, and an empty field into no foreground at all.
# Use $SYMBOL_FIXTURE / $BACKGROUND_FIXTURE placeholders for fixture image paths.
HAPPY_CASES=(
    # ---- baseline ----
    "baseline|star.fill"

    # ---- Export ----
    "size-1024|star.fill|--size|1024"
    "scale-2x|star.fill|--scale|2x"
    "color-space-display-p3|star.fill|--color-space|displayP3"
    "color-space-srgb|star.fill|--color-space|sRGB"

    # ---- Generation modes ----
    "icon-generation-mode-system|star.fill|--icon-generation-mode|system|--icon-bg-color|blue|--icon-symbol-color|white"
    "badge-generation-mode-system|star.fill|--badge-fg|symbol:gear|--badge-generation-mode|system|--badge-bg-color|red|--badge-symbol-color|white"
    # The OS honours ISSymbolColor's alpha and ignores ISEnclosureColor's, so a
    # System-mode symbol takes an opacity suffix and a background does not.
    "icon-generation-mode-system-symbol-opacity|star.fill|--icon-generation-mode|system|--icon-symbol-color|white:0.5"
    "icon-generation-mode-system-srgb-components|star.fill|--icon-generation-mode|system|--icon-bg-color|srgb:0.2,0.6,0.9"
    # mint reached System mode only once the token table was the single source.
    "icon-generation-mode-system-mint|star.fill|--icon-generation-mode|system|--icon-bg-color|mint"

    # ---- Icon background ----
    "icon-bg-color-red|star.fill|--icon-bg-color|red"
    # Every colour option takes a ':opacity' suffix, on any comma-free form.
    "icon-bg-color-opacity|star.fill|--icon-bg-color|blue:0.5"
    "icon-bg-color-hex-opacity|star.fill|--icon-bg-color|#0088FF:0.5"
    "icon-symbol-color-opacity|star.fill|--icon-symbol-color|white:0.5"
    # The configuration's stored colour form, accepted anywhere a colour is — so a
    # value can be copied out of a config file straight onto the command line.
    "icon-bg-color-extended-srgb|star.fill|--icon-bg-color|extended-srgb:0.20000,0.60000,0.90196,1.00000"
    "icon-bg-color-extended-gray|star.fill|--icon-bg-color|extended-gray:0.50000,1.00000"
    # Out-of-gamut components are legal: this is Display P3 red in extended sRGB.
    "icon-bg-color-extended-wide-gamut|star.fill|--icon-bg-color|extended-srgb:1.09300,-0.22670,-0.15010,1.00000"
    "icon-symbol-color-extended-srgb|star.fill|--icon-symbol-color|extended-srgb:1.00000,1.00000,1.00000,1.00000"
    # The bounded space prefixes (Phase 3), which replaced the bare r,g,b triple.
    # The alpha is optional in both.
    "icon-bg-color-srgb|star.fill|--icon-bg-color|srgb:0.2,0.6,0.90196"
    "icon-bg-color-srgb-alpha|star.fill|--icon-bg-color|srgb:0.2,0.6,0.90196,0.5"
    "icon-symbol-color-srgb|star.fill|--icon-symbol-color|srgb:1,1,1"
    # display-p3: is the readable spelling of the wide-gamut case above, and only
    # reaches a wide-gamut PNG through --color-space displayP3.
    "icon-bg-color-display-p3|star.fill|--icon-bg-color|display-p3:1,0.2,0"
    "icon-bg-color-display-p3-wide-gamut|star.fill|--color-space|displayP3|--icon-bg-color|display-p3:1,0,0"
    "icon-bg-gradient-off|star.fill|--icon-bg-gradient|off"
    "icon-bg-custom-gradient|star.fill|--icon-bg|custom-gradient|--icon-bg-gradient-colors|#FF6B35,#F7931E"
    "icon-bg-gradient-colors-opacity|star.fill|--icon-bg|custom-gradient|--icon-bg-gradient-colors|red:0.8,orange:0.4"
    "icon-bg-image|star.fill|--icon-bg|\$BACKGROUND_FIXTURE"
    "icon-bg-image-scale|star.fill|--icon-bg|\$BACKGROUND_FIXTURE|--icon-bg-scale|1.3"
    "icon-bg-image-padding-on|star.fill|--icon-bg|\$BACKGROUND_FIXTURE|--icon-bg-padding|on"
    "icon-bg-image-padding-off|star.fill|--icon-bg|\$BACKGROUND_FIXTURE|--icon-bg-padding|off"
    "icon-bg-corner-radius-macos15|star.fill|--icon-bg-corner-radius|macos15"
    "icon-bg-shadow-off|star.fill|--icon-bg-shadow|off"
    "icon-bg-shadow-macos15|star.fill|--icon-bg-shadow|macos15"
    "icon-bg-visibility-off|star.fill|--icon-bg-visibility|off"

    # ---- Icon foreground ----
    # Empty symbol field: --icon-fg is the foreground, and pairing it with
    # --icon-symbol would be refused as a conflict rather than tested.
    "icon-fg-symbol-explicit||--icon-fg|symbol:heart.fill"
    "icon-fg-image||--icon-fg|\$SYMBOL_FIXTURE"
    "icon-fg-image-scale||--icon-fg|\$SYMBOL_FIXTURE|--icon-fg-scale|0.9"
    "icon-fg-scale|star.fill|--icon-fg-scale|1.3"
    "icon-symbol-rendering-hierarchical|shield.fill|--icon-symbol-rendering|hierarchical"
    "icon-symbol-rendering-multicolor|star.fill|--icon-symbol-rendering|multicolor"
    "icon-symbol-rendering-palette|person.3.sequence.fill|--icon-symbol-rendering|palette|--icon-symbol-palette|blue,white:0.5,white:0.26"
    # Opacity on the FIRST palette slot: rejected until 2026-07-29.
    "icon-symbol-palette-primary-opacity|person.3.sequence.fill|--icon-symbol-rendering|palette|--icon-symbol-palette|blue:0.8,white:0.5,white:0.26"
    "icon-symbol-color-yellow|star.fill|--icon-symbol-color|yellow"
    "icon-symbol-weight-bold|star.fill|--icon-symbol-weight|bold"
    "icon-symbol-gradient-on|star.fill|--icon-symbol-gradient|on"
    "icon-fg-shadow-off|star.fill|--icon-fg-shadow|off"
    "icon-fg-visibility-off|star.fill|--icon-fg-visibility|off"
    # Group visibility: one flag writing both layers, and a layer flag beating it.
    "icon-visibility-off|star.fill|--icon-visibility|off"
    "icon-visibility-off-fg-on|star.fill|--icon-visibility|off|--icon-fg-visibility|on"
    "badge-visibility-on|star.fill|--badge-visibility|on"
    "badge-visibility-off-with-fg|star.fill|--badge-fg|symbol:plus.circle|--badge-visibility|off"
    # Activation without --badge-fg: the artwork-only case, and a lone --badge-bg
    # keyword. Both were impossible before phase 5 without naming a symbol.
    "badge-bg-activates-alone|star.fill|--badge-bg|custom-gradient|--badge-bg-gradient-colors|red,orange"
    "badge-bg-image-activates-alone|star.fill|--badge-bg|\$BACKGROUND_FIXTURE"
    "badge-bg-image-alone-plus-symbol-color|star.fill|--badge-bg|\$BACKGROUND_FIXTURE|--badge-symbol-color|white"

    # ---- Badge foreground (supplying --badge-fg activates the badge) ----
    "badge-enable|star.fill|--badge-fg|symbol:plus.circle"
    "badge-fg-image|star.fill|--badge-fg|\$SYMBOL_FIXTURE"
    "badge-fg-scale|star.fill|--badge-fg|symbol:plus.circle|--badge-fg-scale|1.2"
    "badge-symbol-rendering-hierarchical|star.fill|--badge-fg|symbol:plus.circle|--badge-symbol-rendering|hierarchical|--badge-symbol-color|cyan"
    "badge-symbol-rendering-multicolor|star.fill|--badge-fg|symbol:star.fill|--badge-symbol-rendering|multicolor"
    "badge-symbol-rendering-palette|star.fill|--badge-fg|symbol:person.3.sequence.fill|--badge-symbol-rendering|palette|--badge-symbol-palette|red,blue:0.5,green:0.2"
    "badge-symbol-color-yellow|star.fill|--badge-fg|symbol:plus.circle|--badge-symbol-color|yellow"
    "badge-symbol-weight-bold|star.fill|--badge-fg|symbol:plus.circle|--badge-symbol-weight|bold"
    "badge-symbol-gradient-on|star.fill|--badge-fg|symbol:plus.circle|--badge-symbol-gradient|on"
    "badge-fg-shadow-off|star.fill|--badge-fg|symbol:plus.circle|--badge-fg-shadow|off"
    "badge-fg-visibility-off|star.fill|--badge-fg|symbol:plus.circle|--badge-fg-visibility|off"

    # ---- Badge background ----
    "badge-bg-color-red|star.fill|--badge-fg|symbol:plus.circle|--badge-bg-color|red"
    "badge-bg-gradient-off|star.fill|--badge-fg|symbol:plus.circle|--badge-bg-gradient|off"
    "badge-bg-custom-gradient|star.fill|--badge-fg|symbol:gearshape.fill|--badge-bg|custom-gradient|--badge-bg-gradient-colors|red,orange"
    "badge-bg-image|star.fill|--badge-fg|symbol:plus.circle|--badge-bg|\$BACKGROUND_FIXTURE"
    "badge-bg-image-scale|star.fill|--badge-fg|symbol:plus.circle|--badge-bg|\$BACKGROUND_FIXTURE|--badge-bg-scale|1.2"
    "badge-bg-image-padding-on|star.fill|--badge-fg|symbol:plus.circle|--badge-bg|\$BACKGROUND_FIXTURE|--badge-bg-padding|on"
    "badge-bg-image-padding-off|star.fill|--badge-fg|symbol:plus.circle|--badge-bg|\$BACKGROUND_FIXTURE|--badge-bg-padding|off"
    "badge-bg-shadow-off|star.fill|--badge-fg|symbol:plus.circle|--badge-bg-shadow|off"
    "badge-bg-visibility-off|star.fill|--badge-fg|symbol:plus.circle|--badge-bg-visibility|off"

    # ---- Badge placement ----
    "badge-position-top-left|star.fill|--badge-fg|symbol:plus.circle|--badge-position|top-left"
    "badge-position-top-right|star.fill|--badge-fg|symbol:plus.circle|--badge-position|top-right"
    "badge-position-bottom-left|star.fill|--badge-fg|symbol:plus.circle|--badge-position|bottom-left"
    "badge-position-bottom-right|star.fill|--badge-fg|symbol:plus.circle|--badge-position|bottom-right"
    "badge-scale|star.fill|--badge-fg|symbol:plus.circle|--badge-scale|1.3"
    "badge-offset-x|star.fill|--badge-fg|symbol:plus.circle|--badge-offset-x|0.2"
    "badge-offset-y|star.fill|--badge-fg|symbol:plus.circle|--badge-offset-y=-0.1"

    # ---- Foreground nudges: the layer inside its own frame, not the badge ----
    "icon-fg-offset-x|star.fill|--icon-fg-offset-x|0.2"
    "icon-fg-offset-y|star.fill|--icon-fg-offset-y=-0.15"
    "badge-fg-offset-x|star.fill|--badge-fg|symbol:plus.circle|--badge-fg-offset-x|0.2"
    "badge-fg-offset-y|star.fill|--badge-fg|symbol:plus.circle|--badge-fg-offset-y=-0.15"

    # ---- Output modes (path still written via -o; stdout suppressed by the harness) ----
    "output-json|star.fill|--json"
    "output-quiet|star.fill|--quiet"
    "output-verbose|star.fill|--verbose"
)

# Negative cases. Entry format: name|expectedSubstring|symbol[|arg1|...]
# The runner invokes `mica-cli --icon-symbol <symbol> <args…>`; passing "extract"
# as the "symbol" dispatches to the extract subcommand (generate is the default),
# and set_symbol_args() keeps that one word positional.
NEGATIVE_CASES=(
    # ---- generate ----
    "size-too-large|Size must be between|star.fill|--size|9999"
    "size-non-numeric|whole number|star.fill|--size|abc"
    "scale-invalid|is invalid for '--scale|star.fill|--scale|3x"
    "color-space-invalid|is invalid for '--color-space|star.fill|--color-space|BGR"
    "icon-symbol-rendering-invalid|Symbol rendering mode must be one of|star.fill|--icon-symbol-rendering|invalid"
    "icon-symbol-weight-invalid|Symbol weight must be one of|star.fill|--icon-symbol-weight|notaweight"
    "icon-fg-scale-out-of-range|must be between 0.3 and 2.0|star.fill|--icon-fg-scale|5.0"
    "icon-fg-symbol-empty|requires a symbol name||--icon-fg|symbol:"
    # An unknown preset is fatal, and the message lists what is available — presets
    # are the one part of the CLI's vocabulary that `--help` does not carry, so a
    # bare "unknown preset" would leave the user with nowhere to look.
    "icon-preset-unknown|no icon preset named|star.fill|--icon-preset|nosuchpreset"
    "badge-preset-unknown|no badge preset named|star.fill|--badge-preset|nosuchpreset"
    # **A badge preset must not excuse a missing icon foreground.** It produces a
    # base, and `context.base != nil` used to be how the CLI decided a foreground was
    # optional — so this invocation would have rendered the default blue `command`
    # icon and reported success. Only the shipped binary's own message says the right
    # question is being asked; the empty symbol field is what makes this a bare
    # `--badge-preset` run.
    "badge-preset-alone-still-needs-a-foreground|Provide an icon foreground||--badge-preset|Update"
    # The new refusals: the shorthand cannot carry the prefix it exists to omit,
    # and cannot be given alongside the flag it abbreviates.
    "icon-symbol-with-prefix|drop the 'symbol:' prefix||--icon-symbol|symbol:star.fill"
    # A missing value prints the *abstract* and nothing else — see --badge-offset-y's
    # note on the same mechanism. So the abstract has to carry the "no prefix" hint,
    # which is exactly the moment someone needs it. This row is what says it does.
    "icon-symbol-missing-value|no 'symbol:' prefix||--icon-symbol"
    "icon-symbol-conflicts-with-icon-fg|not both|star.fill|--icon-fg|symbol:heart.fill"
    "badge-symbol-conflicts-with-badge-fg|not both|star.fill|--badge-symbol|plus.circle|--badge-fg|symbol:gear"
    "icon-bg-color-invalid|Invalid color format for --icon-bg-color|star.fill|--icon-bg-color|not-a-color"
    # A recognised space name with the wrong component count is a mistake worth
    # reporting, not a colour name to keep guessing at.
    "icon-bg-color-extended-wrong-count|extended-srgb requires 4 components|star.fill|--icon-bg-color|extended-srgb:1,1"
    "icon-bg-color-extended-not-a-number|Components must be finite numbers|star.fill|--icon-bg-color|extended-srgb:oops"
    # srgb: and display-p3: name bounded spaces, so an out-of-range component is
    # reported rather than clamped — and the error names the form that can carry it.
    "icon-bg-color-srgb-out-of-range|components are 0-1|star.fill|--icon-bg-color|srgb:1.2,0,0"
    "icon-bg-color-display-p3-out-of-range|components are 0-1|star.fill|--icon-bg-color|display-p3:0,0,1.5"
    "icon-bg-color-srgb-wrong-count|takes 3 or 4 components|star.fill|--icon-bg-color|srgb:1,0"
    # The six forms Phase 3 dropped. The bare triple is the one worth pinning: it
    # guessed between 0-1 and 0-255, so 1,1,1 was white and 2,2,2 dark gray.
    "icon-bg-color-bare-components-dropped|Invalid color format for --icon-bg-color|star.fill|--icon-bg-color|0.2,0.6,0.9"
    "icon-bg-color-legacy-name-dropped|Invalid color format for --icon-bg-color|star.fill|--icon-bg-color|crimson"
    "icon-bg-color-no-dot-alias-dropped|Invalid color format for --icon-bg-color|star.fill|--icon-bg-color|systemblue"
    "icon-bg-color-rgba-dropped|Invalid color format for --icon-bg-color|star.fill|--icon-bg-color|rgba(255,0,0,0.5)"
    # The AppKit spellings, retired 2026-08-17. Removed rather than aliased, so
    # the shipped binary has to *refuse* them — the one thing a unit test on the
    # parser cannot say about the copy a user actually runs.
    "icon-bg-color-system-spelling-retired|Invalid color format for --icon-bg-color|star.fill|--icon-bg-color|system.blue"
    "icon-symbol-color-label-retired|Invalid color format for --icon-symbol-color|star.fill|--icon-symbol-color|label"
    "icon-bg-color-grayscale-dropped|Invalid color format for --icon-bg-color|star.fill|--icon-bg-color|0.5"
    "icon-bg-custom-gradient-missing-colors|--icon-bg custom-gradient requires|star.fill|--icon-bg|custom-gradient"
    # Retired 2026-08-16. The point of the case is *which* error: the keyword has no
    # case left in IconBackgroundValue, so an unscreened value parses as an image path
    # and would fail as "File not found" for a file nobody named.
    "icon-bg-prerendered-retired|no longer available|star.fill|--icon-bg|prerendered-liquid-glass"
    "badge-offset-out-of-range|must be between -1.0 and 1.0|star.fill|--badge-fg|symbol:plus.circle|--badge-offset-x|9.0"
    # A foreground nudge is bounded at half the badge's range, and the two ranges go
    # through one validator — so the *message* is what says the right bounds were
    # checked. A value of 0.6 is legal for the badge and not for its glyph.
    "icon-fg-offset-out-of-range|must be between -0.5 and 0.5|star.fill|--icon-fg-offset-x|0.6"
    "badge-fg-offset-out-of-range|must be between -0.5 and 0.5|star.fill|--badge-fg|symbol:plus.circle|--badge-fg-offset-y|0.6"
    "badge-bg-custom-gradient-missing-colors|--badge-bg custom-gradient requires|star.fill|--badge-fg|symbol:plus.circle|--badge-bg|custom-gradient"
    "badge-generation-system-image-fg|image foregrounds are only supported in mica mode|star.fill|--badge-fg|\$SYMBOL_FIXTURE|--badge-generation-mode|system"
    # Phase 4 / decision D2: System mode refuses what it cannot show rather than
    # rendering something else. The alpha one is not obvious — the OS discards an
    # enclosure alpha, so the icon used to come out opaque with nothing said.
    "system-bg-opacity-refused|opacity|star.fill|--icon-generation-mode|system|--icon-bg-color|blue:0.5"
    "system-badge-bg-opacity-refused|opacity|star.fill|--badge-fg|symbol:plus|--badge-generation-mode|system|--badge-bg-color|blue:0.5"
    "system-bg-wide-gamut-refused|outside sRGB|star.fill|--icon-generation-mode|system|--icon-bg-color|display-p3:1,0,0"
    "system-symbol-wide-gamut-refused|outside sRGB|star.fill|--icon-generation-mode|system|--icon-symbol-color|display-p3:0,1,0"
    "quiet-verbose-conflict|--quiet and --verbose cannot be used together|star.fill|--quiet|--verbose"

    # ---- extract subcommand ----
    "extract-bad-scale|is invalid for '--scale|extract|/System/Applications/Calculator.app|--scale|3x"
    "extract-depth-without-recursive|--depth requires --recursive|extract|/System/Applications|--depth|2"
    "extract-path-not-found|Bundle not found|extract|/nonexistent/path.app"
    "extract-dir-without-recursive|Pass --recursive|extract|/System/Applications"
)

# `generate --config` cases. These need their own runner because a configuration
# supplies the foreground, so unlike HAPPY_CASES there is no positional symbol —
# which is also what makes them the test of `mica-cli --config …` routing through
# the default subcommand with a flag as its first token.
#
# Entry format: slug|expectedExit|stderrSubstring|expectedWidth|arg1[|arg2|...]
#   expectedExit    the exit code the case must produce
#   stderrSubstring '-' to skip, otherwise stderr must contain it
#   expectedWidth   '-' to skip, otherwise the PNG's pixel width must match
# $CONFIG expands to the committed smoke-config.json; the other fixtures are
# named in full so the failure mode of each is obvious from the entry.
CONFIG_CASES=(
    # A configuration on its own, invoked with no subcommand name.
    "config-only|0|-|512|--config|\$CONFIG"
    # …and with it, since `generate --config` must mean the same thing.
    "config-explicit-subcommand|0|-|512|generate|--config|\$CONFIG"
    # A flag beats the file: 256@2x becomes 128@1x.
    "config-size-override|0|-|128|--config|\$CONFIG|--size|128|--scale|1x"
    # An unknown key is a warning on stderr and a successful run.
    "config-unknown-key|0|not a configuration key|-|--config|\$FIXTURES/smoke-config-unknown-key.json"
    # …and it is still heard under --quiet, which is the point of the channel.
    "config-warning-survives-quiet|0|not a configuration key|-|--config|\$FIXTURES/smoke-config-unknown-key.json|--quiet"
    # Malformed JSON is the one fatal case.
    "config-truncated-json|1|not valid JSON|-|--config|\$FIXTURES/smoke-config-truncated.json"
    # A missing file fails before anything is rendered.
    "config-missing-file|1|Cannot read configuration|-|--config|\$FIXTURES/no-such-config.json"
    # A relative image path resolves against the configuration's own directory.
    "config-relative-image|0|-|-|--config|\$FIXTURES/smoke-config-relative-image.json"
)

# Cross-surface parity (Phase 5 of the colour-resolution plan). One colour
# form per entry, rendered twice by the SHIPPED binary — once with the colour as a
# flag, once with the identical colour in a --config file — and the two PNGs
# compared byte for byte, in both colour spaces.
#
# The in-process suite (ColorSurfaceAgreementTests) already proves the flag and
# config parsers store the same value, and one renderer means equal settings render
# alike. What only this can catch is the rest of the invocation: bundled resources,
# the encoder, and the colour-space conversion actually reached on disk. Byte
# equality is safe here because a given input is reproducible across processes —
# the LSB dithering noise the project notes warns about is between *different* render
# paths, not repeated identical ones.
PARITY_CASES=(
    "token|blue"
    "token-alias|grey"
    "token-dynamic|primary"
    "token-with-opacity|blue:0.5"
    "hex|#0088FF"
    "hex-alpha|#0088FFCC"
    "function|rgb(0,136,255)"
    "srgb-components|srgb:0,0.53,1"
    "display-p3|display-p3:0,0.5,1"
    "extended-wide-gamut|extended-srgb:1.09300,-0.22670,-0.15010,1.00000"
)

# Happy-path cases for the `extract` subcommand. Format differs from HAPPY_CASES
# because extract takes an input path (not a symbol name) and writes one or more
# PNGs into an output directory (via -o <dir>).
# Entry format: slug|inputPath[|arg1|arg2|...]
EXTRACT_CASES=(
    "extract-baseline|/System/Applications/Calculator.app"
    "extract-size-256|/System/Applications/Calculator.app|--size|256"
    "extract-scale-2x|/System/Applications/Calculator.app|--size|128|--scale|2x"
    "extract-color-space-srgb|/System/Applications/Calculator.app|--color-space|sRGB"
    "extract-color-space-display-p3|/System/Applications/Calculator.app|--color-space|displayP3"
    "extract-recursive|/System/Applications/Utilities|--recursive|--depth|0|--size|128"
    "extract-json|/System/Applications/Calculator.app|--json"
    "extract-quiet|/System/Applications/Calculator.app|--quiet"
    "extract-verbose|/System/Applications/Calculator.app|--verbose"
)

# ---- helpers -----------------------------------------------------------------

# Expand $SYMBOL_FIXTURE / $BACKGROUND_FIXTURE placeholders in the given args,
# writing the result into the global EXPANDED_ARGS array.
expand_fixtures() {
    EXPANDED_ARGS=()
    local a
    for a in "$@"; do
        case "${a}" in
            '$SYMBOL_FIXTURE')     EXPANDED_ARGS+=("${FIXTURE_SYMBOL}") ;;
            '$BACKGROUND_FIXTURE') EXPANDED_ARGS+=("${FIXTURE_BACKGROUND}") ;;
            '$CONFIG')             EXPANDED_ARGS+=("${FIXTURE_CONFIG}") ;;
            '$FIXTURES/'*)         EXPANDED_ARGS+=("${FIXTURES_DIR}/${a#\$FIXTURES/}") ;;
            *)                     EXPANDED_ARGS+=("${a}") ;;
        esac
    done
}

# A case's "symbol" field is a bare SF Symbol name, which reaches the CLI as
# `--icon-symbol <name>`. It was the positional argument until that was removed;
# translating here rather than in ~120 data rows keeps each row readable and keeps
# the one exception in one place.
#
# That exception is "extract": four negative cases put it in the symbol field to
# dispatch to the other subcommand, which is a positional and must pass through
# untouched. A blind rewrite of the rows would have turned those four into
# `--icon-symbol extract` — a generate run with a nonexistent symbol, which still
# fails, and still matches its expected substring for the wrong reason.
SYMBOL_ARGS=()
set_symbol_args() {
    SYMBOL_ARGS=()
    case "$1" in
        '')      ;;
        extract) SYMBOL_ARGS=("extract") ;;
        *)       SYMBOL_ARGS=("--icon-symbol" "$1") ;;
    esac
}

# ---- phase functions ---------------------------------------------------------

build_cli() {
    echo "==> Building ${SCHEME}..."
    if ! xcodebuild \
            -project "${XCODE_PROJECT}" \
            -scheme "${SCHEME}" \
            -configuration Debug \
            build \
            -quiet 2>&1; then
        echo "ERROR: xcodebuild failed for scheme ${SCHEME}." >&2
        exit 2
    fi

    local built_products_dir
    built_products_dir="$(
        xcodebuild \
            -project "${XCODE_PROJECT}" \
            -scheme "${SCHEME}" \
            -configuration Debug \
            -showBuildSettings 2>/dev/null \
        | awk -F '= ' '/^[[:space:]]+BUILT_PRODUCTS_DIR[[:space:]]*=/ { print $2; exit }'
    )"

    if [[ -z "${built_products_dir}" ]]; then
        echo "ERROR: could not resolve BUILT_PRODUCTS_DIR from xcodebuild." >&2
        exit 2
    fi

    # The embedded copy, deliberately — NOT "${built_products_dir}/mica-cli".
    #
    # mica-cli reaches its bundled resources through `Bundle.main`. The target's
    # membershipExceptions list carries only .swift files and it has no Resources build
    # phase, so the loose build product cannot see symbol-calibration.json
    # (SymbolSizingService) and **the lookup fails silently** — symbol sizing drops to
    # its auto box-fit tier, producing visibly different glyph sizes from the app.
    #
    # There were two such lookups until 2026-08-16. Assets.car was the other, holding
    # the Liquid Glass background artwork, and a miss there rendered no background at
    # all; that whole feature is gone.
    #
    # The shipped binary does not have this problem: it lives in Contents/MacOS, so
    # CFBundle resolves the enclosing .app and `Bundle.main` is the app itself. That is
    # also the only copy a user ever runs, the CLI being distributed inside the bundle.
    #
    # Testing the loose one meant every render here was output the shipped CLI would
    # never produce, and nothing caught it because a wrong-but-present PNG still passes.
    # Found 2026-08-01 when a GUI-exported configuration replayed through the CLI came
    # back missing its pre-rendered background.
    CLI_BINARY="${built_products_dir}/Mica.app/Contents/MacOS/mica-cli"
    if [[ ! -x "${CLI_BINARY}" ]]; then
        echo "ERROR: embedded CLI binary not found or not executable: ${CLI_BINARY}" >&2
        exit 2
    fi
    echo "==> CLI binary: ${CLI_BINARY}"
}

setup_run() {
    if [[ ! -f "${FIXTURE_SYMBOL}" ]]; then
        echo "ERROR: missing fixture ${FIXTURE_SYMBOL}" >&2
        exit 2
    fi
    if [[ ! -f "${FIXTURE_BACKGROUND}" ]]; then
        echo "ERROR: missing fixture ${FIXTURE_BACKGROUND}" >&2
        exit 2
    fi
    if [[ ! -f "${FIXTURE_CONFIG}" ]]; then
        echo "ERROR: missing fixture ${FIXTURE_CONFIG}" >&2
        exit 2
    fi

    local timestamp
    timestamp="$(date +%Y-%m-%d-%H%M%S)"
    OUTPUT_DIR="${OUTPUT_ROOT}/${timestamp}"
    if ! mkdir -p "${OUTPUT_DIR}"; then
        echo "ERROR: failed to create output directory: ${OUTPUT_DIR}" >&2
        exit 2
    fi
    README="${OUTPUT_DIR}/README.txt"

    local git_sha git_branch
    git_sha="$(git -C "${PROJECT_ROOT}" rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    git_branch="$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"

    {
        echo "mica-cli smoke test"
        echo "========================"
        echo "Timestamp:   ${timestamp}"
        echo "CLI binary:  ${CLI_BINARY}"
        echo "Git branch:  ${git_branch}"
        echo "Git SHA:     ${git_sha}"
        echo "Output dir:  ${OUTPUT_DIR}"
        echo ""
        echo "Results:"
    } > "${README}"

    echo "==> Output dir: ${OUTPUT_DIR}"
}

run_happy_case() {
    local entry="$1"
    local old_ifs="${IFS}"
    IFS='|' read -ra parts <<< "${entry}"
    IFS="${old_ifs}"

    if [[ "${#parts[@]}" -lt 2 ]]; then
        echo "FAIL  ???  malformed entry: ${entry}" | tee -a "${README}"
        HAPPY_FAIL=$((HAPPY_FAIL + 1))
        return
    fi

    local slug="${parts[0]}"
    local symbol="${parts[1]}"
    local rest=("${parts[@]:2}")

    HAPPY_INDEX=$((HAPPY_INDEX + 1))
    local index_formatted
    printf -v index_formatted "%03d" "${HAPPY_INDEX}"
    local output_file="${OUTPUT_DIR}/${index_formatted}__${slug}.png"

    local stderr_file
    stderr_file="$(mktemp)"
    local exit_code=0
    expand_fixtures ${rest[@]+"${rest[@]}"}
    set_symbol_args "${symbol}"

    "${CLI_BINARY}" ${SYMBOL_ARGS[@]+"${SYMBOL_ARGS[@]}"} ${EXPANDED_ARGS[@]+"${EXPANDED_ARGS[@]}"} -o "${output_file}" 2>"${stderr_file}" >/dev/null \
        || exit_code=$?

    if [[ "${exit_code}" -eq 0 && -s "${output_file}" ]]; then
        HAPPY_PASS=$((HAPPY_PASS + 1))
        echo "PASS  ${index_formatted}  ${slug}" | tee -a "${README}"
    else
        HAPPY_FAIL=$((HAPPY_FAIL + 1))
        echo "FAIL  ${index_formatted}  ${slug}  exit=${exit_code}" | tee -a "${README}"
        if [[ -s "${stderr_file}" ]]; then
            sed 's/^/        /' "${stderr_file}" | head -5 >> "${README}"
        fi
    fi

    rm -f "${stderr_file}"
}

run_extract_case() {
    local entry="$1"
    local old_ifs="${IFS}"
    IFS='|' read -ra parts <<< "${entry}"
    IFS="${old_ifs}"

    if [[ "${#parts[@]}" -lt 2 ]]; then
        echo "FAIL  E???  malformed entry: ${entry}" | tee -a "${README}"
        EXTRACT_FAIL=$((EXTRACT_FAIL + 1))
        return
    fi

    local slug="${parts[0]}"
    local input_path="${parts[1]}"
    local rest=("${parts[@]:2}")

    EXTRACT_INDEX=$((EXTRACT_INDEX + 1))
    local index_formatted
    printf -v index_formatted "E%03d" "${EXTRACT_INDEX}"
    local case_dir="${OUTPUT_DIR}/${index_formatted}__${slug}"
    mkdir -p "${case_dir}"

    if [[ ! -e "${input_path}" ]]; then
        EXTRACT_FAIL=$((EXTRACT_FAIL + 1))
        echo "FAIL  ${index_formatted}  ${slug}  missing input: ${input_path}" | tee -a "${README}"
        return
    fi

    local stderr_file
    stderr_file="$(mktemp)"
    local exit_code=0

    "${CLI_BINARY}" extract "${input_path}" -o "${case_dir}" ${rest[@]+"${rest[@]}"} 2>"${stderr_file}" >/dev/null \
        || exit_code=$?

    local png_count
    png_count=$(find "${case_dir}" -maxdepth 2 -name "*.png" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "${exit_code}" -eq 0 && "${png_count}" -gt 0 ]]; then
        EXTRACT_PASS=$((EXTRACT_PASS + 1))
        echo "PASS  ${index_formatted}  ${slug}  (${png_count} PNG$([[ ${png_count} -eq 1 ]] || echo s))" | tee -a "${README}"
    else
        EXTRACT_FAIL=$((EXTRACT_FAIL + 1))
        echo "FAIL  ${index_formatted}  ${slug}  exit=${exit_code}, PNGs=${png_count}" | tee -a "${README}"
        if [[ -s "${stderr_file}" ]]; then
            sed 's/^/        /' "${stderr_file}" | head -5 >> "${README}"
        fi
    fi

    rm -f "${stderr_file}"
}

run_config_case() {
    local entry="$1"
    local old_ifs="${IFS}"
    IFS='|' read -ra parts <<< "${entry}"
    IFS="${old_ifs}"

    if [[ "${#parts[@]}" -lt 5 ]]; then
        echo "FAIL  C???  malformed config entry: ${entry}" | tee -a "${README}"
        CONFIG_FAIL=$((CONFIG_FAIL + 1))
        return
    fi

    local slug="${parts[0]}"
    local expected_exit="${parts[1]}"
    local expected_stderr="${parts[2]}"
    local expected_width="${parts[3]}"
    local rest=("${parts[@]:4}")

    CONFIG_INDEX=$((CONFIG_INDEX + 1))
    local index_formatted
    printf -v index_formatted "C%03d" "${CONFIG_INDEX}"
    local output_file="${OUTPUT_DIR}/${index_formatted}__${slug}.png"

    local stderr_file
    stderr_file="$(mktemp)"
    local exit_code=0
    expand_fixtures ${rest[@]+"${rest[@]}"}

    "${CLI_BINARY}" ${EXPANDED_ARGS[@]+"${EXPANDED_ARGS[@]}"} -o "${output_file}" 2>"${stderr_file}" >/dev/null \
        || exit_code=$?

    local failures=()

    if [[ "${exit_code}" -ne "${expected_exit}" ]]; then
        failures+=("exit=${exit_code}, expected ${expected_exit}")
    fi

    if [[ "${expected_stderr}" != "-" ]] && ! grep -qi -- "${expected_stderr}" "${stderr_file}"; then
        failures+=("stderr missing: ${expected_stderr}")
    fi

    # A case expected to succeed must have produced a PNG; one expected to fail
    # must not have written a half-rendered file.
    if [[ "${expected_exit}" -eq 0 ]]; then
        if [[ ! -s "${output_file}" ]]; then
            failures+=("no PNG written")
        elif [[ "${expected_width}" != "-" ]]; then
            local width
            width="$(sips -g pixelWidth "${output_file}" 2>/dev/null | awk '/pixelWidth:/ { print $2 }')"
            if [[ "${width}" != "${expected_width}" ]]; then
                failures+=("width=${width:-unknown}, expected ${expected_width}")
            fi
        fi
    elif [[ -e "${output_file}" ]]; then
        failures+=("a failed run still wrote ${output_file##*/}")
    fi

    if [[ "${#failures[@]}" -eq 0 ]]; then
        CONFIG_PASS=$((CONFIG_PASS + 1))
        echo "PASS  ${index_formatted}  ${slug}" | tee -a "${README}"
    else
        CONFIG_FAIL=$((CONFIG_FAIL + 1))
        echo "FAIL  ${index_formatted}  ${slug}  ${failures[*]}" | tee -a "${README}"
        if [[ -s "${stderr_file}" ]]; then
            sed 's/^/        /' "${stderr_file}" | head -5 >> "${README}"
        fi
    fi

    rm -f "${stderr_file}"
}

run_negative_case() {
    local entry="$1"
    local old_ifs="${IFS}"
    IFS='|' read -ra parts <<< "${entry}"
    IFS="${old_ifs}"

    if [[ "${#parts[@]}" -lt 3 ]]; then
        echo "FAIL  N-???  malformed negative entry: ${entry}" | tee -a "${README}"
        NEG_FAIL=$((NEG_FAIL + 1))
        return
    fi

    local name="${parts[0]}"
    local expected="${parts[1]}"
    local symbol="${parts[2]}"
    local rest=("${parts[@]:3}")

    local output
    local exit_code=0
    expand_fixtures ${rest[@]+"${rest[@]}"}
    set_symbol_args "${symbol}"
    output="$("${CLI_BINARY}" ${SYMBOL_ARGS[@]+"${SYMBOL_ARGS[@]}"} ${EXPANDED_ARGS[@]+"${EXPANDED_ARGS[@]}"} 2>&1)" || exit_code=$?

    if [[ "${exit_code}" -ne 0 ]] && echo "${output}" | grep -qi -- "${expected}"; then
        NEG_PASS=$((NEG_PASS + 1))
        echo "PASS  N-${name}  (errored as expected)" | tee -a "${README}"
    else
        NEG_FAIL=$((NEG_FAIL + 1))
        echo "FAIL  N-${name}  exit=${exit_code}, expected substring: ${expected}" | tee -a "${README}"
        echo "${output}" | sed 's/^/        /' | head -5 >> "${README}"
    fi
}

# Imported-background defaults, by comparing renders of the shipped binary against
# each other. Four claims, each expressed as "these two invocations must (not)
# produce identical bytes":
#
#   1. `--icon-bg <art>` still renders exactly what it always has. Phase 2 made the
#      import *hide* the foreground and phase 3 removed the render's veto on it, so
#      the visible result must be unchanged — and the way to say that without
#      keeping a golden PNG is that it equals the same invocation with the
#      foreground explicitly switched off.
#   2. Switching the foreground back on changes the render. Before phase 3 nothing
#      could: the gate was in the render and no setting reached past it.
#   3. The corner radius defaults to `off` on import, and an explicit flag beats it.
#   4. The superseded `macos11` token renders exactly as `macos15` does. This claim
#      needs no imported artwork and uses none — it is here because the A/B harness
#      is, and because a token that still parses but resolves elsewhere is a
#      failure only a render comparison can see.
#
# The artwork must FILL ITS OWN BOUNDS. The committed test-background-2.png has
# fully transparent corners, like anything Mica renders, so clipping it at any
# radius changes nothing and claim 3 would pass while measuring nothing. Hence the
# crop below.
#
# Byte comparison is sound here for the same reason as the parity section: these are
# repeated runs of one render path, not two different paths.
IMPORT_PASS=0
IMPORT_FAIL=0

# "slug|expectation|args-of-A|--|args-of-B", expectation being same|differ.
IMPORT_CASES=(
    "bare-equals-explicit-off|same|--icon-bg|\$FILLED|--|--icon-bg|\$FILLED|--icon-fg-visibility|off"
    "revealing-foreground-changes-the-render|differ|--icon-bg|\$FILLED|--|--icon-bg|\$FILLED|--icon-fg-visibility|on"
    "corner-radius-defaults-off|differ|--icon-bg|\$FILLED|--|--icon-bg|\$FILLED|--icon-bg-corner-radius|macos26"
    "corner-radius-off-is-the-default|same|--icon-bg|\$FILLED|--|--icon-bg|\$FILLED|--icon-bg-corner-radius|off"
    # The foreground rule, end to end. Rule 2: naming or styling a foreground reveals
    # it, so the render changes. Both spellings of "naming" are here, because
    # --icon-symbol and --icon-fg symbol: must not disagree about a rule this visible.
    "rule2-symbol-colour-reveals-the-foreground|differ|--icon-bg|\$FILLED|--|--icon-bg|\$FILLED|--icon-symbol-color|green"
    "rule2-icon-symbol-reveals-the-foreground|differ|--icon-bg|\$FILLED|--|--icon-bg|\$FILLED|--icon-symbol|star.fill"
    "rule2-icon-fg-reveals-the-foreground|differ|--icon-bg|\$FILLED|--|--icon-bg|\$FILLED|--icon-fg|symbol:star.fill"
    # The superseded style token, on the shipped binary. "macos11" named the
    # macOS 11-15 design until 2026-08-08 and still decodes, so a script or an
    # exported configuration written before then must render byte-identically to
    # the same call spelled "macos15". A unit test can only pin the enum; this is
    # the flag surface end to end. These two need a foreground of their own: they
    # import no artwork, so nothing else would supply one.
    "superseded-corner-radius-token|same|--icon-symbol|star.fill|--icon-bg-corner-radius|macos11|--|--icon-symbol|star.fill|--icon-bg-corner-radius|macos15"
    "superseded-shadow-token|same|--icon-symbol|star.fill|--icon-bg-shadow|macos11|--|--icon-symbol|star.fill|--icon-bg-shadow|macos15"

    # ---- presets ----
    #
    # The precedence rule end to end: a preset applies *before* the flags, so an
    # explicit flag overrides it. Only the shipped binary can show this — the
    # ordering lives in `GenerationContext.load` and reaches the render through the
    # whole pipeline, and a unit test on the settings cannot see a resource lookup or
    # an encoder go wrong on the way.
    #
    # **These two rows restate a preset's keys by hand, and that is deliberate** — it is
    # the one place in the suite where a literal copy of the catalogue is the assertion
    # rather than a liability, because "a preset equals its own keys" cannot be checked
    # without writing the keys out. So they are also the one place curation has to be
    # followed by hand: re-curating Installer or Update means editing these rows. The
    # 2026-08-31 pass changed Update's symbol and colour and broke this row exactly.
    # Everywhere else — here and in PresetFlagsTests — expectations are derived from the
    # preset rather than repeated.
    #
    # The two "same" rows are the load-bearing half. A preset that silently failed to
    # apply would still render, still exit 0, and still differ from its overridden
    # twin — so a suite of "differ" rows alone would pass with the feature entirely
    # broken. These pin what a preset *is*: the same icon its keys describe.
    "icon-preset-equals-its-own-keys|same|--icon-preset|Installer|--|--icon-symbol|arrow.down.app|--icon-bg-color|blue|--icon-bg-gradient|off|--icon-symbol-color|white"
    "badge-preset-equals-its-own-keys|same|--icon-symbol|star.fill|--badge-preset|Update|--|--icon-symbol|star.fill|--badge-fg|symbol:arrowshape.up.fill|--badge-bg-color|green|--badge-symbol-color|white|--badge-position|bottom-right"
    # A flag beats the preset, on both scopes.
    "icon-flag-overrides-the-preset|differ|--icon-preset|Installer|--|--icon-preset|Installer|--icon-bg-color|red"
    "badge-flag-overrides-the-preset|differ|--icon-symbol|star.fill|--badge-preset|Update|--|--icon-symbol|star.fill|--badge-preset|Update|--badge-position|top-left"
    # Style-only, for free: `--icon-preset media --icon-symbol hammer.fill` is Media's
    # look on a different glyph, which is why the CLI needs no style-only preset kind.
    "symbol-override-is-style-only|differ|--icon-preset|Media|--|--icon-preset|Media|--icon-symbol|hammer.fill"
    # Scope isolation. An icon preset draws no badge, so adding one must change the
    # render; a badge preset must not disturb the icon.
    "icon-preset-draws-no-badge|differ|--icon-preset|Installer|--|--icon-preset|Installer|--badge-preset|Update"
    "badge-preset-leaves-the-icon-alone|same|--icon-preset|Installer|--badge-preset|Update|--|--icon-symbol|arrow.down.app|--icon-bg-color|blue|--icon-bg-gradient|off|--icon-symbol-color|white|--badge-preset|Update"
    # Scope-completeness on the shipped binary: a preset resets what it does not
    # mention, so a flag set *before* the preset in the argument list has no effect on
    # the preset's own scope. Both orderings must land on the same icon — argument
    # order is not the precedence rule, the preset-then-flags pipeline is.
    "argument-order-does-not-change-precedence|same|--icon-preset|Media|--icon-symbol|hammer.fill|--|--icon-symbol|hammer.fill|--icon-preset|Media"
)

# Bounds-filling artwork, built from a rendered icon so the script needs no new
# committed fixture.
make_filled_fixture() {
    FILLED_FIXTURE="${OUTPUT_DIR}/filled-artwork.png"
    local source="${OUTPUT_DIR}/filled-artwork-source.png"
    "${CLI_BINARY}" --icon-symbol square.fill --size 256 --icon-bg-color white \
        -o "${source}" -q >/dev/null 2>&1
    sips --cropToHeightWidth 200 200 "${source}" --out "${FILLED_FIXTURE}" >/dev/null 2>&1
}

run_import_case() {
    local entry="$1"
    local slug="${entry%%|*}"
    local rest="${entry#*|}"
    local expectation="${rest%%|*}"
    rest="${rest#*|}"

    local a_args=() b_args=() seen_separator=0
    local IFS='|'
    read -r -a fields <<< "${rest}"
    unset IFS
    local field
    for field in "${fields[@]}"; do
        if [[ "${field}" == "--" ]]; then
            seen_separator=1
            continue
        fi
        field="${field//\$FILLED/${FILLED_FIXTURE}}"
        if [[ "${seen_separator}" -eq 0 ]]; then
            a_args+=("${field}")
        else
            b_args+=("${field}")
        fi
    done

    local stem="${OUTPUT_DIR}/I__${slug}"
    local failures=()
    local exit_code=0

    # No foreground is supplied here. It used to be a positional `star.fill`, which
    # was invisible to rule 2 and so harmless; `--icon-symbol` is not, and would
    # reveal the very foreground the bare-import cases exist to see hidden. Each row
    # names its own foreground when it wants one.
    "${CLI_BINARY}" --size 512 "${a_args[@]}" -o "${stem}-a.png" -q >/dev/null 2>&1 || exit_code=$?
    [[ "${exit_code}" -eq 0 ]] || failures+=("A exited ${exit_code}")
    exit_code=0
    "${CLI_BINARY}" --size 512 "${b_args[@]}" -o "${stem}-b.png" -q >/dev/null 2>&1 || exit_code=$?
    [[ "${exit_code}" -eq 0 ]] || failures+=("B exited ${exit_code}")

    if [[ "${#failures[@]}" -eq 0 ]]; then
        if [[ ! -s "${stem}-a.png" || ! -s "${stem}-b.png" ]]; then
            failures+=("a render produced no PNG")
        elif cmp -s "${stem}-a.png" "${stem}-b.png"; then
            [[ "${expectation}" == "same" ]] || failures+=("expected different renders, got identical bytes")
        else
            [[ "${expectation}" == "differ" ]] || failures+=("expected identical renders, got different bytes")
        fi
    fi

    if [[ "${#failures[@]}" -eq 0 ]]; then
        echo "PASS  I-${slug}  (${expectation})" | tee -a "${README}"
        IMPORT_PASS=$((IMPORT_PASS + 1))
    else
        local joined
        joined="$(IFS='; '; echo "${failures[*]}")"
        echo "FAIL  I-${slug}  ${joined}" | tee -a "${README}"
        IMPORT_FAIL=$((IMPORT_FAIL + 1))
    fi
}

# One colour form, rendered as a flag and as a configuration, in one colour space.
run_parity_case() {
    local slug="$1"
    local color="$2"
    local space="$3"

    PARITY_INDEX=$((PARITY_INDEX + 1))
    local index_formatted
    printf -v index_formatted "P%03d" "${PARITY_INDEX}"
    local stem="${OUTPUT_DIR}/${index_formatted}__${slug}-${space}"

    local config_file="${OUTPUT_DIR}/${index_formatted}__${slug}-${space}.json"
    # printf %s so a form containing a backslash could not be re-interpreted; none
    # do today, and none of the forms contain a double quote.
    printf '{\n  "icon-fg": "symbol:star.fill",\n  "size": 128,\n  "color-space": "%s",\n  "icon-bg-color": "%s"\n}\n' \
        "${space}" "${color}" > "${config_file}"

    local failures=()
    local exit_code=0

    "${CLI_BINARY}" --config "${config_file}" -o "${stem}-config.png" -q >/dev/null 2>&1 || exit_code=$?
    [[ "${exit_code}" -eq 0 ]] || failures+=("--config exited ${exit_code}")

    exit_code=0
    "${CLI_BINARY}" --icon-symbol star.fill --size 128 --color-space "${space}" --icon-bg-color "${color}" \
        -o "${stem}-flag.png" -q >/dev/null 2>&1 || exit_code=$?
    [[ "${exit_code}" -eq 0 ]] || failures+=("flag exited ${exit_code}")

    if [[ "${#failures[@]}" -eq 0 ]]; then
        if [[ ! -s "${stem}-config.png" || ! -s "${stem}-flag.png" ]]; then
            failures+=("a render produced no PNG")
        elif ! cmp -s "${stem}-config.png" "${stem}-flag.png"; then
            failures+=("the flag and the configuration rendered differently")
        fi
    fi

    if [[ "${#failures[@]}" -eq 0 ]]; then
        echo "PASS  ${index_formatted}  ${slug} (${space})  [${color}]" | tee -a "${README}"
        PARITY_PASS=$((PARITY_PASS + 1))
    else
        local joined
        joined="$(IFS='; '; echo "${failures[*]}")"
        echo "FAIL  ${index_formatted}  ${slug} (${space})  [${color}]  ${joined}" | tee -a "${README}"
        PARITY_FAIL=$((PARITY_FAIL + 1))
    fi
}

print_summary() {
    local happy_total=$((HAPPY_PASS + HAPPY_FAIL))
    local neg_total=$((NEG_PASS + NEG_FAIL))
    local extract_total=$((EXTRACT_PASS + EXTRACT_FAIL))
    local config_total=$((CONFIG_PASS + CONFIG_FAIL))
    local parity_total=$((PARITY_PASS + PARITY_FAIL))
    local import_total=$((IMPORT_PASS + IMPORT_FAIL))
    local line="Happy: ${HAPPY_PASS}/${happy_total} | Config: ${CONFIG_PASS}/${config_total} | Parity: ${PARITY_PASS}/${parity_total} | Import: ${IMPORT_PASS}/${import_total} | Negative: ${NEG_PASS}/${neg_total} | Extract: ${EXTRACT_PASS}/${extract_total} | Output: ${OUTPUT_DIR}"

    echo ""
    echo "============================================================"
    echo "${line}"
    echo "============================================================"
    {
        echo ""
        echo "============================================================"
        echo "${line}"
        echo "============================================================"
    } >> "${README}"

    if command -v open >/dev/null 2>&1; then
        open "${OUTPUT_DIR}"
    fi

    # PARITY_FAIL was missing from this list until 2026-08-03: a parity failure
    # printed FAIL and the script still exited 0, so the cross-surface gate the project notes
    # relies on could not fail a CI run. Every counter belongs here.
    if [[ "${HAPPY_FAIL}" -ne 0 || "${CONFIG_FAIL}" -ne 0 || "${PARITY_FAIL}" -ne 0 \
        || "${IMPORT_FAIL}" -ne 0 || "${NEG_FAIL}" -ne 0 || "${EXTRACT_FAIL}" -ne 0 ]]; then
        exit 1
    fi
    exit 0
}

# ---- main --------------------------------------------------------------------

main() {
    build_cli
    setup_run
    for entry in "${HAPPY_CASES[@]-}"; do
        [[ -z "$entry" ]] && continue
        run_happy_case "$entry"
    done
    for entry in "${CONFIG_CASES[@]-}"; do
        [[ -z "$entry" ]] && continue
        run_config_case "$entry"
    done
    make_filled_fixture
    for entry in "${IMPORT_CASES[@]-}"; do
        [[ -z "$entry" ]] && continue
        run_import_case "$entry"
    done
    for entry in "${PARITY_CASES[@]-}"; do
        [[ -z "$entry" ]] && continue
        parity_slug="${entry%%|*}"
        parity_color="${entry#*|}"
        for parity_space in sRGB displayP3; do
            run_parity_case "${parity_slug}" "${parity_color}" "${parity_space}"
        done
    done
    for entry in "${EXTRACT_CASES[@]-}"; do
        [[ -z "$entry" ]] && continue
        run_extract_case "$entry"
    done
    for entry in "${NEGATIVE_CASES[@]-}"; do
        [[ -z "$entry" ]] && continue
        run_negative_case "$entry"
    done
    print_summary
}

main "$@"
