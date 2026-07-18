# Extracting Icons

Mica can pull the icon out of any app, file, or folder on disk and save it as a PNG — handy for populating a self-service catalogue, and for refreshing it every time Apple restyles their icons.

## In the app

Drag an app (or any file) into the Mica window. Its icon is imported as the icon background, where you can:

- toggle **Icon Padding** to keep the native macOS icon padding and shadow, or fill the frame;
- add the missing padding and drop shadow to flat third-party icons so they sit consistently next to native ones;
- export at any size with **⌘E**.

Dropping an **image file** (PNG, JPEG, and so on) imports the image itself rather than its file icon.

## In the CLI: `mica-cli extract`

```shell
mica-cli extract <path> [options]
```

The extracted icon of `<path>` is saved as `<name>.png` in the working directory (or the directory given with `-o`).

### Single items

```shell
# One app's icon into the working directory
mica-cli extract /Applications/Safari.app

# Into a specific directory, at 2x resolution
mica-cli extract /System/Applications/Calculator.app -o ~/Desktop/icons --scale 2x
```

### Bulk extraction

Point `extract` at a directory with `--recursive` to export the icon of everything inside it:

```shell
# Every item in /Applications (one level deep)
mica-cli extract /Applications -o ~/Desktop/icons --recursive

# Recurse into nested folders up to two levels, 256 px output
mica-cli extract ~/Projects -o ~/icons --recursive --depth 2 --size 256
```

`--depth` controls how far into nested directories to go: `0` includes only direct children; each increment descends one level further. `--depth` requires `--recursive`.

### Options

| Flag | Description | Default |
|---|---|---|
| `-o, --output <path>` | Destination directory for the exported PNGs | working directory |
| `-s, --size <pixels>` | Icon size in pixels | 512 |
| `--scale <1x\|2x>` | Output resolution | `1x` |
| `-r, --recursive` | Process directory contents | off |
| `--depth <n>` | Maximum nested depth when the input is a directory (`0` = direct children only) | — |
| `--color-space <space>` (alias `--colour-space`) | `sRGB` or `displayP3` | `sRGB` |
| `--json` | Emit a JSON result object to stdout | off |
| `-q, --quiet` | Only errors on stderr; saved paths still print to stdout | off |
| `-v, --verbose` | Per-item progress on stderr | off |

### Scripting

Saved paths go to **stdout**, diagnostics go to **stderr**, so `extract` pipes cleanly:

```shell
# Collect the saved paths
mica-cli extract /Applications -o ~/icons --recursive --quiet | while read -r icon; do
  echo "exported: $icon"
done

# Machine-readable results
mica-cli extract /Applications/Notes.app --json | jq
```

### A note on colour spaces

macOS renders extracted icons without an embedded colour profile, so `extract` defaults to tagging output as sRGB — the safe choice for web and MDM portals. Use `--color-space displayP3` only if your workflow specifically needs it.
