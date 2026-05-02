#!/bin/bash
# zorin-macos-theme — apply macOS look to Zorin OS
# https://github.com/ianmds1/zorin-macos-theme
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[x]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}━━ $1 ━━${NC}"; }

[ "$EUID" -ne 0 ] && error "Run as root: sudo ./scripts/apply-theme.sh"

REAL_USER=${SUDO_USER:-$(logname 2>/dev/null || id -un)}
REAL_UID=$(id -u "$REAL_USER")
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
DBUS="unix:path=/run/user/${REAL_UID}/bus"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

gsetting() { sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" gsettings set "$@"; }

section "1. Installing WhiteSur theme"
if [ ! -d /usr/share/themes/WhiteSur-Light ]; then
    info "Cloning WhiteSur-gtk-theme..."
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme
    cd /tmp/WhiteSur-gtk-theme
    sudo -u "$REAL_USER" bash install.sh -t all --nautilus --flatpak 2>/dev/null || \
        bash install.sh -t all 2>/dev/null || true
    cd "$REPO_DIR"
    rm -rf /tmp/WhiteSur-gtk-theme
else
    info "WhiteSur-gtk-theme already installed."
fi

section "2. Installing WhiteSur icon theme"
if [ ! -d /usr/share/icons/WhiteSur ]; then
    info "Cloning WhiteSur-icon-theme..."
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/WhiteSur-icon-theme
    cd /tmp/WhiteSur-icon-theme
    sudo -u "$REAL_USER" bash install.sh 2>/dev/null || bash install.sh 2>/dev/null || true
    cd "$REPO_DIR"
    rm -rf /tmp/WhiteSur-icon-theme
else
    info "WhiteSur-icon-theme already installed."
fi

section "3. Installing WhiteSur cursors"
if [ ! -d /usr/share/icons/WhiteSur-cursors ]; then
    info "Cloning WhiteSur-cursors..."
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git /tmp/WhiteSur-cursors
    cp -r /tmp/WhiteSur-cursors/WhiteSur-cursors /usr/share/icons/
    rm -rf /tmp/WhiteSur-cursors
else
    info "WhiteSur-cursors already installed."
fi

section "4. GTK4 / libadwaita theming"
info "Extracting WhiteSur GTK4 CSS..."
GTK4_DIR="$REAL_HOME/.config/gtk-4.0"
ASSETS_DIR="$GTK4_DIR/windows-assets"
mkdir -p "$GTK4_DIR" "$ASSETS_DIR"

# Try to extract from gresource (best quality)
GRESOURCE=$(find /usr/share/themes/WhiteSur-Light -name "gtk.gresource" 2>/dev/null | head -1)
if [ -n "$GRESOURCE" ]; then
    info "Extracting from gresource: $GRESOURCE"
    TMPDIR_GTK=$(mktemp -d)
    cd "$TMPDIR_GTK"
    for res in $(gresource list "$GRESOURCE" 2>/dev/null); do
        fname=$(basename "$res")
        if [[ "$fname" == *.css ]]; then
            gresource extract "$GRESOURCE" "$res" > "$GTK4_DIR/$fname" 2>/dev/null && \
                info "  Extracted: $fname"
        elif [[ "$fname" == *.png ]]; then
            gresource extract "$GRESOURCE" "$res" > "$ASSETS_DIR/$fname" 2>/dev/null
        fi
    done
    cd "$REPO_DIR"
    rm -rf "$TMPDIR_GTK"
    info "Extracted $(ls "$ASSETS_DIR" | wc -l) window button assets."
else
    # Fallback: copy from repo
    warn "gresource not found, copying from repo..."
    cp "$REPO_DIR/gtk4/gtk.css" "$GTK4_DIR/gtk.css"
    cp "$REPO_DIR/gtk4/gtk-dark.css" "$GTK4_DIR/gtk-dark.css"
fi

chown -R "$REAL_USER:$REAL_USER" "$GTK4_DIR"

section "5. Applying GNOME settings"
info "Setting GTK/icon/cursor themes..."
gsetting org.gnome.desktop.interface gtk-theme 'WhiteSur-Light'
gsetting org.gnome.desktop.interface icon-theme 'WhiteSur-light'
gsetting org.gnome.desktop.interface cursor-theme 'WhiteSur-cursors'
gsetting org.gnome.desktop.interface font-name 'Cantarell 11'
gsetting org.gnome.desktop.interface color-scheme 'default'

info "Setting window button layout (macOS: left side)..."
gsetting org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'

info "Setting shell theme..."
gsetting org.gnome.shell.extensions.user-theme name 'WhiteSur-Light' 2>/dev/null || \
    warn "user-theme extension not active — shell theme not applied"

section "6. Dock configuration (macOS style)"
info "Configuring zorin-taskbar dock..."
gsetting org.gnome.shell.extensions.zorin-taskbar panel-position 'BOTTOM' 2>/dev/null || true
gsetting org.gnome.shell.extensions.zorin-taskbar panel-size 64 2>/dev/null || true

info "Removing icon padding..."
SHELL_CSS="/usr/share/themes/WhiteSur-Light/gnome-shell/gnome-shell.css"
if [ -f "$SHELL_CSS" ] && ! grep -q "natural-hpadding: 0px" "$SHELL_CSS"; then
    cat >> "$SHELL_CSS" << 'EOF'

/* Reduced icon spacing for zorin-taskbar dock */
#zorintaskbarTaskbar .panel-button {
  -natural-hpadding: 0px !important;
  -minimum-hpadding: 0px !important;
}
EOF
    info "Icon padding override added."
