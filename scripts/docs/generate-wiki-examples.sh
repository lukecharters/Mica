#!/usr/bin/env bash
#
# Generate every example image the wiki shows, into wiki/images/.
#
# Phase 1 of docs/plans/user-documentation-rewrite-2026-08-17.md. The wiki's
# settings reference puts a rendered result beside each of the 46 settings, and
# those images are produced here rather than by hand: a hand-made image cannot be
# regenerated when a default changes, and a stale example is worse than none.
#
# Run it, commit what lands in wiki/images/, and read MANIFEST.md — it gives the
# exact command behind every image, which is what each reference entry has to
# quote. The writer never has to guess a filename or invent a command.
#
#   scripts/docs/generate-wiki-examples.sh              # build, render, verify
#   SKIP_BUILD=1 scripts/docs/generate-wiki-examples.sh # reuse the last build
#   KEEP_OLD=1   scripts/docs/generate-wiki-examples.sh # don't delete old images
#
# ---- three things that will otherwise cost you an hour ----------------------
#
# 1. It renders with the EMBEDDED binary, Mica.app/Contents/MacOS/mica-cli, never
#    Build/Products/*/mica-cli. The loose product cannot see
#    symbol-calibration.json through Bundle.main, that lookup fails silently, and
#    symbol sizing drops to its auto box-fit tier — so every glyph comes out a
#    different size from the app's. A wrong-but-present PNG passes every check.
#
# 2. System mode cannot render inside the Bash tool sandbox. IconServices is
#    blocked, the render falls back to a plain tile, and nothing errors. Run with
#    dangerouslyDisableSandbox: true. The fallback is caught rather than trusted:
#    see verify_system_mode().
#
# 3. It needs Pillow for the verification pass:  python3 -m pip install --user Pillow
#
# ---- how the manifest works --------------------------------------------------
#
# Every image is one `emit <group> <slug> <args...>` call, and the filename is
# <group>-<slug>.png — the config key, then the value. `icon-bg-gradient-on.png`,
# `badge-position-top-left.png`. Predictable names mean a missing image is
# obvious and the writer never guesses.
#
# A group is a set of images meant to be shown together, and it is also the unit
# of verification: verify-wiki-examples.py compares every group pairwise and
# fails if two members are too similar. That check is the point of this script
# being a script. A render that succeeds but shows nothing is the failure mode
# here, and it is invisible in a file listing — the writer builds an entry around
# "left is on, right is off" and the page then documents a difference the
# software does not produce.
#
# Slugs for numbers keep the decimal (`icon-fg-scale-0.5.png`) and spell a
# negative out (`badge-offset-x-minus0.15.png`), because a bare minus would give
# a double dash.
#
# ---- the base, and the four measured overrides -------------------------------
#
# The base is fixed so only the setting under test varies. Anything else in a
# command is an override, and there are four, each measured on 2026-08-18 rather
# than assumed:
#
#   * icon/badge-symbol-rendering uses cloud.sun.rain.fill. On star.fill,
#     hierarchical renders BYTE-IDENTICALLY to monochrome — one layer, so there is
#     no hierarchy to shade — and a four-mode strip would show three pictures and
#     claim four. Measured 2026-08-18: 0 and 0.000% between those two on
#     star.fill, and all six pairs distinct on the layered symbol.
#   * icon/badge-symbol-palette uses cloud.sun.rain.fill for the same reason: the
#     three slots only mean something over three layers. On star.fill the strip
#     would demonstrate "the primary colour", which is what symbol-color is for.
#   * badge-symbol-gradient and badge-fg-shadow use heart.fill at badge scale
#     2.0. Both act on the glyph inside the badge, which at the default size is
#     ~50px across: measured 0.17% and 0.18% of pixels changed, under the floor
#     and genuinely too small to see. The bigger filled glyph takes them to 3.9%
#     and 0.83%.
#
# The plan named symbol weight as an override case too. It is not: on star.fill,
# ultralight through black changes 7.6% of pixels and reads clearly side by side
# (thin sharp points versus fat rounded ones). Measured and eyeballed 2026-08-18.
# So weight stays on the base symbol.
#
# Badge images render at 512 and icon images at 256. The badge is about 38% of
# the enclosure, so its glyph at size 256 is mush; the size is not the setting
# under test in any badge entry, and an illegible image serves nobody.

