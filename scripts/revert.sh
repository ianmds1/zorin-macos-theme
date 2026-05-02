#!/bin/bash
# zorin-macos-theme — revert to Zorin OS default theme
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

gsetting() { sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" gsettings set "$@"; }

info "Reverting to Zorin OS default theme..."

gsetting org.gnome.desktop.interface gtk-theme 'ZorinBlue-Light'
gsetting org.gnome.desktop.interface icon-theme 'zorin-icon-themes'
gsetting org.gnome.desktop.interface cursor-theme 'default'
gsetting org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsetting org.gnome.shell.extensions.user-theme name '' 2>/dev/null || true

# Remove GTK4 overrides
rm -f "$REAL_HOME/.config/gtk-4.0/gtk.css"
rm -f "$REAL_HOME/.config/gtk-4.0/gtk-dark.css"
info "GTK4 overrides removed."

# Remove GTK_THEME from profile
sed -i '/GTK_THEME=WhiteSur-Light/d' "$REAL_HOME/.profile" 2>/dev/null || true
info "GTK_THEME removed from ~/.profile."

# Revert GDM
rm -f /etc/gdm3/greeter.dconf-defaults
info "GDM reverted to default."

echo ""
echo -e "${GREEN}✔ Reverted to Zorin OS defaults.${NC}"
echo -e "${YELLOW}→ Log out and back in to apply.${NC}"
