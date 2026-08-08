#!/bin/bash
# check-help-links.sh — every wiki page the Help menu links to exists in wiki/.
#
# Item B5 of the Mac-conventions plan. The Help menu is Mica's only
# documentation surface, so a renamed wiki page is a shipped dead link — and a quiet
# one: it opens a GitHub 404 that reads like the page merely moved.
#
# **Why this is a script and not a test.** The natural home is `MicaTests`, beside the
# rest of `MicaLinksTests`. It cannot go there: that target is injected into
# `Mica.app`, which is sandboxed with only `files.user-selected` granted, so
# `FileManager` reports the repository as not existing at all. Measured 2026-08-04 —
# a test walking up from `#filePath` failed with "could not locate the repository
# root" while every link was correct. `mica-cli Tests` is unsandboxed and could host
# it, but only by keeping its own copy of the slug list, which is the duplication this
# check exists to catch.
#
# **The slug list is read out of the source, never restated here.** Parsing
# `MicaLinks.wikiPageSlugs` is the whole point; a copy in this file would pass while
# the app shipped something else.
#
# Usage:  scripts/tests/check-help-links.sh
# Exit:   0 all links resolve, 1 a page is missing or the source could not be parsed.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINKS_SOURCE="$REPO_ROOT/Mica/App/MicaLinks.swift"
WIKI_DIR="$REPO_ROOT/wiki"

FAIL=0

fail() { printf 'FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
pass() { printf 'ok    %s\n' "$1"; }

# --- Locate the inputs. A missing input is a failure, never a silent pass. ---

if [[ ! -f "$LINKS_SOURCE" ]]; then
    fail "no MicaLinks.swift at $LINKS_SOURCE"
    exit 1
fi

if [[ ! -d "$WIKI_DIR" ]]; then
    fail "no wiki/ directory at $WIKI_DIR"
    exit 1
fi

# --- Parse `static let wikiPageSlugs = ["Home", "CLI-Guide", ...]` ---

SLUG_LINE="$(grep -E 'static let wikiPageSlugs' "$LINKS_SOURCE" || true)"

if [[ -z "$SLUG_LINE" ]]; then
    fail "could not find 'static let wikiPageSlugs' in MicaLinks.swift — did it move or get renamed?"
    exit 1
fi

# Every double-quoted string on that line, one per line.
SLUGS="$(printf '%s\n' "$SLUG_LINE" | grep -oE '"[^"]+"' | tr -d '"')"

if [[ -z "$SLUGS" ]]; then
    fail "wikiPageSlugs parsed as empty — the declaration's shape changed"
    exit 1
fi

SLUG_COUNT="$(printf '%s\n' "$SLUGS" | grep -c .)"
printf 'Checking %s wiki link(s) from MicaLinks.wikiPageSlugs against %s\n\n' \
    "$SLUG_COUNT" "${WIKI_DIR#"$REPO_ROOT"/}"

# --- Each slug must have a page ---

while IFS= read -r slug; do
    [[ -z "$slug" ]] && continue
    if [[ -f "$WIKI_DIR/$slug.md" ]]; then
        pass "wiki/$slug.md"
    else
        fail "Help menu links wiki/$slug but wiki/$slug.md does not exist"
    fi
done <<< "$SLUGS"

# --- The repository path must not still be a placeholder ---

if grep -qE 'OWNER/REPO' "$LINKS_SOURCE"; then
    fail "MicaLinks.swift still holds an OWNER/REPO placeholder"
else
    pass "the repository path is a real path"
fi

printf '\n'
if [[ "$FAIL" -eq 0 ]]; then
    printf 'PASS  %s link(s) resolve\n' "$SLUG_COUNT"
    exit 0
else
    printf 'FAIL  %s problem(s)\n' "$FAIL"
    exit 1
fi