set -u
set -o pipefail

# ---- configuration -----------------------------------------------------------

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly IMAGES_DIR="${PROJECT_ROOT}/wiki/images"
readonly VERIFIER="${PROJECT_ROOT}/scripts/docs/verify-wiki-examples.py"
# The app scheme, not mica-cli — see note 1 in the header.
readonly SCHEME="Mica"
readonly XCODE_PROJECT="${PROJECT_ROOT}/Mica.xcodeproj"

readonly ICON_SIZE=256
readonly BADGE_SIZE=512

# The symbol every example uses unless an override above applies.
readonly BASE_SYMBOL="star.fill"
# A layered symbol, for the rendering and palette strips.
readonly LAYERED_SYMBOL="cloud.sun.rain.fill"
# The badge's symbol for layout, colour and scale examples.
readonly BADGE_SYMBOL="plus"

CLI_BINARY=""
WORK_DIR=""
RECORDS=""
ARTWORK=""          # opaque, fills its own bounds — for background examples
LOGO=""             # transparent — for foreground examples
OS_MAJOR=0

EMITTED=0
RENDER_FAIL=0
SKIPPED_GROUPS=""

# ---- plumbing ----------------------------------------------------------------

die() {
    echo "ERROR: $*" >&2
    exit 2
}

build_cli() {
    if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
        echo "==> Skipping build (SKIP_BUILD=1)"
    else
        echo "==> Building ${SCHEME}..."
        # generic/platform=macOS, never platform=macOS: the latter matches both
        # arches of the host and silently picks one.
        if ! xcodebuild \
                -project "${XCODE_PROJECT}" \
                -scheme "${SCHEME}" \
                -configuration Debug \
                -destination 'generic/platform=macOS' \
                build -quiet 2>&1; then
            die "xcodebuild failed for scheme ${SCHEME}."
        fi
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
    [[ -n "${built_products_dir}" ]] \
        || die "could not resolve BUILT_PRODUCTS_DIR from xcodebuild."

    CLI_BINARY="${built_products_dir}/Mica.app/Contents/MacOS/mica-cli"
    [[ -x "${CLI_BINARY}" ]] \
        || die "embedded CLI binary not found or not executable: ${CLI_BINARY}"
    echo "==> CLI binary: ${CLI_BINARY}"
}

setup_run() {
    OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
    echo "==> macOS ${OS_MAJOR}.x"

    command -v python3 >/dev/null 2>&1 || die "python3 not found; the verifier needs it."
    [[ -f "${VERIFIER}" ]] || die "verifier not found: ${VERIFIER}"

    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wiki-examples.XXXXXX")" \
        || die "could not create a work directory."
    RECORDS="${WORK_DIR}/records.tsv"
    : > "${RECORDS}"

    mkdir -p "${IMAGES_DIR}" || die "could not create ${IMAGES_DIR}"

    if [[ "${KEEP_OLD:-0}" == "1" ]]; then
        echo "==> Keeping existing images (KEEP_OLD=1)"
    else
        # The images that were here were made by hand for the old pages, and
        # several are named for what they look like rather than which setting
        # they show (terminal-black.png, hierarchical-teal.png). Nothing in the
        # rewritten wiki references them.
        local old
        old="$(find "${IMAGES_DIR}" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
        if [[ "${old}" != "0" ]]; then
            echo "==> Deleting ${old} existing PNG(s) from wiki/images/"
            find "${IMAGES_DIR}" -maxdepth 1 -name '*.png' -delete
        fi
    fi
    echo "==> Output: ${IMAGES_DIR}"
}

