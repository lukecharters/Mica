# Getting Started

## Install

<!-- TODO: replace OWNER/REPO with the real GitHub path once the repo is published -->
Download the latest `.pkg` or `.dmg` from the [Releases page](https://github.com/OWNER/REPO/releases).

- The **`.pkg`** installs `Mica.app` into `/Applications` and symlinks the bundled CLI to `/usr/local/bin/mica-cli`, so `mica-cli` works in your terminal straight away.
- The **`.dmg`** is just the app — drag `Mica.app` to `/Applications`. If you want the CLI on your `PATH` too:

```shell
sudo ln -s /Applications/Mica.app/Contents/MacOS/mica-cli /usr/local/bin/mica-cli
```

Mica requires **macOS 15 Sequoia or later**. System generation mode (Liquid Glass icons) and gradient symbol rendering require **macOS 26 Tahoe or later**.

## Your first icon (app)

<!-- SCREENSHOT PLACEHOLDER — the default window on first launch
<img src="images/screenshot-first-launch.png" alt="Mica on first launch" width="700">
-->

1. Launch Mica. You'll see a three-pane window: the **layer sidebar** on the left, the **preview** in the middle, and the **inspector** on the right.
2. With **Icon** selected in the sidebar, click the grid button next to the Symbol field in the inspector to open the **SF Symbols browser**, search for a symbol (say `star.fill`), and click it.
3. Pick a colour from the **Background Color** dropdown.
4. Press **⌘E**, choose where to save, and you have a PNG.

That's the whole loop. From here, explore:

- Flick on **Show Advanced Controls** (bottom of the inspector) to split each group into Foreground and Background layers and reveal imported images, rendering modes, symbol weights, corner styles, and more.
- Use the **preview size menu** in the toolbar to see your icon at the exact size it will appear in Jamf Self Service.
- Turn on the **Badge** layer to overlay a second symbol — see the [App Guide](App-Guide#badge).

## Your first icon (CLI)

```shell
# A star on the default blue gradient, saved as star.fill.png in the working directory
mica-cli star.fill

# Somewhere specific, bigger, red
mica-cli star.fill -o ~/Desktop/star.png --size 1024 --icon-bg-color red
```

The CLI and the app share the same rendering engine — identical settings produce identical pixels. See the [CLI Guide](CLI-Guide) for more.

## Your first extraction

Need an existing app's icon as a PNG?

```shell
mica-cli extract /Applications/Safari.app
```

Or drag the app into the Mica window to import its icon and add padding and a drop shadow before exporting. See [Extracting Icons](Extracting-Icons).

## Where next

- [App Guide](App-Guide) — every control explained
- [CLI Guide](CLI-Guide) — scripted and batch generation
- [CLI Reference](CLI-Reference) — every flag
