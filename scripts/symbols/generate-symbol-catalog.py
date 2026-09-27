#!/usr/bin/env python3
"""Generate Mica/Resources/symbol-catalog.json from the SF Symbols app and the system.

The catalog records, for every current SF Symbol name: the macOS version it first
appeared in, the macOS version of each extra rendering mode, and every older name
(alias) that draws the same glyph, with the macOS version of that name. It lets Mica
pick the spelling that works on the running macOS.

Sources, all read from this Mac:

  sfsymbols CLI           current names, per-mode availability
                          (SF Symbols.app/Contents/Executables/sfsymbols)
  name_availability.plist release year of every name, current and old
                          (SF Symbols.app/Contents/Resources/Metadata)
  name_aliases.strings    old name -> current name; the app's copy and the
                          system's CoreGlyphs.bundle copy, merged
  gallery order           the app's "Copy N Names" output, pasted into a text
                          file; the only source of the order the gallery shows

Regenerating after an SF Symbols release:

  1. In SF Symbols.app, select All, select every symbol, Edit > Copy N Names,
     and paste into .local/sf-symbols-app/gallery-order.txt
  2. scripts/symbols/generate-symbol-catalog.py
  3. swift scripts/symbols/verify-symbol-catalog.swift

Names in the CLI output that the gallery does not show go under "retired": they
still resolve, but the picker does not offer them. Localised variants (.ar, .hi,
.rtl ...) are left out; the app accepts them through NSImage.

The run fails, writing nothing, on any inconsistency between the sources.
"""

import argparse
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
APP = Path("/Applications/SF Symbols.app")
CLI = APP / "Contents/Executables/sfsymbols"
METADATA = APP / "Contents/Resources/Metadata"
CORE_GLYPHS = Path(
    "/System/Library/PrivateFrameworks/SFSymbols.framework/Versions/A/Resources/"
    "CoreGlyphs.bundle/Contents/Resources"
)
DEFAULT_ORDER = REPO / ".local/sf-symbols-app/gallery-order.txt"
DEFAULT_OUTPUT = REPO / "Mica/Resources/symbol-catalog.json"

FORMAT_VERSION = 1
EXTRA_MODES = ("hierarchical", "palette", "multicolor")
# NSImage(systemSymbolName:) is macOS 11 API; the CLI reports 2019 symbols as 11.0.
MACOS_FLOOR = (11, 0)
HEX_ID = re.compile(r"^[0-9A-F]{32}(\.|$)")


class CatalogError(Exception):
    pass


def version(text):
    return tuple(int(part) for part in text.split("."))


def version_text(parts):
    return ".".join(str(part) for part in parts)


def read_plist(path):
    with open(path, "rb") as handle:
        return plistlib.load(handle)


def read_strings(path):
    result = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(path)],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


def run_cli(cli):
    result = subprocess.run(
        [str(cli), "search", "--limit", "0", "--json", ""],
        capture_output=True, text=True, check=True,
    )
    records = json.loads(result.stdout)
    return [r for r in records if not r["name"].startswith("custom.")]


def read_order(path):
    names = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    duplicates = sorted({n for n in names if names.count(n) > 1})
    if duplicates:
        raise CatalogError(f"gallery order repeats names: {duplicates[:10]}")
    return names


def macos_for_year(year, year_to_release):
    release = year_to_release.get(year)
    if release is None or "macOS" not in release:
        raise CatalogError(f"year_to_release has no macOS for {year!r}")
    return max(version(release["macOS"]), MACOS_FLOOR)


def is_localised(name, known):
    parts = name.split(".")
    return any(".".join(parts[:i]) in known for i in range(len(parts) - 1, 0, -1))