# make_artwork
#
# Two source images, generated rather than committed, so this script needs no
# fixtures and ships no third-party artwork.
#
# ARTWORK must fill its own bounds, and that is not a detail: a Mica-rendered PNG
# has transparent corners, so clipping it at any corner radius changes nothing
# and both icon-bg-padding and the corner-radius setting read as inert over it.
# The crop is what removes the transparent margin. Same trick, same reason, as
# cli-smoke-test.sh's import section.
make_artwork() {
    echo "==> Generating source artwork"
    local raw="${WORK_DIR}/artwork-raw.png"
    ARTWORK="${IMAGES_DIR}/artwork-source.png"
    LOGO="${IMAGES_DIR}/artwork-logo.png"

    "${CLI_BINARY}" --icon-symbol swift --size 512 \
        --icon-bg custom-gradient --icon-bg-gradient-colors '#F05138,#FFB800' \
        --icon-bg-corner-radius off --icon-fg-scale 1.2 \
        -o "${raw}" -q >/dev/null 2>&1 \
        || die "could not render the artwork source."
    sips --cropToHeightWidth 400 400 "${raw}" --out "${ARTWORK}" >/dev/null 2>&1 \
        || die "sips could not crop the artwork source."

    "${CLI_BINARY}" --icon-symbol swift --size 512 \
        --icon-bg-visibility off --icon-symbol-color '#F05138' --icon-fg-scale 1.4 \
        -o "${LOGO}" -q >/dev/null 2>&1 \
        || die "could not render the logo source."

    # Both are shown on Use-Your-Own-Artwork, so they are records too.
    printf 'artwork\tsource\t%s\t%s\n' "${ARTWORK}" \
        "mica-cli --icon-symbol swift --icon-bg custom-gradient --icon-bg-gradient-colors '#F05138,#FFB800' --icon-bg-corner-radius off --icon-fg-scale 1.2 --size 512  (then cropped to 400x400)" \
        >> "${RECORDS}"
    printf 'artwork\tlogo\t%s\t%s\n' "${LOGO}" \
        "mica-cli --icon-symbol swift --icon-bg-visibility off --icon-symbol-color '#F05138' --icon-fg-scale 1.4 --size 512" \
        >> "${RECORDS}"
}

# emit <group> <slug> <args...>
#
# Renders wiki/images/<group>-<slug>.png with the given complete argument list,
# and records the group, the file and the user-facing command. The argument list
# is complete on purpose: the recorded command is then exactly what produced the
# image, with nothing implicit for a reader to reconstruct.
emit() {
    local group="$1"
    local slug="$2"
    shift 2

    local file="${IMAGES_DIR}/${group}-${slug}.png"

    if [[ -e "${file}" ]]; then
        die "two manifest entries want the same filename: ${group}-${slug}.png"
    fi

    if ! "${CLI_BINARY}" "$@" -o "${file}" -q >"${WORK_DIR}/render.log" 2>&1; then
        echo "  RENDER FAIL  ${group}-${slug}: $(head -2 "${WORK_DIR}/render.log" | tr '\n' ' ')" >&2
        RENDER_FAIL=$((RENDER_FAIL + 1))
        return 1
    fi

    # The command as a reader would type it: the tool's name, the temp artwork
    # paths as the filenames the wiki calls them, and no -o/-q plumbing.
    #
    # Values are quoted where a shell would otherwise eat them, and a hex colour
    # is the case that matters: '#FF6B35,#F7931E' unquoted starts a comment, so
    # the shell drops the gradient and everything after it. The command would
    # still run, and would render the default background — a wiki entry whose
    # command silently does not produce the image beside it.
    local pretty="mica-cli"
    local arg shown
    for arg in "$@"; do
        case "${arg}" in
            "${ARTWORK}") shown="artwork.png" ;;
            "${LOGO}")    shown="logo.png" ;;
            *)            shown="${arg}" ;;
        esac
        # Anything outside this set gets single-quoted. Commas and colons are
        # left bare: they are safe, and every palette value has them.
        case "${shown}" in
            *[^A-Za-z0-9._=,:/-]*) pretty="${pretty} '${shown}'" ;;
            *)                     pretty="${pretty} ${shown}" ;;
        esac
    done

    printf '%s\t%s\t%s\t%s\n' "${group}" "${slug}" "${file}" "${pretty}" >> "${RECORDS}"
    EMITTED=$((EMITTED + 1))
}

