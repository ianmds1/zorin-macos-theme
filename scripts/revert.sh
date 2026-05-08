#!/bin/bash
# zorin-macos-theme — revert to Zorin OS 18 defaults
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

[ "$EUID" -ne 0 ] && error "Run as root: sudo ./scripts/revert.sh"

REAL_USER=${SUDO_USER:-$(logname 2>/dev/null || id -un)}
REAL_UID=$(id -u "$REAL_USER")
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
DBUS="unix:path=/run/user/${REAL_UID}/bus"
BACKUP_DIR="/usr/local/share/zorin-macos-theme-backups"

gs() { sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" gsettings set "$@" 2>/dev/null || warn "gsettings: $*"; }
greset() { sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" gsettings reset "$@" 2>/dev/null || true; }

info "Reverting to Zorin OS 18 defaults..."

# Interface
gs org.gnome.desktop.interface gtk-theme           'ZorinBlue-Light'
gs org.gnome.desktop.interface icon-theme          'ZorinBlue-Light'
gs org.gnome.desktop.interface cursor-theme        'default'
gs org.gnome.desktop.interface font-name           'Cantarell 11'
gs org.gnome.desktop.interface document-font-name  'Cantarell 11'
gs org.gnome.desktop.interface monospace-font-name 'Source Code Pro 10'
gs org.gnome.desktop.interface color-scheme        'default'

# Window buttons (Zorin default: right side)
gs org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

# Shell theme
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" \
    gsettings reset org.gnome.shell.extensions.user-theme name 2>/dev/null || true

# Zorin taskbar defaults
if sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" \
   gsettings list-schemas 2>/dev/null | grep -q "org.gnome.shell.extensions.zorin-taskbar"; then
    ZTASK="org.gnome.shell.extensions.zorin-taskbar"
    greset $ZTASK intellihide
    greset $ZTASK intellihide-behaviour
    greset $ZTASK intellihide-hide-from-windows
    greset $ZTASK panel-position
    greset $ZTASK panel-size
    greset $ZTASK panel-margin
    greset $ZTASK panel-element-positions
    greset $ZTASK panel-anchors
    greset $ZTASK panel-lengths
    greset $ZTASK click-action
    greset $ZTASK dot-style-focused
    greset $ZTASK dot-style-unfocused
    greset $ZTASK global-border-radius
    info "Zorin taskbar reset to defaults."
fi

# Restore Super+Space for input source
gs org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space']"

# Restore GNOME Terminal defaults
if sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" \
   gsettings list-schemas 2>/dev/null | grep -q "org.gnome.Terminal.ProfilesList"; then
    TERM_PROFILE=$(sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" \
        gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if [ -n "$TERM_PROFILE" ]; then
        TERM_SCHEMA="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$TERM_PROFILE/"
        greset "$TERM_SCHEMA" use-system-font
        greset "$TERM_SCHEMA" font
        greset "$TERM_SCHEMA" use-theme-colors
        greset "$TERM_SCHEMA" foreground-color
        greset "$TERM_SCHEMA" background-color
    fi
fi

# Remove GTK4 overrides
rm -f "$REAL_HOME/.config/gtk-4.0/gtk.css"
rm -f "$REAL_HOME/.config/gtk-4.0/gtk-dark.css"
info "GTK4 overrides removed."

# Remove GTK_THEME from profile
sed -i '/GTK_THEME=WhiteSur-Light/d' "$REAL_HOME/.profile" 2>/dev/null || true
info "GTK_THEME removed from ~/.profile."

# Reset wallpaper to Zorin default
greset org.gnome.desktop.background picture-uri
greset org.gnome.desktop.background picture-uri-dark
info "Wallpaper reset to Zorin default."

# Revert GDM
rm -f /etc/gdm3/greeter.dconf-defaults
info "GDM reverted to default."

# Restore zorin-taskbar JS if backups exist
if [ -f "$BACKUP_DIR/panel.js.orig" ] && [ -f "$BACKUP_DIR/panelManager.js.orig" ]; then
    cp -f "$BACKUP_DIR/panel.js.orig" /usr/share/gnome-shell/extensions/zorin-taskbar@zorinos.com/panel.js
    cp -f "$BACKUP_DIR/panelManager.js.orig" /usr/share/gnome-shell/extensions/zorin-taskbar@zorinos.com/panelManager.js
    info "Zorin taskbar Quick Settings patch reverted."
fi

echo ""
echo -e "${GREEN}✔ Reverted to Zorin OS 18 defaults.${NC}"
echo -e "${YELLOW}→ Log out and back in to apply.${NC}"
