#!/bin/bash
# zorin-macos-theme — apply macOS look to Zorin OS 17/18
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

gs() { sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" gsettings set "$@" 2>/dev/null || warn "gsettings failed: $*"; }
gcheck() { sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" gsettings list-schemas 2>/dev/null | grep -q "$1"; }

# ── Detect Zorin OS version ───────────────────────────────────────────────────
ZORIN_VERSION=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    [[ "$ID" == "zorin" ]] && ZORIN_VERSION="$VERSION_ID"
fi
[ -n "$ZORIN_VERSION" ] && info "Zorin OS $ZORIN_VERSION detected." || warn "Not Zorin OS — some steps may not apply."

# ── 0. Dependencies ───────────────────────────────────────────────────────────
section "0. Dependencies"
apt-get install -y -qq git curl unzip libglib2.0-bin 2>/dev/null || true

# ── 1. WhiteSur GTK Theme ─────────────────────────────────────────────────────
section "1. WhiteSur GTK Theme"
if [ ! -d /usr/share/themes/WhiteSur-Light ]; then
    info "Cloning WhiteSur-gtk-theme..."
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme
    cd /tmp/WhiteSur-gtk-theme
    bash install.sh -t all --dest /usr/share/themes 2>/dev/null || bash install.sh -t all 2>/dev/null || true
    cd "$REPO_DIR"
    rm -rf /tmp/WhiteSur-gtk-theme
    info "WhiteSur GTK theme installed."
else
    info "WhiteSur GTK theme already present."
fi

# ── 2. WhiteSur Icon Theme ────────────────────────────────────────────────────
section "2. WhiteSur Icon Theme"
if [ ! -d /usr/share/icons/WhiteSur ] && [ ! -d "$REAL_HOME/.local/share/icons/WhiteSur" ]; then
    info "Cloning WhiteSur-icon-theme..."
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/WhiteSur-icon-theme
    cd /tmp/WhiteSur-icon-theme
    bash install.sh --dest /usr/share/icons 2>/dev/null || sudo -u "$REAL_USER" bash install.sh 2>/dev/null || true
    cd "$REPO_DIR"
    rm -rf /tmp/WhiteSur-icon-theme
    info "WhiteSur icons installed."
else
    info "WhiteSur icons already present."
fi

# ── 2b. macOS-like Tray Icon Enhancement ─────────────────────────────────────
section "2b. Tray Icon Enhancement (macOS Sonoma-like)"
# Cupertino-Sonoma = macOS Sonoma-style status icons (wifi, bt, battery, volume)
#                    used as PRIMARY icon theme
# WhiteSur-light   = fallback for app icons (dock, file manager, etc.)
# Papirus          = fallback for app indicator coverage (6,680+ panel icons)
if ! dpkg -l papirus-icon-theme &>/dev/null; then
    info "Installing Papirus icon theme (app indicator fallback)..."
    apt-get install -y -qq papirus-icon-theme 2>/dev/null && info "Papirus installed." || warn "Papirus install failed — skipping."
else
    info "Papirus already installed."
fi

if [ ! -d /usr/share/icons/Cupertino-Sonoma ]; then
    info "Cloning Cupertino-Sonoma icon theme (macOS Sonoma tray icons)..."
    git clone --depth=1 https://github.com/USBA/Cupertino-Sonoma-iCons.git /tmp/Cupertino-Sonoma 2>/dev/null
    if [ -d /tmp/Cupertino-Sonoma ]; then
        # Create directory aliases so index.theme lookup works correctly
        # panel/16-dark and panel/24-dark contain the white icons for dark top bar
        ln -sfn 16-dark  /tmp/Cupertino-Sonoma/panel/16
        ln -sfn 24-dark  /tmp/Cupertino-Sonoma/panel/24
        ln -sfn scalable-dark /tmp/Cupertino-Sonoma/status/scalable
        cp -r /tmp/Cupertino-Sonoma /usr/share/icons/Cupertino-Sonoma
        rm -rf /tmp/Cupertino-Sonoma
        info "Cupertino-Sonoma installed."
    else
        warn "Cupertino-Sonoma clone failed — skipping."
    fi
else
    info "Cupertino-Sonoma already installed."
fi

# Cupertino-Sonoma inherits WhiteSur-light + Papirus for full app icon coverage
CUPERTINO_INDEX="/usr/share/icons/Cupertino-Sonoma/index.theme"
if [ -f "$CUPERTINO_INDEX" ] && ! grep -q "WhiteSur-light" "$CUPERTINO_INDEX"; then
    sed -i 's/Inherits=Adwaita,hicolor/Inherits=WhiteSur-light,Papirus,Adwaita,hicolor/' "$CUPERTINO_INDEX"
    info "Cupertino-Sonoma: WhiteSur-light + Papirus added as fallback icon sources."
fi

# Also keep Papirus and WhiteSur-light caches updated
gtk-update-icon-cache -f /usr/share/icons/WhiteSur-light/ 2>/dev/null || true
[ -d /usr/share/icons/Papirus ] && gtk-update-icon-cache -f /usr/share/icons/Papirus/ 2>/dev/null || true

# ── 3. WhiteSur Cursors ───────────────────────────────────────────────────────
section "3. WhiteSur Cursors"
if [ ! -d /usr/share/icons/WhiteSur-cursors ]; then
    info "Cloning WhiteSur-cursors..."
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git /tmp/WhiteSur-cursors
    cp -r /tmp/WhiteSur-cursors/WhiteSur-cursors /usr/share/icons/
    rm -rf /tmp/WhiteSur-cursors
    info "WhiteSur cursors installed."
else
    info "WhiteSur cursors already present."
fi

# ── 4. GTK4 / libadwaita theming ─────────────────────────────────────────────
section "4. GTK4 / libadwaita CSS"
GTK4_DIR="$REAL_HOME/.config/gtk-4.0"
ASSETS_DIR="$GTK4_DIR/windows-assets"
mkdir -p "$GTK4_DIR" "$ASSETS_DIR"

GRESOURCE=$(find /usr/share/themes/WhiteSur-Light -name "gtk.gresource" 2>/dev/null | head -1)
if [ -n "$GRESOURCE" ] && command -v gresource &>/dev/null; then
    info "Extracting GTK4 CSS from gresource..."
    for res in $(gresource list "$GRESOURCE" 2>/dev/null); do
        fname=$(basename "$res")
        if [[ "$fname" == *.css ]]; then
            gresource extract "$GRESOURCE" "$res" > "$GTK4_DIR/$fname"
        elif [[ "$fname" == *.png ]]; then
            gresource extract "$GRESOURCE" "$res" > "$ASSETS_DIR/$fname"
        fi
    done
    info "Extracted $(ls "$ASSETS_DIR" 2>/dev/null | wc -l) window button assets."
else
    warn "gresource not available — copying CSS from repo..."
    cp "$REPO_DIR/gtk4/gtk.css"      "$GTK4_DIR/gtk.css"
    cp "$REPO_DIR/gtk4/gtk-dark.css" "$GTK4_DIR/gtk-dark.css"
fi
chown -R "$REAL_USER:$REAL_USER" "$GTK4_DIR"

# ── 5. GNOME interface settings ───────────────────────────────────────────────
section "5. GNOME theme settings"
info "GTK / icon / cursor / font..."
gs org.gnome.desktop.interface gtk-theme            'WhiteSur-Light'
gs org.gnome.desktop.interface icon-theme           'Cupertino-Sonoma'
gs org.gnome.desktop.interface cursor-theme         'WhiteSur-cursors'
gs org.gnome.desktop.interface font-name            'Cantarell 11'
gs org.gnome.desktop.interface document-font-name   'Cantarell 11'
gs org.gnome.desktop.interface monospace-font-name  'Source Code Pro 10'
gs org.gnome.desktop.interface color-scheme         'default'
gs org.gnome.desktop.interface font-antialiasing    'grayscale'
gs org.gnome.desktop.interface font-hinting         'slight'

info "Window manager: macOS button layout (left) + titlebar font..."
gs org.gnome.desktop.wm.preferences button-layout          'close,minimize,maximize:'
gs org.gnome.desktop.wm.preferences titlebar-font          'Cantarell Bold 11'
gs org.gnome.desktop.wm.preferences titlebar-uses-system-font true
gs org.gnome.desktop.wm.preferences action-double-click-titlebar 'toggle-maximize'

info "Shell theme..."
if gcheck "org.gnome.shell.extensions.user-theme"; then
    gs org.gnome.shell.extensions.user-theme name 'WhiteSur-Light'
else
    warn "user-theme extension not found — shell theme skipped."
fi

# Zorin appearance schema (Zorin 18 specific)
if gcheck "com.zorin.desktop.appearance"; then
    info "Zorin appearance schema..."
    gs com.zorin.desktop.appearance gtk-theme    'WhiteSur-Light'   2>/dev/null || true
    gs com.zorin.desktop.appearance icon-theme   'Cupertino-Sonoma'   2>/dev/null || true
    gs com.zorin.desktop.appearance cursor-theme 'WhiteSur-cursors' 2>/dev/null || true
fi

# ── 6. Zorin Taskbar — full macOS dock config ─────────────────────────────────
section "6. Dock (zorin-taskbar — macOS style)"
if gcheck "org.gnome.shell.extensions.zorin-taskbar"; then
    ZTASK="org.gnome.shell.extensions.zorin-taskbar"
    info "Panel position / size / margin..."
    gs $ZTASK panel-position   'BOTTOM'
    gs $ZTASK panel-size       64
    gs $ZTASK panel-margin     16

    info "Intellihide (auto-hide when windows overlap)..."
    gs $ZTASK intellihide                    true
    gs $ZTASK intellihide-behaviour          'FOCUSED_WINDOWS'
    gs $ZTASK intellihide-hide-from-windows  true
    gs $ZTASK intellihide-use-pressure       true
    gs $ZTASK intellihide-use-pointer        true
    gs $ZTASK intellihide-revealed-hover     true
    gs $ZTASK intellihide-show-in-fullscreen false
    gs $ZTASK intellihide-show-on-notification false

    info "Click behavior..."
    gs $ZTASK click-action          'CYCLE-MIN'
    gs $ZTASK middle-click-action   'LAUNCH'
    gs $ZTASK shift-click-action    'MINIMIZE'
    gs $ZTASK scroll-icon-action    'CYCLE_WINDOWS'
    gs $ZTASK activate-single-window true
    gs $ZTASK minimize-shift        true
    gs $ZTASK peek-mode             true
    gs $ZTASK preview-middle-click-close true

    info "App grouping / appearance..."
    gs $ZTASK group-apps                  true
    gs $ZTASK group-apps-use-launchers    true
    gs $ZTASK group-apps-use-fixed-width  true
    gs $ZTASK group-apps-label-max-width  0
    gs $ZTASK dot-style-focused           'CILIORA'
    gs $ZTASK dot-style-unfocused         'DOTS'
    gs $ZTASK global-border-radius        3
    gs $ZTASK progress-show-bar           true
    gs $ZTASK progress-show-count         true

    info "Panel layout: taskbar only, centered (macOS dock style)..."
    # Detect current monitor identifier
    MONITOR_ID=$(sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" \
        gsettings get $ZTASK panel-sizes 2>/dev/null | grep -oP '"[^"]+(?=":)' | head -1 | tr -d '"')

    if [ -n "$MONITOR_ID" ] && [ "$MONITOR_ID" != "@a{si}" ]; then
        info "Monitor: $MONITOR_ID"
        gs $ZTASK panel-anchors  "{\"$MONITOR_ID\":\"MIDDLE\"}"
        gs $ZTASK panel-lengths  "{\"$MONITOR_ID\":-1}"
        gs $ZTASK panel-element-positions \
            "{\"$MONITOR_ID\":[{\"element\":\"showAppsButton\",\"visible\":false,\"position\":\"stackedTL\"},{\"element\":\"taskbar\",\"visible\":true,\"position\":\"stackedTL\"},{\"element\":\"leftBox\",\"visible\":false,\"position\":\"stackedTL\"},{\"element\":\"centerBox\",\"visible\":false,\"position\":\"stackedBR\"},{\"element\":\"rightBox\",\"visible\":false,\"position\":\"stackedBR\"},{\"element\":\"activitiesButton\",\"visible\":false,\"position\":\"stackedBR\"},{\"element\":\"systemMenu\",\"visible\":false,\"position\":\"stackedBR\"},{\"element\":\"dateMenu\",\"visible\":false,\"position\":\"stackedBR\"},{\"element\":\"desktopButton\",\"visible\":false,\"position\":\"stackedBR\"}]}"
    else
        warn "Could not detect monitor ID — panel layout not set (configure manually in Zorin Taskbar settings)."
    fi

    info "Adding icon padding override to gnome-shell.css..."
    SHELL_CSS="/usr/share/themes/WhiteSur-Light/gnome-shell/gnome-shell.css"
    if [ -f "$SHELL_CSS" ] && ! grep -q "natural-hpadding: 0px" "$SHELL_CSS"; then
        cat >> "$SHELL_CSS" << 'EOF'

/* Reduced icon spacing for zorin-taskbar dock */
#zorintaskbarTaskbar .panel-button {
  -natural-hpadding: 0px !important;
  -minimum-hpadding: 0px !important;
}
EOF
    fi
else
    warn "zorin-taskbar not found — dock not configured."
fi

# ── 7. Keyboard shortcuts ────────────────────────────────────────────────────
section "7. Keyboard shortcuts"
info "Free Super+Space from switch-input-source..."
gs org.gnome.desktop.wm.keybindings switch-input-source "['XF86Keyboard']"

# ── 8. Wallpaper ──────────────────────────────────────────────────────────────
section "8. Wallpaper"
WALLPAPER_DIR="$REAL_HOME/Pictures/Wallpapers"
mkdir -p "$WALLPAPER_DIR"
cp "$REPO_DIR/wallpapers/"*.jpg "$WALLPAPER_DIR/" 2>/dev/null || true
chown "$REAL_USER:$REAL_USER" "$WALLPAPER_DIR/"*.jpg 2>/dev/null || true

WALLPAPER="file://$WALLPAPER_DIR/macos-bigsur-classic.jpg"
gs org.gnome.desktop.background picture-uri       "$WALLPAPER"
gs org.gnome.desktop.background picture-uri-dark  "$WALLPAPER"
gs org.gnome.desktop.background picture-options   'zoom'
info "Wallpaper: macos-bigsur-classic.jpg"

# ── 9. GTK_THEME env ──────────────────────────────────────────────────────────
PROFILE="$REAL_HOME/.profile"
if ! grep -q "GTK_THEME=WhiteSur-Light" "$PROFILE" 2>/dev/null; then
    echo 'export GTK_THEME=WhiteSur-Light' >> "$PROFILE"
    info "GTK_THEME=WhiteSur-Light added to ~/.profile"
fi

# ── 10. GDM login screen ──────────────────────────────────────────────────────
section "9. GDM login screen"
GDM_DEFAULTS="/etc/gdm3/greeter.dconf-defaults"
if [ -d "$(dirname "$GDM_DEFAULTS")" ]; then
    cat > "$GDM_DEFAULTS" << EOF
# GDM Greeter - macOS Theme (zorin-macos-theme)

[org/gnome/desktop/interface]
gtk-theme='WhiteSur-Light'
icon-theme='Cupertino-Sonoma'
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
    info "GDM login screen themed."
else
    warn "GDM config dir not found — login screen skipped."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✔  macOS theme applied to Zorin OS ${ZORIN_VERSION:-?}!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Theme    : WhiteSur-Light (GTK3 + GTK4/libadwaita)"
echo "  Icons    : Cupertino-Sonoma (tray) + WhiteSur-light + Papirus (fallback)"
echo "  Cursors  : WhiteSur-cursors"
echo "  Buttons  : ● ─ □  (left side, macOS style)"
echo "  Dock     : Bottom, 64px, centered, intellihide"
echo "  Wallpaper: macOS Big Sur Classic"
echo "  GDM      : WhiteSur login screen"
echo ""
echo -e "${YELLOW}  → Log out and back in for all changes to take effect.${NC}"
echo ""