skip_group() {
    echo "  SKIP  $1 — $2"
    SKIPPED_GROUPS="${SKIPPED_GROUPS}${SKIPPED_GROUPS:+, }$1"
}

# ---- the manifest ------------------------------------------------------------

# Bases. Everything else in an emit call is the setting under test.
icon_base()  { echo "--icon-symbol ${BASE_SYMBOL} --size ${ICON_SIZE}"; }
badge_base() { echo "--icon-symbol ${BASE_SYMBOL} --badge-symbol ${BADGE_SYMBOL} --size ${BADGE_SIZE}"; }

generate_icon_foreground() {
    echo "==> Icon foreground"
    local -a B; read -r -a B <<< "$(icon_base)"

    # Two ways to name a foreground. --icon-symbol NAME is exact shorthand for
    # --icon-fg symbol:NAME, so the strip shows the source split instead: a
    # symbol, and an image.
    emit icon-fg symbol "${B[@]}"
    emit icon-fg image --icon-fg "${LOGO}" --size "${ICON_SIZE}"

    emit icon-fg-scale 0.5 "${B[@]}" --icon-fg-scale 0.5
    emit icon-fg-scale 1.0 "${B[@]}" --icon-fg-scale 1.0
    emit icon-fg-scale 1.5 "${B[@]}" --icon-fg-scale 1.5

    # Layered symbol: see the override note in the header.
    local -a L=(--icon-symbol "${LAYERED_SYMBOL}" --size "${ICON_SIZE}")
    emit icon-symbol-rendering monochrome   "${L[@]}" --icon-symbol-rendering monochrome
    emit icon-symbol-rendering hierarchical "${L[@]}" --icon-symbol-rendering hierarchical
    emit icon-symbol-rendering multicolor   "${L[@]}" --icon-symbol-rendering multicolor
    # Palette needs no colours of its own here, and that is new. The default
    # palette was white, white:0.5, white:0.26 until 2026-08-18 — one hue at three
    # opacities, which is exactly what hierarchical draws — so palette at its own
    # default rendered IDENTICALLY to hierarchical (maxdiff 4, 0.000% of pixels)
    # and this strip had to pass explicit colours to show four modes. The default
    # is red,green,yellow now, so the strip shows what choosing palette actually
    # gives you.
    emit icon-symbol-rendering palette      "${L[@]}" --icon-symbol-rendering palette

    emit icon-symbol-color white  "${B[@]}" --icon-symbol-color white
    emit icon-symbol-color black  "${B[@]}" --icon-symbol-color black
    emit icon-symbol-color yellow "${B[@]}" --icon-symbol-color yellow

    # Palette needs the rendering mode as well; the colours alone do nothing.
    # `default` passes no palette on purpose — it is what the setting looks like
    # untouched, which is the thing a reference entry has to show first.
    emit icon-symbol-palette default "${L[@]}" --icon-symbol-rendering palette
    emit icon-symbol-palette custom "${L[@]}" \
        --icon-symbol-rendering palette --icon-symbol-palette 'yellow,white,cyan'

    emit icon-symbol-weight ultralight "${B[@]}" --icon-symbol-weight ultralight
    emit icon-symbol-weight regular    "${B[@]}" --icon-symbol-weight regular
    emit icon-symbol-weight black      "${B[@]}" --icon-symbol-weight black

    if [[ "${OS_MAJOR}" -ge 26 ]]; then
        emit icon-symbol-gradient on  "${B[@]}" --icon-symbol-gradient on
        emit icon-symbol-gradient off "${B[@]}" --icon-symbol-gradient off
    else
        skip_group "icon-symbol-gradient" "needs macOS 26, this Mac is ${OS_MAJOR}"
    fi

    emit icon-fg-shadow on  "${B[@]}" --icon-fg-shadow on
    emit icon-fg-shadow off "${B[@]}" --icon-fg-shadow off
}

