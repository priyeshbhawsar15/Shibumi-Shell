pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "GamingPauseModel.js" as GamingPauseModel

// Owned once by the admitted Bar, never once per output. No polling/processes.
Item {
  id: root

  enabled: false
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
    || ((Quickshell.env("HOME") || "") + "/.local/state")
  readonly property string statePath: stateHome + "/omarchy/gaming-mode/session.json"
  readonly property string sessionSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
  property bool paused: false

  visible: false
  width: 0
  height: 0

  function refresh() {
    if (!enabled || journal.path !== statePath || !journal.loaded) {
      paused = false
      return
    }
    paused = GamingPauseModel.decorationsPaused(journal.text(), sessionSignature)
  }

  onEnabledChanged: {
    if (!enabled) paused = false
    else Qt.callLater(refresh)
  }

  FileView {
    id: journal
    path: root.enabled ? root.statePath : ""
    preload: root.enabled
    watchChanges: root.enabled
    printErrors: false
    onLoaded: root.refresh()
    onFileChanged: reload()
    onLoadFailed: function(error) { root.paused = false }
  }
}
