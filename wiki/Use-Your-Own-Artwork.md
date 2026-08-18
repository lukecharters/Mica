# Use Your Own Artwork

Use a PNG as a foreground, background, or complete app icon.

Put a file named `company-logo.png` on your Desktop before running these commands.

## Use the logo as the foreground

```shell
mica-cli --icon-fg ~/Desktop/company-logo.png \
  --icon-bg-color blue \
  --output ~/Desktop/logo-foreground.png
```

**Result:** The logo appears over Mica's blue background.

## Use artwork as the background

```shell
mica-cli --icon-bg ~/Desktop/company-logo.png \
  --output ~/Desktop/logo-background.png
```

**Result:** The artwork fills the icon.
Importing a background hides the foreground by default.

Add a symbol when you want both layers.

```shell
mica-cli --icon-bg ~/Desktop/company-logo.png \
  --icon-symbol lock.fill \
  --icon-symbol-color white \
  --output ~/Desktop/logo-with-symbol.png
```

## Keep an extracted icon's padding

```shell
mkdir -p ~/Desktop/extracted-icons
mica-cli extract /Applications/Safari.app --output ~/Desktop/extracted-icons
mica-cli --icon-bg ~/Desktop/extracted-icons/Safari.png \
  --icon-bg-padding on \
  --output ~/Desktop/safari-reused.png
```

**Result:** The extracted icon keeps its native space and shadow.

## Change the result

- [Background Type](Icon-Settings#background-type) explains the foreground visibility rules.
- [Background Padding](Icon-Settings#background-padding) compares filled and padded artwork.
- [Extract App Icons](Extract-App-Icons) covers bulk extraction.
