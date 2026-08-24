# Home — a reading-focused home screen for KOReader

`home.koplugin` replaces KOReader's default file-browser landing view with a curated reading dashboard. Instead of a list of files, you're greeted by a large "hero" cover of the book you were last reading, a grid of your other recent titles, and a compact status bar — all designed to get you back into a book with a single tap.

> _A reading-focused home screen with a hero cover for your latest book and a row of recent titles._

<img src="screenshot.png" height="512">
---

## Features

- **Continue reading** — A large cover of your last-read book, with its title, author, description, and reading progress. Tap it to jump straight back in.
- **Recent books** — Your other books shown as cover cards with progress and titles, and you can sort them by most recently read or by name.
- **Your home folder is the source** — Home uses the root folder you've configured in KOReader as your library, and displays the books inside it. Set that folder to wherever your books live, and Home will show them.
- **Status bar** — A top bar with the clock, Wi-Fi status, and battery, so you always have the essentials at a glance.
- **Set as your start screen** — Make Home the first thing you see when KOReader launches, or toggle to it any time from the menu or a gesture.

---

## How it works

Home is drawn on top of a live FileManager instead of replacing it, so all of KOReader's native menus, gestures, and plugins keep working underneath. It reads the books from your configured home (root) folder, highlights the one you were last reading as the hero cover, and lays out the rest as recent titles. Tapping any cover opens that book in the reader.

---

## Usage

- **Open it on demand** — from the FileManager main menu, choose the **Home** toggle.
- **Make it your start screen** — go to *Settings → Start with → Home*.
- **Bind a gesture** — the plugin registers an **"Open Home"** action you can assign to any gesture.

To go back to the regular file browser, use the same menu toggle or pick a different *Start with* option.

---

## Installation

Download and rename to `home.koplugin`, copy into your KOReader `plugins/` directory, then restart KOReader.
Enable it from the FileManager main menu or set it as your start screen.
