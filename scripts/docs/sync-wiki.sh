#!/bin/bash
# sync-wiki.sh — publish wiki/ to the GitHub wiki, then verify it rendered.
#
# A GitHub wiki is its own git repository (OWNER/REPO.wiki.git) with its own
# history, and it is NOT included when someone clones the main repo. So wiki/
# here is the source of truth — versioned with the code, reviewable in a PR, and
# checked by check-wiki-coverage.sh and check-help-links.sh — and the wiki repo
# is only ever a publish target. This script is the one direction: repo -> wiki.
#
# Usage:  scripts/docs/sync-wiki.sh
#         DRY_RUN=1 scripts/docs/sync-wiki.sh   # show what would change, push nothing
#         KEEP_CLONE=1 scripts/docs/sync-wiki.sh # leave the clone for inspection
# Exit:   0 synced (or nothing to sync), 1 something is wrong — see the message.
#
# ---- four things that will otherwise cost you an hour -----------------------
#
# 1. THE WIKI MUST BE INITIALISED IN A BROWSER FIRST. Enabling Wikis in Settings
#    is not enough: .wiki.git does not exist until one page has been saved
#    through the web UI, and there is no API for creating one. Until then the
#    clone fails with "repository not found", which reads exactly like an auth
#    failure and sends you off debugging credentials. This script detects that
#    case and tells you what to do instead of letting git's message mislead you.
#
# 2. THE BRANCH IS NOT NECESSARILY main. Wiki repos have historically been
#    initialised as master. Pushing a hardcoded `main` creates a second branch
#    that renders nothing, with no error anywhere. The branch is read from the
#    clone, never assumed.
#
# 3. rsync --delete IS LOAD-BEARING, AND SO IS --exclude .git. `cp` only ever
#    adds and overwrites, so a renamed or deleted page lives on the published
#    wiki forever, still linked from search, with nothing to tell you. --delete
#    fixes that; without --exclude .git it would also delete the clone's history.
#
# 4. THE REPOSITORY URL IS READ OUT OF MicaLinks.swift, never restated here.
#    Same rule as check-help-links.sh: a copy in this file would happily publish
#    to a different repo than the one the app's Help menu opens. It also means
#    the casing is right by construction — github.com is case-insensitive and
#    would redirect a wrong-cased clone, hiding the inconsistency.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINKS_SOURCE="$REPO_ROOT/Mica/App/MicaLinks.swift"
WIKI_DIR="$REPO_ROOT/wiki"

DRY_RUN="${DRY_RUN:-0}"
KEEP_CLONE="${KEEP_CLONE:-0}"

