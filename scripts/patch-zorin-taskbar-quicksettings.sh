#!/bin/bash
set -e

EXT_DIR=/usr/share/gnome-shell/extensions/zorin-taskbar@zorinos.com
PANEL_JS="${PANEL_JS:-$EXT_DIR/panel.js}"
PANEL_MANAGER_JS="${PANEL_MANAGER_JS:-$EXT_DIR/panelManager.js}"
BACKUP_DIR="${BACKUP_DIR:-/usr/local/share/zorin-macos-theme-backups}"

[ "$EUID" -ne 0 ] && { echo "Run as root: sudo $0"; exit 1; }
[ -f "$PANEL_JS" ] || { echo "panel.js not found: $PANEL_JS"; exit 1; }
[ -f "$PANEL_MANAGER_JS" ] || { echo "panelManager.js not found: $PANEL_MANAGER_JS"; exit 1; }

mkdir -p "$BACKUP_DIR"
[ -f "$BACKUP_DIR/panel.js.orig" ] || cp -a "$PANEL_JS" "$BACKUP_DIR/panel.js.orig"
[ -f "$BACKUP_DIR/panelManager.js.orig" ] || cp -a "$PANEL_MANAGER_JS" "$BACKUP_DIR/panelManager.js.orig"

python3 - "$PANEL_JS" "$PANEL_MANAGER_JS" <<'PY'
from pathlib import Path
import sys

panel_js = Path(sys.argv[1])
panel_manager_js = Path(sys.argv[2])


def replace_once(text: str, old: str, new: str, label: str, path: Path):
    if new in text:
        return text, False
    if old not in text:
        raise SystemExit(f"{path}: expected snippet not found for {label}")
    return text.replace(old, new, 1), True


panel_text = panel_js.read_text()
panel_manager_text = panel_manager_js.read_text()

panel_replacements = [
    (
        "standalone-visible-map",
        """        this.statusArea = this.panel.statusArea = {}

        //next 3 functions are needed by other extensions to add elements to the secondary panel
""",
        """        this.statusArea = this.panel.statusArea = {}
        let panelPositions = PanelSettings.getPanelElementPositions(
          SETTINGS,
          this.monitor.index,
        )
        let visibleByElement = Object.fromEntries(
          panelPositions.map((pos) => [pos.element, pos.visible]),
        )

        //next 3 functions are needed by other extensions to add elements to the secondary panel
""",
    ),
    (
        "standalone-panel-menus",
        """        this._setPanelMenu(
          systemMenuInfo.name,
          systemMenuInfo.constructor,
          this.panel,
        )
        this._setPanelMenu('dateMenu', DateMenu.DateMenuButton, this.panel)
        this._setPanelMenu(
          'activities',
          Main.panel.statusArea.activities.constructor,
          this.panel,
        )
""",
        """        if (visibleByElement[Pos.SYSTEM_MENU]) {
          this._setPanelMenu(
            systemMenuInfo.name,
            systemMenuInfo.constructor,
            this.panel,
          )
        }
        if (visibleByElement[Pos.DATE_MENU]) {
          this._setPanelMenu('dateMenu', DateMenu.DateMenuButton, this.panel)
        }
        if (visibleByElement[Pos.ACTIVITIES_BTN]) {
          this._setPanelMenu(
            'activities',
            Main.panel.statusArea.activities.constructor,
            this.panel,
          )
        }
""",
    ),
    (
        "standalone-sync-helper",
        """    getOrientation() {
      return this.geom.vertical ? 'vertical' : 'horizontal'
    }

    updateElementPositions() {
      let panelPositions = PanelSettings.getPanelElementPositions(
        SETTINGS,
        this.monitor.index,
      )

      this._updateGroupedElements(panelPositions)

      this.panel.hide()
      this.panel.show()
    }
""",
        """    getOrientation() {
      return this.geom.vertical ? 'vertical' : 'horizontal'
    }

    _syncStandalonePanelMenus(panelPositions) {
      if (!this.isStandalone) {
        return
      }

      let visibleByElement = Object.fromEntries(
        panelPositions.map((pos) => [pos.element, pos.visible]),
      )
      let systemMenuInfo = Utils.getSystemMenuInfo()

      let syncPanelMenu = (elementName, propName, constr) => {
        if (visibleByElement[elementName]) {
          this._setPanelMenu(propName, constr, this.panel)
        } else {
          this._removePanelMenu(propName)
          PERSISTENTSTORAGE[propName] = []
        }
      }

      syncPanelMenu(
        Pos.SYSTEM_MENU,
        systemMenuInfo.name,
        systemMenuInfo.constructor,
      )
      syncPanelMenu(Pos.DATE_MENU, 'dateMenu', DateMenu.DateMenuButton)
      syncPanelMenu(
        Pos.ACTIVITIES_BTN,
        'activities',
        Main.panel.statusArea.activities.constructor,
      )

      this._setAllocationMap()
    }

    _isPanelElementVisible(elementName) {
      let panelPositions = PanelSettings.getPanelElementPositions(
        SETTINGS,
        this.monitor.index,
      )

      return panelPositions.some(
        (pos) => pos.element === elementName && pos.visible,
      )
    }

    updateElementPositions() {
      let panelPositions = PanelSettings.getPanelElementPositions(
        SETTINGS,
        this.monitor.index,
      )

      this._syncStandalonePanelMenus(panelPositions)
      this._updateGroupedElements(panelPositions)

      this.panel.hide()
      this.panel.show()
    }
""",
    ),
    (
        "quicksettings-arrow-guard",
        """      if (this.statusArea.quickSettings?.menu) {
        this.statusArea.quickSettings.menu._arrowSide = this.geom.position
        this.statusArea.quickSettings.menu._arrowAlignment = 0.5
      }
""",
        """      if (
        this.statusArea.quickSettings?.menu &&
        this._isPanelElementVisible(Pos.SYSTEM_MENU)
      ) {
        this.statusArea.quickSettings.menu._arrowSide = this.geom.position
        this.statusArea.quickSettings.menu._arrowAlignment = 0.5
      }
""",
    ),
    (
        "allocation-map-optional-menus",
        """      setMap(Pos.LEFT_BOX, this._leftBox)
      setMap(Pos.TASKBAR, this.taskbar.actor)
      setMap(Pos.CENTER_BOX, this._centerBox)
      setMap(Pos.DATE_MENU, this.statusArea.dateMenu.container)
      setMap(
        Pos.SYSTEM_MENU,
        this.statusArea[Utils.getSystemMenuInfo().name].container,
      )
      setMap(Pos.RIGHT_BOX, this._rightBox)
""",
        """      setMap(Pos.LEFT_BOX, this._leftBox)
      setMap(Pos.TASKBAR, this.taskbar.actor)
      setMap(Pos.CENTER_BOX, this._centerBox)
      setMap(Pos.DATE_MENU, this.statusArea.dateMenu ? this.statusArea.dateMenu.container : 0)
      setMap(
        Pos.SYSTEM_MENU,
        this.statusArea[Utils.getSystemMenuInfo().name]
          ? this.statusArea[Utils.getSystemMenuInfo().name].container
          : 0,
      )
      setMap(Pos.RIGHT_BOX, this._rightBox)
""",
    ),
]

