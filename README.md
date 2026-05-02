# 🍎 zorin-macos-theme

Transform your **Zorin OS 17/18** desktop into a macOS look-alike — one script applies everything.

## What gets applied

| # | Component | Value |
|---|---|---|
| 1 | GTK3 theme | WhiteSur-Light |
| 2 | GTK4 / libadwaita theme | WhiteSur CSS extracted from gresource |
| 3 | Window button assets | 80 PNGs (close/minimize/maximize) |
| 4 | Icon theme | WhiteSur-light |
| 5 | Cursor theme | WhiteSur-cursors |
| 6 | Shell (top bar) theme | WhiteSur-Light |
| 7 | Window buttons | `● ─ □` left side (macOS style) |
| 8 | Titlebar font | Cantarell Bold 11 |
| 9 | Dock position | Bottom, 64px, centered |
| 10 | Dock auto-hide | Intellihide (hides when windows overlap) |
| 11 | Dock layout | Taskbar only — no clock, no system tray |
| 12 | Icon spacing | 0px padding (compact dock) |
| 13 | Click behavior | Cycle/minimize on click |
| 14 | Wallpaper | macOS Big Sur Classic |
| 15 | GDM login screen | WhiteSur theme + Big Sur wallpaper |
| 16 | `~/.profile` | `GTK_THEME=WhiteSur-Light` |
| 17 | `Super+Space` | Freed from switch-input-source |

## Install

```bash
git clone https://github.com/ianmds1/zorin-macos-theme
cd zorin-macos-theme
sudo ./scripts/apply-theme.sh
```

**Log out and back in** for all changes to take effect.

## Revert

```bash
sudo ./scripts/revert.sh
```

Resets everything back to Zorin OS 18 defaults.

## Requirements

- **Zorin OS 17 or 18** (GNOME 45/46, Wayland or X11)
- `git`, `curl`, `libglib2.0-bin` (auto-installed by the script)
- Internet connection on first run (to download WhiteSur themes)

## What gets downloaded automatically

- [WhiteSur GTK Theme](https://github.com/vinceliuice/WhiteSur-gtk-theme)
- [WhiteSur Icon Theme](https://github.com/vinceliuice/WhiteSur-icon-theme)
- [WhiteSur Cursors](https://github.com/vinceliuice/WhiteSur-cursors)

## Files

```
zorin-macos-theme/
├── scripts/
│   ├── apply-theme.sh   # Full installer
│   └── revert.sh        # Revert to Zorin defaults
├── gtk4/
│   ├── gtk.css          # WhiteSur CSS for GTK4/libadwaita apps (fallback)
│   └── gtk-dark.css     # Dark variant
├── wallpapers/
│   ├── macos-bigsur-classic.jpg   (3.2MB)
│   ├── macos-bigsur.jpg           (104KB)
│   └── macos-style.jpg            (2.3MB)
└── README.md
```

## Technical notes

- **GTK4 / libadwaita**: Apps like Files, Settings, Software Center ignore `gsettings gtk-theme`. The script extracts the real WhiteSur CSS from `gtk.gresource` and installs it to `~/.config/gtk-4.0/gtk.css` + `windows-assets/` (80 PNGs for window buttons).
- **GDM login screen**: Themed via `/etc/gdm3/greeter.dconf-defaults`.
- **Dock layout**: The `panel-element-positions` setting hides the system tray, clock, and activities button — leaving only the app taskbar, centered, like a real macOS dock. Detected per monitor ID automatically.
- **Intellihide**: Dock hides when a focused window overlaps it, reveals on hover or pointer pressure.

## Companion project

Want offline macOS-style dictation (PT-BR / any language)?
👉 [linux-dictation](https://github.com/ianmds1/linux-dictation)

## Credits

- [WhiteSur GTK Theme](https://github.com/vinceliuice/WhiteSur-gtk-theme) by Vince Liuice — GPL-3.0
- [WhiteSur Icon Theme](https://github.com/vinceliuice/WhiteSur-icon-theme) by Vince Liuice — GPL-3.0
- [WhiteSur Cursors](https://github.com/vinceliuice/WhiteSur-cursors) by Vince Liuice

## License

MIT — scripts and config files in this repo.
WhiteSur themes are GPL-3.0 (downloaded separately at install time).
