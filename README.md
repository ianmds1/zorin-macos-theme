# 🍎 zorin-macos-theme

Transform your **Zorin OS** desktop into a macOS look-alike — WhiteSur theme, macOS icons, cursors, dock layout, wallpapers and GTK4/libadwaita support. One script, fully automated.

![screenshot](docs/screenshot.png)

## What gets applied

| Component | Value |
|---|---|
| GTK theme | WhiteSur-Light |
| Shell theme | WhiteSur-Light |
| Icon theme | WhiteSur-light |
| Cursor theme | WhiteSur-cursors |
| Window buttons | Left side (close · minimize · maximize) |
| Dock | Bottom, 64px, no icon padding |
| Wallpaper | macOS Big Sur Classic |
| GTK4 / libadwaita | WhiteSur CSS extracted from gresource |
| GDM login screen | WhiteSur theme + Big Sur wallpaper |

## Install

```bash
git clone https://github.com/ianmds1/zorin-macos-theme
cd zorin-macos-theme
sudo ./scripts/apply-theme.sh
```

Then **log out and back in** for all changes to take effect.

## Revert

```bash
sudo ./scripts/revert.sh
```

## Requirements

- **Zorin OS 17 or 18** (GNOME 45/46)
- Wayland or X11
- Internet connection (to download WhiteSur themes on first run)
- `git`, `curl` (usually pre-installed)

## What it installs automatically

- [WhiteSur GTK Theme](https://github.com/vinceliuice/WhiteSur-gtk-theme)
- [WhiteSur Icon Theme](https://github.com/vinceliuice/WhiteSur-icon-theme)
- [WhiteSur Cursors](https://github.com/vinceliuice/WhiteSur-cursors)

## Files

```
zorin-macos-theme/
├── scripts/
│   ├── apply-theme.sh   # Main installer — applies everything
│   └── revert.sh        # Reverts to Zorin OS defaults
├── gtk4/
│   ├── gtk.css          # WhiteSur GTK4/libadwaita CSS (light)
│   └── gtk-dark.css     # WhiteSur GTK4/libadwaita CSS (dark)
├── wallpapers/
│   ├── macos-bigsur-classic.jpg
│   ├── macos-bigsur.jpg
│   └── macos-style.jpg
└── README.md
```

## Notes

- **GTK4 / libadwaita apps** (Files, Settings, etc.) ignore the system GTK theme by default. This project extracts the real WhiteSur CSS from the theme's `gtk.gresource` and places it in `~/.config/gtk-4.0/gtk.css`.
- **Window button assets** (close/minimize/maximize PNG icons) are also extracted from gresource automatically.
- **GDM login screen** is themed via `/etc/gdm3/greeter.dconf-defaults`.

## Dictation tool

Looking for a macOS-style offline dictation tool for Linux? Check out the companion project:
👉 [linux-dictation](https://github.com/ianmds1/linux-dictation)

## Credits

- [WhiteSur GTK Theme](https://github.com/vinceliuice/WhiteSur-gtk-theme) by Vince Liuice
- [WhiteSur Icon Theme](https://github.com/vinceliuice/WhiteSur-icon-theme) by Vince Liuice
- [WhiteSur Cursors](https://github.com/vinceliuice/WhiteSur-cursors) by Vince Liuice

## License

MIT — the scripts and configuration in this repo are MIT licensed.
The WhiteSur themes themselves are GPL-3.0 (downloaded separately).
