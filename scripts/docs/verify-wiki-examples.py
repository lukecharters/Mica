#!/usr/bin/env python3
"""Verify the wiki example images produced by generate-wiki-examples.sh.

Reads the records TSV the generator writes (group, slug, file, command) and
answers the one question a file listing cannot: **does each image actually show
the setting it claims to show?**

A missing image is obvious. An image that renders but is identical to its
sibling is not, and it is the failure that matters here: the writer builds an
entry around "left is `on`, right is `off`", and if the two renders are the same
picture the page documents a difference the software does not produce. That
happens for real, in three ways this catches:

  * A setting is inert without a companion flag. `--icon-bg-gradient-colors`
    alone is byte-identical to the default: it needs `--icon-bg custom-gradient`.
  * A setting has no visible effect on the chosen symbol. Rendering mode is the
    same picture four times on `star.fill`, which has one layer.
  * System mode silently fell back. IconServices discards a value it does not
    recognise and draws its own tile, so the render succeeds and is plausible.

So every group is checked pairwise, and a group whose members are too similar
fails the run.

Two metrics, because one is not enough. Mean difference over the whole image is
useless here: a shadow changes a few hundred pixels a lot, and averaging over
65,536 hides it. So:

  maxdiff  largest per-channel absolute difference, 0-255
  changed  percentage of pixels where any channel differs by more than 8

Both must clear their floor. Calibrated against the real renders on 2026-08-18:
the weakest genuine difference in the manifest is `badge-fg-shadow` at 20 and
0.83%, and the strongest false one an inert render at 0 and 0.000%. The floors
sit between, nearer the false end.
"""

import argparse
import sys
from collections import OrderedDict

try:
    from PIL import Image, ImageChops
except ImportError:
    sys.stderr.write(
        "ERROR: this needs Pillow.\n"
        "       python3 -m pip install --user Pillow\n"
    )
    sys.exit(2)

# Calibrated floors — see the module docstring.
DEFAULT_MIN_MAXDIFF = 16
DEFAULT_MIN_CHANGED = 0.25

# A pixel counts as changed when a channel moves by more than this. Above the
# noise the renderer produces between runs, below any difference a reader sees.
CHANGED_CHANNEL_THRESHOLD = 8


def load(path):
    """Open a PNG as RGBA. Alpha matters: a shadow is mostly an alpha change."""
    return Image.open(path).convert("RGBA")


def compare(image_a, image_b):
    """Return (maxdiff, percentage of pixels changed) between two RGBA images."""
    if image_a.size != image_b.size:
        # Different sizes are a generator bug, not a subtle-difference result.
        return 255, 100.0

    diff = ImageChops.difference(image_a, image_b)
    bands = diff.split()
    maxdiff = max(band.getextrema()[1] for band in bands)

    # Per-pixel maximum across the four channels, then a histogram of it. This
    # is why the whole comparison is one pass of C rather than a Python loop
    # over a quarter of a million pixels.
    merged = bands[0]
    for band in bands[1:]:
        merged = ImageChops.lighter(merged, band)

    histogram = merged.histogram()
    changed = sum(histogram[CHANGED_CHANNEL_THRESHOLD + 1:])
    total = image_a.size[0] * image_a.size[1]
    return maxdiff, 100.0 * changed / total


def read_records(path):
    """Parse the generator's TSV into {group: [(slug, file), ...]}, in order."""
    groups = OrderedDict()
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, start=1):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) < 3:
                raise SystemExit(
                    "ERROR: %s line %d: expected at least 3 tab-separated "
                    "fields, got %d" % (path, number, len(fields))
                )
            group, slug, filename = fields[0], fields[1], fields[2]
            groups.setdefault(group, []).append((slug, filename))
    return groups


def main():
    parser = argparse.ArgumentParser(
        description="Verify wiki example images are present and visibly distinct."
    )
    parser.add_argument("records", help="TSV written by generate-wiki-examples.sh")
    parser.add_argument("--min-maxdiff", type=int, default=DEFAULT_MIN_MAXDIFF)
    parser.add_argument("--min-changed", type=float, default=DEFAULT_MIN_CHANGED)
    parser.add_argument(
        "--quiet", action="store_true",
        help="print only groups that fail, plus the summary",
    )
    args = parser.parse_args()

    groups = read_records(args.records)

    missing = []
    unreadable = []
    too_similar = []
    checked_pairs = 0

    for group, members in groups.items():
        images = OrderedDict()
        for slug, filename in members:
            try:
                images[slug] = load(filename)
            except FileNotFoundError:
                missing.append(filename)
            except Exception as error:                  # noqa: BLE001
                unreadable.append("%s (%s)" % (filename, error))

        if len(images) < 2:
            # Nothing to compare. A single-image group is a source fixture.
            if not args.quiet and images:
                slug, image = next(iter(images.items()))
                print("  --   %-34s %s  %dx%d"
                      % (group, slug, image.size[0], image.size[1]))
            continue

        slugs = list(images.keys())
        weakest = None
        for i in range(len(slugs)):
            for j in range(i + 1, len(slugs)):
                checked_pairs += 1
                maxdiff, changed = compare(images[slugs[i]], images[slugs[j]])
                passes = (maxdiff >= args.min_maxdiff
                          and changed >= args.min_changed)
                if not passes:
                    too_similar.append(
                        "%s: %s vs %s (maxdiff %d, changed %.3f%%)"
                        % (group, slugs[i], slugs[j], maxdiff, changed)
                    )
                if weakest is None or changed < weakest[2]:
                    weakest = (slugs[i], slugs[j], changed, maxdiff)

        failed = any(entry.startswith(group + ":") for entry in too_similar)
        if failed or not args.quiet:
            mark = "FAIL" if failed else "ok"
            print("  %-4s %-34s %d images, weakest pair %s/%s "
                  "(maxdiff %d, changed %.3f%%)"
                  % (mark, group, len(images), weakest[0], weakest[1],
                     weakest[3], weakest[2]))

    print("")
    print("Groups: %d    Images: %d    Pairs compared: %d"
          % (len(groups), sum(len(v) for v in groups.values()), checked_pairs))
    print("Floors: maxdiff >= %d, changed >= %.2f%%"
          % (args.min_maxdiff, args.min_changed))

    problems = 0

    if missing:
        problems += len(missing)
        print("")
        print("MISSING (%d):" % len(missing))
        for entry in missing:
            print("  %s" % entry)

    if unreadable:
        problems += len(unreadable)
        print("")
        print("UNREADABLE (%d):" % len(unreadable))
        for entry in unreadable:
            print("  %s" % entry)

    if too_similar:
        problems += len(too_similar)
        print("")
        print("TOO SIMILAR (%d) — these entries would document a difference "
              "the render does not produce:" % len(too_similar))
        for entry in too_similar:
            print("  %s" % entry)
        print("")
        print("  Fix the manifest, not the floors. Either the setting needs a")
        print("  companion flag to take effect, or it needs a symbol, size or")
        print("  badge scale that shows it. Lowering the floor here would let a")
        print("  page claim a difference a reader cannot see.")

    if problems:
        print("")
        print("FAIL: %d problem(s)." % problems)
        return 1

    print("")
    print("PASS: every image is present, readable and visibly distinct from "
          "its siblings.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
