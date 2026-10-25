import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "services" as Services
import "services/GamingPauseModel.js" as GamingPauseModel
import "visuals" as Visuals

ShellRoot {
  id: test
  property bool observerEnabled: true

  Services.GamingPause { id: pauseState; enabled: test.observerEnabled }
  QtObject {
    id: player
    readonly property string trackTitle: "Fixture track"
    readonly property string trackArtist: "Fixture artist"
    property bool isPlaying: true
  }
  QtObject { id: media; property var activePlayer: player }
  QtObject { id: suiteMedia; property var mediaService: null }
  Component.onCompleted: Qt.callLater(function() {
    media.activePlayer = player
    suiteMedia.mediaService = media
    fakeBar.mediaOwner = suiteMedia
  })
  QtObject {
    id: fakeBar
    property var mediaOwner: null
    function pluginService(id) { return id === "hancore.shibumi.media" ? mediaOwner : null }
    readonly property bool gameDecorationsPaused: pauseState.paused
    property bool barHidden: false
    readonly property int barSize: 28
    readonly property color urgent: "white"
  }
  Window {
    id: appWindow
    width: 120
    height: 48
    visible: true
    Visuals.NowPlayingVisualizer { id: visualizer; bar: fakeBar; anchors.centerIn: parent }
  }

  function snapshotJson() {
    const bars = []
    function visit(item) {
      if ("animDuration" in item && "loMin" in item) bars.push({ index: item.index, height: item.height })
      if ("children" in item) {
        for (let i = 0; i < item.children.length; i++) visit(item.children[i])
      }
    }
    visit(visualizer)
    bars.sort(function(a, b) { return a.index - b.index })
    return JSON.stringify({ paused: pauseState.paused, animating: visualizer.animating,
      playing: player.isPlaying, width: visualizer.implicitWidth, bars: bars,
      active: visualizer.active, visualizerPlaying: visualizer.playing,
      serviceFound: visualizer.mediaService !== null,
      barMatches: visualizer.bar === fakeBar,
      track: visualizer.activePlayer ? visualizer.activePlayer.trackTitle : "no-player",
      visible: visualizer.visible, windowVisible: appWindow.visible,
      parentVisible: visualizer.parent ? visualizer.parent.visible : false })
  }

  // Fixture-private IPC; runner selects this child PID in a private runtime.
  IpcHandler {
    target: "gaming-pause-fixture"
    function snapshot(): string { return test.snapshotJson() }
    function enable(value: bool): string { test.observerEnabled = value; return test.snapshotJson() }
    function hideBar(value: bool): string { fakeBar.barHidden = value; return test.snapshotJson() }
    function parseCase(name: string): string {
      const state = { schemaVersion: 1, signature: "fixture-gaming", pauseDecorations: true }
      let raw = ""
      if (name === "missing") raw = "{}"
      else if (name === "array") raw = "[]"
      else if (name === "malformed") raw = "{bad"
      else if (name === "oversized") raw = new Array(65538).join("x")
      else if (name === "version") { state.schemaVersion = 2; raw = JSON.stringify(state) }
      else if (name === "signature") { state.signature = "other-session"; raw = JSON.stringify(state) }
      else if (name === "string-flag") { state.pauseDecorations = "true"; raw = JSON.stringify(state) }
      else if (name === "optout") { state.pauseDecorations = false; raw = JSON.stringify(state) }
      else if (name === "valid") raw = JSON.stringify(state)
      return JSON.stringify({ paused: GamingPauseModel.decorationsPaused(raw, "fixture-gaming") })
    }
  }
}