def build(records, order, availability, aliases):
    by_name = {r["name"]: r for r in records}
    year_to_release = availability["year_to_release"]
    years = availability["symbols"]

    missing = [n for n in order if n not in by_name]
    if missing:
        raise CatalogError(f"{len(missing)} gallery names are not in the CLI output: {missing[:10]}")

    entries = {}
    for name, record in by_name.items():
        modes = record.get("availability", {})
        mono = modes.get("monochrome", {}).get("macOS")
        if mono is None:
            raise CatalogError(f"{name} has no monochrome macOS version")
        entry = {"name": name, "macOS": version_text(max(version(mono), MACOS_FLOOR))}
        extra = {m: modes[m]["macOS"] for m in EXTRA_MODES if "macOS" in modes.get(m, {})}
        if extra:
            entry["modes"] = extra
        entry["aliases"] = []
        entries[name] = entry

    known = set(entries) | set(aliases)
    skipped = {"hex": 0, "localised": 0}
    for old, current in aliases.items():
        if HEX_ID.match(old):
            skipped["hex"] += 1
            continue
        if old in entries:
            raise CatalogError(f"alias {old} -> {current} shadows a current name")
        if current in aliases:
            raise CatalogError(f"alias chain {old} -> {current} -> {aliases[current]}")
        if current not in entries:
            if is_localised(current, known):
                skipped["localised"] += 1
                continue
            raise CatalogError(f"alias {old} -> {current}: target is not a current name")
        alias = {"name": old}
        if old in years:
            alias_version = macos_for_year(years[old], year_to_release)
            if alias_version > version(entries[current]["macOS"]):
                raise CatalogError(f"alias {old} is newer than {current}")
            alias["macOS"] = version_text(alias_version)
        entries[current]["aliases"].append(alias)

    for entry in entries.values():
        entry["aliases"].sort(key=lambda a: (version(a.get("macOS", "0")), a["name"]))
        if not entry["aliases"]:
            del entry["aliases"]

    gallery = set(order)
    symbols = [entries[n] for n in order]
    retired = [entries[n] for n in sorted(entries) if n not in gallery]
    return symbols, retired, skipped


def render(symbols, retired, generated_from):
    def lines(items):
        return ",\n".join("    " + json.dumps(item, ensure_ascii=False) for item in items)

    return (
        "{\n"
        f'  "formatVersion": {FORMAT_VERSION},\n'
        f'  "generatedFrom": {json.dumps(generated_from)},\n'
        '  "symbols": [\n' + lines(symbols) + "\n  ],\n"
        '  "retired": [\n' + lines(retired) + "\n  ]\n"
        "}\n"
    )


def macos_description():
    def sw_vers(flag):
        return subprocess.run(["sw_vers", flag], capture_output=True, text=True, check=True).stdout.strip()
    return f"{sw_vers('-productVersion')} ({sw_vers('-buildVersion')})"


def app_description(app):
    info = read_plist(app / "Contents/Info.plist")
    return f"{info['CFBundleShortVersionString']} ({info['CFBundleVersion']})"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--order", type=Path, default=DEFAULT_ORDER)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    try:
        if not args.order.exists():
            raise CatalogError(f"{args.order} not found; see step 1 of this script's docstring")
        availability = read_plist(METADATA / "name_availability.plist")
        aliases = {**read_strings(METADATA / "name_aliases.strings"),
                   **read_strings(CORE_GLYPHS / "name_aliases.strings")}
        symbols, retired, skipped = build(run_cli(CLI), read_order(args.order), availability, aliases)
    except (CatalogError, OSError, subprocess.CalledProcessError, plistlib.InvalidFileException) as error:
        print(f"generate-symbol-catalog: {error}", file=sys.stderr)
        return 1

    generated_from = {"macOS": macos_description(), "sfSymbolsApp": app_description(APP)}
    args.output.write_text(render(symbols, retired, generated_from))

    alias_count = sum(len(e.get("aliases", [])) for e in symbols + retired)
    print(f"{args.output.relative_to(REPO)}: {len(symbols)} symbols, {len(retired)} retired, "
          f"{alias_count} aliases (skipped {skipped['localised']} localised, {skipped['hex']} hex-ID)")
    if retired:
        print("retired: " + ", ".join(e["name"] for e in retired))
    return 0


if __name__ == "__main__":
    sys.exit(main())
