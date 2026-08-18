# Getting Started

This tutorial installs Mica and creates three useful PNG files.

## 1. Install Mica

Download the latest `.pkg` from the [Releases page](https://github.com/lukecharters/Mica/releases).
Open the package and complete the installer.

The package installs Mica in `/Applications`.
It also adds `mica-cli` to your command path.

Open Terminal and check the command.

```shell
mica-cli --version
```

**Result:** Terminal prints the installed Mica version.

## 2. Make your first icon in the app

Open Mica from the Applications folder.
Select **Icon** in the left sidebar.
Click the grid button beside **Symbol**.
Search for `star.fill`.
Select the symbol and press **Select**.

<!-- Phase 5 adds window-anatomy.png and symbol-browser.png here. -->

**Result:** The preview shows a white star on a blue background.

## 3. Export the icon

Press **⇧⌘E**.
Choose the Desktop.
Set the name to `mica-star.png`.
Press **Export**.

<!-- Phase 5 adds window-anatomy.png here. -->

**Result:** Your Desktop contains a 512 by 512 PNG.

## 4. Make the same icon from Terminal

Run this command.

```shell
mica-cli --icon-symbol star.fill --output ~/Desktop/mica-star-cli.png
```

**Result:** Your Desktop contains `mica-star-cli.png`.
It matches the icon you made in the app.

## 5. Extract an existing app icon

Run this command.

```shell
mica-cli extract /Applications/Safari.app --output ~/Desktop
```

**Result:** Your Desktop contains `Safari.png`.

## Next

- [Make Icons For Self Service](Make-Icons-For-Self-Service)
- [Reuse Settings With Config Files](Reuse-Settings-With-Config-Files)
- [Settings Index](Settings-Index)
