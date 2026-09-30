# Home — a reading-focused home screen for KOReader

`home.koplugin` replaces KOReader's default file-browser landing view with a curated reading dashboard. Instead of a list of files, you're greeted by a large "hero" cover of the book you were last reading, a grid of your other recent titles, and a compact status bar — all designed to get you back into a book with a single tap.

> _A reading-focused home screen with a hero cover for your latest book and a Library grid of your books._

![Home screen screenshot](screenshot.png)

---

## Features

- **Continue reading** — A large cover of your last-read book, with its title, author, description, and reading progress. Tap it to jump straight back in.
- **Personal greeting** — A greeting line at the top of the screen that reveals itself with a subtle typewriter animation when Home appears. You can change the text, font, or turn the animation off entirely.
- **Library** — Your other books and subfolders in the current folder, shown as cover cards with progress and titles. Sort and filter with the same options as the file browser.
- **Browse folders in place** — Tap a subfolder to open it inside Home, swipe left or right to page through the grid, and swipe up to go back to the parent folder — all without leaving Home.
- **Your home folder is the source** — Home uses the root folder you've configured in KOReader as your library, and displays the books inside it. Set that folder to wherever your books live, and Home will show them.
- **Status bar & quick panel** — A top bar with the clock, Wi-Fi status, and battery. Tap the icons on the right to open a quick control panel where you can see the battery level, toggle Wi-Fi or open network info, and adjust brightness.
- **Set as your start screen** — Make Home the first thing you see when KOReader launches, or toggle to it any time from the menu or a gesture.

---

## How it works

Home is drawn on top of a live FileManager instead of replacing it, so all of KOReader's native menus, gestures, and plugins keep working underneath. It reads the books from your configured home (root) folder, highlights the one you were last reading as the hero cover, and lays out the rest in a library grid. Tapping any cover opens that book in the reader.

---

## Usage

- **Open it on demand** — from the FileManager main menu, choose the **Home** toggle.
- **Make it your start screen** — go to *Settings → Start with → Home*.
- **Bind a gesture** — the plugin registers an **"Open Home"** action you can assign to any gesture.
- **Open the menu** — tap or swipe down in the top zone of the screen (matching KOReader's usual menu gesture) to bring up the FileManager menu.
- **Navigate the library** — swipe left/right over the grid to page through titles, and swipe up to return to the parent folder.
- **Quick controls** — tap the icon cluster on the right of the status bar to open the quick panel (battery, Wi-Fi, brightness).

Go to *Settings → Display mode → Home display mode* to customize the greeting and library layout.

To go back to the regular file browser, use the same menu toggle or pick a different *Start with* option.

---

## Installation

[Download](https://github.com/NobelLiu/home.koplugin/releases/latest) and rename to `home.koplugin`, copy into your KOReader `plugins/` directory, then restart KOReader.
Enable it from the FileManager main menu or set it as your start screen.

---

## Third-party fonts

Home ships font files under [`ui/uikit/fonts/`](ui/uikit/fonts/) for UI text and icons. They are not covered by the [MIT license](LICENSE) at the repository root:

- **Noto Sans SC** — [`ui/uikit/fonts/Noto_Sans_SC/`](ui/uikit/fonts/Noto_Sans_SC/); [SIL Open Font License 1.1](ui/uikit/fonts/Noto_Sans_SC/OFL.txt).
- **Material Symbols Outlined** — [`ui/uikit/fonts/Material_Icons/`](ui/uikit/fonts/Material_Icons/); [Apache License 2.0](ui/uikit/fonts/Material_Icons/LICENSE.txt).
