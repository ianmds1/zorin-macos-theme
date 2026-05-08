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
apt-get install -y -qq git curl unzip libglib2.0-bin python3 fonts-jetbrains-mono 2>/dev/null || true

# ── 1. WhiteSur GTK Theme ─────────────────────────────────────────────────────
section "1. WhiteSur GTK Theme"
if [ ! -d /usr/share/themes/WhiteSur-Light ] || [ ! -d /usr/share/themes/WhiteSur-Dark ]; then
    info "Cloning WhiteSur-gtk-theme..."
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme
    cd /tmp/WhiteSur-gtk-theme
    bash install.sh -c light -t default --dest /usr/share/themes 2>/dev/null || bash install.sh -c light -t default 2>/dev/null || true
    bash install.sh -c dark  -t default --dest /usr/share/themes 2>/dev/null || bash install.sh -c dark  -t default 2>/dev/null || true
    cd "$REPO_DIR"
    rm -rf /tmp/WhiteSur-gtk-theme
    info "WhiteSur GTK Light/Dark themes installed."
else
    info "WhiteSur GTK Light/Dark themes already present."
fi

# ── 2. WhiteSur Icon Theme ────────────────────────────────────────────────────
section "2. WhiteSur Icon Theme"
if [ ! -d /usr/share/icons/WhiteSur-light ]; then
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

# ── 2b. Icon cache update ─────────────────────────────────────────────────────
section "2b. Icon cache"
gtk-update-icon-cache -f /usr/share/icons/WhiteSur-light/ 2>/dev/null || true
gtk-update-icon-cache -f /usr/share/icons/WhiteSur-dark/  2>/dev/null || true

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
ASSETS_DIR="$GTK4_DIR/assets"
mkdir -p "$GTK4_DIR" "$ASSETS_DIR"

# Extract the FULL CSS (not @import wrappers) so GTK4 picks gtk.css or
# gtk-dark.css automatically based on color-scheme toggle (prefer-dark <-> default)
GRESOURCE=$(find /usr/share/themes/WhiteSur-Light -name "gtk.gresource" 2>/dev/null | head -1)
if [ -n "$GRESOURCE" ] && command -v gresource &>/dev/null; then
    info "Extracting WhiteSur GTK4 CSS (light + dark variants for toggle)..."
    gresource extract "$GRESOURCE" /org/gnome/theme/gtk.css      > "$GTK4_DIR/gtk.css"      2>/dev/null || true
    gresource extract "$GRESOURCE" /org/gnome/theme/gtk-dark.css > "$GTK4_DIR/gtk-dark.css" 2>/dev/null || true
    for res in $(gresource list "$GRESOURCE" 2>/dev/null | grep "assets/"); do
        gresource extract "$GRESOURCE" "$res" > "$ASSETS_DIR/$(basename "$res")" 2>/dev/null || true
    done
    ln -sfn assets "$GTK4_DIR/windows-assets"
    info "GTK4 CSS applied — dark/light toggle works via color-scheme."
else
    warn "gresource not available — copying CSS from repo..."
    cp "$REPO_DIR/gtk4/gtk.css"      "$GTK4_DIR/gtk.css"
    cp "$REPO_DIR/gtk4/gtk-dark.css" "$GTK4_DIR/gtk-dark.css"
fi
chown -R "$REAL_USER:$REAL_USER" "$GTK4_DIR"

# ── 4b. GTK3 dark settings ────────────────────────────────────────────────────
GTK3_DIR="$REAL_HOME/.config/gtk-3.0"
mkdir -p "$GTK3_DIR"
cat > "$GTK3_DIR/settings.ini" << 'EOFGTK3'
[Settings]
gtk-theme-name=WhiteSur-Light
gtk-icon-theme-name=WhiteSur-light
gtk-cursor-theme-name=WhiteSur-cursors
gtk-font-name=Cantarell 11
gtk-decoration-layout=close,minimize,maximize:
EOFGTK3
chown -R "$REAL_USER:$REAL_USER" "$GTK3_DIR"
info "GTK3 settings configured."

# ── 5. GNOME interface settings ───────────────────────────────────────────────
section "5. GNOME theme settings"
info "GTK / icon / cursor / font..."
gs org.gnome.desktop.interface gtk-theme            'WhiteSur-Light'
gs org.gnome.desktop.interface icon-theme           'WhiteSur-light'
gs org.gnome.desktop.interface cursor-theme         'WhiteSur-cursors'
gs org.gnome.desktop.interface font-name            'Cantarell 11'
gs org.gnome.desktop.interface document-font-name   'Cantarell 11'
gs org.gnome.desktop.interface monospace-font-name  'Source Code Pro 10'
gs org.gnome.desktop.interface color-scheme         'default'
gs org.gnome.desktop.interface font-antialiasing    'grayscale'
gs org.gnome.desktop.interface font-hinting         'slight'

