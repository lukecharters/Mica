#!/bin/bash
# Check that the user documentation covers the complete settings surface.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_SOURCE="$REPO_ROOT/Mica/Services/MicaConfig.swift"
WIKI_DIR="$REPO_ROOT/wiki"
SETTINGS_PAGES=(
    "$WIKI_DIR/Icon-Settings.md"
    "$WIKI_DIR/Badge-Settings.md"
    "$WIKI_DIR/Export-Settings.md"
)

FAIL=0

fail() { printf 'FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
pass() { printf 'ok    %s\n' "$1"; }

if [[ ! -f "$CONFIG_SOURCE" || ! -d "$WIKI_DIR" ]]; then
    fail "required source or wiki directory is missing"
    exit 1
fi

for page in "${SETTINGS_PAGES[@]}"; do
    if [[ ! -f "$page" ]]; then
        fail "missing ${page#"$REPO_ROOT"/}"
    fi
done

if [[ "$FAIL" -ne 0 ]]; then
    exit 1
fi

KEYS="$(
    sed -n '/enum MicaConfigKey:/,/static let britishAliases:/p' "$CONFIG_SOURCE" |
        sed -nE 's/^[[:space:]]*case[[:space:]]+[A-Za-z0-9]+([[:space:]]*=[[:space:]]*"([^"]+)")?.*/\2/p' |
        awk '
            NR == 1 && $0 == "" { print "size"; next }
            NR == 2 && $0 == "" { print "scale"; next }
            NF { print }
        '
)"

KEY_COUNT="$(printf '%s\n' "$KEYS" | grep -c .)"
if [[ "$KEY_COUNT" -eq 46 ]]; then
    pass "parsed 46 configuration keys"
else
    fail "parsed $KEY_COUNT configuration keys, expected 46"
fi

while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    matches="$(grep -lF "\`\"$key\"\`" "${SETTINGS_PAGES[@]}" 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$matches" -eq 1 ]]; then
        pass "setting $key has one reference entry"
    elif [[ "$matches" -eq 0 ]]; then
        fail "setting $key has no reference entry"
    else
        fail "setting $key appears as an entry on $matches settings pages"
    fi
done <<< "$KEYS"

VALID_FLAGS="$(
    {
        printf '%s\n' "$KEYS"
        printf '%s\n' icon-symbol badge-symbol output config json quiet verbose
        printf '%s\n' help version recursive depth
        printf '%s\n' colour-space icon-symbol-colour icon-bg-colour
        printf '%s\n' icon-bg-gradient-colours badge-symbol-colour
        printf '%s\n' badge-bg-colour badge-bg-gradient-colours
    } | sort -u
)"

WIKI_TEXT="$(
    awk '
        /<!--/ { in_comment = 1 }
        !in_comment { print }
        /-->/ { in_comment = 0 }
    ' "$WIKI_DIR"/*.md
)"

FLAGS="$(
    printf '%s\n' "$WIKI_TEXT" |
        grep -oE -- '--[a-z][a-z-]*' |
        sed 's/^--//' |
        sort -u
)"

while IFS= read -r flag; do
    [[ -z "$flag" ]] && continue
    if printf '%s\n' "$VALID_FLAGS" | grep -qxF "$flag"; then
        :
    else
        fail "wiki mentions unknown flag --$flag"
    fi
done <<< "$FLAGS"
pass "all documented long flags are recognised"

IMAGE_REFS="$(
    printf '%s\n' "$WIKI_TEXT" |
        grep -oE 'src="images/[^"]+"' |
        sed -E 's/^src="images\/(.*)"$/\1/' |
        sort -u
)"

while IFS= read -r image; do
    [[ -z "$image" ]] && continue
    if [[ -f "$WIKI_DIR/images/$image" ]]; then
        :
    else
        fail "missing wiki/images/$image"
    fi
done <<< "$IMAGE_REFS"
pass "all wiki image references resolve"

LINKS="$(
    printf '%s\n' "$WIKI_TEXT" |
        grep -oE '\]\([A-Za-z0-9_-]+(#[A-Za-z0-9_-]+)?\)' |
        sed -E 's/^\]\(([^#)]+).*/\1/' |
        sort -u
)"

while IFS= read -r slug; do
    [[ -z "$slug" ]] && continue
    if [[ -f "$WIKI_DIR/$slug.md" ]]; then
        :
    else
        fail "wiki link target $slug has no wiki/$slug.md"
    fi
done <<< "$LINKS"
pass "all internal wiki page links resolve"

printf '\n'
if [[ "$FAIL" -eq 0 ]]; then
    printf 'PASS  wiki settings coverage is complete\n'
    exit 0
else
    printf 'FAIL  %s problem(s)\n' "$FAIL"
    exit 1
fi
