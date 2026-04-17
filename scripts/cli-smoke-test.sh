#!/usr/bin/env bash
#
# CLI smoke-test for sfIconGen-CLI.
# Exercises every non-default argument value (happy path) plus a fixed set of
# invalid-input cases (negative path). Produces per-case PNGs in a timestamped
# output directory and a README.txt summary. See
# docs/superpowers/specs/2026-04-17-cli-smoke-test-design.md for the design.

set -u
set -o pipefail

# ---- configuration -----------------------------------------------------------

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly FIXTURES_DIR="${PROJECT_ROOT}/scripts/fixtures"
readonly OUTPUT_ROOT="${PROJECT_ROOT}/scripts/smoke-output"
readonly FIXTURE_SYMBOL="${FIXTURES_DIR}/test-symbol.png"
readonly FIXTURE_BACKGROUND="${FIXTURES_DIR}/test-background.png"
readonly SCHEME="sfIconGen-CLI"
readonly XCODE_PROJECT="${PROJECT_ROOT}/macOS Icon Generator App.xcodeproj"

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

# ---- case data ---------------------------------------------------------------
# Populated in later tasks.
HAPPY_CASES=(
    # ---- baseline ----
    "baseline|star.fill"

    # ---- Export ----
    "size-1024|star.fill|--size|1024"
    "retina|star.fill|--retina"
    "color-space-display-p3|star.fill|--color-space|displayP3"

    # ---- Generation ----
    "generation-mode-apple-reference|star.fill|--generation-mode|apple-reference"
    "icon-source-image|folder.fill|--icon-source|image|--imported-image|\$SYMBOL_FIXTURE"
    "imported-image-scale|folder.fill|--icon-source|image|--imported-image|\$SYMBOL_FIXTURE|--imported-image-scale|1.5"
    "appex-enclosure-color-red|star.fill|--generation-mode|apple-reference|--appex-enclosure-color|red"
    "appex-symbol-color-yellow|star.fill|--generation-mode|apple-reference|--appex-symbol-color|yellow"

    # ---- Background ----
    "background-mode-image|star.fill|--background-mode|image|--imported-background|\$BACKGROUND_FIXTURE"
    "base-color-red|star.fill|--base-color|red"
    "use-custom-colors|star.fill|--use-custom-colors|--custom-primary|#FF6B35|--custom-secondary|#F7931E"
    "no-gradient|star.fill|--no-gradient"
    "corner-radius-macos11|star.fill|--corner-radius|macos11"
    "background-shadow-off|star.fill|--background-shadow-style|off"
    "background-shadow-macos11|star.fill|--background-shadow-style|macos11"
    "imported-background-scale|star.fill|--background-mode|image|--imported-background|\$BACKGROUND_FIXTURE|--imported-background-scale|1.3"
    "imported-background-padding-compensation|star.fill|--background-mode|image|--imported-background|\$BACKGROUND_FIXTURE|--imported-background-padding-compensation"

    # ---- Symbol ----
    "rendering-mode-hierarchical|shield.fill|--rendering-mode|hierarchical"
    "rendering-mode-multicolor|star.fill|--rendering-mode|multicolor"
    "rendering-mode-palette|shield.fill|--rendering-mode|palette|--palette-primary|red|--palette-secondary|blue:0.6|--palette-tertiary|green:0.3"
    "symbol-color-yellow|star.fill|--symbol-color|yellow"
    "hierarchical-color-cyan|shield.fill|--rendering-mode|hierarchical|--hierarchical-color|cyan"
    "no-symbol-shadow|star.fill|--no-symbol-shadow"
    "symbol-weight-bold|star.fill|--symbol-weight|bold"
    "symbol-scale-1-3|star.fill|--symbol-scale|1.3"
    "symbol-color-rendering-gradient|star.fill|--symbol-color-rendering|gradient"

    # ---- Badge ----
    "badge-enable|star.fill|--badge|plus.circle"
    "badge-position-top-left|star.fill|--badge|plus.circle|--badge-position|top-left"
    "badge-position-top-right|star.fill|--badge|plus.circle|--badge-position|top-right"
    "badge-position-bottom-left|star.fill|--badge|plus.circle|--badge-position|bottom-left"
    "badge-scale|star.fill|--badge|plus.circle|--badge-scale|1.3"
    "badge-symbol-scale|star.fill|--badge|plus.circle|--badge-symbol-scale|0.7"
    "badge-offset-x|star.fill|--badge|plus.circle|--badge-offset-x|0.2"
    "badge-offset-y|star.fill|--badge|plus.circle|--badge-offset-y=-0.1"
    "badge-color-red|star.fill|--badge|plus.circle|--badge-color|red"
    "badge-use-custom|star.fill|--badge|plus.circle|--badge-use-custom|--badge-primary|#00AAFF|--badge-secondary|#0055AA"
    "badge-rendering-hierarchical|star.fill|--badge|plus.circle|--badge-rendering|hierarchical|--badge-hierarchical-color|cyan"
    "badge-rendering-multicolor|star.fill|--badge|star.fill|--badge-rendering|multicolor"
    "badge-rendering-palette|star.fill|--badge|plus.circle|--badge-rendering|palette|--badge-palette-primary|red|--badge-palette-secondary|blue:0.5|--badge-palette-tertiary|green:0.2"
    "badge-symbol-color-yellow|star.fill|--badge|plus.circle|--badge-symbol-color|yellow"
    "badge-symbol-weight-bold|star.fill|--badge|plus.circle|--badge-symbol-weight|bold"
    "badge-symbol-color-rendering-gradient|star.fill|--badge|plus.circle|--badge-symbol-color-rendering|gradient"
    "badge-no-gradient|star.fill|--badge|plus.circle|--badge-no-gradient"
    "badge-no-background-shadow|star.fill|--badge|plus.circle|--badge-no-background-shadow"
    "badge-no-symbol-shadow|star.fill|--badge|plus.circle|--badge-no-symbol-shadow"
    "badge-icon-source-image|star.fill|--badge|placeholder|--badge-icon-source|image|--badge-imported-image|\$SYMBOL_FIXTURE"
    "badge-icon-source-apple-reference|star.fill|--badge|gear|--badge-icon-source|apple-reference|--badge-appex-enclosure-color|red|--badge-appex-symbol-color|white"
    "badge-imported-image-scale|star.fill|--badge|placeholder|--badge-icon-source|image|--badge-imported-image|\$SYMBOL_FIXTURE|--badge-imported-image-scale|1.2"
    "badge-imported-background|star.fill|--badge|plus.circle|--badge-imported-background|\$BACKGROUND_FIXTURE"
    "badge-imported-background-scale|star.fill|--badge|plus.circle|--badge-imported-background|\$BACKGROUND_FIXTURE|--badge-imported-background-scale|1.2"
    "badge-imported-background-padding-compensation|star.fill|--badge|plus.circle|--badge-imported-background|\$BACKGROUND_FIXTURE|--badge-imported-background-padding-compensation"
)
NEGATIVE_CASES=()

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

    CLI_BINARY="${built_products_dir}/${SCHEME}"
    if [[ ! -x "${CLI_BINARY}" ]]; then
        echo "ERROR: built CLI binary not found or not executable: ${CLI_BINARY}" >&2
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
        echo "sfIconGen-CLI smoke test"
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
    # Resolve fixture placeholders: $SYMBOL_FIXTURE, $BACKGROUND_FIXTURE.
    local expanded=()
    local a
    for a in ${rest[@]+"${rest[@]}"}; do
        case "${a}" in
            '$SYMBOL_FIXTURE')     expanded+=("${FIXTURE_SYMBOL}") ;;
            '$BACKGROUND_FIXTURE') expanded+=("${FIXTURE_BACKGROUND}") ;;
            *)                     expanded+=("${a}") ;;
        esac
    done

    "${CLI_BINARY}" "${symbol}" ${expanded[@]+"${expanded[@]}"} -o "${output_file}" 2>"${stderr_file}" >/dev/null \
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

run_negative_case() {
    echo "[negative] (stub) $1"
}

print_summary() {
    echo "[summary] (stub)"
}

# ---- main --------------------------------------------------------------------

main() {
    build_cli
    setup_run
    for entry in "${HAPPY_CASES[@]-}"; do
        [[ -z "$entry" ]] && continue
        run_happy_case "$entry"
    done
    for entry in "${NEGATIVE_CASES[@]-}"; do
        [[ -z "$entry" ]] && continue
        run_negative_case "$entry"
    done
    print_summary
}

main "$@"
