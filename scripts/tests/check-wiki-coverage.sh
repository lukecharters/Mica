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
            NF { print }
        '
)"

KEY_COUNT="$(printf '%s\n' "$KEYS" | grep -c .)"
if [[ "$KEY_COUNT" -eq 49 ]]; then
    pass "parsed 49 configuration keys"
else
    fail "parsed $KEY_COUNT configuration keys, expected 49"
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
        printf '%s\n' icon-symbol badge-symbol output config json quiet verbose force
        # Real flags with no configuration key. A configuration carries the values
        # of a preset rather than its name, so the file stays self-contained.
        # Keep this comment free of apostrophes: it sits inside a $( ) and bash
        # scans for the closing paren with quoting still in force.
        printf '%s\n' icon-preset badge-preset
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

# Every <img src=...> value, quoted or unquoted, with the quotes removed.
IMG_SRCS="$(
    printf '%s\n' "$WIKI_TEXT" |
        grep -oE '<img[^>]*[[:space:]]src=("[^"]*"|[^[:space:]>]+)' |
        sed -E 's/.*[[:space:]]src=//; s/^"//; s/"$//' |
        sort -u
)"

BAD_SRC=0
while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    if [[ "$src" != images/* ]]; then
        fail "wiki image src $src does not start with images/"
        BAD_SRC=$((BAD_SRC + 1))
    fi
done <<< "$IMG_SRCS"
if [[ "$BAD_SRC" -eq 0 ]]; then
    pass "all wiki image sources start with images/"
fi

IMAGE_REFS="$(
    printf '%s\n' "$IMG_SRCS" |
        sed -nE 's/^images\///p' |
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

# The generator renders the two generation-mode images for its own System-mode
# check. No page shows them.
UNUSED_EXEMPT=(
    MANIFEST.md
    icon-generation-mode-mica.png
    icon-generation-mode-system.png
)

UNUSED=0
for file in "$WIKI_DIR"/images/*; do
    [[ -f "$file" ]] || continue
    name="${file##*/}"
    if printf '%s\n' "${UNUSED_EXEMPT[@]}" | grep -qxF "$name"; then
        continue
    fi
    if printf '%s\n' "$IMAGE_REFS" | grep -qxF "$name"; then
        :
    else
        fail "wiki/images/$name is used by no page"
        UNUSED=$((UNUSED + 1))
    fi
done
if [[ "$UNUSED" -eq 0 ]]; then
    pass "every wiki image is used by a page"
fi

# A link that climbs out of the wiki breaks on the GitHub wiki. An image path
# that does the same is caught by the images/ check above.
PARENT_LINKS="$(
    printf '%s\n' "$WIKI_TEXT" |
        grep -oE '\]\(\.\./[^)]*\)|href="\.\./[^"]*"|href=\.\./[^[:space:]>]*' |
        sort -u
)"

if [[ -z "$PARENT_LINKS" ]]; then
    pass "no wiki link climbs out of the wiki"
else
    while IFS= read -r link; do
        fail "wiki link climbs out of the wiki: $link"
    done <<< "$PARENT_LINKS"
fi

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

SIDEBAR="$WIKI_DIR/_Sidebar.md"
UNLISTED=0
for page in "$WIKI_DIR"/*.md; do
    slug="$(basename "$page" .md)"
    [[ "$slug" == "_Sidebar" ]] && continue
    if grep -qE "\]\($slug(#[A-Za-z0-9_-]+)?\)" "$SIDEBAR" 2>/dev/null; then
        :
    else
        fail "wiki/$slug.md is not linked from _Sidebar.md"
        UNLISTED=$((UNLISTED + 1))
    fi
done
if [[ "$UNLISTED" -eq 0 ]]; then
    pass "every wiki page is linked from _Sidebar.md"
fi

printf '\n'
if [[ "$FAIL" -eq 0 ]]; then
    printf 'PASS  wiki settings coverage is complete\n'
    exit 0
else
    printf 'FAIL  %s problem(s)\n' "$FAIL"
    exit 1
fi