for label, old, new in panel_replacements:
    panel_text, _ = replace_once(panel_text, old, new, label, panel_js)

panel_manager_replacements = [
    (
        "skip-top-panel-menu-adjust",
        """  _updatePanelElementPositions() {
    this.allPanels.forEach((p) => p.updateElementPositions())
  }

  _adjustPanelMenuButton(button, monitor, arrowSide) {
    if (button && button.menu) {
""",
        """  _updatePanelElementPositions() {
    this.allPanels.forEach((p) => p.updateElementPositions())
  }

  _isActorInTopPanel(actor) {
    while (actor) {
      if (actor === Main.panel) {
        return true
      }

      actor = actor.get_parent?.()
    }

    return false
  }

  _adjustPanelMenuButton(button, monitor, arrowSide) {
    if (
      button === Main.panel.statusArea.quickSettings ||
      button === Main.panel.statusArea.dateMenu ||
      this._isActorInTopPanel(button)
    ) {
      return
    }

    if (button && button.menu) {
""",
    ),
    (
        "skip-top-panel-height-limit",
        """  _getBoxPointerPreferredHeight(boxPointer, alloc, monitor) {
    if (
      boxPointer._dtpInPanel &&
      boxPointer.sourceActor &&
      SETTINGS.get_boolean('intellihide')
    ) {
      monitor =
        monitor ||
        Main.layoutManager.findMonitorForActor(boxPointer.sourceActor)
""",
        """  _getBoxPointerPreferredHeight(boxPointer, alloc, monitor) {
    let sourceActor = boxPointer.sourceActor
    let isTopPanelMenu =
      sourceActor === Main.panel.statusArea.quickSettings ||
      sourceActor === Main.panel.statusArea.dateMenu ||
      this._isActorInTopPanel(sourceActor)

    if (
      boxPointer._dtpInPanel &&
      sourceActor &&
      !isTopPanelMenu &&
      SETTINGS.get_boolean('intellihide')
    ) {
      monitor =
        monitor || Main.layoutManager.findMonitorForActor(sourceActor)
""",
    ),
]

for label, old, new in panel_manager_replacements:
    panel_manager_text, _ = replace_once(
        panel_manager_text, old, new, label, panel_manager_js
    )

panel_js.write_text(panel_text)
panel_manager_js.write_text(panel_manager_text)
PY

echo "Patched zorin-taskbar top-panel menu compatibility."
