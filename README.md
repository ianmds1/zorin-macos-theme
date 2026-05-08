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
| 9 | Terminal font | JetBrains Mono 11 |
| 10 | Dock position | Bottom, 64px, centered |
| 11 | Dock auto-hide | Intellihide (hides when windows overlap) |
| 12 | Dock layout | Taskbar only — no clock, no system tray |
| 13 | Icon spacing | 0px padding (compact dock) |
| 14 | Click behavior | Cycle/minimize on click |
| 15 | Wallpaper | macOS Big Sur Classic |
| 16 | GDM login screen | WhiteSur theme + Big Sur wallpaper |
| 17 | Dark/light toggle | Syncs GNOME/Zorin color-scheme with WhiteSur-Light / WhiteSur-Dark |
| 18 | `Super+Space` | Freed from switch-input-source |
| 19 | Top-panel menu fix | Keeps Wi-Fi and AppIndicators working with taskbar-only dock + intellihide |

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
│   ├── apply-theme.sh             # Full installer
│   ├── patch-zorin-taskbar-quicksettings.sh
│   ├── zorin-macos-theme-sync     # Keeps tray dark/light toggle in sync
│   └── revert.sh                  # Revert to Zorin defaults
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

- **GTK4 / libadwaita**: Apps like Files, Settings, Software Center ignore `gsettings gtk-theme`. The script extracts the real WhiteSur CSS from `gtk.gresource` and installs it to `~/.config/gtk-4.0/gtk.css`, `gtk-dark.css`, and `windows-assets/` for macOS-style title buttons.
- **GNOME Terminal**: The script applies `JetBrains Mono 11` to the default GNOME Terminal profile and forces the classic gray-on-black look used in the live setup.
- **Dark/light tray toggle**: Zorin's tray toggle changes `color-scheme`, but custom GTK themes do not switch automatically. `zorin-macos-theme-sync` maps `default → WhiteSur-Light` and `prefer-dark → WhiteSur-Dark`.
- **GDM login screen**: Themed via `/etc/gdm3/greeter.dconf-defaults`.
- **Dock layout**: The `panel-element-positions` setting hides the system tray, clock, and activities button — leaving only the app taskbar, centered, like a real macOS dock. Detected per monitor ID automatically.
- **Intellihide**: Dock hides when a focused window overlaps it, reveals on hover or pointer pressure.
- **Top-panel menu compatibility**: `apply-theme.sh` patches Zorin Taskbar so top-panel menus keep working after lock/unlock even with `intellihide=true` and a taskbar-only dock. That includes Quick Settings / Wi-Fi and AppIndicators such as GPaste. Original `panel.js` and `panelManager.js` are backed up to `/usr/local/share/zorin-macos-theme-backups/` and restored by `revert.sh`.
- **Icons**: WhiteSur-light is used as the primary icon theme across apps, tray, and GDM.

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
