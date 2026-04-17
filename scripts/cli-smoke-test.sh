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
HAPPY_CASES=()
NEGATIVE_CASES=()

# ---- phase functions ---------------------------------------------------------

build_cli() {
    echo "[build] (stub)"
}

setup_run() {
    echo "[setup] (stub)"
}

run_happy_case() {
    echo "[happy] (stub) $1"
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
