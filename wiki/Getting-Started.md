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
Search for `star`.
Select **star.fill** and press **Select**.

<img src="images/symbol-browser.png" width="700" alt="The symbol browser filtered by a search for star">

**Result:** The preview shows a white star on a blue background.

## 3. Export the icon

Press **⇧⌘E**.
Choose the Desktop.
Set the name to `mica-star.png`.
Press **Export**.

<img src="images/window-anatomy.png" width="900" alt="The Mica window with the sidebar, canvas, and inspector labelled">

Your icon is on the canvas in the middle pane.

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
