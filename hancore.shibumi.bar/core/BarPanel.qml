pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons

PanelWindow {
  id: barWindow

  required property var bar
  readonly property bool validScreen: screen !== null
    && screen.name !== ""
    && screen.width > 0
    && screen.height > 0
  // Let top shadows fade beyond barSize without enlarging layout or input:
  // V1 uses 8px blur + 1px offset; Full/Fit use 9px + 2px independently
  // of the V1 shadow toggle. Notch only needs its 1px antialiasing fringe.
  readonly property int shadowPadding: !bar.vertical && bar.position === "top"
    && bar.visualTokens
      ? bar.visualTokens.shellStyle === "shibumi"
        ? bar.visualTokens.shadowEnabled === true ? 9 : 0
        : ["full", "fit"].indexOf(bar.visualTokens.shellStyle) >= 0 ? 11
          : bar.visualTokens.shellStyle === "notch" ? 1 : 0
      : 0
  readonly property var layoutSession: dragSession
  readonly property real surfaceWidth: barSurfaceLoader.item
    ? Number(barSurfaceLoader.item.width) || 0 : 0
  readonly property int responsiveStage: barSurfaceLoader.item
    && "responsiveStage" in barSurfaceLoader.item
      ? Number(barSurfaceLoader.item.responsiveStage) || 0 : 0
  readonly property var responsiveProbe: barSurfaceLoader.item
    && "responsiveProbe" in barSurfaceLoader.item
      ? barSurfaceLoader.item.responsiveProbe : ({})

  property bool hoverRevealed: false

  Timer {
    id: autohideHideTimer
    interval: 1000
    onTriggered: {
      if (!hoverArea.containsMouse && !barWindow.nowPlayingExpanded && !barWindow.nowPlayingHovered && (!bar || typeof bar.activePopoutForScreen !== "function"
            || !bar.activePopoutForScreen(barWindow.screen ? barWindow.screen.name : ""))) {
        barWindow.hoverRevealed = false
      }
    }
  }

  function requestHide() {
    if (bar && bar.barAutohideEnabled) autohideHideTimer.restart()
  }

  function requestShow() {
    autohideHideTimer.stop()
    barWindow.hoverRevealed = true
  }

  readonly property bool autohideActive: bar && bar.barAutohideEnabled === true
  readonly property bool nowPlayingHovered: barSurfaceLoader.item
    && "nowPlayingHovered" in barSurfaceLoader.item
    ? (barSurfaceLoader.item.nowPlayingHovered === true) : false
  readonly property bool autohideRevealed: !autohideActive || hoverRevealed || nowPlayingExpanded || nowPlayingHovered || (dragSession && dragSession.editing)
  readonly property bool nowPlayingExpanded: barSurfaceLoader.item
    && "nowPlayingExpandLevel" in barSurfaceLoader.item
    ? (barSurfaceLoader.item.nowPlayingExpandLevel > 0.01) : false

  visible: bar.hostReady && bar.styleReady && validScreen && !bar.barHidden
    && windowRecovery.recoveryVisible
  // Keep the anchor window edge-local in every presentation and while editing.
  // The reserved desktop area remains the independent exclusiveZone below.
  implicitWidth: bar.vertical && validScreen ? bar.barSize : 0
  // Personal fork: the expanded now-playing notch draws below the bar, so a
  // horizontal window is tall enough for it at all times (no resize flash on
  // expand). The mask below keeps the transparent remainder click-through.
  readonly property int notchExpandedHeight: 380
  implicitHeight: !bar.vertical && validScreen
    ? Math.max(bar.barSize + shadowPadding, notchExpandedHeight) : 0
  color: "transparent"
  surfaceFormat.opaque: false

  anchors {
    top: bar.position === "top" || bar.vertical
    bottom: bar.position === "bottom" || bar.vertical
    left: bar.position === "left" || !bar.vertical
    right: bar.position === "right" || !bar.vertical
  }

  WlrLayershell.namespace: "shibumi-bar"
  WlrLayershell.layer: WlrLayer.Top
  exclusiveZone: autohideActive ? 0 : bar.barExclusiveSize
  WlrLayershell.keyboardFocus: dragSession.editing
    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // Personal fork: input covers only the bar strip (the 8px reveal strip while
  // auto-hidden, the expanded notch while open). Edit mode keeps the bar strip;
  // upstream's separate backdrop window owns outside-click dismissal.
  mask: Region {
    x: barWindow.bar.vertical && barWindow.bar.position === "right"
      ? Math.max(0, barWindow.width - barWindow.bar.barSize) : 0
    y: !barWindow.bar.vertical && barWindow.bar.position === "bottom"
      ? Math.max(0, barWindow.height - barWindow.bar.barSize) : 0
    width: !barWindow.bar.vertical ? barWindow.width : barWindow.bar.barSize
    height: barWindow.bar.vertical
      ? barWindow.height
      : (barWindow.nowPlayingExpanded ? barWindow.notchExpandedHeight : (barWindow.autohideActive && !barWindow.autohideRevealed ? 8 : barWindow.bar.barSize))
  }

  WindowRecovery {
    id: windowRecovery
    targetWindow: barWindow
    targetScreen: barWindow.screen
    recoveryAllowed: barWindow.bar.hostReady
      && barWindow.bar.styleReady
      && !barWindow.bar.barHidden
  }

  DragSession {
    id: dragSession
    layoutController: barWindow.bar.layoutController
    screenName: barWindow.screen ? String(barWindow.screen.name || "") : ""
    originX: barWindow.bar.vertical && barWindow.bar.position === "right"
      && barWindow.validScreen
        ? Math.max(0, barWindow.screen.width - barWindow.bar.barSize) : 0
    originY: !barWindow.bar.vertical && barWindow.bar.position === "bottom"
      && barWindow.validScreen
        ? Math.max(0, barWindow.screen.height - barWindow.bar.barSize) : 0
    geometryKey: JSON.stringify([
      barWindow.screen ? String(barWindow.screen.name || "") : "",
      barWindow.screen ? Number(barWindow.screen.width) || 0 : 0,
      barWindow.screen ? Number(barWindow.screen.height) || 0 : 0,
      barWindow.screen ? Number(barWindow.screen.devicePixelRatio) || 1 : 1,
      String(barWindow.bar.position || ""),
      Number(barWindow.bar.barSize) || 0
    ])
  }

  Component.onCompleted: bar.registerLayoutSession(dragSession)
  Component.onDestruction: {
    if (typeof bar.releasePopoutsForScreen === "function")
      bar.releasePopoutsForScreen(dragSession.screenName)
    bar.unregisterLayoutSession(dragSession)
  }

  DragGhostPanel {
    bar: barWindow.bar
    layoutSession: dragSession
    targetScreen: barWindow.screen
  }

  HostedPanelConnector {
    bar: barWindow.bar
    targetScreen: barWindow.screen
  }

  MouseArea {
    id: hoverArea
    // While hidden, this owns the thin edge sensor. Once revealed it must sit
    // behind the bar surface, otherwise it blocks the notch's own hover area
    // and the media control centre can never expand.
    z: barWindow.autohideRevealed ? 0 : 100
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: barWindow.autohideActive ? ((barWindow.autohideRevealed || barWindow.nowPlayingExpanded) ? barWindow.bar.barSize : 8) : 0
    hoverEnabled: true
    // This is a reveal sensor only. It must never consume clicks intended for
    // widgets once the bar is visible.
    acceptedButtons: Qt.NoButton
    onEntered: function() {
      barWindow.requestShow()
      if (barSurfaceLoader.item && typeof barSurfaceLoader.item.checkNotchHover === "function") {
        barSurfaceLoader.item.checkNotchHover(hoverArea.mouseX)
      }
    }
    onPositionChanged: function(mouse) {
      if (barSurfaceLoader.item && typeof barSurfaceLoader.item.checkNotchHover === "function") {
        barSurfaceLoader.item.checkNotchHover(mouse.x)
      }
    }
    onExited: barWindow.requestHide()
  }

  Loader {
    id: editBackdropLoader

    active: dragSession.editing
      && barWindow.visible && barWindow.backingWindowVisible
      && barWindow.bar.hostReady && barWindow.bar.styleReady
      && barWindow.validScreen && !barWindow.bar.barHidden
      && windowRecovery.recoveryVisible
    sourceComponent: Component {
      EditBackdropPanel {
        bar: barWindow.bar
        layoutSession: dragSession
        targetScreen: barWindow.screen
        barVisible: barWindow.visible && barWindow.backingWindowVisible
          && windowRecovery.recoveryVisible
      }
    }
  }

  Rectangle {
    anchors.fill: barSurfaceLoader
    visible: dragSession.editing
    color: Commons.Color.background
    opacity: 0.34
    z: 1
  }

  Loader {
    id: barSurfaceLoader

    width: barWindow.bar.vertical ? barWindow.bar.barSize : parent.width
    height: barWindow.bar.vertical ? parent.height : (barWindow.nowPlayingExpanded ? barWindow.notchExpandedHeight : barWindow.bar.barSize)
    x: barWindow.bar.vertical && barWindow.bar.position === "right"
      ? Math.max(0, parent.width - width) : 0
    y: !barWindow.bar.vertical && barWindow.bar.position === "bottom"
      ? Math.max(0, parent.height - height)
      : (barWindow.autohideActive && !barWindow.autohideRevealed ? -height : 0)

    Behavior on y {
      enabled: barWindow.autohideActive && !dragSession.editing
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    active: barWindow.bar.hostReady && barWindow.bar.styleReady
      && barWindow.validScreen && barWindow.bar.visualTokens !== null
    sourceComponent: active ? barWindow.bar.activeStyle.barSurfaceComponent : null
    z: 10
    onLoaded: {
      if (item && "layoutSession" in item) item.layoutSession = dragSession
      if (item && "screenName" in item)
        item.screenName = barWindow.screen ? String(barWindow.screen.name || "") : ""
    }
  }

  PopupWindow {
    id: tooltipWindow

    visible: barWindow.bar.styleReady
      && barWindow.bar.tooltipShown
      && barWindow.bar.targetBelongsToWindow(barWindow.bar.tooltipTarget, barWindow)
    color: "transparent"
    implicitWidth: tooltipSurfaceLoader.item
      ? Math.ceil(tooltipSurfaceLoader.item.implicitWidth)
      : 0
    implicitHeight: tooltipSurfaceLoader.item
      ? Math.ceil(tooltipSurfaceLoader.item.implicitHeight)
      : 0

    anchor {
      window: barWindow
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1

      onAnchoring: {
        const target = barWindow.bar.tooltipTarget
        if (!barWindow.bar.targetBelongsToWindow(target, barWindow)) return

        let localX = target.width / 2 - tooltipWindow.implicitWidth / 2
        const gap = barWindow.bar.activeStyle.tooltipGap
        let localY = target.height + gap
        if (barWindow.bar.position === "bottom")
          localY = -tooltipWindow.implicitHeight - gap
        else if (barWindow.bar.position === "left") {
          localX = target.width + gap
          localY = target.height / 2 - tooltipWindow.implicitHeight / 2
        } else if (barWindow.bar.position === "right") {
          localX = -tooltipWindow.implicitWidth - gap
          localY = target.height / 2 - tooltipWindow.implicitHeight / 2
        }

        const point = barWindow.contentItem.mapFromItem(target, localX, localY)
        tooltipWindow.anchor.rect.x = Math.round(point.x)
        tooltipWindow.anchor.rect.y = Math.round(point.y)
      }
    }

    Loader {
      id: tooltipSurfaceLoader

      anchors.fill: parent
      active: barWindow.bar.styleReady
        && barWindow.bar.visualTokens !== null
      sourceComponent: active ? barWindow.bar.activeStyle.tooltipSurfaceComponent : null
    }
  }
}