fi

section "7. Wallpaper"
WALLPAPER_DIR="$REAL_HOME/Pictures/Wallpapers"
mkdir -p "$WALLPAPER_DIR"
if ls "$REPO_DIR/wallpapers/"*.jpg &>/dev/null; then
    cp "$REPO_DIR/wallpapers/"*.jpg "$WALLPAPER_DIR/"
    chown "$REAL_USER:$REAL_USER" "$WALLPAPER_DIR/"*.jpg
    WALLPAPER="file://$WALLPAPER_DIR/macos-bigsur-classic.jpg"
    gsetting org.gnome.desktop.background picture-uri "$WALLPAPER"
    gsetting org.gnome.desktop.background picture-uri-dark "$WALLPAPER"
    gsetting org.gnome.desktop.background picture-options 'zoom'
    info "Wallpaper set: macos-bigsur-classic.jpg"
fi

section "8. GTK_THEME environment variable"
PROFILE="$REAL_HOME/.profile"
if ! grep -q "GTK_THEME=WhiteSur-Light" "$PROFILE" 2>/dev/null; then
    echo 'export GTK_THEME=WhiteSur-Light' >> "$PROFILE"
    info "Added GTK_THEME to ~/.profile"
fi

section "9. GDM login screen theme"
GDM_DEFAULTS="/etc/gdm3/greeter.dconf-defaults"
if [ -f "$GDM_DEFAULTS" ] || [ -d "$(dirname "$GDM_DEFAULTS")" ]; then
    cat > "$GDM_DEFAULTS" << EOF
# GDM Greeter - macOS Theme

[org/gnome/desktop/interface]
gtk-theme='WhiteSur-Light'
icon-theme='WhiteSur-light'
cursor-theme='WhiteSur-cursors'
font-name='Cantarell 11'
color-scheme='default'

[org/gnome/desktop/background]
picture-uri='file://$WALLPAPER_DIR/macos-bigsur-classic.jpg'
picture-uri-dark='file://$WALLPAPER_DIR/macos-bigsur-classic.jpg'
picture-options='zoom'

[org/gnome/login-screen]
logo=''
EOF
    info "GDM login screen theme applied."
else
    warn "GDM config directory not found — skipping login screen theme."
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✔  macOS theme applied to Zorin OS!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Theme    : WhiteSur-Light"
echo "  Icons    : WhiteSur-light"
echo "  Cursors  : WhiteSur-cursors"
echo "  Dock     : Bottom, 64px, macOS layout"
echo "  Wallpaper: macOS Big Sur Classic"
echo ""
echo -e "${YELLOW}  → Log out and back in for all changes to take effect.${NC}"
echo ""