info "Window manager: macOS button layout (left) + titlebar font..."
gs org.gnome.desktop.wm.preferences button-layout          'close,minimize,maximize:'
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" gsettings set org.gnome.desktop.interface gtk-decoration-layout 'close,minimize,maximize:' 2>/dev/null || true
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
    gs com.zorin.desktop.appearance gtk-theme    'WhiteSur-Light'    2>/dev/null || true
    gs com.zorin.desktop.appearance icon-theme   'WhiteSur-light'   2>/dev/null || true
    gs com.zorin.desktop.appearance cursor-theme 'WhiteSur-cursors' 2>/dev/null || true
fi

if gcheck "com.zorin.desktop.auto-theme"; then
    info "Zorin dark/light tray toggle: WhiteSur Light/Dark mapping..."
    gs com.zorin.desktop.auto-theme day-theme   'WhiteSur-Light'  2>/dev/null || true
    gs com.zorin.desktop.auto-theme night-theme 'WhiteSur-Dark'   2>/dev/null || true
fi

# ── 5c. GNOME Terminal ────────────────────────────────────────────────────────
section "5c. GNOME Terminal"
if gcheck "org.gnome.Terminal.ProfilesList"; then
    TERM_PROFILE=$(sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" \
        gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if [ -n "$TERM_PROFILE" ]; then
        TERM_SCHEMA="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$TERM_PROFILE/"
        info "Terminal font and colors..."
        gs "$TERM_SCHEMA" use-system-font false
        gs "$TERM_SCHEMA" font 'JetBrains Mono 11'
        gs "$TERM_SCHEMA" use-theme-colors false
        gs "$TERM_SCHEMA" foreground-color 'rgb(170,170,170)'
        gs "$TERM_SCHEMA" background-color 'rgb(0,0,0)'
    else
        warn "Could not detect GNOME Terminal default profile."
    fi
else
    warn "GNOME Terminal schema not found — terminal styling skipped."
fi

# The GNOME/Zorin dark style toggle changes color-scheme, but custom GTK themes
# do not automatically switch between WhiteSur-Light and WhiteSur-Dark. Keep
# them synchronized in the user session and at next login.
section "5b. Dark/light toggle sync"
SYNC_BIN="$REAL_HOME/.local/bin/zorin-macos-theme-sync"
AUTOSTART_DIR="$REAL_HOME/.config/autostart"
mkdir -p "$(dirname "$SYNC_BIN")" "$AUTOSTART_DIR"
install -m 0755 "$REPO_DIR/scripts/zorin-macos-theme-sync" "$SYNC_BIN"
cat > "$AUTOSTART_DIR/zorin-macos-theme-sync.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Zorin macOS Theme Sync
Comment=Sync WhiteSur Light/Dark themes with GNOME color-scheme toggle
Exec=$SYNC_BIN
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
chown "$REAL_USER:$REAL_USER" "$SYNC_BIN" "$AUTOSTART_DIR/zorin-macos-theme-sync.desktop"
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS" "$SYNC_BIN" --once 2>/dev/null || true
info "Dark/light toggle sync installed."

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

    info "Patching zorin-taskbar Quick Settings / Wi-Fi compatibility..."
    "$REPO_DIR/scripts/patch-zorin-taskbar-quicksettings.sh"
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
if grep -q "GTK_THEME=WhiteSur-" "$PROFILE" 2>/dev/null; then
    sed -i '/GTK_THEME=WhiteSur-/d' "$PROFILE"
    info "Removed fixed GTK_THEME from ~/.profile so dark/light toggle can work."
fi

# ── 10. GDM login screen ──────────────────────────────────────────────────────
section "9. GDM login screen"
GDM_DEFAULTS="/etc/gdm3/greeter.dconf-defaults"
if [ -d "$(dirname "$GDM_DEFAULTS")" ]; then
    cat > "$GDM_DEFAULTS" << EOF
# GDM Greeter - macOS Theme (zorin-macos-theme)

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
echo "  Theme    : WhiteSur-Light + dark mode via color-scheme (toggle works)"
echo "  Icons    : WhiteSur-light"
echo "  Cursors  : WhiteSur-cursors"
echo "  Terminal : JetBrains Mono 11"
echo "  Buttons  : ● ─ □  (left side, macOS style)"
echo "  Dock     : Bottom, 64px, centered, intellihide"
echo "  Wallpaper: macOS Big Sur Classic"
echo "  GDM      : WhiteSur login screen"
echo ""
echo -e "${YELLOW}  → Log out and back in for all changes to take effect.${NC}"
echo ""