FAIL=0
fail() { printf 'FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
pass() { printf 'ok    %s\n' "$1"; }
info() { printf '      %s\n' "$1"; }

# --- Locate the inputs. A missing input is a failure, never a silent pass. ---

if [[ ! -f "$LINKS_SOURCE" ]]; then
    fail "no MicaLinks.swift at $LINKS_SOURCE"
    exit 1
fi

if [[ ! -d "$WIKI_DIR" ]]; then
    fail "no wiki/ directory at $WIKI_DIR"
    exit 1
fi

for tool in git rsync curl; do
    command -v "$tool" >/dev/null 2>&1 || { fail "$tool is not installed"; exit 1; }
done

# --- Parse `static let repository = URL(string: "https://github.com/o/r")!` ---

REPO_URL="$(grep -E 'static let repository' "$LINKS_SOURCE" \
    | grep -oE 'https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+' | head -1)"

if [[ -z "$REPO_URL" ]]; then
    fail "could not parse the repository URL from MicaLinks.swift — did its shape change?"
    exit 1
fi

if [[ "$REPO_URL" == *"OWNER/REPO"* ]]; then
    fail "MicaLinks.swift still holds an OWNER/REPO placeholder"
    exit 1
fi

REPO_PATH="${REPO_URL#https://github.com/}"
WIKI_URL="${REPO_URL}.wiki.git"

printf 'Publishing %s -> %s\n\n' "${WIKI_DIR#"$REPO_ROOT"/}" "$WIKI_URL"

# --- Clone the wiki. An uninitialised wiki is the expected first failure. ---

CLONE_DIR="$(mktemp -d)"
cleanup() {
    if [[ "$KEEP_CLONE" == "1" ]]; then
        info "clone kept at $CLONE_DIR"
    else
        rm -rf "$CLONE_DIR"
    fi
}
trap cleanup EXIT

if ! git clone --quiet "$WIKI_URL" "$CLONE_DIR/wiki" 2>/dev/null; then
    fail "could not clone $WIKI_URL"
    info ""
    info "The usual cause is that the wiki has never been initialised. Enabling"
    info "Wikis in Settings does not create the repository — one page has to be"
    info "saved through the web UI first, and there is no API for it:"
    info ""
    info "    gh repo edit $REPO_PATH --enable-wiki"
    info "    open \"$REPO_URL/wiki/_new\""
    info ""
    info "Save any page (this script overwrites it), then run this again."
    exit 1
fi

cd "$CLONE_DIR/wiki" || { fail "could not enter the clone"; exit 1; }

BRANCH="$(git branch --show-current)"
[[ -z "$BRANCH" ]] && BRANCH="$(git rev-parse --abbrev-ref HEAD)"
pass "cloned, on branch '$BRANCH'"

# --- Sync. --delete removes pages that no longer exist in wiki/. ---
#
# MANIFEST.md is excluded: it is the command-per-image record for the generator,
# addressed to whoever writes the pages, not a page anyone should land on.

rsync -a --delete \
    --exclude '.git' \
    --exclude 'images/MANIFEST.md' \
    "$WIKI_DIR/" .

git add -A

if git diff --cached --quiet; then
    pass "wiki is already up to date — nothing to push"
    exit 0
fi

printf '\nChanges to publish:\n'
git diff --cached --name-status | sed 's/^/      /'
printf '\n'

if [[ "$DRY_RUN" == "1" ]]; then
    pass "DRY_RUN=1 — stopping before commit and push"
    exit 0
fi

# --- Commit and push ---

if ! git commit --quiet -m "Sync wiki from main repo"; then
    fail "commit failed"
    exit 1
fi

if ! git push --quiet origin "$BRANCH"; then
    fail "push to origin/$BRANCH failed"
    exit 1
fi
pass "pushed to origin/$BRANCH"

# --- Verify it actually rendered ---
#
# curl proves a page and an image exist. It cannot prove the relative
# <img src="images/..."> paths resolved on the rendered page or that _Sidebar.md
# is showing, so the last line sends you to look. A wiki that publishes but
# renders every image broken returns 200 for all of this.

printf '\nVerifying:\n'

PAGE_COUNT="$(find . -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
SOURCE_COUNT="$(find "$WIKI_DIR" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
if [[ "$PAGE_COUNT" == "$SOURCE_COUNT" ]]; then
    pass "$PAGE_COUNT pages published"
else
    fail "published $PAGE_COUNT pages but wiki/ holds $SOURCE_COUNT"
fi

# The slugs the app's Help menu opens. Read from the source, same as the URL.
SLUGS="$(grep -E 'static let wikiPageSlugs' "$LINKS_SOURCE" \
    | grep -oE '"[^"]+"' | tr -d '"')"

while IFS= read -r slug; do
    [[ -z "$slug" ]] && continue
    CODE="$(curl -s -o /dev/null -w '%{http_code}' "$REPO_URL/wiki/$slug")"
    if [[ "$CODE" == "200" ]]; then
        pass "Help menu link /wiki/$slug ($CODE)"
    else
        fail "Help menu link /wiki/$slug returned $CODE"
    fi
done <<< "$SLUGS"

FIRST_IMAGE="$(find "$WIKI_DIR/images" -name '*.png' | head -1)"
if [[ -n "$FIRST_IMAGE" ]]; then
    IMAGE_NAME="$(basename "$FIRST_IMAGE")"
    CODE="$(curl -s -o /dev/null -w '%{http_code}' \
        "https://raw.githubusercontent.com/wiki/$REPO_PATH/images/$IMAGE_NAME")"
    if [[ "$CODE" == "200" ]]; then
        pass "images/$IMAGE_NAME is served ($CODE)"
    else
        fail "images/$IMAGE_NAME returned $CODE"
    fi
fi

printf '\n'
if [[ "$FAIL" -gt 0 ]]; then
    printf 'FAIL  %s check(s) failed\n' "$FAIL"
    exit 1
fi

printf 'PASS  wiki published\n\n'
info "Now look at a page — curl cannot tell you whether the relative"
info "<img src=\"images/...\"> paths resolved or whether _Sidebar.md is showing:"
info ""
info "    open \"$REPO_URL/wiki/Icon-Settings\""