generate_icon_background() {
    echo "==> Icon background"
    local -a B; read -r -a B <<< "$(icon_base)"

    emit icon-bg standard        "${B[@]}" --icon-bg standard
    emit icon-bg custom-gradient "${B[@]}" --icon-bg custom-gradient \
        --icon-bg-gradient-colors '#FF6B35,#F7931E'
    emit icon-bg image           "${B[@]}" --icon-bg "${ARTWORK}"

    emit icon-bg-color blue "${B[@]}" --icon-bg-color blue
    emit icon-bg-color red  "${B[@]}" --icon-bg-color red
    emit icon-bg-color mint "${B[@]}" --icon-bg-color mint

    # Inert without --icon-bg custom-gradient: measured byte-identical to the
    # default without it. The gate is the background's source.
    emit icon-bg-gradient-colors sunset "${B[@]}" --icon-bg custom-gradient \
        --icon-bg-gradient-colors '#FF6B35,#F7931E'
    emit icon-bg-gradient-colors ocean "${B[@]}" --icon-bg custom-gradient \
        --icon-bg-gradient-colors '#2E86AB,#A23B72'

    emit icon-bg-gradient on  "${B[@]}" --icon-bg-gradient on
    emit icon-bg-gradient off "${B[@]}" --icon-bg-gradient off

    emit icon-bg-corner-radius off      "${B[@]}" --icon-bg-corner-radius off
    emit icon-bg-corner-radius macos15  "${B[@]}" --icon-bg-corner-radius macos15
    emit icon-bg-corner-radius macos26  "${B[@]}" --icon-bg-corner-radius macos26

    emit icon-bg-shadow off     "${B[@]}" --icon-bg-shadow off
    emit icon-bg-shadow macos15 "${B[@]}" --icon-bg-shadow macos15
    emit icon-bg-shadow macos26 "${B[@]}" --icon-bg-shadow macos26

    # Padding only means anything over an imported image.
    emit icon-bg-padding on  "${B[@]}" --icon-bg "${ARTWORK}" --icon-bg-padding on
    emit icon-bg-padding off "${B[@]}" --icon-bg "${ARTWORK}" --icon-bg-padding off
}

# The six visibility settings cannot be photographed one at a time usefully, so
# each page opens with one strip of four. The badge is in the icon strip so that
# "the whole group hidden" is a picture of something rather than an empty canvas
# that reads as a broken image.
generate_visibility() {
    echo "==> Visibility strips"
    # The symbol is black here, not the default white, and that is the difference
    # between a strip that works and one that reads as a broken image. Hide the
    # background and what is left is the symbol on transparency — and a white
    # symbol on transparency is invisible against the white page GitHub renders
    # the wiki on. The image would be correct and look blank.
    local -a IB=(--icon-symbol "${BASE_SYMBOL}" --badge-symbol "${BADGE_SYMBOL}"
                 --size "${ICON_SIZE}" --icon-symbol-color black)

    emit icon-visibility all-on    "${IB[@]}"
    emit icon-visibility fg-off    "${IB[@]}" --icon-fg-visibility off
    emit icon-visibility bg-off    "${IB[@]}" --icon-bg-visibility off
    emit icon-visibility group-off "${IB[@]}" --icon-visibility off

    local -a BB; read -r -a BB <<< "$(badge_base)"
    emit badge-visibility all-on    "${BB[@]}"
    emit badge-visibility fg-off    "${BB[@]}" --badge-fg-visibility off
    emit badge-visibility bg-off    "${BB[@]}" --badge-bg-visibility off
    emit badge-visibility group-off "${BB[@]}" --badge-visibility off
}

