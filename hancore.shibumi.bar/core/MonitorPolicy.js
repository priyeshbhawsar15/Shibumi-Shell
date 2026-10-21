.pragma library

// Keep controls reachable after the configured main display is disconnected.
function isSecondaryMonitor(monitors, name, mainDescription) {
  if (!name || !mainDescription || !monitors || monitors.length <= 1) return false
  var main = null
  for (var i = 0; i < monitors.length; i++) {
    if (String(monitors[i].description || "") === mainDescription) {
      main = monitors[i]
      break
    }
  }
  main = main || monitors[0]
  return String(main.name || "") !== name
}
