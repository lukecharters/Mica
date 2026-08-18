# Extract App Icons

Export the icon that macOS assigns to an app, file, or folder.

## Extract one app

```shell
mkdir -p extracted-icons
mica-cli extract /Applications/Safari.app --output extracted-icons
```

**Result:** `extracted-icons/Safari.png` contains Safari's assigned icon.

## Extract a whole directory

```shell
mkdir -p extracted-icons
mica-cli extract /Applications \
  --output extracted-icons \
  --recursive \
  --quiet
```

This command processes direct children.

## Limit recursion depth

```shell
mkdir -p extracted-icons
mica-cli extract /Applications \
  --output extracted-icons \
  --recursive \
  --depth 2 \
  --size 256 \
  --quiet
```

Depth `0` includes direct children only.
Each larger value includes one more nested level.

## Parse extraction results

```shell
mkdir -p extracted-icons
mica-cli extract /Applications/Notes.app \
  --output extracted-icons \
  --json |
  plutil -extract outputs.0.path raw -o - -
```

**Result:** `plutil` prints the saved PNG path.

macOS supplies extracted pixels in Extended sRGB without an embedded profile.
Mica tags the exported PNG with your chosen colour space.

## Change the result

- [CLI Reference](CLI-Reference#extract) lists every extraction option.
- [Use Your Own Artwork](Use-Your-Own-Artwork) reuses an extracted icon.