generate_badge_layout() {
    echo "==> Badge layout"
    local -a B; read -r -a B <<< "$(badge_base)"

    emit badge-position top-left     "${B[@]}" --badge-position top-left
    emit badge-position top-right    "${B[@]}" --badge-position top-right
    emit badge-position bottom-left  "${B[@]}" --badge-position bottom-left
    emit badge-position bottom-right "${B[@]}" --badge-position bottom-right

    emit badge-scale 0.7 "${B[@]}" --badge-scale 0.7
    emit badge-scale 1.0 "${B[@]}" --badge-scale 1.0
    emit badge-scale 1.4 "${B[@]}" --badge-scale 1.4

    # A negative value must be attached with '='. Given a space, ArgumentParser
    # reads -0.15 as another flag and fails before any transform runs.
    emit badge-offset-x minus0.15 "${B[@]}" --badge-offset-x=-0.15
    emit badge-offset-x 0         "${B[@]}" --badge-offset-x=0
    emit badge-offset-x 0.15      "${B[@]}" --badge-offset-x=0.15

    emit badge-offset-y minus0.15 "${B[@]}" --badge-offset-y=-0.15
    emit badge-offset-y 0         "${B[@]}" --badge-offset-y=0
    emit badge-offset-y 0.15      "${B[@]}" --badge-offset-y=0.15
}

generate_badge_foreground() {
    echo "==> Badge foreground"
    local -a B; read -r -a B <<< "$(badge_base)"

    # Both members carry a bigger badge, because an imported image inside a
    # default-size badge is ~50px across and unreadable. Scaling both keeps the
    # pair comparable.
    emit badge-fg symbol "${B[@]}" --badge-scale 2.0
    emit badge-fg image --icon-symbol "${BASE_SYMBOL}" --size "${BADGE_SIZE}" \
        --badge-fg "${LOGO}" --badge-scale 2.0

    emit badge-fg-scale 0.5 "${B[@]}" --badge-fg-scale 0.5
    emit badge-fg-scale 1.0 "${B[@]}" --badge-fg-scale 1.0
    emit badge-fg-scale 1.5 "${B[@]}" --badge-fg-scale 1.5

    # The layered symbol goes in the badge here, and the badge is scaled up so
    # its layers are legible at all.
    local -a L=(--icon-symbol "${BASE_SYMBOL}" --size "${BADGE_SIZE}"
                --badge-symbol "${LAYERED_SYMBOL}" --badge-scale 2.0)
    emit badge-symbol-rendering monochrome   "${L[@]}" --badge-symbol-rendering monochrome
    emit badge-symbol-rendering hierarchical "${L[@]}" --badge-symbol-rendering hierarchical
    emit badge-symbol-rendering multicolor   "${L[@]}" --badge-symbol-rendering multicolor
    # No colours of its own, same reason as the icon's.
    emit badge-symbol-rendering palette      "${L[@]}" --badge-symbol-rendering palette

    emit badge-symbol-color white  "${B[@]}" --badge-symbol-color white
    emit badge-symbol-color black  "${B[@]}" --badge-symbol-color black
    emit badge-symbol-color yellow "${B[@]}" --badge-symbol-color yellow

    emit badge-symbol-palette default "${L[@]}" --badge-symbol-rendering palette
    emit badge-symbol-palette custom "${L[@]}" \
        --badge-symbol-rendering palette --badge-symbol-palette 'yellow,white,cyan'

    emit badge-symbol-weight ultralight "${B[@]}" --badge-symbol-weight ultralight
    emit badge-symbol-weight regular    "${B[@]}" --badge-symbol-weight regular
    emit badge-symbol-weight black      "${B[@]}" --badge-symbol-weight black

    # Both of these act on the glyph inside the badge, and need a big filled one
    # to be visible at all — see the override note in the header.
    local -a G=(--icon-symbol "${BASE_SYMBOL}" --size "${BADGE_SIZE}"
                --badge-symbol heart.fill --badge-scale 2.0)
    if [[ "${OS_MAJOR}" -ge 26 ]]; then
        emit badge-symbol-gradient on  "${G[@]}" --badge-symbol-gradient on
        emit badge-symbol-gradient off "${G[@]}" --badge-symbol-gradient off
    else
        skip_group "badge-symbol-gradient" "needs macOS 26, this Mac is ${OS_MAJOR}"
    fi

    emit badge-fg-shadow on  "${G[@]}" --badge-fg-shadow on
    emit badge-fg-shadow off "${G[@]}" --badge-fg-shadow off
}

