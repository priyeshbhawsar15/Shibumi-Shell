import QtQuick
import Quickshell
import "hancore.shibumi.bar/core/EntrySettings.js" as EntrySettings

// Widget entries reach WidgetSlot through a Repeater's modelData, which is what
// this reproduces: there a nested array stops being a JavaScript array.
ShellRoot {
  id: root

  property var entries: [{
    id: "fixture.widget",
    cities: [{ name: "Paris", zone: "Europe/Paris" }],
    nested: { list: [1, 2] },
    format: "HH:mm",
    count: 3,
    on: false
  }]

  function fail(message) {
    console.error("widget-settings-smoke:", message)
    Qt.exit(1)
  }

  Instantiator {
    id: instantiator
    model: root.entries
    delegate: QtObject {
      required property var modelData
    }
  }

  // Quickshell ignores Qt.exit while the config is still loading.
  Timer {
    interval: 50
    running: true
    onTriggered: {
      const settings = EntrySettings.fromEntry(instantiator.objectAt(0).modelData)
      if (!Array.isArray(settings.cities) || settings.cities.length !== 1)
        return root.fail("cities is not a real array")
      if (settings.cities[0].zone !== "Europe/Paris")
        return root.fail("cities lost its contents")
      if (!Array.isArray(settings.nested.list))
        return root.fail("a deeper array is not a real array")
      if (settings.format !== "HH:mm" || settings.count !== 3 || settings.on !== false)
        return root.fail("a plain setting changed")
      if ("id" in settings) return root.fail("id leaked into the settings")
      console.log("widget settings smoke passed")
      Qt.exit(0)
    }
  }
}