generate_badge_background() {
    echo "==> Badge background"
    local -a B; read -r -a B <<< "$(badge_base)"

    emit badge-bg standard        "${B[@]}" --badge-bg standard
    emit badge-bg custom-gradient "${B[@]}" --badge-bg custom-gradient \
        --badge-bg-gradient-colors '#FF6B35,#F7931E'
    emit badge-bg image           "${B[@]}" --badge-bg "${ARTWORK}"

    # gray is the Mica-mode default; blue is what System mode uses.
    emit badge-bg-color gray "${B[@]}" --badge-bg-color gray
    emit badge-bg-color blue "${B[@]}" --badge-bg-color blue
    emit badge-bg-color red  "${B[@]}" --badge-bg-color red

    emit badge-bg-gradient-colors sunset "${B[@]}" --badge-bg custom-gradient \
        --badge-bg-gradient-colors '#FF6B35,#F7931E'
    emit badge-bg-gradient-colors ocean "${B[@]}" --badge-bg custom-gradient \
        --badge-bg-gradient-colors '#2E86AB,#A23B72'

    emit badge-bg-gradient on  "${B[@]}" --badge-bg-gradient on
    emit badge-bg-gradient off "${B[@]}" --badge-bg-gradient off

    # on|off, not the icon's off|macos15|macos26. The badge has no era styles.
    emit badge-bg-shadow on  "${B[@]}" --badge-bg-shadow on
    emit badge-bg-shadow off "${B[@]}" --badge-bg-shadow off

    emit badge-bg-padding on  "${B[@]}" --badge-bg "${ARTWORK}" --badge-bg-padding on
    emit badge-bg-padding off "${B[@]}" --badge-bg "${ARTWORK}" --badge-bg-padding off
}

generate_generation_modes() {
    echo "==> Generation modes"
    if [[ "${OS_MAJOR}" -lt 26 ]]; then
        skip_group "icon-generation-mode" "System mode needs macOS 26, this Mac is ${OS_MAJOR}"
        return
    fi

    local -a B=(--icon-symbol "${BASE_SYMBOL}" --size "${ICON_SIZE}"
                --icon-bg-color blue --icon-symbol-color white)
    emit icon-generation-mode mica   "${B[@]}" --icon-generation-mode mica
    emit icon-generation-mode system "${B[@]}" --icon-generation-mode system
}

# ---- verification ------------------------------------------------------------

# verify_system_mode
#
# IconServices silently discards a colour value it does not recognise and draws
# its own fallback tile at 248,247,247 — indistinguishable from `white`. It does
# the same thing when the render is blocked, which is what happens inside the
# Bash tool sandbox. Either way the render "succeeds" and returns a plausible
# picture, so no assertion on the System-mode image alone can tell.
#
# The check is differential: ask for two different background colours and require
# the results to differ. A fallback tile ignores both and comes back twice.
verify_system_mode() {
    local system_image="${IMAGES_DIR}/icon-generation-mode-system.png"
    [[ -f "${system_image}" ]] || return 0

    echo "==> Checking System mode did not fall back to a plain tile"
    local probe="${WORK_DIR}/system-probe-red.png"
    "${CLI_BINARY}" --icon-symbol "${BASE_SYMBOL}" --size "${ICON_SIZE}" \
        --icon-generation-mode system --icon-bg-color red --icon-symbol-color white \
        -o "${probe}" -q >/dev/null 2>&1 \
        || die "the System-mode probe render failed outright."

    local probe_records="${WORK_DIR}/system-probe.tsv"
    printf 'system-mode-fallback-probe\tblue\t%s\t-\n' "${system_image}"  > "${probe_records}"
    printf 'system-mode-fallback-probe\tred\t%s\t-\n'  "${probe}"        >> "${probe_records}"

    if ! python3 "${VERIFIER}" "${probe_records}" --quiet >/dev/null 2>&1; then
        echo "" >&2
        echo "ERROR: System mode rendered the same picture for a blue and a red" >&2
        echo "       background. IconServices ignored both and drew its fallback" >&2
        echo "       tile, so icon-generation-mode-system.png is not a System-mode" >&2
        echo "       icon." >&2
        echo "" >&2
        echo "       If you are running this through a tool sandbox, IconServices" >&2
        echo "       is blocked. Re-run with the sandbox disabled." >&2
        return 1
    fi
    echo "  ok    a blue and a red System-mode render differ"
    return 0
}

write_manifest() {
    local manifest="${IMAGES_DIR}/MANIFEST.md"
    echo "==> Writing $(basename "${manifest}")"

    {
        echo "# Wiki example images"
        echo ""
        echo "Generated by \`scripts/docs/generate-wiki-examples.sh\`."
        echo "**Do not edit these images or this file by hand.** Re-run the script."
        echo ""
        echo "Every reference entry in the settings pages quotes the command that"
        echo "produced its image. Copy it from the table below rather than writing"
        echo "one, so the page and the picture cannot disagree."
        echo ""
        echo "\`artwork.png\` in a command is \`artwork-source.png\` here, and"
        echo "\`logo.png\` is \`artwork-logo.png\`. Both are generated too."
        echo ""
        echo "| Image | Group | Value | Command |"
        echo "|---|---|---|---|"
        # Sorted by group, then kept in emit order within it, so a writer reads
        # the table in the same order the pages are written.
        local group slug file command
        while IFS=$'\t' read -r group slug file command; do
            printf '| `%s` | `%s` | `%s` | `%s` |\n' \
                "$(basename "${file}")" "${group}" "${slug}" "${command}"
        done < "${RECORDS}"
    } > "${manifest}"
}

print_summary() {
    local png_count
    png_count="$(find "${IMAGES_DIR}" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"

    echo ""
    echo "================================================================"
    echo "Images emitted:   ${EMITTED}"
    echo "PNGs on disk:     ${png_count}"
    echo "Render failures:  ${RENDER_FAIL}"
    if [[ -n "${SKIPPED_GROUPS}" ]]; then
        echo "Skipped groups:   ${SKIPPED_GROUPS}"
    fi
    echo "Output:           wiki/images/"
    echo "================================================================"
}

# ---- main --------------------------------------------------------------------

main() {
    case "${1:-}" in
        -h|--help)
            sed -n '2,60p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
    esac

    build_cli
    setup_run
    make_artwork

    generate_icon_foreground
    generate_icon_background
    generate_visibility
    generate_badge_layout
    generate_badge_foreground
    generate_badge_background
    generate_generation_modes

    write_manifest

    local failed=0
    [[ "${RENDER_FAIL}" -eq 0 ]] || failed=1

    echo ""
    echo "==> Verifying every group is present and visibly distinct"
    python3 "${VERIFIER}" "${RECORDS}" || failed=1

    verify_system_mode || failed=1

    print_summary

    if [[ "${failed}" -ne 0 ]]; then
        echo ""
        echo "FAIL: see the errors above." >&2
        exit 1
    fi

    rm -rf "${WORK_DIR}"
    echo ""
    echo "PASS."
}

main "$@"
